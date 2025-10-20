#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154

stackName="lambda-layer-playground"
BUCKET=${stackName}

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

if ! aws s3 ls "s3://${BUCKET}" >/dev/null 2>&1; then
    echo "バケットが存在しません。新しいバケットを作成します: ${BUCKET}"

    aws s3 mb "s3://${BUCKET}"

    sleep 20
    if aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "${POLICY_JSON}" >/dev/null 2>&1; then
        echo "バケットポリシーが正常に適用されました。"
    else
        echo "エラー: バケットポリシーを適用できませんでした。" >&2
        exit 1
    fi
else
    echo "バケット ${BUCKET} は既に存在します。"
fi


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


PROJECT_ROOT="${SCRIPT_DIR}/lambda"

cd "${PROJECT_ROOT}" || exit 1

now=$(date +%s)

if ls layer*.zip 1> /dev/null 2>&1; then
  rm layer*.zip
fi

cd "${PROJECT_ROOT}/layer/nodejs" || exit 1

if [ -d "node_modules" ]; then
  rm -rf node_modules
fi

npm install --production

cd "${PROJECT_ROOT}/layer" || exit 1
zip -r ../layer-${now}.zip nodejs/ -x "*.DS_Store" "*/__pycache__/*" "*/.*"

cd "$PROJECT_ROOT" || exit 1

# function.zip を作成
if ls function*.zip 1> /dev/null 2>&1; then
  rm function*.zip
fi

cd "${PROJECT_ROOT}/function" || exit 1

if [ -d "node_modules" ]; then
  rm -rf node_modules
fi

npm install --production

zip -r ../function-${now}.zip . -x "*.DS_Store" "*/.*"

cd "$PROJECT_ROOT" || exit 1

aws s3 cp "layer-${now}.zip" "s3://${BUCKET}/layer-${now}.zip" --content-type "application/zip"
aws s3 cp "function-${now}.zip" "s3://${BUCKET}/function-${now}.zip" --content-type "application/zip"

cd ${SCRIPT_DIR} || exit 1

aws cloudformation deploy  \
    --stack-name "${stackName}"  \
    --template-file "./template.yaml"  \
    --parameter-overrides "CodeVersion=${now}" \
                            "BucketName=${BUCKET}" \
    --capabilities CAPABILITY_NAMED_IAM  \
   