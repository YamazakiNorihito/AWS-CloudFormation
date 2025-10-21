```bash
aws cloudformation deploy \
  --stack-name "step-function-when-put-s3" \
  --template-file "./template.yaml" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND
```
