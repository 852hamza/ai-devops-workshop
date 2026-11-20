# AI-Powered DevOps: from `git push` to Kubernetes on AWS

You change one line of code and run `git push`. A few minutes later the new version is live on Kubernetes in your own AWS account. The pipeline builds the server, tests, scans and ships the image, deploys it and checks that it works. If anything breaks, AI explains why.

```
Codespace ──git push──▶ GitHub Actions
                          1. Detect changes   did infra/ change? first run?
                          2. Terraform        only when needed: EC2 server + k3d Kubernetes
                          3. Build            tests → Docker image → Trivy scan → Amazon ECR
                          4. Deploy           kubectl on the server through AWS Systems Manager
                          5. Health check     is the new version really live?
                          ✗  AI explainer     tells you what failed and how to fix it
                                 │
Browser ──▶ http://<server-ip>/ ──▶ Traefik Ingress ──▶ Service ──▶ Pods
```

No access keys are stored anywhere (GitHub logs in to AWS with OIDC) and the server has no SSH port.

| Folder | What's inside |
|---|---|
| `app/` | Small Flask web app, its tests, and the Dockerfile you write in Lab 1 |
| `infra/` | Terraform: security group, IAM role, EC2 server, boot script that creates the cluster |
| `k8s/` | Kubernetes Deployment and Service (you add the Ingress in Lab 3) |
| `bootstrap/` | One-time AWS setup (CloudFormation) |
| `scripts/` | Helpers the pipeline uses |
| `.github/workflows/` | `pipeline.yml` (runs on every push) and `destroy.yml` (clean-up) |
| `solutions/` | Answers, if you get stuck |

---

## Before the workshop (about 30 minutes, at home)

- [ ] **AWS account** created and activated (needs a debit/virtual card that works for international payments; activation can take up to 24 hours).
- [ ] **Budget alert:** Billing and Cost Management → Budgets → Create budget → $5 monthly budget, your email.
- [ ] **Region:** at the top right of the AWS console, choose **Asia Pacific (Mumbai) ap-south-1**.
- [ ] **GitHub account.** Students: apply for the free [GitHub Student Developer Pack](https://education.github.com) (it includes GitHub Copilot).
- [ ] **Your copy of this repo:** click **Use this template → Create a new repository**, name it exactly `ai-devops-workshop`.
- [ ] **Codespace:** in your new repo, **Code → Codespaces → Create codespace on main**. Wait until the terminal prints `Workshop tools ready`, then close the tab.

No AWS account? Come anyway and pair with a classmate.

---

## Lab 0 · Connect GitHub to AWS (10 min)

The pipeline needs three things before it can log in to AWS, so we create them once by hand.

1. Open the **Launch Stack** link from the instructor (or: CloudFormation → Create stack → upload `bootstrap/bootstrap.yaml`).
2. Fill in:
   - Stack name: `ai-devops-workshop`
   - **GitHubOwner:** your GitHub username, exactly as in your repo URL (capital letters matter)
   - Leave the rest as default. Use `CreateOIDCProvider = false` only if your account already has a GitHub identity provider.
3. Tick the IAM checkbox → **Submit**. Wait for `CREATE_COMPLETE` (about 1 minute), then open the **Outputs** tab.
4. In your GitHub repo: **Settings → Secrets and variables → Actions**.

   | Add as | Name | Value from Outputs |
   |---|---|---|
   | Secret | `AWS_ROLE_ARN` | `AwsRoleArn` |
   | Variable | `AWS_REGION` | `AwsRegion` |
   | Variable | `TF_STATE_BUCKET` | `TfStateBucket` |
   | Variable | `ECR_REPOSITORY` | `EcrRepository` |

5. Open the **Actions** tab. If it asks, enable workflows. You should see **pipeline** and **destroy**.

✅ Checkpoint: stack is `CREATE_COMPLETE`, 1 secret + 3 variables added.

---

## Lab 1 · Docker and security scanning (20 min)

Open your Codespace and a terminal.

**1. Run the app and its tests**

```bash
cd app
pytest -v          # 3 passed
python app.py      # open the port 8080 pop-up, then Ctrl+C
cd ..
```

**2. Write the Dockerfile with AI.** Open `app/Dockerfile`; it only lists the requirements. Ask Copilot Chat (sidebar):

> Write a Dockerfile for the Flask app in app.py with dependencies in requirements.txt. Use python:3.12-slim, a build argument APP_VERSION (default "dev") exposed as an environment variable, install requirements without pip cache, copy app.py, run as a non-root user, expose 8080 and start with gunicorn --bind 0.0.0.0:8080 --workers 2 app:app. Explain each line.

Read the answer and check every requirement before you use it. Stuck? `cp solutions/Dockerfile app/Dockerfile`

**3. Build, run and check it**

```bash
docker build --build-arg APP_VERSION=local -t workshop-app:local app
docker run --rm -d -p 8080:8080 --name web workshop-app:local
curl -s localhost:8080/healthz     # must show "version":"local"
docker exec web whoami             # must print appuser, not root
docker stop web
```

If the version says `dev`, your Dockerfile is missing the `ARG APP_VERSION` line. Fix it now, or the pipeline's health check will fail later.

**4. Scan it**

```bash
trivy image --severity HIGH,CRITICAL --ignore-unfixed workshop-app:local
```

Pick one finding and ask Copilot to explain it. The pipeline fails the build on any **CRITICAL** issue that has a fix.

**5. Commit, don't push yet**

```bash
git add app/Dockerfile
git commit -m "Add Dockerfile"
```

✅ Checkpoint: `/healthz` shows `local`, container runs as `appuser`, Dockerfile committed.

---

## Lab 2 · Infrastructure from a push (30 min)

**1. Read `infra/main.tf`.** Notice: port 80 and 30080 open, **no port 22**; the server's IAM role can only use Systems Manager and read from ECR. Ask Copilot: *"Explain this Terraform file resource by resource."*

**2. Check it locally** (does not touch AWS):

```bash
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
```

**3. Push**

```bash
git push
```

Open **Actions** and click the running workflow. The first run takes about 8–12 minutes because the server installs Docker and creates the cluster. While you wait:

- **Detect changes** summary says *Run Terraform: true (no infrastructure yet)*.
- **Terraform** and **Test, build, scan, push** run at the same time.
- AWS console: **EC2** shows `workshop-k3d`; **S3** shows `workshop/terraform.tfstate` in your `tfstate-…` bucket; **ECR** shows an image tagged with your commit ID.

**4. Open your app.** The run's **Summary** shows `Live: http://<ip>:30080/`. The page shows your commit ID as the version.

✅ Checkpoint: your app is live and shows your own commit ID.

---

## Lab 3 · Kubernetes: NodePort, Ingress, scaling (35 min)

**1. A terminal on the server, without SSH.** EC2 → Instances → `workshop-k3d` → **Connect** → **Session Manager** → **Connect**.

```bash
sudo -i
kubectl get nodes
kubectl get deployment,pods,service -o wide
```

**2. NodePort.** Right now traffic reaches your app like this: browser → port 30080 on the server → Service `web-svc` → pods. Quick to test, but one odd port per app.

**3. Switch to an Ingress.** One entry point on port 80 that routes to your Service. Ask Copilot:

> Write a Kubernetes Ingress named web-ingress with ingressClassName traefik that sends all paths (/) to the service web-svc on port 80.

Save it as `k8s/ingress.yaml` (stuck? `cp solutions/ingress.yaml k8s/ingress.yaml`), then:

```bash
git add k8s/ingress.yaml
git commit -m "Add ingress"
git push
```

Detect changes says Terraform will **not** run (only `k8s/` changed). When it is green, open `http://<ip>/` on port 80. Tip: `http://<ip>/?watch` refreshes every 2 seconds and every version has its own colour.

**4. Load balancing.** In your Codespace:

```bash
IP=<your-ip>
for i in $(seq 20); do curl -s http://$IP/healthz | jq -r .pod; done | sort | uniq -c
```

**5. Scale by hand** (Session Manager):

```bash
kubectl scale deployment web --replicas=5
kubectl get pods -w        # Ctrl+C when all are Running
```

Run the curl loop again: 5 pod names. This change is not in git, so the next push will undo it.

**6. Scale the GitOps way.** In `k8s/deployment.yaml` set `replicas: 3`, then commit and push. After the run, `kubectl get pods` shows exactly 3.

**7. Close the NodePort.** In `infra/terraform.tfvars` set `enable_nodeport = false`, then commit and push. This time Terraform **runs** (because `infra/` changed) and the plan destroys exactly 1 resource: the port 30080 rule. Port 80 keeps working.

✅ Checkpoint: app works on port 80, 3 pods, port 30080 closed.

---

## Lab 4 · Break it, fix it with AI, roll back (20 min)

**How to investigate any failure:** open the failed run → **Summary** → **AI failure explainer**. If your repo has no Copilot token, it shows the log and a prompt: paste both into Copilot Chat. Then open the red step and check that the AI's answer matches the log.

**Scenario 1 · A failing test.** In `app/app.py` change `MESSAGE` to `"Hello from AI DevOps!"`, then `git commit -am "Change message" && git push`. Watch what the pipeline does and what happens to your live app. Find the cause with AI and fix it.

**Scenario 2 · A bad release.** In `k8s/deployment.yaml` change only the **readinessProbe** path to `/health`, commit and push. Keep `http://<ip>/?watch` open while it runs. Does your app ever go down? Fix it with:

```bash
git revert HEAD --no-edit
git push
```

**Scenario 3 · Challenge.** In `k8s/ingress.yaml` change the service name to `web-service`, commit and push. Everything deploys, yet the pipeline fails. Why? Revert when you know.

**Emergency rollback and self-healing** (Session Manager):

```bash
kubectl rollout history deployment/web
kubectl rollout undo deployment/web     # emergency brake; the next push redeploys what is in git
kubectl delete pod <pod-name>           # Kubernetes starts a replacement within seconds
kubectl get pods -w
```

✅ Checkpoint: you fixed a failure with AI and saw a bad release fail without taking the app down.

---

## Clean up (do not skip)

A running server costs money every hour.

1. **Actions → destroy → Run workflow**, type `destroy`. Wait for green.
2. **S3** → your `tfstate-…` bucket → **Empty** → type `permanently delete`.
3. **CloudFormation** → `ai-devops-workshop` → **Delete**.
4. Delete your Codespace at https://github.com/codespaces.

Keep the repository: it is your portfolio project. Repeat Lab 0 and push again to rebuild everything.

---

## When something breaks

| You see | Do this |
|---|---|
| `Repository variable … is missing` / `secret AWS_ROLE_ARN is missing` | Add it exactly as in Lab 0 (names are case-sensitive). |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | GitHubOwner in the stack doesn't match your repo URL. CloudFormation → Update stack. |
| `file with no instructions` (build) | Finish Lab 1 or `cp solutions/Dockerfile app/Dockerfile`. |
| Security gate fails | A CRITICAL vulnerability with a fix. Ask the instructor. |
| Health check waits with `now: dev` | Your Dockerfile is missing `ARG APP_VERSION`. |
| Session Manager **Connect** is grey | Wait 2 minutes and refresh. |
| `kubectl`: connection refused | Run `sudo -i` first. |
| `http://<ip>:30080` doesn't open on campus Wi-Fi | Many networks block odd ports. Use your phone, or `curl` from the Codespace. |
| Codespace won't start | Press `.` on your repo page to edit in the browser; the pipeline still does the work. |
