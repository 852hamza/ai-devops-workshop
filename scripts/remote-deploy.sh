#!/bin/bash
# Runs on the server through ssm-exec.sh. The deploy job puts AWS_REGION,
# ECR_REGISTRY and APP_VERSION in front of this file and writes /tmp/manifests.yaml.
set -euo pipefail
export PATH=$PATH:/usr/local/bin:/snap/bin
export HOME=/root
export KUBECONFIG=${KUBECONFIG:-/root/.kube/config}
STATE_DIR=${STATE_DIR:-/var/lib/workshop}

echo "==> Waiting for the cluster"
for _ in $(seq 60); do
  if [ -f "$STATE_DIR/failed" ]; then
    echo "Server setup failed:"
    tail -n 40 /var/log/workshop-setup.log
    exit 1
  fi
  [ -f "$STATE_DIR/ready" ] && break
  sleep 10
done
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "==> Refreshing the ECR pull secret (tokens expire after 12h)"
kubectl create secret docker-registry ecr-creds \
  --docker-server="$ECR_REGISTRY" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$AWS_REGION")" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying manifests for $APP_VERSION"
kubectl apply -f /tmp/manifests.yaml

echo "==> Waiting for the rollout"
if ! kubectl rollout status deployment/web --timeout=180s; then
  echo
  echo "!! Rollout failed. Pods:"
  kubectl get pods -l app=web -o wide || true
  echo
  echo "!! Recent events:"
  kubectl get events --sort-by=.lastTimestamp | tail -n 15 || true
  echo
  echo "!! Rolling back to the previous version"
  if kubectl rollout undo deployment/web; then
    kubectl rollout status deployment/web --timeout=120s || true
  else
    echo "(nothing to roll back to, this was the first deploy)"
  fi
  exit 1
fi

echo "==> Done"
kubectl get deployment,pods,service,ingress -o wide
