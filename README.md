# aws-kubernetes-lab

AWS、Kubernetes、Terraform、GitHub Actions を使って、Amazon EKS 上にフロントエンド・バックエンド・PostgreSQL を構築した学習用リポジトリです。

単にアプリケーションを EKS 上で動かすだけではなく、Kubernetes の基本的なリソース設計、AWS 上でのマネージド Kubernetes 運用、Terraform による Infrastructure as Code、GitHub Actions と OIDC を利用した CI/CD、IAM Role の責務分離、Persistent Storage、Ingress、NetworkPolicy、RBAC などを一通り実際に構築することを目的としています。

ローカル Kubernetes で学んだ内容を Amazon EKS 上に移し、ローカル環境とクラウド環境で何が共通し、何が AWS 固有の実装に置き換わるのかを確認しながら構築しました。

## Overview

- Amazon EKS 上に Frontend / Go Backend / PostgreSQL を構築
- Terraform で VPC / EKS / ECR / IAM / Pod Identity を管理
- GitHub Actions + OIDC で Application Deploy と Terraform Plan を自動化
- PostgreSQL は EBS に永続化
- ALB / Ingress / NetworkPolicy / RBAC / HPA まで検証

## Key Design Decisions

- Application Deploy と Terraform Plan の IAM Role を分離
- AWS Access Key を GitHub に保存せず OIDC を利用
- Terraform State を S3 Remote Backend で管理
- PostgreSQL Secret の実値は Git 管理外
- Kubernetes から生成される AWS Resource と Terraform 管理 Resource を意識して分離

## Architecture

アプリケーションへのアクセスは以下の流れです。

Browser
→ Application Load Balancer
→ Kubernetes Ingress
→ Frontend Service
→ Frontend Pods
→ Backend Service
→ Backend Pods
→ PostgreSQL StatefulSet
→ PersistentVolumeClaim
→ Amazon EBS

フロントエンドは Nginx ベースのコンテナとして動作し、バックエンドは Go で実装しています。

バックエンドから PostgreSQL に接続し、PostgreSQL のデータは Amazon EBS に永続化しています。

外部公開には AWS Load Balancer Controller を利用し、Kubernetes の Ingress Resource から Application Load Balancer を作成しています。

## AWS Architecture

AWS 上では主に以下のサービスを利用しています。

Amazon EKS は Kubernetes Control Plane を管理します。

Amazon EC2 は EKS Managed Node Group の Worker Node として利用しています。

Amazon ECR は frontend / backend の Docker Image Repository として利用しています。

Application Load Balancer は Kubernetes Ingress 経由で外部からアプリケーションへアクセスするために利用しています。

Amazon EBS は PostgreSQL の Persistent Volume として利用しています。

Amazon S3 は Terraform remote state の保存先として利用しています。

AWS IAM は EKS、EBS CSI Driver、AWS Load Balancer Controller、GitHub Actions などの権限制御に利用しています。

EKS Pod Identity を利用して、Kubernetes 上の ServiceAccount と AWS IAM Role を関連付けています。

## Kubernetes Architecture

Kubernetes 上では、役割ごとにリソースを分離しています。

Frontend と Backend は Deployment で管理しています。

Deployment から ReplicaSet が作成され、ReplicaSet が必要な数の Pod を維持します。

Frontend と Backend にはそれぞれ Service を作成し、Pod の IP Address が変化しても安定した名前で通信できるようにしています。

PostgreSQL は StatefulSet を利用しています。

StatefulSet を利用することで Pod に安定した名前と Storage を持たせています。

PostgreSQL の Storage には PersistentVolumeClaim を利用し、StorageClass 経由で Amazon EBS を動的に作成しています。

外部通信には Ingress を利用しています。

Ingress は AWS Load Balancer Controller によって Application Load Balancer に変換されます。

Backend には HorizontalPodAutoscaler を設定し、負荷に応じて Pod 数を調整できる構成にしています。

NetworkPolicy を利用して、Backend や PostgreSQL へアクセスできる Pod を制限しています。

ServiceAccount、Role、RoleBinding を利用して Kubernetes API へのアクセス権限も分離しています。

## Repository Structure

`.github/workflows/` には GitHub Actions の Workflow を配置しています。

`deploy.yml` は Application Deployment 用です。

`terraform.yml` は Terraform の validation / plan 用です。

`kubernetes/full-app/frontend/` には frontend の Dockerfile と Kubernetes Manifest を配置しています。

`kubernetes/full-app/backend/` には Go backend、Dockerfile、Deployment、Service を配置しています。

`kubernetes/full-app/database/` には PostgreSQL、StorageClass、初期化 SQL、Secret の example file などを配置しています。

`kubernetes/full-app/networking/` には Ingress と NetworkPolicy を配置しています。

`kubernetes/full-app/autoscaling/` には HorizontalPodAutoscaler を配置しています。

`kubernetes/full-app/security/` には ServiceAccount や RBAC 関連 Manifest を配置しています。

`terraform/dev/` には AWS Infrastructure を構築する Terraform code を配置しています。

## Terraform

AWS Infrastructure は Terraform で管理しています。

Terraform では主に以下を構築しています。

VPC、Public Subnet、Internet Gateway、Route Table、Amazon EKS、EKS Managed Node Group、Amazon ECR、EBS CSI Driver 用 IAM Role、AWS Load Balancer Controller 用 IAM Role、GitHub Actions OIDC Provider、GitHub Actions 用 IAM Role などです。

Terraform module には terraform-aws-modules/vpc/aws と terraform-aws-modules/eks/aws を利用しています。

Infrastructure の作成と Application Deployment は責務を分離しています。

頻繁に変更される Application は GitHub Actions から Deployment を更新し、Infrastructure の変更が必要な場合のみ Terraform を使用します。

## Terraform Remote State

Terraform state はローカルファイルではなく Amazon S3 に保存しています。

S3 Bucket では Versioning を有効化しています。

また、Public Access Block を設定し、Terraform state が外部公開されないようにしています。

Terraform の S3 native state locking を有効化しているため、複数の Terraform process が同時に state を変更しないよう制御できます。

ローカル環境から実行する場合は AWS CLI profile を利用します。

`AWS_PROFILE=eks-lab terraform init`

`AWS_PROFILE=eks-lab terraform plan`

`AWS_PROFILE=eks-lab terraform apply`

GitHub Actions 上では local profile を利用せず、OIDC から取得した一時的な AWS Credential を利用します。

## CI/CD

Application と Terraform では Workflow を分離しています。

Application Deployment Workflow では main branch への 特定のファイルの push を起点に処理を実行します。

GitHub Actions
→ GitHub OIDC
→ AWS IAM Role
→ Amazon ECR Login
→ Docker Image Build
→ Amazon ECR Push
→ Amazon EKS kubeconfig Update
→ Kubernetes Deployment Image Update
→ Rollout Status Check

frontend と backend の Docker Image には Git Commit SHA を Tag として利用できる構成にしており、どの Commit から作られた Image か追跡できるようにしています。

## GitHub Actions OIDC

GitHub Actions から AWS に接続するために、Access Key と Secret Access Key を GitHub Secrets に保存する構成にはしていません。

代わりに GitHub Actions OIDC を利用しています。

GitHub Actions
→ OIDC Token
→ AWS STS
→ IAM Role Assume
→ Temporary Credential

という流れで AWS にアクセスします。

これにより、長期間有効な AWS Access Key を GitHub に保存する必要がありません。

OIDC Trust Policy では対象 Repository と main branch を制限しています。

## IAM Role Separation

GitHub Actions 用 IAM Role は Application Deployment 用と Terraform Plan 用に分離しています。

Application Deployment Role は Amazon ECR への Image Push と Amazon EKS への Deployment 更新に必要な権限を持っています。

Terraform Plan Role は AWS Resource の状態を読み取るための ReadOnly 権限と、Terraform remote state を管理するために必要な S3 権限を持っています。

このように Role を分離することで、Application Deployment Workflow に Infrastructure 全体を変更できる権限を与えないようにしています。

## Container Image Build

開発環境には Apple Silicon Mac を利用しているため、ローカル環境は arm64 Architecture です。

一方、EKS Managed Node Group は x86_64 Architecture の EC2 Instance を利用しています。

そのため Docker Image Build 時には linux/amd64 Platform を指定しています。

これにより、Mac 上で作成した Image を EKS Worker Node 上で正常に実行できるようにしています。

## PostgreSQL

PostgreSQL は StatefulSet として EKS 上に配置しています。

Storage には Amazon EBS を利用しています。

EBS CSI Driver を EKS Add-on として導入し、PersistentVolumeClaim から Amazon EBS Volume を動的に作成しています。

PostgreSQL Container では `PGDATA` を `/var/lib/postgresql/data/pgdata` に設定しています。

これは EBS Volume の Root Directory に存在する `lost+found` などの影響を避けるためです。

Database 初期化用 SQL は ConfigMap として Pod に Mount しています。

PostgreSQL の `/docker-entrypoint-initdb.d/` を利用し、新しい Volume が初期化される際に Table や初期データを作成します。

## Secret Management

PostgreSQL Password を含む Kubernetes Secret は Repository に Commit しません。

Repository には Example File のみを保存します。

`kubernetes/full-app/database/postgres-secret.example.yaml`

実際の環境ではこれをコピーして、

`kubernetes/full-app/database/postgres-secret.yaml`

を作成します。

実際の Secret File は `.gitignore` に追加しています。

なお、Kubernetes Secret 自体は暗号化された Secret Store ではないため、本番環境では AWS Secrets Manager や External Secrets Operator などの利用を検討する必要があります。

## Storage

PostgreSQL のデータは Pod 内ではなく PersistentVolume に保存します。

Pod
→ PersistentVolumeClaim
→ StorageClass
→ EBS CSI Driver
→ Amazon EBS

という流れで Storage を割り当てています。

Pod が削除・再作成されても、PersistentVolume が残っていれば Database Data は保持されます。

## Networking

Frontend、Backend、PostgreSQL 間の通信には Kubernetes Service を利用しています。

Service は Pod Name ではなく Label Selector を利用して対象 Pod を見つけます。

Service の裏側では EndpointSlice が利用され、現在通信可能な Pod Endpoint が管理されます。

Frontend から Backend へは Service Name を利用して通信します。

Backend から PostgreSQL へも Kubernetes DNS を利用します。

## Ingress and ALB

外部公開には Kubernetes Ingress を利用しています。

Ingress Resource を作成すると AWS Load Balancer Controller が監視し、AWS API を利用して Application Load Balancer を作成します。

Browser
→ ALB
→ Ingress Rule
→ Frontend Service
→ Frontend Pod

という通信経路になります。

AWS Load Balancer Controller には EKS Pod Identity を利用して AWS IAM Role を付与しています。

AWS Load Balancer Controller の ServiceAccount は現在手動で作成しているため、
今後 Helm / Terraform 側へ管理を移して完全に再現可能な構成にする予定です。

## NetworkPolicy

NetworkPolicy を利用して Pod 間通信を制限しています。

例えば PostgreSQL に対して、任意の Pod から自由に接続できる状態にはせず、Backend からの通信のみ許可する構成を検証しています。

Kubernetes の Ingress Resource と NetworkPolicy の ingress は別の概念です。

Ingress Resource は主に Cluster 外部から Service への HTTP Routing を扱います。

NetworkPolicy の ingress は Pod への Network Traffic 制御を扱います。

## Horizontal Pod Autoscaler

Backend には HorizontalPodAutoscaler を設定しています。

HPA は Metrics Server から CPU 使用率などの Metrics を取得し、Deployment の Replica 数を変更します。

HPA
→ Deployment
→ ReplicaSet
→ Pod 数変更

という流れになります。

HPA を利用するため、Container には CPU Requests を設定しています。

## Resource Requests and Limits

Pod には CPU と Memory の Requests / Limits を設定できます。

Requests は Scheduler が Pod を Node に配置する際に利用します。

Limits は Container が利用できる最大 Resource を制限します。

CPU Limit を超えた場合は CPU Throttling が発生します。

Memory Limit を超えた場合は OOMKilled になる可能性があります。

## Readiness and Liveness Probe

Application Pod には Health Check を設定できます。

Readiness Probe は、その Pod に Traffic を送ってよいかを判断します。

Readiness Probe が失敗した Pod は Running 状態でも Service の Endpoint から除外されます。

Liveness Probe は Container を Restart すべきかを判断します。

Liveness Probe が一定回数失敗すると kubelet が Container を Restart します。

## RBAC

Kubernetes API へのアクセスには RBAC を利用しています。

ServiceAccount
→ RoleBinding
→ Role
→ Kubernetes API Permission

という形で権限を設定します。

Role は Namespace 内の Resource に対して権限を設定します。

ClusterRole は Cluster 全体で利用可能な Permission を定義できます。

必要以上の Permission を与えないことを意識しています。

## Scheduling

Kubernetes Scheduler の Placement Control についても検証しています。

nodeSelector、Node Affinity、Pod Anti-Affinity、Taint、Toleration などを利用して Pod の配置を制御できます。

nodeSelector は単純な Node Label 指定です。

Node Affinity はより柔軟な条件を設定できます。

Pod Anti-Affinity を利用すると、同じ Application の Pod を異なる Node に分散できます。

Taint は特定 Node への Scheduling を制限します。

Toleration を持つ Pod はその Taint を許容できます。

## Rolling Update

Deployment の Image を変更すると Rolling Update が行われます。

新しい Pod を少しずつ作成し、Ready になった Pod へ Traffic を切り替えながら古い Pod を削除します。

存在しない Image Tag を指定した場合には `ErrImagePull` や `ImagePullBackOff` が発生します。

Rolling Update が正常に進まない場合でも、既存の Ready Pod が残ることで Service を継続できることを確認しました。

`kubectl rollout undo` を利用した Rollback も検証しています。

## Troubleshooting

今回の構築では意図的なものを含め、複数のエラーを確認しました。

Pod が `Pending` の場合は `kubectl describe pod` で Events を確認します。

`ImagePullBackOff` の場合は Image Name、Tag、Registry、Permission を確認します。

`CrashLoopBackOff` の場合は `kubectl logs` や `kubectl logs --previous` を利用します。

Pod が `Running` なのに `0/1` の場合は Readiness Probe を確認します。

Service へ接続できない場合は Selector、Label、EndpointSlice、Target Port を確認します。

通信 Timeout の場合は NetworkPolicy や Network Path を確認します。

Connection Refused の場合は Application が対象 Port で Listen しているか確認します。

DNS 解決に失敗する場合は Service Name や CoreDNS を確認します。

## Problems Encountered

今回の構築では、実際にいくつかの問題に遭遇しました。

EKS Managed Node が NotReady になった際には VPC CNI Add-on が不足していました。

EBS CSI Driver の導入では IAM Policy と Pod Identity Association を調整しました。

AWS Load Balancer Controller では ServiceAccount が存在せず Pod が作成できない問題が発生しました。

Mac の arm64 環境から x86_64 EKS Node 用 Image を作成するために Docker Build Platform を指定しました。

GitHub Actions OIDC では Trust Policy の subject format を確認しました。

Terraform CI では local AWS profile が GitHub Actions Runner に存在しない問題があり、Provider から local profile dependency を除外しました。

Terraform Plan では Application Deployment Role に AWS Resource の Read Permission が不足していたため、Terraform Plan 専用 IAM Role を分離しました。

Terraform State を Local Backend から Amazon S3 Backend へ Migration しました。

これらを通して、Application Code だけでなく、IAM、Networking、Storage、CI/CD、State Management まで含めた構築を経験しています。

## Local Terraform Usage

Terraform Directory に移動します。

`cd terraform/dev`

初回は Terraform を初期化します。

`AWS_PROFILE=eks-lab terraform init`

変更内容を確認します。

`AWS_PROFILE=eks-lab terraform plan`

Infrastructure を変更する場合は Apply します。

`AWS_PROFILE=eks-lab terraform apply`

Terraform State は S3 Backend に保存されます。

## Application Deployment

Application Image の変更は GitHub Actions から自動 Deployment されます。

main branch への frontend / backend 関連ファイルの push を検知すると frontend / backend Image が Build され、Amazon ECR に Push されます。

その後、GitHub Actions が Amazon EKS に接続し、Deployment の Container Image を新しい Image に変更します。

最後に `kubectl rollout status` で Deployment が正常に完了したことを確認します。

## Security Considerations

AWS Access Key を Repository や GitHub Secrets に長期間保存しないよう、GitHub Actions OIDC を利用しています。

Terraform Plan と Application Deployment の IAM Role を分離しています。

Database Password を Repository に Commit しない構成にしています。

S3 Terraform State Bucket は Public Access を Block しています。

NetworkPolicy を利用して Pod 間通信を制御しています。

RBAC を利用して Kubernetes API Permission を制御しています。

本番環境ではさらに Private Subnet、Secrets Manager、KMS、WAF、HTTPS、監査 Log、Container Image Scan、Policy as Code などを導入する余地があります。

## Production Improvements

この Repository は学習用のため、本番環境としては改善できる点があります。

EKS Worker Node を Private Subnet に配置すること。

NAT Gateway または VPC Endpoint を適切に利用すること。

Route 53 と ACM を利用して HTTPS 化すること。

AWS Secrets Manager または External Secrets Operator を利用すること。

RDS / Aurora を利用して Database を Kubernetes Cluster 外へ分離すること。

CloudWatch、Prometheus、Grafana などを利用して Monitoring を追加すること。

Terraform Plan を Pull Request で実行し、Terraform Apply に Approval を設けること。

Development / Staging / Production Environment を分離すること。

Container Image Vulnerability Scan を CI に追加すること。

Kubernetes Manifest を Helm や Kustomize で管理すること。

GitOps として Argo CD や Flux を利用することなどが考えられます。

## Cleanup

AWS Resource は起動しているだけで Cost が発生するものがあります。

特に Amazon EKS Control Plane、EC2 Worker Node、Application Load Balancer、Amazon EBS などには注意が必要です。

削除する際は、Kubernetes から作成された AWS Resource を先に削除してから Terraform Destroy を行います。

Ingress
→ Application Load Balancer 削除確認
→ PostgreSQL PVC / EBS 削除
→ AWS Load Balancer Controller 削除
→ Terraform Destroy

という順序で削除します。

Terraform Destroy を行う前に Application Load Balancer や Persistent Volume を削除しないと、AWS Resource が残る可能性があります。

S3 の Terraform State Bucket は Terraform の管理対象外として作成しているため、Terraform Destroy 後も残ります。

## What I Learned

このプロジェクトでは、Kubernetes Object の使い方だけでなく、それぞれの Resource がどのようにつながっているかを重視して学習しました。

Deployment → ReplicaSet → Pod

Service → EndpointSlice → Pod

Ingress → Service → Pod

HPA → Deployment → ReplicaSet → Pod

Pod → PVC → PV → Amazon EBS

GitHub Actions → OIDC → IAM Role → AWS

Terraform → S3 Remote State → AWS Infrastructure

といった処理の流れを実際に構築しながら確認しました。

ローカル Kubernetes と Amazon EKS では Kubernetes Resource 自体の考え方は共通ですが、Load Balancer、Storage、Identity、Network などの実装部分が AWS の Service に置き換わることも確認できました。

この Repository は、Kubernetes、AWS、Terraform、CI/CD を個別に学ぶのではなく、それらを一つの Application Infrastructure として接続して理解することを目的としています。
