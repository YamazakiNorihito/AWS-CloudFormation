# EC2 AMI作成 & 起動プレイグラウンド

このリポジトリは、EC2インスタンスからAMI（Amazon Machine Image）を作成し、そのAMIを元に新しいEC2インスタンスを起動する一連のプロセスを、CloudFormationとシェルスクリプトを使って体験するためのものです。

`deploy-ec2.sh` スクリプトを実行することで、以下の手順が自動的に実行されます。

1. `base-ec2-instance.yaml` を使って、ベースとなるEC2インスタンスを起動します。
2. 起動したEC2インスタンスからAMIを作成します。
3. 作成したAMIを使い、`ec2-launch-from-ami.yaml` を使って新しいEC2インスタンスを起動します。

## 構成ファイル

- `base-ec2-instance.yaml` : ベースとなる EC2 インスタンスを作成する CloudFormation テンプレート
- `ec2-launch-from-ami.yaml` : 既存の AMI から EC2 インスタンスを起動する CloudFormation テンプレート
- `deploy-ec2.sh` : 上記のプロセスを自動化するシェルスクリプト

## 使い方

1. `deploy-ec2.sh` スクリプト内の設定値（`SUBNET_ID`, `KEY_NAME`, `VPC_ID`など）を、ご自身の環境に合わせて編集します。
2. スクリプトを実行します。リージョンやプロファイルは引数で指定することも可能です。

```sh
# スクリプトに実行権限を付与
chmod +x deploy-ec2.sh

# スクリプトを実行
./deploy-ec2.sh
```

3. スタックの作成が完了すると、EC2 インスタンスが作成されます。

## 注意事項

- AWS CLI の認証情報が設定されている必要があります。
- 適切な IAM 権限が必要です。

## 参考

- [AWS CloudFormation ドキュメント](https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/Welcome.html)
