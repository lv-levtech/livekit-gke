# LiveKit on GKE Self-Hosting

GKE (Google Kubernetes Engine) で LiveKit Server をセルフホストするための Terraform および Helm 構成。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────────┐
│                           GCP Project                                │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                        VPC Network                            │  │
│  │                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                   GKE Cluster                           │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │  │  │
│  │  │  │ LiveKit Pod │  │ LiveKit Pod │  │ LiveKit Pod │     │  │  │
│  │  │  │ (Node 1)    │  │ (Node 2)    │  │ (Node 3)    │     │  │  │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘     │  │  │
│  │  │        │                │                │              │  │  │
│  │  │        └────────────────┴────────────────┘              │  │  │
│  │  │                         │                                │  │  │
│  │  └─────────────────────────│────────────────────────────────┘  │  │
│  │                            │                                    │  │
│  │  ┌─────────────────────────┴────────────────────────────────┐  │  │
│  │  │              Cloud Memorystore (Redis)                   │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐   ┌────────────────┐  │
│  │ Cloud DNS        │   │ Secret Manager   │   │ Cloud IAM      │  │
│  │ - A Records      │   │ - API Key        │   │ - Workload ID  │  │
│  │ - Managed Cert   │   │ - API Secret     │   │ - SA Roles     │  │
│  └──────────────────┘   └──────────────────┘   └────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## 必要条件

- Terraform >= 1.5.0
- Helm >= 3.13.0
- Google Cloud SDK (gcloud)
- kubectl
- GCP プロジェクト（オーナー権限または必要な IAM 権限）

## ディレクトリ構成

```
livekit-gke/
├── terraform/
│   ├── modules/
│   │   ├── network/          # VPC、サブネット、ファイアウォール
│   │   ├── gke/              # GKE クラスタ
│   │   ├── memorystore/      # Cloud Memorystore (Redis)
│   │   ├── dns/              # 静的IP、DNS、Managed Certificate
│   │   ├── iam/              # サービスアカウント、Workload Identity
│   │   └── secret-manager/   # Secret Manager
│   └── environments/
│       ├── dev/              # 開発環境
│       ├── stg/              # ステージング環境
│       └── prd/              # 本番環境
├── helm/
│   ├── values/
│   │   ├── common.yaml       # 共通設定
│   │   ├── dev.yaml          # 開発環境設定
│   │   ├── stg.yaml          # ステージング環境設定
│   │   └── prd.yaml          # 本番環境設定
│   └── scripts/
│       ├── deploy.sh         # デプロイスクリプト
│       └── status.sh         # ステータス確認スクリプト
└── .github/
    └── workflows/
        ├── terraform-plan.yml   # PR時のTerraform Plan
        ├── terraform-apply.yml  # Terraform Apply
        └── helm-deploy.yml      # Helm Deploy
```

## セットアップ手順

### 1. 前提条件の設定

```bash
# GCPプロジェクトの設定
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# 必要なAPIを有効化
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  redis.googleapis.com \
  dns.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com
```

### 2. Terraform State用のGCSバケット作成

```bash
# バケット作成
gsutil mb -l asia-northeast1 gs://${PROJECT_ID}-terraform-state

# バージョニング有効化
gsutil versioning set on gs://${PROJECT_ID}-terraform-state
```

### 3. 環境変数ファイルの設定

各環境ディレクトリで設定ファイルを作成:

```bash
cd terraform/environments/dev

# backend.tf を編集してバケット名を設定
sed -i "s/YOUR_TERRAFORM_STATE_BUCKET/${PROJECT_ID}-terraform-state/" backend.tf

# terraform.tfvars を作成
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars を編集
vim terraform.tfvars
```

**terraform.tfvars の設定例:**

```hcl
project_id  = "your-gcp-project-id"
region      = "asia-northeast1"
domain      = "livekit.example.com"
turn_domain = "turn.example.com"
```

### 4. Terraform の実行

```bash
# 開発環境のデプロイ
cd terraform/environments/dev

terraform init
terraform plan
terraform apply
```

### 5. kubectl の設定

```bash
# Terraform output からコマンドを取得して実行
$(terraform output -raw get_credentials_command)
```

### 6. LiveKit API キーの作成

```bash
# ランダムなAPIキーを生成
API_KEY=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
API_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9')

echo "API Key: $API_KEY"
echo "API Secret: $API_SECRET"

# Kubernetes Secret として保存
kubectl create namespace livekit
kubectl create secret generic livekit-server-keys \
  --from-literal=LIVEKIT_API_KEY=$API_KEY \
  --from-literal=LIVEKIT_API_SECRET=$API_SECRET \
  -n livekit
```

### 7. TURN TLS 証明書の設定

TURN サーバー用の TLS 証明書が必要です:

```bash
# Let's Encrypt または他のCAから証明書を取得後
kubectl create secret tls livekit-turn-tls-dev \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n livekit
```

### 8. Helm デプロイ

```bash
# デプロイスクリプトを使用
cd helm/scripts
./deploy.sh dev install

# または直接 Helm を使用
helm repo add livekit https://helm.livekit.io
helm repo update

REDIS_ADDR=$(terraform output -raw redis_address)

helm install livekit livekit/livekit-server \
  -f ../values/common.yaml \
  -f ../values/dev.yaml \
  --set livekit.redis.address=$REDIS_ADDR \
  -n livekit
```

### 9. デプロイ確認

```bash
# ステータス確認スクリプト
./status.sh dev

# または kubectl で直接確認
kubectl get pods -n livekit
kubectl get svc -n livekit
kubectl get ingress -n livekit
```

## 環境別設定

| 環境 | ノードタイプ | ノード数 | Redis | 用途 |
|------|-------------|---------|-------|------|
| dev  | c2-standard-4 | 1-3 | BASIC | 開発・テスト |
| stg  | c2-standard-8 | 2-5 | BASIC | ステージング |
| prd  | c2-standard-8 | 3-10 | STANDARD_HA | 本番 |

## ポート構成

| ポート | プロトコル | 用途 |
|--------|-----------|------|
| 7880 | TCP | WebSocket API |
| 7881 | TCP | WebRTC TCP |
| 50000-60000 | UDP | WebRTC UDP |
| 3478 | UDP | STUN/TURN |
| 5349 | TCP | TURN TLS |
| 6789 | TCP | Prometheus metrics |

## 重要な注意事項

### 1. Private Cluster 非対応

LiveKit は WebRTC の特性上、Private Cluster をサポートしていません。NAT 環境では ICE candidate の検出が正しく機能しません。

### 2. Host Networking 必須

WebRTC のメディア転送には Host Networking が必要です。これにより、1ノードあたり1 Pod の制限があります。

### 3. GKE Standard のみ

GKE Autopilot は Host Networking をサポートしていないため、Standard クラスタを使用する必要があります。

### 4. TLS 証明書

- **メインドメイン**: GKE Managed Certificate を使用
- **TURN ドメイン**: 別途 TLS 証明書が必要（Kubernetes Secret として管理）

### 5. WebSocket タイムアウト

BackendConfig で WebSocket 接続の長時間維持を設定しています（10時間）。

## トラブルシューティング

### Pod が起動しない

```bash
# Pod の詳細確認
kubectl describe pod -n livekit -l app.kubernetes.io/name=livekit-server

# ログ確認
kubectl logs -n livekit -l app.kubernetes.io/name=livekit-server
```

### 外部から接続できない

1. ファイアウォールルールを確認
2. 静的 IP が正しく割り当てられているか確認
3. DNS レコードが正しいか確認
4. Managed Certificate のステータスを確認

```bash
kubectl get managedcertificates -n livekit
```

### Redis 接続エラー

```bash
# Redis アドレスを確認
terraform output redis_address

# Pod から Redis への接続テスト
kubectl run redis-test --rm -it --image=redis:alpine -- \
  redis-cli -h <redis-host> ping
```

## CI/CD

### GitHub Secrets の設定

以下のシークレットを GitHub リポジトリに設定:

- `GCP_SA_KEY`: サービスアカウントの JSON キー

### GitHub Variables の設定

以下の変数を環境ごとに設定:

- `GCP_PROJECT_ID`: GCP プロジェクト ID
- `GCP_REGION`: GCP リージョン（デフォルト: asia-northeast1）

### ワークフロー

1. **terraform-plan.yml**: PR 時に自動実行、変更内容をコメント
2. **terraform-apply.yml**: 手動実行、環境選択可能
3. **helm-deploy.yml**: 手動実行、Helm デプロイ/アップグレード

## 参考リンク

- [LiveKit Self-Hosting Documentation](https://docs.livekit.io/home/self-hosting/deployment/)
- [LiveKit Kubernetes Deployment](https://docs.livekit.io/home/self-hosting/kubernetes/)
- [LiveKit Helm Chart](https://github.com/livekit/livekit-helm)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
