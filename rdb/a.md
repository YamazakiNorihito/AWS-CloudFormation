```bash
aws cloudformation deploy --stack-name "rdb-stack" --template-file ./template.yaml --parameter-overrides file://parameters.json --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND --region us-east-1
```
