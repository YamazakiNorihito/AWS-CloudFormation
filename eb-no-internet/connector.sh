#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154

set -Eeuo pipefail

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { log "ERROR: $*"; exit 1; }

cleanup_port() {
  local port="$1"
  local pids
  # Find listeners on the port and kill them if any (portable: avoid GNU xargs -r)
  pids=$(lsof -tiTCP:"${port}" -sTCP:LISTEN || true)
  if [[ -n "${pids}" ]]; then
    log "Killing processes listening on TCP port ${port}: ${pids}"
    kill ${pids} || true
    # give the OS a moment to release the port
    sleep 1
  fi
}

wait_for_port_listen() {
  local host="$1" port="$2" timeout_sec="${3:-30}" label="${4:-port ${port}}"
  local i=0
  while (( i < timeout_sec )); do
    if lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
      log "${label}: now listening on ${host}:${port}"
      return 0
    fi
    # macOS/BSD nc supports -z
    if nc -z "${host}" "${port}" >/dev/null 2>&1; then
      log "${label}: TCP connect OK to ${host}:${port}"
      return 0
    fi
    sleep 1; ((i++))
  done
  return 1
}

require_nonempty() {
  local name="$1" value="$2"
  [[ -n "${value}" ]] || fail "Required value ${name} is empty. Check your parameters/exports."
}

CLEANUP_DONE=0
TUNNEL_PID=""

cleanup_all() {
  if [[ "${CLEANUP_DONE}" -eq 1 ]]; then
    return
  fi
  CLEANUP_DONE=1

  if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "${TUNNEL_PID}" 2>/dev/null; then
    log "Stopping tunnel process ${TUNNEL_PID}"
    kill "${TUNNEL_PID}" 2>/dev/null || true
    wait "${TUNNEL_PID}" 2>/dev/null || true
  fi

  if [[ -n "${LOCAL_MYSQL_PORT:-}" ]]; then
    cleanup_port "${LOCAL_MYSQL_PORT}"
  fi
  if [[ -n "${LOCAL_SSH_PORT:-}" ]]; then
    cleanup_port "${LOCAL_SSH_PORT}"
  fi
}

# -------- Script body --------
EnvironmentName="local"

LOCAL_SSH_PORT=12222
PEM_FILE="./key-pair-nginx-${EnvironmentName}.pem"

# プロファイル名の設定
PROFILE="dev-medcom.ne.jp"
REGION="us-east-1"

trap cleanup_all EXIT
trap 'log "Interrupt received, shutting down tunnel..."; cleanup_all; exit 130' INT
trap 'log "Termination signal received, shutting down tunnel..."; cleanup_all; exit 143' TERM

# Fetch required values
log "Fetching CloudFormation exports and instance information..."
EIC_ID=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-EicEndpointId'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}" || true)


PrivateSubnetAZ1Id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-PrivateSubnetAZ1Id'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}" || true)

PrivateSubnetAZ2Id=$(aws cloudformation list-exports \
    --query "Exports[?Name=='${EnvironmentName}-PrivateSubnetAZ2Id'].Value" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}" || true)

EC2_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=env-nginx-${EnvironmentName}" "Name=subnet-id,Values=${PrivateSubnetAZ1Id}" \
    --query "Reservations[].Instances[].PrivateIpAddress" \
    --output text \
    --region "${REGION}" \
    --profile "${PROFILE}" || true)

if [[ -z "${EC2_IP}" && -n "${PrivateSubnetAZ2Id}" ]]; then
  log "EC2 instance not found in AZ1, trying PrivateSubnetAZ2Id: ${PrivateSubnetAZ2Id}"
  EC2_IP=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=env-nginx-${EnvironmentName}" "Name=subnet-id,Values=${PrivateSubnetAZ2Id}" \
      --query "Reservations[].Instances[].PrivateIpAddress" \
      --output text \
      --region "${REGION}" \
      --profile "${PROFILE}" || true)
fi

require_nonempty EIC_ID "${EIC_ID}"
require_nonempty EC2_IP "${EC2_IP}"


log "EIC_ID: ${EIC_ID}"
log "EC2_IP: ${EC2_IP}"

cleanup_port "${LOCAL_SSH_PORT}"


# Start EIC local tunnel to instance: local ${LOCAL_SSH_PORT} -> EC2_IP:22
log "Starting EC2 Instance Connect tunnel on localhost:${LOCAL_SSH_PORT} -> ${EC2_IP}:22 ..."
TUNNEL_LOG=~/eic_tunnel.log
: > "${TUNNEL_LOG}"
aws ec2-instance-connect open-tunnel \
  --instance-connect-endpoint-id "${EIC_ID}" \
  --private-ip-address "${EC2_IP}" \
  --remote-port 22 \
  --local-port "${LOCAL_SSH_PORT}" \
  --region "${REGION}" \
  --profile "${PROFILE}" \
  > "${TUNNEL_LOG}" 2>&1 &

TUNNEL_PID=$!
log "Tunnel process started with PID ${TUNNEL_PID}. Waiting for listener..."



# Wait for the local tunnel listener to be ready
if ! wait_for_port_listen 127.0.0.1 "${LOCAL_SSH_PORT}" 30 "EIC tunnel"; then
  log "EIC tunnel did not become ready within timeout. Showing last 50 lines of ${TUNNEL_LOG}:"
  tail -n 50 "${TUNNEL_LOG}" || true
  fail "EIC tunnel not listening on 127.0.0.1:${LOCAL_SSH_PORT}"
fi

lsof -iTCP:"${LOCAL_SSH_PORT}" -sTCP:LISTEN || true

log "Tunnel ready on localhost:${LOCAL_SSH_PORT}. Press Ctrl+C to close and cleanup."

# Keep the tunnel alive until user interrupts
wait "$TUNNEL_PID"

# ssh-keygen -R "[localhost]:12222"
# ssh -i ./key-pair-nginx-local.pem -p 12222 ec2-user@localhost
