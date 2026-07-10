resource "aws_cloudwatch_event_rule" "s3_upload_rule" {
  name        = "${var.project_name}-s3-upload-rule"
  description = "Trigger Step Functions when transaction CSV is uploaded to S3 input folder"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [data.aws_s3_bucket.transaction_bucket.bucket]
      }
      object = {
        key = [{
          prefix = "input/"
        }]
      }
    }
  })
}

resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "${var.project_name}-eventbridge-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.transaction_workflow.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "stepfunctions_target" {
  rule      = aws_cloudwatch_event_rule.s3_upload_rule.name
  target_id = "StartStepFunctions"
  arn       = aws_sfn_state_machine.transaction_workflow.arn
  role_arn  = aws_iam_role.eventbridge_role.arn
}

resource "aws_s3_bucket_notification" "eventbridge_notification" {
  bucket      = aws_s3_bucket.transaction_bucket.id
  eventbridge = true
}
