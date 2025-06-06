# WebSocket Chat App 解説リポジトリ（AWS公式サンプル補足）

このリポジトリは、AWS公式の WebSocket チャットアプリサンプル
👉 [simple-websockets-chat-app](https://github.com/aws-samples/simple-websockets-chat-app)
（対象コミット: `43ab677cd867584e9e17bad6803739a1e5199350`）
を使ってアプリを構築しようとした際に、**そのままでは動作しない部分の修正方法を補足**する目的で作成しました。

実際に私自身がこのサンプルを参考に構築し、つまずいた点や必要だった修正内容をまとめています。
公式サンプルは非常にシンプルで優れていますが、**現在の AWS SDK 環境などに合わせて微調整が必要**です。

---

## ✅ 本家サンプルの概要

* API Gateway (WebSocket) + Lambda (Node.js) + DynamoDB によるシンプルな構成
* `wscat` CLI ツールを使ってチャット通信を試せる
* WebSocketを使った実装の最小構成例として最適

---

## 🛠 このリポジトリで補足するポイント

### 1. AWS SDK for JavaScript v2 → v3 へのマイグレーション

AWS公式のコードは v2 を使っていますが、現在は v3 がデフォルトとなっており、v2 は新しいプロジェクトでは推奨されていません。
また、v2 はデフォルトでは Lambda に含まれず、自前でライブラリをインストールしてデプロイする必要があります。
そのため、以下のコードモッドを使って v3 へ移行する必要があります：

```bash
npx aws-sdk-js-codemod -t v2-to-v3 onconnect/app.js 
npx aws-sdk-js-codemod -t v2-to-v3 ondisconnect/app.js 
npx aws-sdk-js-codemod -t v2-to-v3 sendmessage/app.js 
```

---

### 2. `sendmessage/app.js` における endpoint 設定の修正

v3 では `ApiGatewayManagementApi` のエンドポイントに `https://` を含めたスキーマ付きURLを明示的に指定する必要があります。

```diff
-  const apigwManagementApi = new AWS.ApiGatewayManagementApi({
+  const apigwManagementApi = new ApiGatewayManagementApi({
+    // The key apiVersion is no longer supported in v3, and can be removed.
+    // @deprecated The client uses the "latest" apiVersion.
     apiVersion: '2018-11-29',
-    endpoint: `${event.requestContext.apiId}.execute-api.${process.env.AWS_REGION}.amazonaws.com/${event.requestContext.stage}`
+    endpoint: `https://${event.requestContext.domainName}/${event.requestContext.stage}`
   });
```

---

## 🚀 デプロイ手順

```bash
sam deploy --guided --region {region} --profile {profile}
```

※ `--region` や `--profile` の指定は、省略可能です。

---

## 💬 ブラウザでの確認方法（おまけ）

`index.html` をブラウザにドラッグ＆ドロップすることで、
CLIではなくGUIでチャットの動作確認ができます。

---

## 🔗 関連リンク

* [AWS公式 GitHub: simple-websockets-chat-app](https://github.com/aws-samples/simple-websockets-chat-app)
* [SDK v2 から v3 への移行ガイド](https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/migrating.html)

---

このREADMEは、AWSサンプルを使いたい開発者がスムーズに試せるよう、公式との差分や注意点を中心にまとめています。
