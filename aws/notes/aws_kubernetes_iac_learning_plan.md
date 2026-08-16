# AWS → Kubernetes → IaC 学習計画

## 目的

資格取得そのものをゴールにせず、**SAA と CKA を教材として使いながら、最終的に「本番っぽい Kubernetes 環境 + IaC + AWS デプロイ」まで自力で組める状態**を目指す。

最終的には、以下をまとめて証明できる成果物を GitHub に残す。

- AWS の設計判断
- Kubernetes の基本運用
- kubectl を使ったトラブルシューティング
- Terraform による IaC
- AWS 上へのデプロイ
- 障害試験
- 設計理由のドキュメント化
- CloudFormation / AWS CDK / Terraform の比較

---

# 全体ロードマップ

## フェーズ1：AWS の設計判断を固める

**目安：1〜2週間**

SAA は「深いコーディング」ではなく、コスト・性能・可用性・セキュリティを考えて AWS 構成を選ぶ試験なので、まず AWS の部品表と判断軸を作るために使う。

### 公式リンク

- AWS Certified Solutions Architect – Associate  
  https://aws.amazon.com/jp/certification/certified-solutions-architect-associate/

- AWS Skill Builder  
  https://skillbuilder.aws/

- 公式 Practice Question Set（SAA-C03）  
  https://skillbuilder.aws/learn/6NV91XYP1P/official-practice-question-set-aws-certified-solutions-architect--associate-saac03--/DGD9JUJV5F

### 最低限説明できるようにする AWS サービス

#### Compute

- Amazon EC2
- AWS Lambda
- Amazon ECS
- Amazon EKS
- AWS Fargate
- AWS Batch

#### Network

- Amazon VPC
- Subnet
- Security Group
- Application Load Balancer
- Network Load Balancer
- Amazon Route 53
- AWS Transit Gateway
- AWS Direct Connect
- AWS Site-to-Site VPN
- AWS Client VPN

#### Storage

- Amazon S3
- Amazon EBS
- Amazon EFS
- Amazon FSx

#### Database

- Amazon RDS
- Amazon Aurora
- Amazon DynamoDB
- Amazon ElastiCache
- Amazon Redshift

#### Security

- AWS IAM
- AWS WAF
- AWS Shield
- AWS Network Firewall

#### Reliability / DR

- Multi-AZ
- Auto Scaling
- Backup & Restore
- Pilot Light
- Warm Standby
- Active-Active

### フェーズ1の終了条件

以下を自分の言葉で説明できれば OK。

> 要件を言われたとき、候補を 2〜3 個挙げて、なぜその 1 個を選ぶのか説明できる。

---

# フェーズ2：Kubernetes を CKA 範囲で学ぶ

**目安：2週間**

ただし、来週 Cybozu のインターンで Kubernetes を使うため、ここは前倒しで最優先。

### CKA 公式

https://training.linuxfoundation.org/ja/certification/certified-kubernetes-administrator-cka/

### Kubernetes Basics

https://kubernetes.io/docs/tutorials/kubernetes-basics/

### 最初に覚える順番

```text
Container
   ↓
Pod
   ↓
ReplicaSet
   ↓
Deployment
   ↓
Service
   ↓
Ingress
```

そのあと、以下に進む。

- ConfigMap
- Secret
- Namespace
- PersistentVolume
- PersistentVolumeClaim
- StorageClass
- Horizontal Pod Autoscaler（HPA）
- NetworkPolicy
- RBAC
- DaemonSet
- StatefulSet
- Job
- CronJob

---

# インターン前の Kubernetes 最優先プラン

来週のインターンまでに、まずは「kubectl で怖がらずに触れる状態」にする。

## 優先順位

1. Pod / Deployment / Service
2. Ingress
3. ConfigMap / Secret
4. Namespace
5. readinessProbe / livenessProbe
6. kubectl logs / describe / exec / get events
7. Rolling Update / Rollback
8. PersistentVolume / PersistentVolumeClaim
9. Horizontal Pod Autoscaler（HPA）
10. NetworkPolicy
11. 余裕があれば StatefulSet / Job / CronJob / RBAC

## 最低限使えるようにする kubectl

```bash
kubectl get pods
kubectl get svc
kubectl get deployments
kubectl describe pod <name>
kubectl logs <name>
kubectl exec -it <name> -- sh
kubectl get events
kubectl apply -f ...
kubectl delete -f ...
kubectl rollout status deployment/...
kubectl rollout undo deployment/...
```

YAML を完全暗記するより、**何か壊れたときに原因を追えること**を優先する。

---

# 3日間の Kubernetes 短期集中

## Day 1：Kubernetes Basics

Kubernetes Basics を一通り進める。

https://kubernetes.io/docs/tutorials/kubernetes-basics/

重点項目：

- Cluster
- Deployment
- Pod
- Service
- Scale
- Rolling Update

### この日に理解したいこと

- Pod は何か
- Deployment は何を管理しているか
- Replica 数を増やすと何が起きるか
- Service がなぜ必要か
- Rolling Update とは何か
- Pod を直接公開しない理由

---

## Day 2：kind でローカルクラスタを作る

### kind 公式

https://kind.sigs.k8s.io/

### 最初のコマンド

```bash
kind create cluster
kubectl get nodes
```

### 作るもの

```text
Ingress
   ↓
Service
   ↓
Deployment
   ├─ Pod
   ├─ Pod
   └─ Pod
```

さらに、

- ConfigMap
- Secret

まで追加する。

### 目標

自分で以下を説明できること。

- Deployment と Pod の関係
- Service が Pod にどう接続するか
- Ingress が何をしているか
- ConfigMap と Secret の違い

---

## Day 3：わざと壊して直す

### 障害パターン

#### 1. image 名を間違える

期待する状態：

```text
ImagePullBackOff
```

やること：

```bash
kubectl get pods
kubectl describe pod <name>
```

原因を見つけて修正。

#### 2. port を間違える

症状：

- Pod は起動している
- Service 経由で通信できない

確認：

```bash
kubectl get svc
kubectl describe svc <name>
kubectl get pods -o wide
```

#### 3. 環境変数を消す

症状：

- アプリ起動失敗

確認：

```bash
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

#### 4. Pod を削除する

```bash
kubectl delete pod <pod-name>
```

確認すること：

- Deployment が新しい Pod を自動で作るか

#### 5. readinessProbe を失敗させる

確認すること：

- Pod 自体は存在する
- Service からトラフィックが流れなくなる

#### 6. Rolling Update → Rollback

```bash
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
```

確認すること：

- 新バージョンの適用
- 失敗時に前バージョンへ戻せるか

---

# フェーズ3：ローカルに本番っぽい Kubernetes 環境を作る

**目安：1〜2週間**

教材だけで終わらせず、実際に 1 つサービスを作る。

## 想定構成

```text
                    Internet
                       ↓
                    Ingress
                       ↓
        ┌──────── Kubernetes ────────┐
        │                            │
        │ frontend Deployment ×2    │
        │          ↓                 │
        │ backend Deployment ×3     │
        │          ↓                 │
        │      PostgreSQL            │
        │                            │
        │ worker Deployment          │
        │                            │
        └────────────────────────────┘
```

## 入れるもの

### ConfigMap
通常設定。

### Secret
機密情報。

### PersistentVolume
PostgreSQL のデータ永続化。

### Horizontal Pod Autoscaler（HPA）
CPU などの負荷に応じて Pod 数を増減。

### NetworkPolicy

```text
frontend → backend : 許可
backend → PostgreSQL : 許可
frontend → PostgreSQL : 禁止
```

### readinessProbe / livenessProbe

- readinessProbe：トラフィックを流してよいか
- livenessProbe：プロセスが死んでいないか

---

# 本番っぽい障害試験

以下を実施して結果を残す。

- backend Pod を 1 個削除
- Node を落とす
- CPU 負荷をかける
- ConfigMap を変更
- Secret を更新
- 壊れた image をデプロイ
- Rolling Update
- Rollback
- NetworkPolicy で通信遮断
- PostgreSQL 障害

## 記録すること

- 何を壊したか
- どんな症状が出たか
- どう調査したか
- どのコマンドを使ったか
- 原因は何だったか
- どう直したか

---

# フェーズ4：Terraform + AWS

**目安：2週間**

## Terraform AWS チュートリアル

https://developer.hashicorp.com/terraform/tutorials/aws-get-started

### まず理解するコマンド

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

### 最初に作る AWS 構成

```text
AWS
│
├─ VPC
├─ Public Subnet
├─ Private Subnet
├─ Security Group
└─ EC2
```

### 次に作る本命構成

```text
AWS
│
├─ VPC
│   ├─ Public Subnet ×2
│   └─ Private Subnet ×2
│
├─ IAM
├─ Amazon EKS
├─ Kubernetes Nodes
│   └─ AWS Fargate も候補
├─ Application Load Balancer
└─ Database
```

### AWS では長時間動かしっぱなしにしない

```text
terraform apply
    ↓
動作確認
    ↓
スクリーンショット・ログ保存
    ↓
ドキュメント作成
    ↓
terraform destroy
```

---

# AWS Budgets を先に設定

AWS アカウントを作ったばかりなら、予算アラートを最初に設定する。

https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-create.html

目的：

- EKS
- NAT Gateway
- Load Balancer
- EC2

などの消し忘れ対策。

---

# Terraform / CloudFormation / AWS CDK 比較

Terraform が理解できたら、同じ小規模構成を 3 方式で実装する。

```text
IaC
├─ Terraform
├─ AWS CloudFormation
└─ AWS CDK
```

## 注意

**同じ実リソースを 3 つの IaC で同時管理しない。**

学習用に別環境として作る。

```text
iac-comparison/
├─ terraform/
├─ cloudformation/
└─ cdk/
```

例：

```text
VPC + Subnet + EC2
```

をそれぞれで作る。

## 比較項目

| 観点 | Terraform | CloudFormation | AWS CDK |
|---|---|---|---|
| 記述量 |  |  |  |
| 可読性 |  |  |  |
| 型安全性 |  |  |  |
| AWS 依存度 |  |  |  |
| 再利用性 |  |  |  |
| 状態管理 |  |  |  |
| plan / diff |  |  |  |
| AI に変更させやすいか |  |  |  |

---

# 最終成果物

```text
cloud-native-lab/
│
├─ app/
│   ├─ frontend/
│   └─ backend/
│
├─ kubernetes/
│   ├─ base/
│   ├─ deployment/
│   ├─ service/
│   ├─ ingress/
│   ├─ network-policy/
│   └─ monitoring/
│
├─ terraform/
│   ├─ modules/
│   ├─ networking/
│   └─ eks/
│
├─ cloudformation/
├─ cdk/
│
├─ docs/
│   ├─ architecture.md
│   ├─ decisions/
│   ├─ failure-tests.md
│   ├─ cost.md
│   └─ security.md
│
└─ README.md
```

README 冒頭の目標文：

> **AWS・Kubernetes・IaC を用いて、本番運用を想定したクラウドネイティブ環境を設計・構築し、障害試験まで実施したプロジェクト**

---

# 推奨スケジュール

## 今週

- SAA の知識確認
- Kubernetes Basics
- kubectl 基本操作
- kind 導入
- Deployment / Service / Ingress
- ConfigMap / Secret
- 基本的な障害対応

## 来週

**Cybozu インターン**

インターン前に以下ができれば十分。

- Pod の状態確認
- logs
- describe
- exec
- Service の確認
- Deployment の確認
- Rolling Update
- Rollback
- ImagePullBackOff の調査
- port ミスの調査

## インターン後 1〜2週間

- CKA 範囲を広げる
- PersistentVolume
- PersistentVolumeClaim
- HPA
- NetworkPolicy
- RBAC
- StatefulSet
- Job / CronJob
- 本番っぽいローカルクラスタ完成
- 障害試験

## その次

- Terraform 基礎
- AWS VPC / EC2 を Terraform で構築
- Terraform + Amazon EKS
- AWS 上で短時間デプロイ
- terraform destroy

## 最後

- CloudFormation / AWS CDK 比較
- GitHub 整理
- architecture.md
- ADR
- failure-tests.md
- cost.md
- security.md
- README 作成

---

# この学習計画のゴール

資格を持っているだけではなく、以下まで説明・実演できる状態を目指す。

> なぜこの構成にしたのか

> 障害時にどう動くのか

> どこをどう調べれば原因が分かるのか

> 同じ環境を IaC でどう再現するのか

学習の流れ：

```text
AWS サービスを知る
        ↓
設計判断ができる
        ↓
Kubernetes を実際に触る
        ↓
わざと壊して直す
        ↓
Terraform で再現する
        ↓
AWS へデプロイする
        ↓
CloudFormation / CDK と比較する
        ↓
GitHub で成果物として残す
```
