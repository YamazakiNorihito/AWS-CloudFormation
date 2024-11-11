
# ALB を経由して S3 の StaticFile を返す構成ガイド

このドキュメントでは、ALB（Application Load Balancer）を使用して S3 バケット内の静的ファイルを配信する構成について説明します。

## 構成ポイント

1. **S3 バケット名をドメイン名と一致させる**
   - S3 バケット名をドメイン名（例: `example.com`）と同じにすること
   - 例: `example.com` というドメインの場合、S3 バケット名も `example.com` とします。

2. **Listener Rule の `forward` 設定**
   - ALB のリスナーで、特定のパスパターンに一致するリクエストを S3 に転送します。
   - リスナー設定で、`path-pattern` に一致するリクエストを正しく S3 バケット内のファイルにマッピングします。

3. **パス構成の整合性**
   - 例えば、`/s3-static/` パスを使用する場合、S3 バケットのファイルパスは `s3-static/index.html` のように配置します。

---

## 設定例

以下は、AWS コンソールや AWS CLI を使用して設定を行う例です。

### 1. S3 バケットの作成

```bash
aws s3 mb s3://example.com
aws s3 cp ./index.html s3://example.com/s3-static/index.html
```

## 動作確認

以下の URL にアクセスして、S3 内の静的ファイルが正しく表示されることを確認します。

```
https://example.com/s3-static/index.html
```
