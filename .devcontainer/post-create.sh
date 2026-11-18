#!/usr/bin/env bash
set -euo pipefail

TRIVY_VERSION=v0.76.1

sudo apt-get update -qq
sudo apt-get install -y -qq jq > /dev/null

pip install --user -q -r app/requirements.txt -r app/requirements-dev.txt

curl -sfL "https://raw.githubusercontent.com/aquasecurity/trivy/${TRIVY_VERSION}/contrib/install.sh" \
  | sudo sh -s -- -b /usr/local/bin "${TRIVY_VERSION}"

echo
terraform version | head -n 1
kubectl version --client | head -n 1
aws --version
trivy --version | head -n 1
docker --version || echo "docker is still starting, try again in a minute"
echo
echo "Workshop tools ready"
