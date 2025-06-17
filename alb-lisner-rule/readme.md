
# ALB Listener Rule to S3 Routing Playground

このプロジェクトは、**Application Load Balancer (ALB)** のリスナールールを活用して、**クライアントから直接 S3 バケットにアクセスできるルートを設定する**ための実験用リポジトリです。

## 🔧 概要

- 既存の ALB に対してリスナールールを追加し、特定パスへのアクセスを S3 にルーティングします。
- VPC エンドポイント経由で S3 にセキュアにアクセスします。
- 静的ウェブファイルをホストしている S3 バケットにアクセス可能にします。

## 📁 ディレクトリ構成

```bash
.
├── s3-vpc-endpoint.yaml         # S3 VPC エンドポイントの CloudFormation テンプレート
├── s3-vpc-endpoint-param.json   # 上記テンプレート用のパラメータファイル
├── alb-listener-rule.yaml                # ALB リスナールールの CloudFormation テンプレート
├── alb-listener-rule-param.json          # 上記テンプレート用のパラメータファイル
└── readme.md
```

## 🚀 デプロイ手順

```bash
aws cloudformation deploy \
  --stack-name s3-access-vpc-endpoint-stack \
  --template-file s3-vpc-endpoint.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides file://s3-vpc-endpoint-param.json \
  --region <AWS_REGION>
```

```bash
aws cloudformation deploy \
  --stack-name alb-to-s3-routing-rule-stack \
  --template-file alb-listener-rule.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides file://alb-listener-rule-param.json \
  --region <AWS_REGION>
```
