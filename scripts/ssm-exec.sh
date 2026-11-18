#!/usr/bin/env bash
# Run a local script on the instance with SSM Run Command, print its output,
# and exit with its result. No SSH needed.
#
# usage: ssm-exec.sh <instance-id> <script> [timeout-seconds]
set -euo pipefail

instance=$1
script=$2
timeout=${3:-600}

echo "Waiting for the SSM agent on $instance"
ping=""
for _ in $(seq 60); do
  ping=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$instance" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)
  [ "$ping" = "Online" ] && break
  sleep 10
done
if [ "$ping" != "Online" ]; then
  echo "::error::SSM agent on $instance never came online. Is the instance running with the workshop-node role?"
  exit 1
fi

params=$(jq -n --arg b64 "$(base64 -w0 "$script")" --arg t "$timeout" \
  '{commands: ["echo \($b64) | base64 -d > /tmp/job.sh", "bash /tmp/job.sh"], executionTimeout: [$t]}')

id=$(aws ssm send-command \
  --instance-ids "$instance" \
  --document-name AWS-RunShellScript \
  --comment "$(basename "$script")" \
  --parameters "$params" \
  --query Command.CommandId --output text)
echo "Sent command $id, waiting for it to finish"

status=Pending
deadline=$((SECONDS + timeout + 60))
while [ "$SECONDS" -lt "$deadline" ]; do
  sleep 5
  status=$(aws ssm get-command-invocation --command-id "$id" --instance-id "$instance" \
    --query Status --output text 2>/dev/null || echo Pending)
  case $status in
    Success | Failed | Cancelled | TimedOut) break ;;
  esac
done

echo "----- output from $instance -----"
aws ssm get-command-invocation --command-id "$id" --instance-id "$instance" \
  --query StandardOutputContent --output text || true
err=$(aws ssm get-command-invocation --command-id "$id" --instance-id "$instance" \
  --query StandardErrorContent --output text 2>/dev/null || true)
if [ -n "$err" ] && [ "$err" != "None" ]; then
  echo "----- stderr -----"
  echo "$err"
fi
echo "---------------------------------"

echo "Status: $status"
[ "$status" = "Success" ]
