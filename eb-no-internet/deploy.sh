#!/bin/bash

set -euo pipefail

# プロファイル名の設定
PROFILE=""
BUCKET=""
REGION="us-east-1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# -----------------------------
# Create Deploy S3
# -----------------------------
POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudformation.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
EOF
)

if ! aws s3 ls "s3://${BUCKET}" --region "${REGION}" --profile "${PROFILE}" ; then
  echo "バケットが存在しません。新しいバケットを作成します: ${BUCKET}"
  aws s3 mb "s3://${BUCKET}" --region "${REGION}" --profile "${PROFILE}"
  echo "バケットが完全に動作するのを待っています..."
  sleep 20 

  if aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "${POLICY_JSON}"  --region "${REGION}" --profile "${PROFILE}" >/dev/null 2>&1; then
      echo "バケットポリシーが正常に適用されました。"
  else
      echo "エラー: バケットポリシーを適用できませんでした。" >&2
      exit 1
  fi
fi
# テンプレートをS3にアップロード
aws s3 sync . "s3://${BUCKET}/" --exclude "deploy.sh" --exclude "bucket-policy.json" --profile "${PROFILE}"

# -----------------------------
# EB Deploy Frontend
# -----------------------------
stack_name="stack-eb-frontend"
EnvironmentName="local"

aws cloudformation deploy \
  --stack-name "${stack_name}" \
  --s3-bucket "${BUCKET}" \
  --template-file "./frontend/template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
      "EnvironmentName=${EnvironmentName}" \
      "TemplateBucket=${BUCKET}" \
  --region "${REGION}" \
  --profile "${PROFILE}"


# -----------------------------
#  key-pair-nginx-${EnvironmentName}.pem の作成
# -----------------------------
KEY_NAME="key-pair-nginx-${EnvironmentName}"
KEY_FILE="${KEY_NAME}.pem"

if ! aws ec2 describe-key-pairs --key-names "${KEY_NAME}" --region "${REGION}" --profile "${PROFILE}" >/dev/null 2>&1; then
  echo "キーペアが存在しません。新しいキーペアを作成します: ${KEY_NAME}"
  aws ec2 create-key-pair --key-name "${KEY_NAME}" --region "${REGION}" --profile "${PROFILE}" --query "KeyMaterial" --output text > "${KEY_FILE}"
  chmod 400 "${KEY_FILE}"
else
  echo "キーペアが既に存在します: ${KEY_NAME}"
fi

# -----------------------------
#  app-nginx.zip の作成
# -----------------------------
ZIP_TEMP_DIR=$(mktemp -d)
ZIP_FILE="${ZIP_TEMP_DIR}/app-nginx.zip"
(
  cd "${SCRIPT_DIR}/nginx" && \
  zip -r "${ZIP_FILE}" . -x '*.DS_Store'
)
aws s3 cp "${ZIP_FILE}" "s3://${BUCKET}/app-nginx.zip" --content-type "application/zip" --region "${REGION}" --profile "${PROFILE}"

# -----------------------------
#  EB Deploy Backend
# -----------------------------
VpcId=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-VpcId'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
DefaultSecurityGroup=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-DefaultSecurityGroup'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
PrivateSubnetAZ1Id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-PrivateSubnetAZ1Id'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
PrivateSubnetAZ2Id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-PrivateSubnetAZ2Id'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
LoadBalancerARN=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-LoadBalancerARN'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
LoadBalancerDNSName=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-LoadBalancerDNSName'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
PrivateRouteTable1Id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-PrivateRouteTable1Id'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")
PrivateRouteTable2Id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-PrivateRouteTable2Id'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}")

stack_name="stack-eb-backend"
aws cloudformation deploy \
  --stack-name "${stack_name}" \
  --s3-bucket "${BUCKET}" \
  --template-file "./backend/template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
      "EnvironmentName=${EnvironmentName}" \
      "DomainName=${LoadBalancerDNSName}" \
      "VpcId=${VpcId}" \
      "PrivateSubnetAz1Id=${PrivateSubnetAZ1Id}" \
      "PrivateSubnetAz2Id=${PrivateSubnetAZ2Id}" \
      "SharedLoadBalancerArn=${LoadBalancerARN}" \
      "ALBSecurityGroupId=${DefaultSecurityGroup}" \
      "SharedLoadBalancerArn=${LoadBalancerARN}" \
      "TemplateBucket=${BUCKET}" \
      "PrivateRouteTable1Id=${PrivateRouteTable1Id}" \
      "PrivateRouteTable2Id=${PrivateRouteTable2Id}" \
  --region "${REGION}" \
  --profile "${PROFILE}"

echo "CloudFormationスタック ${stack_name} が正常にデプロイされました。"