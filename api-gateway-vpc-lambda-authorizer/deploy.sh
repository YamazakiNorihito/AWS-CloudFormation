#!/bin/bash
set -euo pipefail
BUCKET=$1
REGION=$2
PROFILE=$3

# -----------------------------
# Create S3 Bucket for Deployment
# -----------------------------
./create_s3_bucket_if_not_exists.sh "${BUCKET}" "${REGION}" "${PROFILE}"

# テンプレートをS3にアップロード
aws s3 sync . "s3://${BUCKET}/" --exclude "deploy*" --profile "${PROFILE}"

# -----------------------------
# Deploy CloudFormation
# -----------------------------
# AWS CloudFormationスタックを作成
aws cloudformation deploy \
  --stack-name "api-gateway-in-vpc-stack" \
  --template-file "templates/template.yaml" \
  --s3-bucket "${BUCKET}" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides TemplateBucket="${BUCKET}" TemplateKey="templates" EnvironmentName="apigateway-lambda" \
  --region "${REGION}" \
  --profile "${PROFILE}"


echo "正常にデプロイされました。"