#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154

HostedZoneId="${1:-}"
DOMAIN="${2:-}"
Region="${3:-}"
Profile="${4:-}"

if [[ -z "${HostedZoneId}" || -z "${DOMAIN}" || -z "${Region}" || -z "${Profile}" ]]; then
    echo "Usage: $0 <HostedZoneId> <DOMAIN> <Region> <Profile>"
    echo "例: $0 Z1234567890ABC example.com ap-northeast-1 my-profile"
    exit 1
fi

CERT_ARN=$(aws acm list-certificates \
  --region "${Region}" \
  --profile "${Profile}" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" \
  --output text)

if [[ -z "${CERT_ARN}" || "${CERT_ARN}" == "None" ]]; then
    CERT_ARN=$(aws acm request-certificate \
        --domain-name "${DOMAIN}" \
        --validation-method "DNS" \
        --key-algorithm "RSA_2048" \
        --options "CertificateTransparencyLoggingPreference=ENABLED" \
        --region "${Region}"  \
        --profile "${Profile}" \
        --query "CertificateArn" \
        --output text)
else
    echo "既存のCertificateArnが見つかったためrequest-certificateはスキップします。"
fi

echo "CertificateArn: ${CERT_ARN}"

echo "ACMで発行された証明書を有効にするため、${DOMAIN} に対して以下の CNAME レコードを追加してください。"
echo "（ResourceRecord の Name と Value をそのまま登録してください）"

cname_record_applied=false

while true; do
    validation_output=$(aws acm describe-certificate \
        --certificate-arn "${CERT_ARN}" \
        --region "${Region}"  \
        --profile "${Profile}" \
        --query "Certificate.DomainValidationOptions" \
        --output json)

    if [[ "${cname_record_applied}" == false ]]; then
        records=$(printf '%s\n' "${validation_output}" | jq -r '.[] | select(.ResourceRecord != null) | "\(.ResourceRecord.Name)|\(.ResourceRecord.Value)"')

        if [[ -n "${records}" && "${records}" != "null" ]]; then
            any_applied=false
            while IFS='|' read -r record_name record_value; do
                if [[ -z "${record_name}" || -z "${record_value}" ]]; then
                    continue
                fi

                change_batch=$(jq -n \
                    --arg comment "Add validation CNAME record for ACM certificate ${CERT_ARN}" \
                    --arg name "${record_name}" \
                    --arg value "${record_value}" \
                    '{
                        Comment: $comment,
                        Changes: [
                            {
                                Action: "UPSERT",
                                ResourceRecordSet: {
                                    Name: $name,
                                    Type: "CNAME",
                                    TTL: 300,
                                    ResourceRecords: [
                                        {
                                            Value: $value
                                        }
                                    ]
                                }
                            }
                        ]
                    }')

                if aws route53 change-resource-record-sets \
                    --hosted-zone-id "${HostedZoneId}" \
                    --change-batch "${change_batch}" \
                    --profile "${Profile}" >/dev/null; then
                    any_applied=true
                else
                    echo "CNAMEレコード ${record_name} の設定に失敗しました。"
                fi
            done <<< "${records}"

            if [[ "${any_applied}" == true ]]; then
                cname_record_applied=true
                echo "HostedZoneId ${HostedZoneId} に検証用のCNAMEレコードを設定しました。"
            fi
        fi
    fi

    printf '%s\n' "${validation_output}" | jq

    if printf '%s\n' "${validation_output}" | jq -e 'all(.[]; .ValidationStatus == "SUCCESS")' >/dev/null; then
        echo "ValidationStatusがSUCCESSになりました。"
        break
    fi

    echo "ValidationStatusがSUCCESSになるまで30秒待ちます..."
    sleep 30
done
