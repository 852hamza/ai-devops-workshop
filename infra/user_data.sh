#!/bin/bash
# First boot only: install Docker, kubectl, AWS CLI and k3d, then create the cluster.
# Log: /var/log/workshop-setup.log. The pipeline waits for /var/lib/workshop/ready.
set -euxo pipefail
exec > >(tee -a /var/log/workshop-setup.log) 2>&1

mkdir -p /var/lib/workshop
trap 'touch /var/lib/workshop/failed' ERR

export HOME=/root DEBIAN_FRONTEND=noninteractive
K3S_IMAGE=rancher/k3s:v1.35.9-k3s1
KUBECTL_VERSION=v1.35.9
K3D_VERSION=v5.9.0

apt-get update -y
apt-get install -y docker.io jq curl
systemctl enable --now docker

snap install aws-cli --classic

curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -fsSLo /usr/local/bin/k3d "https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-amd64"
chmod +x /usr/local/bin/kubectl /usr/local/bin/k3d

# 80    -> k3d load balancer -> Traefik
# 30080 -> straight to the node (NodePort)
# API server only on localhost; the pipeline gets in through SSM.
k3d cluster create workshop \
  --image "$K3S_IMAGE" \
  --api-port 127.0.0.1:6443 \
  -p "80:80@loadbalancer" \
  -p "30080:30080@server:0" \
  --wait --timeout 300s

kubectl wait --for=condition=Ready nodes --all --timeout=180s

# k3s installs Traefik with a helm job a couple of minutes after the node is up
timeout 300 bash -c 'until kubectl -n kube-system get deploy traefik >/dev/null 2>&1; do sleep 5; done'
kubectl -n kube-system rollout status deploy/traefik --timeout=300s

# so "sudo -i" in Session Manager can use kubectl straight away
echo 'export KUBECONFIG=/root/.kube/config' > /etc/profile.d/kubeconfig.sh

touch /var/lib/workshop/ready
