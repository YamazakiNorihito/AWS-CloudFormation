# AWS クライアント VPN セットアップ

このプロジェクトは、証明書ベースの認証を使用して、AWS VPC 内のリソースに安全にアクセスするための AWS Client VPN のセットアップ方法を示します。

## 前提条件

- AWS CLI が適切な認証情報とリージョンで設定されていること
- Easy-RSA がインストールされていること
- OpenVPN クライアント（例：Tunnelblick や OpenVPN CLI, AWS Client VPN）がインストールされていること

## 手順

### 1. 証明書の生成

1. Easy-RSA のインストール：

   ```bash
   brew install easy-rsa
   ```

2. Easy-RSA スクリプトを作業ディレクトリにコピー：

   ```bash
   cp -R $(brew --prefix easy-rsa)/libexec/* .
   ```

3. PKI 環境を初期化：

   ```bash
   ./easyrsa init-pki
   ```

4. ルート CA を作成（パスフレーズなし）：

   ```bash
   ./easyrsa build-ca nopass
   # コモンネームを入力（例："MyVPN-CA"）
   ```

5. サーバー証明書のリクエストを生成：

   ```bash
   ./easyrsa gen-req server nopass
   # コモンネームを入力（例："vpn.example.com"）
   ```

6. サーバー証明書を CA で署名：

   ```bash
   ./easyrsa sign-req server server
   ```

7. クライアント証明書のリクエストを生成：

   ```bash
   ./easyrsa gen-req client1 nopass
   # コモンネームを入力（例："client1"）
   ```

8. クライアント証明書を CA で署名：

   ```bash
   ./easyrsa sign-req client client1
   ```

### 2. サーバー証明書を ACM にインポート

```bash
aws acm import-certificate \
  --certificate fileb://pki/issued/server.crt \
  --private-key fileb://pki/private/server.key \
  --certificate-chain fileb://pki/ca.crt \
  --region <AWS_REGION>
```

### 3. クライアント VPN エンドポイントのデプロイ

CloudFormation または AWS CLI を使用してクライアント VPN エンドポイントを作成します。例として CloudFormation を使用：

```bash
aws cloudformation deploy \
  --stack-name my-client-vpn-stack \
  --template-file client-vpn-endpoint.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides file://client-vpn-endpoint-parameters.json \
  --region <AWS_REGION>
```

### 4. クライアントプロファイルのダウンロードと設定

1. AWS コンソールの VPC > Client VPN Endpoints に移動
2. 作成したエンドポイントを選択し、クライアント構成ファイル（.ovpn）をダウンロード
3. 以下のように .ovpn ファイルに証明書とキーを埋め込む：

   ```text
   <ca>
   (pki/ca.crt の内容)
   </ca>
   <cert>
   (pki/issued/client1.crt の内容)
   </cert>
   <key>
   (pki/private/client1.key の内容)
   </key>
   reneg-sec 0
   verify-x509-name vpn.example.com name
   ```

### 5. OpenVPN クライアントで接続

```bash
openvpn --config client-config.ovpn
```

接続確認：

```bash
ping <VPC 内のリソースの IP>
```

## 証明書ファイルの一覧

| 目的               | パス                              |
|--------------------|-----------------------------------|
| CA 証明書         | pki/ca.crt                        |
| サーバー証明書     | pki/issued/server.crt             |
| サーバープライベートキー | pki/private/server.key        |
| クライアント証明書  | pki/issued/client1.crt            |
| クライアントプライベートキー | pki/private/client1.key   |

## 既存環境に VPN を接続する場合

client-vpn-endpoint-only.yaml のテンプレートを使用してください：

```bash
aws cloudformation deploy \
  --stack-name my-client-vpn-only-stack \
  --template-file client-vpn-endpoint-only.yaml \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides file://client-vpn-endpoint-only-param.json \
  --region <AWS_REGION>
```
