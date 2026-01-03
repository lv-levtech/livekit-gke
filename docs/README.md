# LiveKit on GKE - セットアップガイド

LiveKit ServerをGoogle Kubernetes Engine (GKE)上にセルフホストするための構成です。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Google Cloud Platform                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
│  │    prd      │   │    stg      │   │    dev      │       │
│  │    GKE      │   │    GKE      │   │    GKE      │       │
│  │  Cluster    │   │  Cluster    │   │  Cluster    │       │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘       │
│         │                 │                 │               │
│  ┌──────┴──────┐   ┌──────┴──────┐   ┌──────┴──────┐       │
│  │ Memorystore │   │ Memorystore │   │ Memorystore │       │
│  │   (Redis)   │   │   (Redis)   │   │   (Redis)   │       │
│  └─────────────┘   └─────────────┘   └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## 前提条件

- Google Cloud Platform アカウント
- `gcloud` CLI がインストール・設定済み
- `terraform` v1.5.0以上
- `helm` v3.14.0以上
- `kubectl`

## ディレクトリ構成

```
livekit-gke/
├── terraform/
│   ├── modules/          # 再利用可能なTerraformモジュール
│   │   ├── network/      # VPC、サブネット、ファイアウォール
│   │   ├── gke/          # GKEクラスタ
│   │   ├── memorystore/  # Cloud Memorystore (Redis)
│   │   ├── dns/          # 静的IP、Managed Certificate
│   │   ├── iam/          # Workload Identity、サービスアカウント
│   │   └── secret-manager/ # Secret Manager
│   └── environments/     # 環境別設定
│       ├── dev/          # 開発環境
│       ├── stg/          # ステージング環境
│       └── prd/          # 本番環境
├── helm/
│   ├── values/           # Helm values
│   │   ├── common.yaml   # 共通設定
│   │   ├── dev.yaml      # 開発環境
│   │   ├── stg.yaml      # ステージング環境
│   │   └── prd.yaml      # 本番環境
│   └── scripts/
│       └── deploy.sh     # デプロイスクリプト
├── .github/workflows/    # GitHub Actions
└── docs/                 # ドキュメント
```

## クイックスタート

### 1. GCSバケットの作成（Terraformステート用）

```bash
# プロジェクトIDを設定
export PROJECT_ID="your-gcp-project-id"
export BUCKET_NAME="${PROJECT_ID}-terraform-state"

# バケット作成
gsutil mb -p ${PROJECT_ID} -l asia-northeast1 gs://${BUCKET_NAME}
gsutil versioning set on gs://${BUCKET_NAME}
```

### 2. Terraformバックエンドの設定

各環境の `backend.tf` を編集:

```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_TERRAFORM_STATE_BUCKET"
    prefix = "livekit/dev"  # dev, stg, prd
  }
}
```

### 3. 変数ファイルの作成

```bash
cd terraform/environments/dev

# サンプルからコピー
cp terraform.tfvars.example terraform.tfvars

# 編集
vim terraform.tfvars
```

必要な変数:
- `project_id`: GCPプロジェクトID
- `domain`: LiveKitのドメイン (例: livekit-dev.example.com)
- `turn_domain`: TURNサーバーのドメイン (例: turn-dev.example.com)
- `livekit_api_key`: LiveKit APIキー
- `livekit_api_secret`: LiveKit APIシークレット

### 4. Terraformの実行

```bash
cd terraform/environments/dev

# 初期化
terraform init

# 計画確認
terraform plan

# 適用
terraform apply
```

### 5. kubectlの設定

```bash
# Terraformの出力からコマンドを取得
terraform output get_credentials_command

# 例:
gcloud container clusters get-credentials livekit-cluster-dev \
  --region asia-northeast1 --project your-project-id
```

### 6. TURN用TLS証明書の作成

TURNサーバーには別途TLS証明書が必要です:

```bash
# Let's Encryptで取得した証明書を使用する場合
kubectl create secret tls livekit-turn-tls-dev \
  --cert=/path/to/fullchain.pem \
  --key=/path/to/privkey.pem \
  -n livekit
```

### 7. Helmデプロイ

```bash
# デプロイスクリプトを使用
./helm/scripts/deploy.sh dev install

# または手動で
helm repo add livekit https://helm.livekit.io
helm repo update

helm install livekit livekit/livekit-server \
  -f helm/values/common.yaml \
  -f helm/values/dev.yaml \
  --namespace livekit --create-namespace
```

## 環境設定の違い

| 設定 | dev | stg | prd |
|------|-----|-----|-----|
| ノードタイプ | c2-standard-4 | c2-standard-8 | c2-standard-8 |
| ノード数 | 1-3 | 2-5 | 3-10 |
| Redisサイズ | 1GB | 2GB | 5GB |
| Redis HA | BASIC | BASIC | STANDARD_HA |
| Replicas | 1 | 2 | 3 |
| Autoscaling | 無効 | 有効 | 有効 |
| PDB | 無効 | minAvailable: 1 | minAvailable: 2 |

## ポート設定

LiveKitに必要なポート:

| ポート | プロトコル | 用途 |
|--------|-----------|------|
| 7880 | TCP | WebSocket API |
| 7881 | TCP | WebRTC over TCP |
| 50000-60000 | UDP | WebRTC media |
| 5349 | TCP | TURN/TLS |
| 3478 | UDP | TURN/UDP + STUN |
| 6789 | TCP | Prometheus メトリクス |
| 80 | TCP | TLS証明書発行 |

## 重要な制約

### 1ノード1Pod制約

LiveKitはhost networkingを使用するため、1ノードに1 Podしか配置できません。
HPAの`maxReplicas`はノードプールの`maxNodes`以下に設定してください。

### Private Cluster非対応

WebRTC通信の特性上、Private Clusterは使用できません。
NATレイヤーがWebRTC通信に対応していないためです。

### 2種類のTLS証明書

- **メインドメイン**: GKE Managed Certificate使用可
- **TURNドメイン**: Kubernetes Secretで別途管理必須

## CI/CD

### GitHub Secrets

以下のSecretsを設定:

- `GCP_PROJECT_ID`: GCPプロジェクトID
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: Workload Identity Provider
- `GCP_SERVICE_ACCOUNT`: CI/CD用サービスアカウント
- `GCP_REGION`: リージョン (デフォルト: asia-northeast1)
- `LIVEKIT_API_KEY`: LiveKit APIキー
- `LIVEKIT_API_SECRET`: LiveKit APIシークレット

### Workload Identity設定

GitHub ActionsからGCPにアクセスするため、Workload Identityを設定:

```bash
# Workload Identity Pool作成
gcloud iam workload-identity-pools create "github-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Provider作成
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# サービスアカウントへのバインド
gcloud iam service-accounts add-iam-policy-binding \
  "livekit-cicd@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/YOUR_REPO"
```

### ワークフロー

- **terraform-plan.yml**: PRで`terraform/**`変更時に実行
- **terraform-apply.yml**: mainマージで自動適用
- **helm-deploy.yml**: `helm/**`変更時またはワークフロー手動実行

## トラブルシューティング

### Podがスケジュールされない

```bash
# ノードの状態確認
kubectl get nodes -o wide

# Podの詳細確認
kubectl describe pod -n livekit -l app.kubernetes.io/name=livekit-server
```

Anti-Affinityにより1ノード1Podの制約があるため、Podの数がノード数を超えるとPendingになります。

### WebSocket接続が切れる

BackendConfigのタイムアウト設定を確認:

```bash
kubectl get backendconfig -n livekit -o yaml
```

`timeoutSec`が`36000`（10時間）に設定されていることを確認してください。

### TURN接続エラー

1. TURN用TLS証明書が正しく設定されているか確認
2. ファイアウォールでポート5349, 3478が開いているか確認
3. DNSレコードが正しいか確認

```bash
# Secret確認
kubectl get secret livekit-turn-tls-dev -n livekit

# ファイアウォール確認
gcloud compute firewall-rules list --filter="name~livekit"
```

## 参考リンク

- [LiveKit Self-hosting Kubernetes](https://docs.livekit.io/realtime/self-hosting/kubernetes/)
- [LiveKit Helm Charts](https://github.com/livekit/livekit-helm)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [GKE Managed Certificates](https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs)
