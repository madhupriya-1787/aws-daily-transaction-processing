resource "aws_iam_role" "stepfunctions_role" {
  name = "${var.project_name}-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "stepfunctions_policy" {
  name = "${var.project_name}-stepfunctions-policy"
  role = aws_iam_role.stepfunctions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask",
          "iam:PassRole"
        ]
        Resource = "*"
      },
        {
       Effect = "Allow"
       Action = [
         "events:PutRule",
         "events:PutTargets",
         "events:DescribeRule"
      ]
      Resource = "*"
     }
    ]
  })
}

resource "aws_sfn_state_machine" "transaction_workflow" {
  name     = "${var.project_name}-workflow"
  role_arn = aws_iam_role.stepfunctions_role.arn

  definition = jsonencode({
    Comment = "Daily transaction processing workflow"
    StartAt = "CheckEC2Instance"

    States = {
      CheckEC2Instance = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ec2:describeInstances"
        Parameters = {
          InstanceIds = [aws_instance.check_ec2.id]
        }
        Next = "IsEC2Running"
      }

      IsEC2Running = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.Reservations[0].Instances[0].State.Name"
            StringEquals = "running"
            Next         = "RunECSTask"
          },
          {
            Variable     = "$.Reservations[0].Instances[0].State.Name"
            StringEquals = "stopped"
            Next         = "StartEC2Instance"
          }
        ]
        Default = "EC2ValidationFailed"
      }

      StartEC2Instance = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ec2:startInstances"
        Parameters = {
          InstanceIds = [aws_instance.check_ec2.id]
        }
        Next = "WaitForEC2"
      }

      WaitForEC2 = {
        Type    = "Wait"
        Seconds = 60
        Next    = "ValidateEC2Running"
      }

      ValidateEC2Running = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ec2:describeInstances"
        Parameters = {
          InstanceIds = [aws_instance.check_ec2.id]
        }
        Next = "IsEC2Ready"
      }

      IsEC2Ready = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.Reservations[0].Instances[0].State.Name"
            StringEquals = "running"
            Next         = "RunECSTask"
          }
        ]
        Default = "EC2ValidationFailed"
      }

      RunECSTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"

        Parameters = {
          Cluster        = aws_ecs_cluster.transaction_cluster.arn
          LaunchType     = "FARGATE"
          TaskDefinition = aws_ecs_task_definition.transaction_task.arn

          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [aws_default_subnet.default_a.id]
              SecurityGroups = [aws_security_group.ecs_sg.id]
              AssignPublicIp = "ENABLED"
            }
          }
        }

        End = true
      }

      EC2ValidationFailed = {
        Type  = "Fail"
        Error = "EC2ValidationFailed"
        Cause = "EC2 instance is not running or could not be started"
      }
    }
  })
}


