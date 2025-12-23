#!/bin/bash

set -euo pipefail

# プロファイル名の設定
PROFILE="dev-medcom.ne.jp"
BUCKET="internal-alb-test-nori"
REGION="us-east-1"
EnvironmentName="internal-alb-test-nori"

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
# -----------------------------
# Create Deploy S3
# -----------------------------
if ! aws s3 ls "s3://${BUCKET}" --region "${REGION}" --profile "${PROFILE}" ; then
  echo "バケットが存在しません。新しいバケットを作成します: ${BUCKET}"
  aws s3 mb "s3://${BUCKET}" --region "${REGION}" --profile "${PROFILE}"
  echo "バケットが完全に動作するのを待っています..."
  sleep 20 

  max_retries=5
  count=0
  until aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "${POLICY_JSON}"  --region "${REGION}" --profile "${PROFILE}"
  do
    count=$((count+1))
    if [ "${count}" -eq "${max_retries}" ]; then
      echo "Failed to apply policy after ${max_retries} attempts."
      exit 1
    fi
    echo "Retrying to apply policy...attempt ${count}"
    sleep $((10 * count))
  done
fi
# テンプレートをS3にアップロード
aws s3 sync . "s3://${BUCKET}/" --exclude "deploy.sh" --exclude "bucket-policy.json" --profile "${PROFILE}"

# -----------------------------
# Deploy CloudFormation
# -----------------------------
stack_name="stack-e2c5c500-77bd-4855-b437-f4c4cda3e3ca"

aws cloudformation deploy \
  --stack-name "${stack_name}" \
  --s3-bucket "${BUCKET}" \
  --template-file "./template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
    EnvironmentName="${EnvironmentName}" \
    TemplateBucket="${BUCKET}" \
  --region "${REGION}" \
  --profile "${PROFILE}"

echo "CloudFormationスタック ${stack_name} が正常にデプロイされました。"