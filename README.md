# SageMaker CloudFormation サンプル

このリポジトリは、AWS CloudFormationを使ってSageMakerノートブックインスタンスを簡単にデプロイするサンプルです。

## 🎯 内容

**SageMakerノートブック**という機械学習の開発環境を、AWSクラウド上に自動で構築できます。

### 作成されるもの
- **Jupyter Notebook環境**：ブラウザで機械学習コードを書いて実行できる
- **必要なネットワーク設定**：安全にインターネットからアクセスできる環境
- **権限設定**：SageMakerが他のAWSサービスを使えるようにする設定

### 想定する利用者
- 機械学習を始めたい方
- AWSのSageMakerを試してみたい方
- CloudFormationの基本的な使い方を学びたい方

## 🚀 使い方コマンド（網羅版）

### 準備
```bash
# 1. このリポジトリをダウンロード
git clone https://github.com/k-tanaka-522/sagemaker-sample.git
cd sagemaker-sample

# 2. AWS認証確認
aws sts get-caller-identity
```

### デプロイ

#### 基本デプロイ
```bash
# S3バケット作成
aws s3 mb s3://$(aws sts get-caller-identity --query Account --output text)-cfn-templates --region ap-northeast-1

# テンプレートアップロード
aws s3 cp templates/ s3://$(aws sts get-caller-identity --query Account --output text)-cfn-templates/sagemaker/templates/ --recursive --region ap-northeast-1

# デプロイ
aws cloudformation create-stack \
  --stack-name my-sagemaker-notebook \
  --template-body file://main-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=my-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# 完了を待つ
aws cloudformation wait stack-create-complete \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1
```

#### 複数ノートブック（同じVPC内）

**方法A: 別々のスタックで作成**
```bash
# 1つ目のノートブック
aws cloudformation create-stack \
  --stack-name sagemaker-notebook-first \
  --template-body file://main-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=first-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# 2つ目のノートブック（別のVPCに作成される）
aws cloudformation create-stack \
  --stack-name sagemaker-notebook-second \
  --template-body file://main-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=second-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

**方法B: 同じスタック内で作成（推奨）**
1. `main-stack.yaml` 内の `SecondSageMakerNotebookStack` のコメントアウトを外す
2. 出力セクションの `SecondNotebook*` のコメントアウトも外す
3. デプロイを実行

```bash
# 同じVPC内に2つのノートブックが作成される
aws cloudformation create-stack \
  --stack-name sagemaker-dual-notebooks \
  --template-body file://main-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=team-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

**方法Bの利点:**
- 同じVPC、セキュリティグループ、IAMロールを共有
- コスト効率が良い
- 管理が簡単

### アクセス

#### URL取得
```bash
# デプロイ完了後、アクセス情報を取得
aws cloudformation describe-stacks \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

#### アクセス方法
1. **AWSコンソール経由（推奨）**: 上記の`JupyterURL`をブラウザで開く
2. **直接アクセス**: `JupyterLabURL`を直接ブラウザで開く

#### 状態確認
```bash
# ノートブックの状態確認
aws sagemaker describe-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1 \
  --query '[NotebookInstanceStatus,Url]' \
  --output table
```

### 管理

#### 停止・再開
```bash
# 停止
aws sagemaker stop-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1

# 再開
aws sagemaker start-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1
```

#### 削除

##### 基本削除
```bash
# 単一スタック削除
aws cloudformation delete-stack \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1
```

##### 複数削除
```bash
# 複数のスタックを個別に削除
aws cloudformation delete-stack --stack-name sagemaker-notebook-dev --region ap-northeast-1
aws cloudformation delete-stack --stack-name sagemaker-notebook-prod --region ap-northeast-1
```

##### 一括削除
```bash
# sagemaker関連スタックを全て削除
for stack in $(aws cloudformation list-stacks \
  --region ap-northeast-1 \
  --query 'StackSummaries[?contains(StackName, `sagemaker`) && StackStatus != `DELETE_COMPLETE`].StackName' \
  --output text); do
  echo "Deleting stack: $stack"
  aws cloudformation delete-stack --stack-name $stack --region ap-northeast-1
done
```

#### 状態監視
```bash
# デプロイ状態確認
aws cloudformation describe-stacks \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'Stacks[0].StackStatus'

# リアルタイム監視
watch -n 10 'aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query "StackEvents[0:3].[Timestamp,ResourceType,ResourceStatus,ResourceStatusReason]" \
  --output table'
```

## 📊 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                           │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    VPC                              │   │
│  │  (10.0.0.0/16)                                     │   │
│  │                                                     │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │           Public Subnet                     │   │   │
│  │  │          (10.0.1.0/24)                     │   │   │
│  │  │                                             │   │   │
│  │  │  ┌─────────────────────────────────────┐   │   │   │
│  │  │  │      SageMaker Notebook             │   │   │   │
│  │  │  │                                     │   │   │   │
│  │  │  │  - Jupyter Lab環境                 │   │   │   │
│  │  │  │  - ml.t3.medium                    │   │   │   │
│  │  │  │  - 機械学習ライブラリ               │   │   │   │
│  │  │  └─────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  │                                                     │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │        Security Group                       │   │   │
│  │  │  - HTTPSアクセス許可 (ポート443)           │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                IAM Role                             │   │
│  │  - SageMakerの実行権限                             │   │
│  │  - S3、CloudWatch等へのアクセス権限                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                │ HTTPS (443)
                                │
                      ┌─────────────────┐
                      │   あなたのPC     │
                      │  ブラウザから    │
                      │  Jupyter接続     │
                      └─────────────────┘
```

### 作成されるコンポーネント
- **VPC**: あなた専用のネットワーク環境
- **インターネットゲートウェイ**: VPCとインターネットを繋ぐ出入り口
- **パブリックサブネット**: インターネットからアクセス可能なエリア
- **セキュリティグループ**: HTTPS（ポート443）のみ許可のファイアウォール
- **IAMロール**: SageMakerがAWSサービスを使う時の権限
- **SageMakerノートブック**: 機械学習の開発環境（メイン）

## 💰 料金

### 想定コスト（東京リージョン）
- **SageMakerノートブック（ml.t3.medium）**: 約 $0.06/時間
- **EBSストレージ（20GB）**: 約 $0.05/日
- **その他（VPC、NAT Gateway等）**: 約 $0.05/日

### 💡 コスト削減のポイント
1. **使わない時は停止**: インスタンスを停止すればコンピューティング費用は発生しません
2. **不要になったら削除**: スタック全体を削除すれば全てのリソースが削除されます

---

## 🔒 セキュリティ設定について

### サンプルの設定（学習・デモ用）

このサンプルでは **学習・デモ用** として以下の設定を採用しています：

- **パブリックサブネット** - JupyterのWebUIに簡単にアクセス可能
- **DirectInternetAccess: Enabled** - パッケージダウンロードとWebUIアクセス
- **RootAccess: Enabled** - 学習用パッケージのインストール
- **セキュリティグループ** - HTTPSアクセスを許可

### 本番環境向けの追加セキュリティ設定

本番環境では以下の設定を検討してください：

- **プライベートサブネット** - VPCエンドポイント経由でのアクセス
- **DirectInternetAccess: Disabled** - インターネットアクセスを制限
- **RootAccess: Disabled** - 管理者権限を制限
- **VPN/DirectConnect** - 専用線経由でのアクセス
- **IAM条件付きアクセス** - 特定のIPアドレスからのみアクセス許可

### セキュリティ設定の変更方法

main-stack.yaml内で以下を変更：

```yaml
# プライベートサブネット使用の場合
SubnetId: !GetAtt VpcStack.Outputs.PrivateSubnetId
```

sagemaker-notebook-stack.yaml内で以下を変更：

```yaml
# セキュリティ強化の場合
DirectInternetAccess: Disabled
RootAccess: Disabled
```

---

## 📚 詳細説明（上記で分からない人向け）

### AWS CLIの初期設定

#### インストール

**Windowsの場合:**
```bash
winget install Amazon.AWSCLI
```

**macOSの場合:**
```bash
brew install awscli
```

**Linuxの場合:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### 認証設定

**アクセスキーの取得:**
1. AWSコンソールにログイン
2. 「IAM」サービスを開く
3. 「ユーザー」→あなたのユーザー名をクリック
4. 「セキュリティ認証情報」タブをクリック
5. 「アクセスキーの作成」をクリック
6. 「AWS CLI」を選択してアクセスキーを作成

**AWS CLIの設定:**
```bash
aws configure
# AWS Access Key ID [None]: あなたのアクセスキーID
# AWS Secret Access Key [None]: あなたのシークレットアクセスキー
# Default region name [None]: ap-northeast-1  # 東京リージョン
# Default output format [None]: json
```

**設定確認:**
```bash
aws sts get-caller-identity
```

#### 必要なIAM権限

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "sagemaker:*",
                "ec2:*",
                "iam:*",
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### デプロイプロセス詳細

#### 作成順序と時間
1. **VPC作成**（約1分）: あなた専用のネットワーク環境
2. **サブネット・ルーティング作成**（約1分）: インターネットへの経路設定
3. **セキュリティグループ作成**（約30秒）: HTTPSアクセスのみ許可
4. **IAMロール作成**（約30秒）: SageMakerの実行権限
5. **SageMakerノートブック作成**（約5-7分）: メインの機械学習環境

#### デプロイ状況確認方法

**進行状況確認:**
```bash
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceType==`AWS::SageMaker::NotebookInstance`].[Timestamp,ResourceStatus,ResourceStatusReason]' \
  --output table
```

**デプロイ中のステータス:**
- `CREATE_IN_PROGRESS`: 作成中（5-10分）
- `CREATE_COMPLETE`: 作成完了
- `CREATE_FAILED`: 作成失敗
- `ROLLBACK_IN_PROGRESS`: ロールバック中（2-5分）

### アクセス詳細

#### アクセスできない場合のチェック

**ノートブックインスタンスの状態確認:**
```bash
aws sagemaker describe-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1 \
  --query '[NotebookInstanceStatus,Url]' \
  --output table
```

**状態の意味:**
- ✅ **`InService`**: アクセス可能状態
- ⏳ **`Pending`**: 起動中（あと3-5分待つ）
- ⛔ **`Stopped`**: 停止中（再開が必要）
- ❌ **`Failed`**: エラー発生（ログ確認が必要）

#### 初回アクセス時のおすすめアクション

1. **サンプルノートブックを開く**
   - `SageMaker Examples` → `Introduction to Machine Learning` → `Getting Started`

2. **新しいノートブックを作成**
   - `+` ボタン → `Python 3` カーネルを選択

3. **簡単なコードを実行してテスト**
   ```python
   import pandas as pd
   import numpy as np
   import sagemaker
   
   print("SageMakerノートブックが正常に動作しています!")
   print(f"SageMakerバージョン: {sagemaker.__version__}")
   ```

### ネストスタック詳細

#### なぜS3が必要？
ネストスタックでは、子テンプレートをS3に配置する必要があります。これにより、CloudFormationが各テンプレートにアクセスできるようになります。

#### ネストスタックの利点
- **モジュール化**: 各コンポーネントを独立して管理
- **再利用性**: 他のプロジェクトでも部分的に再利用可能
- **保守性**: 変更時の影響範囲を限定
- **スケーラビリティ**: 大規模な環境でも管理しやすい

#### ファイル構成
```
├── main-stack.yaml                    # メインスタック
├── simple-stack.yaml                  # シンプルな単一ファイル版
├── templates/
│   ├── vpc-stack.yaml                # VPC・サブネット管理
│   ├── iam-role-stack.yaml           # IAMロール管理
│   ├── security-group-stack.yaml     # セキュリティグループ管理
│   ├── custom-resource-stack.yaml    # カスタムリソース（Lambda）
│   └── sagemaker-notebook-stack.yaml # SageMakerノートブック
└── README.md                          # このファイル
```

### 🔧 トラブルシューティング

#### よくある問題

**1. デプロイが失敗する**
```bash
# エラー詳細を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1
```

**2. Jupyter Notebookにアクセスできない**
- インスタンスが「InService」状態か確認
- セキュリティグループの設定を確認
- 正しいURLを使用しているか確認

**3. 権限エラーが発生する**
- IAMロールの設定を確認
- 必要な権限が付与されているか確認

#### サポート
問題が解決しない場合は、AWSのサポートフォーラムや公式ドキュメントを参照してください。

---

## 🎯 サンプル実行は以上です

ここまでで、SageMakerノートブックのデプロイ・アクセス・管理の基本的な流れを体験できました。

## 🚀 運用に向けたブラッシュアップポイント

このサンプルは学習・検証用です。**本格的な運用環境では以下の改善を実装するとベストプラクティスに沿った運用が可能になります：**

### 🔧 デプロイメント改善

| 項目 | 現状 | 改善案 | 理由 |
|------|------|--------|------|
| **デプロイ方法** | 手動コマンド実行 | デプロイスクリプト化 | 人的ミスの削減、作業効率化 |
| **テンプレート管理** | ローカルファイル | S3での管理 | バージョン履歴、差分確認、ロールバック |
| **環境管理** | 単一環境 | 環境別パラメータファイル | dev/staging/prod環境の分離 |
| **検証** | 手動確認 | テンプレート自動検証 | 構文エラーやベストプラクティス違反の早期発見 |

### 🛡️ セキュリティ強化

| 項目 | 現状 | 改善案 | 理由 |
|------|------|--------|------|
| **機密情報管理** | パラメータファイル | AWS Secrets Manager | APIキーやパスワードの安全な管理 |
| **暗号化** | 基本設定 | KMS暗号化 | データの保護強化 |
| **アクセス制御** | 基本的なセキュリティグループ | 詳細なIAMポリシー | 最小権限の原則 |
| **削除保護** | なし | Stack Policy | 誤削除の防止 |

### 📊 監視・アラート

| 項目 | 現状 | 改善案 | 理由 |
|------|------|--------|------|
| **状態監視** | 手動確認 | CloudWatch アラーム | 自動的な問題検知 |
| **通知** | なし | SNS通知 | 問題発生時の迅速な対応 |
| **コスト監視** | 手動確認 | コストアラーム | 予算超過の防止 |
| **ドリフト検出** | なし | 定期的なドリフト検出 | 設定変更の検知 |

### 🚀 CI/CD統合

| 項目 | 現状 | 改善案 | 理由 |
|------|------|--------|------|
| **デプロイ** | 手動実行 | GitHub Actions | 自動デプロイ、品質保証 |
| **テスト** | なし | 自動テスト | 品質保証、リグレッション防止 |
| **承認プロセス** | なし | プルリクエスト | コードレビュー、変更管理 |

### 💾 バックアップ・復旧

| 項目 | 現状 | 改善案 | 理由 |
|------|------|--------|------|
| **バックアップ** | なし | 定期的なスナップショット | データ保護、災害復旧 |
| **復旧手順** | なし | 復旧スクリプト | 迅速な復旧 |

### 🏗️ 実装優先度

**Phase 1（すぐに実装）:**
- デプロイスクリプト化
- 環境別パラメータファイル
- S3でのテンプレート管理

**Phase 2（中期）:**
- 監視・アラート設定
- テンプレート検証
- バックアップ自動化

**Phase 3（長期）:**
- CI/CD統合
- 高度なセキュリティ設定
- 災害復旧計画

## 📝 ライセンス

このサンプルコードはMITライセンスの下で公開されています。