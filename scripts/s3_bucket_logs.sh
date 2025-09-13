#!/bin/bash

BUCKET_NAME="stepan-static-web-log"
AWS_REGION="eu-west-1"
LOCAL_LOG_PATH="/var/log/nginx/access.log"

# ---- Check if the bucket exists ----

echo "Checking if bucket '$BUCKET_NAME' exists..."
aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Bucket '$BUCKET_NAME' already exists. No action needed."
else
  echo "Bucket '$BUCKET_NAME' not found. Creating it now in region $AWS_REGION..."
  aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
  echo "Bucket '$BUCKET_NAME' created successfully."
fi

# ---- Check if the local log file is empty
LOCAL_LOG_PATH="/var/log/nginx/access.log"
echo "Starting log archival process for bucket '${BUCKET_NAME}'..."
if [ ! -s "$LOCAL_LOG_PATH" ]; then
  echo "Local log file is empty. No action needed."
  exit 0
fi

# ---- Create a new log file and send it to the bucket ----
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
S3_OBJECT_NAME="access_${TIMESTAMP}.log"
S3_URI="s3://${BUCKET_NAME}/${S3_OBJECT_NAME}"
echo "Uploading logs to a new timestamped file: ${S3_URI}"
aws s3 cp "$LOCAL_LOG_PATH" "$S3_URI"
echo "Log file successfully uploaded to S3."
echo "Clearing local log file at ${LOCAL_LOG_PATH}..."
truncate -s 0 "$LOCAL_LOG_PATH"
echo "Local log file cleared."
echo "Log archival process finished."