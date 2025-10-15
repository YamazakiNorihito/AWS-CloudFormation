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
STACK_NAME=ec2-llm-stack
TEMPLATE_FILE=template.yaml
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

deploy_initial_stack() {
  log "Deploying CloudFormation stack $STACK_NAME..."
  aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameter-overrides SubnetId="$SUBNET_ID" KeyName="$KEY_NAME" VpcId="$VPC_ID" \
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

  aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query "Stacks[0].Outputs" \
  --output table
}

main() {
  deploy_initial_stack
  wait_for_instance

  log "All steps completed successfully."
}

main "$@"
