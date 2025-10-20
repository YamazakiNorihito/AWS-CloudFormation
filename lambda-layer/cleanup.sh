#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154

stackName="lambda-layer-playground"
BUCKET=${stackName}

echo "=========================================="
echo "Lambda Layer Cleanup Script"
echo "=========================================="
echo ""

# CloudFormation スタックの削除
echo "1. CloudFormation スタックを削除しています: ${stackName}"
if aws cloudformation describe-stacks --stack-name "${stackName}" >/dev/null 2>&1; then
    aws cloudformation delete-stack --stack-name "${stackName}"
    echo "   スタックの削除を開始しました。完了を待機しています..."
    aws cloudformation wait stack-delete-complete --stack-name "${stackName}"
    echo "   ✓ スタックの削除が完了しました。"
else
    echo "   スタック ${stackName} は存在しません。"
fi

echo ""

# S3バケットの削除
echo "2. S3バケットを削除しています: ${BUCKET}"
if aws s3 ls "s3://${BUCKET}" >/dev/null 2>&1; then
    echo "   バケット内のオブジェクトを削除しています..."
    aws s3 rm "s3://${BUCKET}" --recursive
    echo "   バケットを削除しています..."
    aws s3 rb "s3://${BUCKET}"
    echo "   ✓ S3バケットの削除が完了しました。"
else
    echo "   バケット ${BUCKET} は存在しません。"
fi

echo ""

# ローカルファイルの削除
echo "3. ローカルのビルド成果物を削除しています..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/lambda"

# Lambda function の zip と node_modules を削除
if [ -d "${PROJECT_ROOT}" ]; then
    echo "   - Lambda function の成果物を削除..."
    cd "${PROJECT_ROOT}" || exit 1

    if ls function*.zip 1> /dev/null 2>&1; then
        rm function*.zip
        echo "     ✓ function*.zip を削除しました。"
    fi

    if ls layer*.zip 1> /dev/null 2>&1; then
        rm layer*.zip
        echo "     ✓ layer*.zip を削除しました。"
    fi

    if [ -d "function/node_modules" ]; then
        rm -rf function/node_modules
        echo "     ✓ function/node_modules を削除しました。"
    fi

    if [ -d "layer/nodejs/node_modules" ]; then
        rm -rf layer/nodejs/node_modules
        echo "     ✓ layer/nodejs/node_modules を削除しました。"
    fi
else
    echo "   Lambda ディレクトリが存在しません。"
fi

echo ""
echo "=========================================="
echo "クリーンアップが完了しました！"
echo "=========================================="
