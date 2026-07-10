resource "aws_ecs_cluster" "transaction_cluster" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "transaction_task" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "transaction-app"
      image     = "${aws_ecr_repository.transaction_app.repository_url}:latest"
      essential = true

      environment = [
  {
    name  = "BUCKET_NAME"
    value = data.aws_s3_bucket.transaction_bucket.bucket
  },
  {
    name  = "INPUT_KEY"
    value = "intermediate/cleaned_transactions.csv"
  },
  {
    name  = "OUTPUT_KEY"
    value = "output/daily_transaction_summary.csv"
  }
]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
