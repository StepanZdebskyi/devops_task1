#!/bin/bash

set -e

EMAIL_ADDRESS="stepan.zdebskyi@techmagic.co"
SNS_TOPIC_NAME="Stepan-EC2-Instance-Down-Alert"

echo "Fetching EC2 instance metadata..."

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

echo "Instance ID: ${INSTANCE_ID}"
echo "AWS Region: ${AWS_REGION}"

# --- Create a unique alarm name by appending the instance ID ---
ALARM_NAME="Stepan-EC2-Instance-Down-Alert-${INSTANCE_ID}"

echo "Checking for existing SNS topic named '${SNS_TOPIC_NAME}'..."
EXISTING_TOPIC_ARN=$(aws sns list-topics --region "${AWS_REGION}" --query "Topics[?ends_with(TopicArn, \`:${SNS_TOPIC_NAME}\`)]|[0].TopicArn" --output text)

if [ "$EXISTING_TOPIC_ARN" != "None" ] && [ -n "$EXISTING_TOPIC_ARN" ]; then
    echo "Found existing topic with ARN: ${EXISTING_TOPIC_ARN}. Deleting it now."
    aws sns delete-topic --topic-arn "${EXISTING_TOPIC_ARN}" --region "${AWS_REGION}"
    echo "Existing topic deleted."
else
    echo "No existing SNS topic named '${SNS_TOPIC_NAME}' found. Proceeding to create."
fi

echo "Creating new SNS topic: ${SNS_TOPIC_NAME}..."
TOPIC_ARN=$(aws sns create-topic --name "${SNS_TOPIC_NAME}" --region "${AWS_REGION}" --query 'TopicArn' --output text)
echo "SNS Topic ARN: ${TOPIC_ARN}"

echo "Subscribing ${EMAIL_ADDRESS} to the SNS topic..."
aws sns subscribe \
  --topic-arn "${TOPIC_ARN}" \
  --protocol email \
  --notification-endpoint "${EMAIL_ADDRESS}" \
  --region "${AWS_REGION}"

echo "IMPORTANT: A confirmation email has been sent to ${EMAIL_ADDRESS}. You must click the link in that email to confirm the subscription."

echo "Setting up CloudWatch alarm named '${ALARM_NAME}' for instance '${INSTANCE_ID}'..."
aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_NAME}" \
  --alarm-description "Alarm when EC2 instance ${INSTANCE_ID} status checks fail for 2 consecutive minutes" \
  --metric-name StatusCheckFailed \
  --namespace AWS/EC2 \
  --statistic Maximum \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions "Name=InstanceId,Value=${INSTANCE_ID}" \
  --alarm-actions "${TOPIC_ARN}" \
  --region "${AWS_REGION}"

echo "CloudWatch alarm created successfully."
echo "You will now be notified via email if this instance fails its status check."