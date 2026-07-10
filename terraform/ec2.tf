data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "check_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_default_subnet.default_a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y python3

mkdir -p /opt/transaction-processing

cat <<'PYTHON' > /opt/transaction-processing/preprocess.py
import csv
import subprocess
import os
import sys

BUCKET_NAME = "${data.aws_s3_bucket.transaction_bucket.bucket}"
INPUT_KEY = "input/transactions.csv"
OUTPUT_KEY = "intermediate/cleaned_transactions.csv"

os.makedirs("/tmp/data", exist_ok=True)

input_file = "/tmp/data/transactions.csv"
output_file = "/tmp/data/cleaned_transactions.csv"

def run(cmd):
    subprocess.run(cmd, check=True)

try:
    print("Downloading input file...")
    run([
        "aws","s3","cp",
        f"s3://{BUCKET_NAME}/{INPUT_KEY}",
        input_file
    ])

    with open(input_file, "r", newline="", encoding="utf-8") as infile:
        reader = csv.DictReader(infile)

        rows = []
        negative_count = 0

        for row in reader:
            amount = float(row["amount"])

            if amount < 0:
                negative_count += 1
                continue

            rows.append(row)

        fieldnames = reader.fieldnames

    with open(output_file, "w", newline="", encoding="utf-8") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Negative records removed: {negative_count}")

    print("Uploading cleaned file...")
    run([
        "aws","s3","cp",
        output_file,
        f"s3://{BUCKET_NAME}/{OUTPUT_KEY}"
    ])

    print("Preprocessing completed successfully.")

except Exception as e:
    print("Error:", e)
    sys.exit(1)

PYTHON

chmod +x /opt/transaction-processing/preprocess.py
EOF

  tags = {
    Name = "${var.project_name}-check-ec2"
  }
}
