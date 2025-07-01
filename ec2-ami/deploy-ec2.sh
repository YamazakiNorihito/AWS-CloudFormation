#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--region REGION] [--profile PROFILE]"
  exit 1
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Configuration
STACK_NAME=ec2-launch-stack
TEMPLATE_FILE=base-ec2-instance.yaml
INSTANCE_TYPE=t3.micro
SUBNET_ID=
KEY_NAME=
VPC_ID=
REGION=us-east-2
PROFILE=

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --help) usage ;;
    *) log "Unknown option: $1"; usage ;;
  esac
done

get_latest_ami() {
  log "Retrieving latest Amazon Linux 2 AMI ID..."
  LATEST_AMI_ID=$(aws ec2 describe-images --owners amazon \
    --filters Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2 Name=state,Values=available \
    --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
    --region "$REGION" --profile "$PROFILE" --output text)
  log "Latest AMI ID: $LATEST_AMI_ID"
}

deploy_initial_stack() {
  log "Deploying CloudFormation stack $STACK_NAME..."
  aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameter-overrides InstanceType="$INSTANCE_TYPE" SubnetId="$SUBNET_ID" KeyName="$KEY_NAME" VpcId="$VPC_ID" \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --region "$REGION" \
    --profile "$PROFILE"
}

wait_for_instance() {
  log "Waiting for instance to be running..."
  INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
    --region "$REGION" --profile "$PROFILE" --output text)
  log "Instance ID: $INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION" --profile "$PROFILE"
  aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID" --region "$REGION" --profile "$PROFILE"
}

create_ami() {
  AMI_NAME="${STACK_NAME}-AMI-$(date +%Y%m%d%H%M)"
  log "Creating AMI $AMI_NAME from instance $INSTANCE_ID..."
  NEW_AMI_ID=$(aws ec2 create-image \
    --instance-id "$INSTANCE_ID" \
    --name "$AMI_NAME" \
    --description "AMI of instance created on $(date +'%Y-%m-%d %H:%M')" \
    --no-reboot \
    --region "$REGION" \
    --profile "$PROFILE" \
    --tag-specifications \
      'ResourceType=image,Tags=[{Key=Name,Value='"$AMI_NAME"'},{Key=Environment,Value=dev}]' \
      'ResourceType=snapshot,Tags=[{Key=Name,Value='"$AMI_NAME"'-snap}]' \
    --query 'ImageId' --output text)
  log "New AMI ID: $NEW_AMI_ID"
}

wait_for_ami() {
  log "Waiting for AMI $NEW_AMI_ID to become available..."
  aws ec2 wait image-available --image-ids "$NEW_AMI_ID" --region "$REGION" --profile "$PROFILE"
  log "AMI $NEW_AMI_ID is now available."
}

wait_for_new_instance() {
  log "Waiting for new instance to be running..."
  NEW_INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}-from-AMI" \
    --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" \
    --region "$REGION" --profile "$PROFILE" --output text)
  log "New Instance ID: $NEW_INSTANCE_ID"
  aws ec2 wait instance-running --instance-ids "$NEW_INSTANCE_ID" --region "$REGION" --profile "$PROFILE"
  aws ec2 wait instance-status-ok --instance-ids "$NEW_INSTANCE_ID" --region "$REGION" --profile "$PROFILE"
}

deploy_new_stack() {
  log "Updating stack $STACK_NAME with new AMI $NEW_AMI_ID..."
  aws cloudformation deploy \
    --stack-name "${STACK_NAME}-from-AMI" \
    --template-file ec2-launch-from-ami.yaml \
    --parameter-overrides InstanceType="$INSTANCE_TYPE" SubnetId="$SUBNET_ID" KeyName="$KEY_NAME" VpcId="$VPC_ID" AMIId="$NEW_AMI_ID" \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --region "$REGION" \
    --profile "$PROFILE"
}

main() {
  log "=== Step 1: Launch initial EC2 instance ==="
  get_latest_ami
  deploy_initial_stack
  wait_for_instance
  log "=== Step 1 complete: Instance $INSTANCE_ID is running ==="

  log "=== Step 2: Create AMI from instance ==="
  create_ami
  wait_for_ami
  log "=== Step 2 complete: AMI $NEW_AMI_ID is available ==="

  log "=== Step 3: Launch new EC2 from AMI ==="
  deploy_new_stack
  wait_for_new_instance
  log "=== Step 3 complete: New instance $NEW_INSTANCE_ID is running ==="

  log "All steps completed successfully."
}

main "$@"
