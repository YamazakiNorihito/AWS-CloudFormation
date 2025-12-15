#!/bin/bash

set -euo pipefail

USER_POOL_ID="${1:-}"
Region="${2:-}"
Profile="${3:-}"

  echo "UserPoolId: ${USER_POOL_ID}"

  # テストユーザー作成
  aws cognito-idp admin-create-user \
    --user-pool-id ${USER_POOL_ID} \
    --username testuser@example.com \
    --temporary-password TempPass123! \
    --user-attributes Name=email,Value=testuser@example.com Name=email_verified,Value=true \
    --region ${Region} \
    --profile ${Profile}

  # パスワードを確定（初回ログイン時のパスワード変更をスキップ）
  aws cognito-idp admin-set-user-password \
    --user-pool-id ${USER_POOL_ID} \
    --username testuser@example.com \
    --password Password1234! \
    --permanent \
    --region ${Region} \
    --profile ${Profile}

  echo ""
  echo "ログイン情報"
  echo ""
  echo "  | 項目       | 値                   |"
  echo "  |------------|----------------------|"
  echo "  | ユーザー名 | testuser@example.com |"
  echo "  | パスワード | Password1234!         |"