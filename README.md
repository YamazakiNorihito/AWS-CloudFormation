
```bash
# create Dockerfile
touch Dockerfile # ファイルの内容は`ecs/Dockerfile`を参照
docker build -t hello-world .
docker run -t -i -p 80:80 hello-world

# 問題なければクロスプラットフォームでビルドする。Fargateで使用するためにLinuxのx86_64（amd64）アーキテクチャに合わせ
docker buildx build --platform linux/amd64 -t hello-world .

# create private repository
## aws ecr create-repository --repository-name hello-repository --region {region}
aws ecr create-repository --repository-name hello-repository --region ap-northeast-1 --profile workday

## output
###{
###    "repository": {
###        "repositoryArn": "arn:aws:ecr:ap-northeast-1:155345814070:repository/hello-repository",
###        "registryId": "155345814070",
###        "repositoryName": "hello-repository",
###        "repositoryUri": "155345814070.dkr.ecr.ap-northeast-1.amazonaws.com/hello-repository",
###        "createdAt": "2024-11-12T06:39:19.706000+09:00",
###        "imageTagMutability": "MUTABLE",
###        "imageScanningConfiguration": {
###            "scanOnPush": false
###        },
###        "encryptionConfiguration": {
###            "encryptionType": "AES256"
###        }
###    }
###}

## ちなみにpublicは以下の通り。ただしサポートされているRegionは限られる。https://docs.aws.amazon.com/ja_jp/general/latest/gr/ecr-public.html
## aws ecr-public create-repository --repository-name hello-repository --region us-east-1 --profile workday

# image push
## docker tag hello-world {aws_account_id}.dkr.ecr.{region}.amazonaws.com/hello-repository
docker tag hello-world 155345814070.dkr.ecr.ap-northeast-1.amazonaws.com/hello-repository

## aws ecr get-login-password --region {region} | docker login --username AWS --password-stdin {aws_account_id}.dkr.ecr.{region}.amazonaws.com
aws ecr get-login-password --region ap-northeast-1 --profile workday | docker login --username AWS --password-stdin 155345814070.dkr.ecr.ap-northeast-1.amazonaws.com

## output
### Login Succeeded

## docker push {aws_account_id}.dkr.ecr.{region}.amazonaws.com/hello-repository
docker push 155345814070.dkr.ecr.ap-northeast-1.amazonaws.com/hello-repository

# infra deploy
aws cloudformation create-stack --stack-name ecs-stack --template-body file://template.yaml --parameters file://parameters.json --region ap-northeast-1 --profile workday --capabilities CAPABILITY_NAMED_IAM
```
