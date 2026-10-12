# Voting App — DevOps Capstone 1

Forked from `dockersamples/example-voting-app` as part of the DevOps Capstone (Beginner Edition).

**Author:** Teeros | temi.asojo@gmail.com

---

## Architecture

```
 Browser
    |
    |-- port 8080 --> [vote] (Python/Flask)
    |                    |
    |                  Redis (queue)
    |                    |
    |               [worker] (.NET)
    |                    |
    |               PostgreSQL (db)
    |                    |
    |-- port 8081 --> [result] (Node.js)
```

| Service  | Technology | Role |
|----------|-----------|------|
| vote     | Python/Flask | Accepts votes, pushes to Redis |
| redis    | Redis 7     | Message queue between vote and worker |
| worker   | .NET 7      | Reads from Redis, writes to PostgreSQL |
| db       | PostgreSQL 15 | Persistent vote storage |
| result   | Node.js 18  | Reads from PostgreSQL, shows live totals |

---

## Step 1 — Run locally with Docker Compose

```bash
docker compose up --build
```

- Vote app: http://localhost:8080
- Result app: http://localhost:8081

---

## Step 2 — Containerize safely

All Dockerfiles have been hardened:
- **Pinned base images** (`python:3.11-slim`, `node:18-slim`, `postgres:15-alpine`, `redis:7.2-alpine`)
- **Non-root user** — each image creates and runs as `appuser`
- **`.dockerignore`** — prevents secrets, caches, and git history from entering the build context

---

## Step 3 — Provision a Kubernetes cluster with Terraform

> Requires: AWS CLI configured, Terraform >= 1.6

```bash
cd terraform
terraform init
terraform plan
terraform apply      # builds EKS cluster in the default VPC (~10 min)

# Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name voting-app-cluster

# Tear down and recreate
terraform destroy
terraform apply
```

The cluster uses the **default VPC** and creates a managed node group of 2× `t3.medium` nodes.

---

## Step 4 — CI/CD with GitHub Actions

Pipeline file: `.github/workflows/ci.yml`

Every push to `main` runs four jobs in sequence:

| Job | What it does |
|-----|-------------|
| `test` | Runs Python unit tests for the vote service |
| `scan` | Trivy filesystem scan on all three services |
| `build-push` | Builds Docker images, tags with commit SHA, pushes to GHCR |
| `deploy` | `helm upgrade --install` to EKS cluster |

**Required GitHub Secrets** (add in Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

Images are pushed to `ghcr.io/teeros/example-voting-app-{vote,result,worker}`.

---

## Step 5 — Deploy and roll back with Helm

```bash
# First-time install
helm upgrade --install voting-app ./helm/voting-app \
  --namespace voting-app --create-namespace

# Ship a bad release (simulate failure)
helm upgrade voting-app ./helm/voting-app \
  --namespace voting-app \
  --set vote.image.tag=bad-tag

# Roll back to the previous good release
helm rollback voting-app 1 --namespace voting-app

# Check history
helm history voting-app --namespace voting-app
```

---

## Project structure

```
example-voting-app/
├── vote/               Python vote service
├── result/             Node.js result service
├── worker/             .NET worker service
├── terraform/          EKS cluster (default VPC)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── helm/
│   └── voting-app/     Helm chart for all services
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── .github/
│   └── workflows/
│       └── ci.yml      Full CI/CD pipeline
└── docker-compose.yml  Local development
```

---

## Security — no secrets in Git

- Database credentials are stored in a Kubernetes `Secret` (`helm/voting-app/templates/db-secret.yaml`)
- AWS credentials live only in GitHub Secrets
- `.dockerignore` on every service keeps `.env` files out of images
