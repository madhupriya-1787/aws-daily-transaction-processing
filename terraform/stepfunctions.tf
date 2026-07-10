resource "aws_iam_role" "stepfunctions_role" {
  name = "${var.project_name}-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "states.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
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
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
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
    Comment = "Transaction processing workflow with EC2 preprocessing and ECS processing"

    StartAt = "CheckEC2Instance"

    States = {
      CheckEC2Instance = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ec2:describeInstances"

        Parameters = {
          InstanceIds = [
            aws_instance.check_ec2.id
          ]
        }

        Next = "IsEC2Running"
      }

      IsEC2Running = {
        Type = "Choice"

        Choices = [
          {
            Variable     = "$.Reservations[0].Instances[0].State.Name"
            StringEquals = "running"
            Next         = "WaitForSSM"
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
          InstanceIds = [
            aws_instance.check_ec2.id
          ]
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
          InstanceIds = [
            aws_instance.check_ec2.id
          ]
        }

        Next = "IsEC2Ready"
      }

      IsEC2Ready = {
        Type = "Choice"

        Choices = [
          {
            Variable     = "$.Reservations[0].Instances[0].State.Name"
            StringEquals = "running"
            Next         = "WaitForSSM"
          }
        ]

        Default = "EC2ValidationFailed"
      }

      WaitForSSM = {
        Type    = "Wait"
        Seconds = 20
        Next    = "RunPreprocessing"
      }

      RunPreprocessing = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ssm:sendCommand"

        Parameters = {
          InstanceIds = [
            aws_instance.check_ec2.id
          ]

          DocumentName = "AWS-RunShellScript"

          Parameters = {
            commands = [
              "python3 /opt/transaction-processing/preprocess.py"
            ]
          }
        }

        ResultPath = "$.PreprocessCommand"
        Next       = "WaitForPreprocessing"
      }

      WaitForPreprocessing = {
        Type    = "Wait"
        Seconds = 10
        Next    = "CheckPreprocessingStatus"
      }

      CheckPreprocessingStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ssm:getCommandInvocation"

        Parameters = {
          "CommandId.$" = "$.PreprocessCommand.Command.CommandId"
          InstanceId    = aws_instance.check_ec2.id
        }

        ResultPath = "$.PreprocessStatus"
        Next       = "IsPreprocessingComplete"
      }

      IsPreprocessingComplete = {
        Type = "Choice"

        Choices = [
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "Success"
            Next         = "RunECSTask"
          },
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "Pending"
            Next         = "WaitForPreprocessing"
          },
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "InProgress"
            Next         = "WaitForPreprocessing"
          },
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "Delayed"
            Next         = "WaitForPreprocessing"
          },
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "Failed"
            Next         = "PreprocessingFailed"
          },
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "Cancelled"
            Next         = "PreprocessingFailed"
          },
          {
            Variable     = "$.PreprocessStatus.Status"
            StringEquals = "TimedOut"
            Next         = "PreprocessingFailed"
          }
        ]

        Default = "PreprocessingFailed"
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
              Subnets = [
                aws_default_subnet.default_a.id
              ]

              SecurityGroups = [
                aws_security_group.ecs_sg.id
              ]

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

      PreprocessingFailed = {
        Type  = "Fail"
        Error = "EC2PreprocessingFailed"
        Cause = "The EC2 preprocessing command failed, was cancelled, or timed out"
      }
    }
  })
}
