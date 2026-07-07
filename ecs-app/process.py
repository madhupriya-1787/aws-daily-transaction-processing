import boto3
import csv
import os
from datetime import datetime

s3 = boto3.client("s3")

BUCKET = os.environ["BUCKET_NAME"]
INPUT_KEY = os.environ.get("INPUT_KEY", "input/transactions.csv")
OUTPUT_KEY = os.environ.get("OUTPUT_KEY", "output/daily_transaction_summary.csv")

local_input = "/tmp/transactions.csv"
local_output = "/tmp/daily_transaction_summary.csv"

print("Downloading transaction file from S3")
s3.download_file(BUCKET, INPUT_KEY, local_input)

total_transactions = 0
credit_transactions = 0
debit_transactions = 0
total_credit_amount = 0.0
total_debit_amount = 0.0
report_date = datetime.now().strftime("%Y-%m-%d")

with open(local_input, "r") as file:
    reader = csv.DictReader(file)

    for row in reader:
        total_transactions += 1
        txn_type = row["TransactionType"].strip().upper()
        amount = float(row["Amount"])

        if txn_type == "CREDIT":
            credit_transactions += 1
            total_credit_amount += amount
        elif txn_type == "DEBIT":
            debit_transactions += 1
            total_debit_amount += amount

with open(local_output, "w", newline="") as file:
    writer = csv.writer(file)
    writer.writerow([
        "Report Date",
        "Total Transactions",
        "Credit Transactions",
        "Debit Transactions",
        "Total Credit Amount",
        "Total Debit Amount"
    ])
    writer.writerow([
        report_date,
        total_transactions,
        credit_transactions,
        debit_transactions,
        total_credit_amount,
        total_debit_amount
    ])

print("Uploading summary report to S3")
s3.upload_file(local_output, BUCKET, OUTPUT_KEY)

print("Processing completed successfully")
