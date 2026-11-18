#!/usr/bin/env bash
# terraform init against the S3 bucket created by bootstrap/bootstrap.yaml
set -euo pipefail

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is not set}"
: "${AWS_REGION:?AWS_REGION is not set}"

terraform -chdir=infra init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=workshop/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
