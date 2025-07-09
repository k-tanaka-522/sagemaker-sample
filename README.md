# SageMaker CloudFormation サンプル

このリポジトリは、AWS CloudFormationを使ってSageMakerノートブックインスタンスを簡単にデプロイするサンプルです。

## 🎯 このサンプルで何ができるか

**SageMakerノートブック**という機械学習の開発環境を、AWSクラウド上に自動で構築できます。

### 作成されるもの
- **Jupyter Notebook環境**：ブラウザで機械学習コードを書いて実行できる
- **必要なネットワーク設定**：安全にインターネットからアクセスできる環境
- **権限設定**：SageMakerが他のAWSサービスを使えるようにする設定

### 想定する利用者
- 機械学習を始めたい方
- AWSのSageMakerを試してみたい方
- CloudFormationの基本的な使い方を学びたい方

## 🚀 クイックスタート（初心者向け）

### Step 1: 事前準備

#### 1.1 AWSアカウントの取得
- [AWS公式サイト](https://aws.amazon.com/)でアカウント作成
- クレジットカードの登録が必要

#### 1.2 AWS CLIのインストールと設定

**Windowsの場合:**
```bash
# AWS CLIのインストール
winget install Amazon.AWSCLI

# またはインストーラーをダウンロード
# https://awscli.amazonaws.com/AWSCLIV2.msi
```

**macOSの場合:**
```bash
# Homebrewを使用
brew install awscli

# または直接インストール
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**Linuxの場合:**
```bash
# 最新版をインストール
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

#### 1.3 AWS CLIの設定

**アクセスキーの取得:**
1. AWSコンソールにログイン
2. 「IAM」サービスを開く
3. 「ユーザー」→あなたのユーザー名をクリック
4. 「セキュリティ認証情報」タブをクリック
5. 「アクセスキーの作成」をクリック
6. 「AWS CLI」を選択してアクセスキーを作成

**AWS CLIの設定コマンド:**
```bash
# 設定コマンドを実行
aws configure

# 以下の情報を入力してください：
# AWS Access Key ID [None]: あなたのアクセスキーID
# AWS Secret Access Key [None]: あなたのシークレットアクセスキー
# Default region name [None]: ap-northeast-1  # 東京リージョン
# Default output format [None]: json
```

**設定の確認:**
```bash
# 設定が正しくできているか確認
aws sts get-caller-identity

# 以下のような出力が表示されれば成功：
# {
#     "UserId": "AIDAXXXXXXXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

#### 1.4 必要な権限の設定

このサンプルを実行するためには、以下の権限が必要です：

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

📝 **初心者の方へ**: 最初は管理者権限で始めて、慢れてきたら必要最小限の権限に変更することをおすすめします。

### Step 2: 簡単デプロイ

```bash
# 1. このリポジトリをダウンロード
git clone <this-repo>
cd sagemaker-sample

# 2. デプロイ実行（約10分）
aws cloudformation create-stack \
  --stack-name my-sagemaker-notebook \
  --template-body file://simple-stack.yaml \
  --parameters file://simple-parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# 3. デプロイ完了を待つ
aws cloudformation wait stack-create-complete \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1

# 4. 結果を確認
aws cloudformation describe-stacks \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'Stacks[0].Outputs'
```

### 🔍 デプロイプロセスの詳細解説

#### ステップバイステップで何が起こっているか

**1. VPCの作成（約1分）**
```bash
# 進行状況を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceType==`AWS::EC2::VPC`].[Timestamp,ResourceStatus,ResourceStatusReason]' \
  --output table
```
- あなた専用のネットワーク環境を作成
- IPアドレス範囲（10.0.0.0/16）を設定

**2. サブネットとルーティングの作成（約1分）**
```bash
# サブネットの作成状況を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceType==`AWS::EC2::Subnet`].[Timestamp,ResourceStatus]' \
  --output table
```
- パブリックサブネットの作成
- インターネットへの経路設定

**3. セキュリティグループの作成（約30秒）**
```bash
# セキュリティグループの作成状況を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceType==`AWS::EC2::SecurityGroup`].[Timestamp,ResourceStatus]' \
  --output table
```
- HTTPSアテクセスのみ許可するファイアウォール設定

**4. IAMロールの作成（約30秒）**
```bash
# IAMロールの作成状況を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceType==`AWS::IAM::Role`].[Timestamp,ResourceStatus]' \
  --output table
```
- SageMakerが他のAWSサービスを使えるように権限設定

**5. SageMakerノートブックインスタンスの作成（約5-7分）**
```bash
# SageMakerノートブックの作成状況を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'StackEvents[?ResourceType==`AWS::SageMaker::NotebookInstance`].[Timestamp,ResourceStatus,ResourceStatusReason]' \
  --output table
```
- メインの機械学習環境を作成
- このステップが最も時間がかかります

#### デプロイ状況のリアルタイム監視

```bash
# 全体の進行状況を確認
aws cloudformation describe-stacks \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'Stacks[0].StackStatus'

# 最新のイベントを表示（リアルタイム監視）
watch -n 10 'aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query "StackEvents[0:3].[Timestamp,ResourceType,ResourceStatus,ResourceStatusReason]" \
  --output table'
```

#### デプロイ中に発生しうるステータス

| ステータス | 意味 | 続行時間 |
|---------|------|----------|
| `CREATE_IN_PROGRESS` | 作成中 | 5-10分 |
| `CREATE_COMPLETE` | 作成完了 | - |
| `CREATE_FAILED` | 作成失敗 | - |
| `ROLLBACK_IN_PROGRESS` | ロールバック中 | 2-5分 |

#### デプロイ完了の確認

```bash
# デプロイ完了後の出力を確認
aws cloudformation describe-stacks \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
  --output table
```

このコマンドで以下の情報が表示されます：
- **NotebookInstanceName**: 作成されたノートブックの名前
- **JupyterURL**: JupyterノートブックへのアクセスURL
- **VpcId**: 作成されたVPCのID
- **ImportantNote**: コストに関する重要な注意事項

### Step 3: アクセス方法

#### 3.1 デプロイ完了後の確認

```bash
# デプロイ完了後、アクセスURLを取得
aws cloudformation describe-stacks \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1 \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

このコマンドで以下のようなURLが表示されます：

```
+-------------------+----------------------------------------------------------------+
|   OutputKey       |                    OutputValue                                 |
+-------------------+----------------------------------------------------------------+
| JupyterURL        | https://console.aws.amazon.com/sagemaker/home?region=ap-...   |
| DirectJupyterURL  | https://my-first-sagemaker-notebook.notebook.ap-northeast-... |
| JupyterLabURL     | https://my-first-sagemaker-notebook.notebook.ap-northeast-... |
+-------------------+----------------------------------------------------------------+
```

#### 3.2 アクセス方法（推奨手順）

**方法A: AWSコンソール経由（初心者推奨）**

1. **上記の`JupyterURL`をブラウザで開く**
2. **AWSコンソールにログイン**
3. **ノートブックインスタンスのステータスが「InService」であることを確認**
4. **「Open JupyterLab」ボタンをクリック**

**方法B: 直接アクセス（上級者向け）**

1. **上記の`JupyterLabURL`をブラウザで直接開く**
2. **AWSアカウントでログインしてあることを確認**

#### 3.3 アクセス時の注意事項

⚠️ **アクセスできない場合のチェックポイント**

```bash
# ノートブックインスタンスの状態を確認
aws sagemaker describe-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1 \
  --query '[NotebookInstanceStatus,Url]' \
  --output table
```

- ✅ **`InService`**: アクセス可能状態
- ⏳ **`Pending`**: 起動中（あと3-5分待つ）
- ⛔ **`Stopped`**: 停止中（再開が必要）
- ❌ **`Failed`**: エラー発生（ログ確認が必要）

#### 3.4 アクセス成功時の画面

アクセスが成功すると、以下のようなJupyterLab環境が表示されます：

- ✅ **左サイドバー**: ファイルブラウザ
- ✅ **メインエリア**: コードエディター
- ✅ **SageMaker Examples**: AWS公式サンプルコードが利用可能
- ✅ **プリインストールライブラリ**: TensorFlow、PyTorch、Scikit-learnなど

#### 3.5 初回アクセス時のおすすめアクション

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

## 📊 アーキテクチャ図

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
│  │  │                                             │   │   │
│  │  │  - HTTPSアクセス許可 (ポート443)           │   │   │
│  │  │  - Jupyter Notebookへの安全なアクセス      │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                IAM Role                             │   │
│  │                                                     │   │
│  │  - SageMakerの実行権限                             │   │
│  │  - S3、CloudWatch等へのアクセス権限                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                │ HTTPS (443)
                                │
                      ┌─────────────────┐
                      │                 │
                      │   あなたのPC     │
                      │                 │
                      │  ブラウザから    │
                      │  Jupyter接続     │
                      │                 │
                      └─────────────────┘
```

## 💡 各コンポーネントの説明（作成順序）

### 1. VPC (Virtual Private Cloud) 🏠
- **役割**: あなた専用のネットワーク環境
- **なぜ必要**: 外部からの不正アクセスを防ぐため
- **設定**: プライベートIPアドレス範囲（10.0.0.0/16）
- **作成時間**: 約30秒

### 2. インターネットゲートウェイ 🌐
- **役割**: VPCとインターネットを繋ぐ出入り口
- **なぜ必要**: ノートブックにインターネットからアクセスするため
- **設定**: 自動設定
- **作成時間**: 約30秒

### 3. パブリックサブネット 📍
- **役割**: インターネットからアクセス可能なエリア
- **なぜ必要**: Jupyter Notebookにブラウザからアクセスするため
- **設定**: VPCの一部（10.0.1.0/24）
- **作成時間**: 約30秒

### 4. ルートテーブルとルート 🗺️
- **役割**: ネットワークの道筋を決める設定
- **なぜ必要**: サブネットからインターネットへの経路を作るため
- **設定**: インターネットゲートウェイ経由で全ての通信を許可
- **作成時間**: 約30秒

### 5. セキュリティグループ 🔒
- **役割**: ファイアウォール（通信の許可・拒否）
- **なぜ必要**: 必要な通信のみを許可して安全性を確保
- **設定**: HTTPS（ポート443）のみ許可
- **作成時間**: 約30秒

### 6. IAMロール 🔑
- **役割**: SageMakerがAWSサービスを使う時の権限
- **なぜ必要**: データの読み書きやログ出力に必要
- **設定**: SageMakerの基本権限（S3、CloudWatch等）
- **作成時間**: 約30秒

### 7. SageMakerノートブックインスタンス 📊
- **役割**: 機械学習の開発環境（メインコンポーネント）
- **なぜ必要**: コードを書いて実行するため
- **設定**: 
  - インスタンスタイプ: ml.t3.medium（小さなサイズ）
  - ストレージ: 20GB
  - サンプルコード: AWS公式リポジトリが自動で利用可能
- **作成時間**: 約5-7分（最も時間がかかる）

### 🔄 作成順序の理由
1. **ネットワーク基盤から作成**: VPC→サブネット→ルーティング
2. **セキュリティ設定**: セキュリティグループでアクセス制御
3. **権限設定**: IAMロールでサービス間の権限を設定
4. **メインサービス**: 最後にSageMakerノートブックを作成

## 💰 コスト情報

### 想定コスト（東京リージョン）
- **SageMakerノートブック（ml.t3.medium）**: 約 $0.06/時間
- **EBSストレージ（20GB）**: 約 $0.05/日
- **その他（VPC、NAT Gateway等）**: 約 $0.05/日

### 💡 コスト削減のポイント
1. **使わない時は停止**: インスタンスを停止すればコンピューティング費用は発生しません
2. **不要になったら削除**: スタック全体を削除すれば全てのリソースが削除されます

## 🛠️ 使い方

### ノートブックインスタンスの操作

#### 停止方法
```bash
# コマンドラインから停止
aws sagemaker stop-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1
```

#### 再開方法
```bash
# コマンドラインから再開
aws sagemaker start-notebook-instance \
  --notebook-instance-name my-first-sagemaker-notebook \
  --region ap-northeast-1
```

#### 削除方法
```bash
# シンプルスタックを削除
aws cloudformation delete-stack \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1

# 複数のスタックを削除する場合
# 1つ目のノートブック（開発用）を削除
aws cloudformation delete-stack \
  --stack-name sagemaker-notebook-dev \
  --region ap-northeast-1

# 2つ目のノートブック（本番用）を削除
aws cloudformation delete-stack \
  --stack-name sagemaker-notebook-prod \
  --region ap-northeast-1
```

#### 一括削除スクリプト

```bash
# 全てのsagemaker関連スタックを一括削除
for stack in $(aws cloudformation list-stacks \
  --region ap-northeast-1 \
  --query 'StackSummaries[?contains(StackName, `sagemaker`) && StackStatus != `DELETE_COMPLETE`].StackName' \
  --output text); do
  echo "Deleting stack: $stack"
  aws cloudformation delete-stack --stack-name $stack --region ap-northeast-1
done

# 削除完了を確認
aws cloudformation list-stacks \
  --region ap-northeast-1 \
  --query 'StackSummaries[?contains(StackName, `sagemaker`)].{Name:StackName,Status:StackStatus}' \
  --output table
```

## 🎓 次のステップ

### 1. サンプルコードを実行
- 作成されたJupyter Notebookで機械学習のサンプルコードを実行
- AWS公式のサンプルが自動で利用可能

### 2. 独自のコードを作成
- 新しいNotebookを作成して機械学習モデルを開発
- データの読み込み、前処理、モデル学習、評価を実行

### 3. 複数のノートブックを作成

#### 3.1 異なるノートブックを作成する方法

**方法A: 複数のシンプルスタックを作成（推奨）**

```bash
# 1つ目のノートブック（開発用）
aws cloudformation create-stack \
  --stack-name sagemaker-notebook-dev \
  --template-body file://simple-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=dev-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1

# 2つ目のノートブック（本番用）
aws cloudformation create-stack \
  --stack-name sagemaker-notebook-prod \
  --template-body file://simple-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=prod-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

**方法B: ネストスタックで作成（上級者向け）**

```bash
# ネストスタック構成で作成
aws cloudformation create-stack \
  --stack-name sagemaker-notebook-nested \
  --template-body file://main-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=nested-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

#### 3.2 複数ノートブックの利用シーン

- **開発環境と本番環境の分離**
- **チームメンバー間でのノートブック共有**
- **異なるプロジェクトや実験の並行実行**
- **異なるインスタンスタイプでのパフォーマンステスト**

#### 3.3 複数ノートブックの管理

```bash
# 全てのノートブックスタックを一覧表示
aws cloudformation list-stacks \
  --region ap-northeast-1 \
  --query 'StackSummaries[?contains(StackName, `sagemaker-notebook`)].{Name:StackName,Status:StackStatus}' \
  --output table

# 全てのノートブックインスタンスを一覧表示
aws sagemaker list-notebook-instances \
  --region ap-northeast-1 \
  --query 'NotebookInstances[*].{Name:NotebookInstanceName,Status:NotebookInstanceStatus,InstanceType:InstanceType}' \
  --output table
```

### 4. より高度な構成を学ぶ
- 複数のサブネットを使った構成
- プライベートサブネットでの実行
- カスタムセキュリティ設定

## 📁 上級者向け：ネストスタック構成

より柔軟で管理しやすい構成を求める場合は、以下のネストスタック構成も利用できます：

```
├── main-stack.yaml                    # メインスタック
├── simple-stack.yaml                  # シンプルな単一ファイル版
├── templates/
│   ├── vpc-stack.yaml                # VPC・サブネット管理
│   ├── iam-role-stack.yaml           # IAMロール管理
│   ├── security-group-stack.yaml     # セキュリティグループ管理
│   ├── custom-resource-stack.yaml    # カスタムリソース（Lambda）
│   └── sagemaker-notebook-stack.yaml # SageMakerノートブック
└── README.md                          # 詳細な使用方法とガイド
```

### ネストスタックの利点
- **モジュール化**: 各コンポーネントを独立して管理
- **再利用性**: 他のプロジェクトでも部分的に再利用可能
- **保守性**: 変更時の影響範囲を限定
- **スケーラビリティ**: 大規模な環境でも管理しやすい

### 利用方法

#### 事前準備（S3バケットの作成）
```bash
# テンプレート格納用のS3バケットを作成
aws s3 mb s3://$(aws sts get-caller-identity --query Account --output text)-cfn-templates --region ap-northeast-1

# テンプレートファイルをS3にアップロード
aws s3 cp templates/ s3://$(aws sts get-caller-identity --query Account --output text)-cfn-templates/sagemaker/templates/ --recursive --region ap-northeast-1
```

#### デプロイ
```bash
# ネストスタックでデプロイ
aws cloudformation create-stack \
  --stack-name sagemaker-nested-example \
  --template-body file://main-stack.yaml \
  --parameters ParameterKey=NotebookInstanceName,ParameterValue=nested-notebook \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-northeast-1
```

**なぜS3が必要？**
ネストスタックでは、子テンプレートをS3に配置する必要があります。これにより、CloudFormationが各テンプレートにアクセスできるようになります。

## 🔧 トラブルシューティング

### よくある問題

#### 1. デプロイが失敗する
```bash
# エラー詳細を確認
aws cloudformation describe-stack-events \
  --stack-name my-sagemaker-notebook \
  --region ap-northeast-1
```

#### 2. Jupyter Notebookにアクセスできない
- インスタンスが「InService」状態か確認
- セキュリティグループの設定を確認
- 正しいURLを使用しているか確認

#### 3. 権限エラーが発生する
- IAMロールの設定を確認
- 必要な権限が付与されているか確認

### サポート
問題が解決しない場合は、AWSのサポートフォーラムや公式ドキュメントを参照してください。

## 📝 ライセンス

このサンプルコードはMITライセンスの下で公開されています。