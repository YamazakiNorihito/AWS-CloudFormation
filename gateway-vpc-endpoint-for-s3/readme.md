# gateway for s3

## deploy

```bash
aws cloudformation deploy --stack-name "gateway-vpc-endpoint-for-s3" --template-file template.yaml --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND --parameter-overrides VpcId="{VpcId}"  VPCRouteTableId="{VPCRouteTableId}"  BucketName="{BucketName}" --region {region} --profile {profileName}
```

## check

```bash
echo "hello s3" > test.txt
aws s3 cp test.txt s3://test-gateway-1234/ --region us-east-2
aws s3 ls s3://test-gateway-1234/ --region us-east-2
```
