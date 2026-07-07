output "s3_bucket_name" {
  value = aws_s3_bucket.transaction_bucket.bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.transaction_app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.transaction_cluster.name
}

output "stepfunctions_name" {
  value = aws_sfn_state_machine.transaction_workflow.name
}

output "ec2_instance_id" {
  value = aws_instance.check_ec2.id
}
