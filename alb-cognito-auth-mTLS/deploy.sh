#!/bin/bash

set -euo pipefail

ALB_DNS="${1:-}"
ALB_ARN="${2:-}"
CertificateArn="${3:-}"
Region="${4:-}"
Profile="${5:-}"

# AWSアカウントIDを自動取得
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "${Profile}")

# -----------------------------
# S3バケット作成とCA証明書アップロード（CloudFormationより先に実行）
# -----------------------------
BUCKET_NAME="mtls-truststore-bucket-${AWS_ACCOUNT_ID}"

# バケットが存在しない場合は作成
if ! aws s3 ls "s3://${BUCKET_NAME}" --region "${Region}" --profile "${Profile}" 2>/dev/null; then
  echo "S3バケット ${BUCKET_NAME} を作成します..."
  aws s3 mb "s3://${BUCKET_NAME}" --region "${Region}" --profile "${Profile}"
fi

# CA証明書をアップロード
echo "CA証明書をアップロードします..."
aws s3 cp ./mtls/ca.crt "s3://${BUCKET_NAME}/ca-bundle.pem" --region "${Region}" --profile "${Profile}"

# -----------------------------
# Deploy CloudFormation
# -----------------------------
stack_name="stack-e2c5c500-77bd-4855-b437-f4c4cda3e3cb"

aws cloudformation deploy \
  --stack-name "${stack_name}" \
  --template-file "./template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
    ALBDnsName="${ALB_DNS}" \
    ALBArn="${ALB_ARN}" \
    CertificateArn="${CertificateArn}" \
    TrustStoreBucketName="${BUCKET_NAME}" \
  --region "${Region}" \
  --profile "${Profile}"

echo "CloudFormationスタック ${stack_name} が正常にデプロイされました。"