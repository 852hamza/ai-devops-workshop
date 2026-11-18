#!/bin/bash
# Runs on the server (through ssm-exec.sh). Waits for user_data.sh to finish.
export KUBECONFIG=/root/.kube/config
export PATH=$PATH:/usr/local/bin:/snap/bin

for i in $(seq 80); do
  if [ -f /var/lib/workshop/failed ]; then
    echo "Server setup FAILED. Last lines of /var/log/workshop-setup.log:"
    tail -n 40 /var/log/workshop-setup.log
    exit 1
  fi
  if [ -f /var/lib/workshop/ready ]; then
    echo "Cluster is ready"
    kubectl get nodes -o wide
    kubectl -n kube-system get deploy traefik
    exit 0
  fi
  echo "[$i/80] still setting up: $(tail -n 1 /var/log/workshop-setup.log 2>/dev/null || echo 'not started yet')"
  sleep 10
done

echo "Timed out. Last lines of /var/log/workshop-setup.log:"
tail -n 40 /var/log/workshop-setup.log
exit 1
