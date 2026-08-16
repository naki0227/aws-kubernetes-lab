# aws-kubernetes-lab

AWS / Kubernetes / Terraform / GitHub Actions を使って、
EKS上にフロントエンド・バックエンド・PostgreSQLを構築した学習用リポジトリです。

## Architecture

Browser
  ↓
ALB
  ↓
Ingress
  ↓
Frontend Service
  ↓
Frontend Pods
  ↓
Backend Service
  ↓
Backend Pods
  ↓
PostgreSQL
  ↓
EBS

Container images:
GitHub Actions → Amazon ECR → Amazon EKS

Infrastructure:
Terraform → VPC / EKS / ECR / IAM / EBS CSI / Pod Identity

Terraform state:
Local → Amazon S3 remote backend

## Directory

.github/workflows/
  deploy.yml       # Application CI/CD
  terraform.yml    # Terraform validation / plan

kubernetes/full-app/
  frontend/
  backend/
  database/
  networking/
  autoscaling/
  security/

terraform/dev/
  main.tf
  providers.tf
  versions.tf
  variables.tf
  outputs.tf

## CI/CD

### Application deploy

main branchへのpushで、

GitHub Actions
→ OIDCでAWS認証
→ Docker image build
→ Amazon ECRへpush
→ kubeconfig更新
→ Amazon EKS Deployment更新
→ rollout確認

を行います。

AWS access key / secret key はGitHub Secretsに保存せず、
GitHub Actions OIDCを利用しています。

### Terraform

Terraform関連ファイル変更時に、

terraform init
→ terraform fmt -check
→ terraform validate
→ terraform plan

をGitHub Actionsで実行します。

Application deploy用IAM Roleと
Terraform plan用IAM Roleは分離しています。

## Terraform state

Terraform stateはS3 backendで管理しています。

- Versioning enabled
- Public access blocked
- S3 native state locking enabled

ローカル実行時はAWS CLI profileを環境変数から指定します。

```bash
AWS_PROFILE=eks-lab terraform plan