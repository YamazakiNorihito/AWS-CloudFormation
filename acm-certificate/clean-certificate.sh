#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154

remove_certificate_validation_records() {
  local cert_arn=$1
  local hosted_zone_id=$2

  local validation_output
  validation_output=$(aws acm describe-certificate \
    --certificate-arn "${cert_arn}" \
    --region "${Region}" \
    --profile "${Profile}" \
    --query "Certificate.DomainValidationOptions" \
    --output json 2>/dev/null || true)

  if [[ -z "${validation_output}" || "${validation_output}" == "null" ]]; then
    echo "No DNS validation records found for certificate ${cert_arn}."
    return
  fi

  local records
  records=$(jq -r '.[] | select(.ResourceRecord != null) | "\(.ResourceRecord.Name)|\(.ResourceRecord.Value)"' <<< "${validation_output}" 2>/dev/null || true)

  if [[ -z "${records}" || "${records}" == "null" ]]; then
    echo "No DNS validation records to remove for certificate ${cert_arn}."
    return
  fi

  while IFS='|' read -r record_name record_value; do
    if [[ -z "${record_name}" || -z "${record_value}" ]]; then
      continue
    fi

    local change_batch
    change_batch=$(jq -n \
      --arg comment "Delete validation CNAME record for ACM certificate ${cert_arn}" \
      --arg name "${record_name}" \
      --arg value "${record_value}" \
      '{
        Comment: $comment,
        Changes: [
          {
            Action: "DELETE",
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

    aws route53 change-resource-record-sets \
      --hosted-zone-id "${hosted_zone_id}" \
      --change-batch "${change_batch}" \
      --profile "${Profile}" >/dev/null || true
    echo "Removed validation record ${record_name}"
  done <<< "${records}"
}


if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <CertificateArn> <HostedZoneId> <Region> <Profile>"
  echo "Example: $0 arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx Z1234567890ABC ap-northeast-1 my-profile"
  exit 1
fi

CertificateArn=$1
HostedZoneId=$2
Region=$3
Profile=$4

remove_certificate_validation_records "${CertificateArn}" "${HostedZoneId}"

aws acm delete-certificate \
  --certificate-arn "${CertificateArn}" \
  --region "${Region}" \
  --profile "${Profile}" || true
