
# Private API Gateway Setup & Test

このプロジェクトは、VPC エンドポイントを使用して AWS Private API Gateway を構築し、ローカル環境から疎通確認するためのものです。

---

## 🔧 前提条件

- 既に VPC が作成されていること
- 自分のローカル PC からその VPC にアクセス可能であること(VPNなどで)
  - VPC内のEC2インスタンスにアクセスできるならそれでも良い

※参考

1. [Invoke a private API](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-private-api-test-invoke-url.html)
2. [How do I connect to a private API Gateway over a Direct Connect connection?](https://repost.aws/knowledge-center/direct-connect-private-api-gateway)

---

## 🧭 セットアップの流れ

1. **VPC エンドポイント (VPCe) の作成**  
   使用ファイル: `vpc-endpoint.yaml`

2. **Private API Gateway の作成**  
   使用ファイル: `api-gateway.yaml`

3. CURLで動作確認
   1. 実行条件
      1. VPN接続状態
      2. VPC内のEC2

  ```bash
  curl -v https://{apigateway-id}.execute-api.{region}.amazonaws.com/prod/api
  or

  curl -vk --http1.1 \
    -H 'x-apigw-api-id: {apigateway-id}' \
    https://vpce-{vpce-dns}.execute-api.{region}.vpce.amazonaws.com/prod/api

  curl -H 'x-apigw-api-id: z7swisn2di' \
    https://vpce-0aa258a344d2e5a50-dwghf19j.execute-api.us-east-2.vpce.amazonaws.com/prod/api
  ```

---

## 🚀 デプロイ手順

### ① VPC エンドポイントの作成

```bash
aws cloudformation deploy \
  --stack-name "vpcendpoint-stack" \
  --template-file "./vpc-endpoint.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides file://vpc-endpoint-parameters.json \
  --region "{region}" \
  --profile "{profile}"
```

### ② Private API Gateway の作成

```bash
aws cloudformation deploy \
  --stack-name "api-gateway-private-stack" \
  --template-file "./api-gateway.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides file://api-gateway-parameters.json \
  --region "{region}" \
  --profile "{profile}"
```
