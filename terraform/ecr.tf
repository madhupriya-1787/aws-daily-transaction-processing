resource "aws_ecr_repository" "transaction_app" {
  name = "${var.project_name}-app"

  force_delete = true

  tags = {
    Name = "${var.project_name}-app"
  }
}
