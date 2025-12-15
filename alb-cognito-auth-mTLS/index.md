# mTLS + Cognito Authentication

## リリース手順

1. `../alb` でALBをデプロイ
2. `./create-ca.sh <Region> <Profile> [クライアント数]` で証明書作成
3. `./deploy.sh <ALB_DNS> <ALB_ARN> <ACM証明書ARN> <Region> <Profile>` でデプロイ
4. `./create-test-user.sh` でCognitoユーザー作成

## クライアント証明書インストール（Mac）

```bash
cd mtls
open client-001.p12  # パスワード: changeit
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt
```

## 動作確認

`https://<ALB_DNS>/` にアクセス
