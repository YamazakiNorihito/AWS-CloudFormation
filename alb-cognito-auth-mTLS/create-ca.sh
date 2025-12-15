#!/bin/bash

# 引数からクライアント証明書の発行数を取得（デフォルト: 1）
Region="${1:-}"
Profile="${2:-}"
CLIENT_COUNT=${3:-1}

# バリデーションチェック
if [[ -z "$Region" ]]; then
  echo "エラー: Region（第1引数）は必須です"
  echo "使用方法: $0 <Region> <Profile> [CLIENT_COUNT]"
  echo "例: $0 ap-northeast-1 my-profile 3"
  exit 1
fi

if [[ -z "$Profile" ]]; then
  echo "エラー: Profile（第2引数）は必須です"
  echo "使用方法: $0 <Region> <Profile> [CLIENT_COUNT]"
  echo "例: $0 ap-northeast-1 my-profile 3"
  exit 1
fi

if ! [[ "$CLIENT_COUNT" =~ ^[0-9]+$ ]] || [[ "$CLIENT_COUNT" -lt 1 ]]; then
  echo "エラー: CLIENT_COUNT（第3引数）は1以上の整数である必要があります"
  exit 1
fi

mkdir -p mtls && cd mtls

# 1. ルートCA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -subj "/CN=PoC Root CA" -out ca.crt

# 2. サーバー証明書（ALB HTTPS用）
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=*.elb.amazonaws.com" -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256

# 3. クライアント証明書（mTLS用）
echo "クライアント証明書を ${CLIENT_COUNT} 件発行します..."
for i in $(seq 1 $CLIENT_COUNT); do
  CLIENT_NUM=$(printf "%03d" $i)
  echo "  - クライアント証明書 ${CLIENT_NUM} を作成中..."

  openssl genrsa -out client-${CLIENT_NUM}.key 2048
  openssl req -new -key client-${CLIENT_NUM}.key -subj "/CN=poc-device-${CLIENT_NUM}" -out client-${CLIENT_NUM}.csr
  openssl x509 -req -in client-${CLIENT_NUM}.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out client-${CLIENT_NUM}.crt -days 365 -sha256

  # PKCS#12形式（ブラウザインポート用）
  openssl pkcs12 -export -out client-${CLIENT_NUM}.p12 \
    -inkey client-${CLIENT_NUM}.key -in client-${CLIENT_NUM}.crt \
    -certfile ca.crt -passout pass:changeit
done

echo "クライアント証明書の発行が完了しました（${CLIENT_COUNT} 件）"

# 4. Trust Store用CAバンドル
cat ca.crt > ca-bundle.pem

# 5. サーバー証明書をACMにインポート
aws acm import-certificate \
    --certificate fileb://server.crt \
    --private-key fileb://server.key \
    --certificate-chain fileb://ca.crt \
    --region "${Region}" --profile "${Profile}"