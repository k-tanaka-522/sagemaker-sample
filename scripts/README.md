# Scripts Directory

このディレクトリには、SageMaker CloudFormation サンプルを便利に使うためのスクリプトが含まれています。

## 🚀 利用可能なスクリプト

### 1. deploy.sh - デプロイスクリプト

CloudFormation スタックの自動デプロイを行います。

#### 使用方法

```bash
# 実行権限を付与
chmod +x scripts/deploy.sh

# 基本的な使用方法
./scripts/deploy.sh deploy                    # ネストスタック
./scripts/deploy.sh multiple                  # 複数ノートブック

# オプション付きの使用方法
./scripts/deploy.sh deploy -n my-dev-notebook -r us-west-2
./scripts/deploy.sh deploy -n production-stack
```

#### 機能

- **自動AWS認証チェック** - デプロイ前に認証状態を確認
- **エラーハンドリング** - 問題が発生した場合の適切なエラーメッセージ
- **カラー出力** - 見やすい色付きログ出力
- **完了待機** - デプロイ完了まで自動で待機
- **出力表示** - デプロイ完了後に接続情報を表示

#### サポートするデプロイタイプ

| コマンド | 説明 | 使用テンプレート |
|----------|------|------------------|
| `deploy` | ネストスタック構成 | `main-stack.yaml` |
| `multiple` | 複数ノートブック | `main-stack.yaml` (×2) |

### 2. validate.sh - 検証スクリプト

CloudFormation テンプレートの構文チェックを行います。

#### 使用方法

```bash
# 実行権限を付与
chmod +x scripts/validate.sh

# 単一テンプレートの検証
./scripts/validate.sh simple-stack.yaml

# すべてのテンプレートを検証
./scripts/validate.sh --all

# 特定のリージョンで検証
./scripts/validate.sh -r us-west-2 simple-stack.yaml
```

#### 機能

- **CloudFormation構文チェック** - AWS公式の構文チェック
- **cfn-lint統合** - インストールされている場合は自動実行
- **一括検証** - すべてのテンプレートを一度に検証
- **詳細レポート** - 問題箇所の詳細な報告

## 📋 前提条件

### 必須
- **AWS CLI** - 設定済みであること
- **Bash** - バージョン4.0以上
- **jq** - JSONパーサー（推奨）

### 推奨
- **cfn-lint** - CloudFormation テンプレートの高度な検証
  ```bash
  pip install cfn-lint
  ```

## 🔧 スクリプトの実行権限

初回実行時は実行権限を付与してください：

```bash
chmod +x scripts/*.sh
```

## 📝 使用例

### 開発環境のデプロイ

```bash
# 開発用ノートブックをデプロイ
./scripts/deploy.sh deploy -n dev-notebook

# 検証
./scripts/validate.sh main-stack.yaml
```

### 本番環境のデプロイ

```bash
# 本番環境用の設定でネストスタックをデプロイ
./scripts/deploy.sh deploy -n production-sagemaker -r ap-northeast-1
```

### 複数環境のデプロイ

```bash
# 開発・本番の両方のノートブックを作成
./scripts/deploy.sh multiple -n team-notebooks
```

## 🔍 トラブルシューティング

### よくある問題

#### 1. 実行権限エラー
```bash
# 解決方法
chmod +x scripts/deploy.sh
```

#### 2. AWS認証エラー
```bash
# 解決方法
aws configure
```

#### 3. テンプレート検証エラー
```bash
# 詳細な検証を実行
./scripts/validate.sh --all
```

### ログの見方

スクリプトは以下の色付きログを出力します：

- 🔵 **[INFO]** - 一般的な情報
- 🟢 **[SUCCESS]** - 成功メッセージ  
- 🟡 **[WARNING]** - 警告メッセージ
- 🔴 **[ERROR]** - エラーメッセージ

## 🚀 カスタマイズ

スクリプトは必要に応じてカスタマイズできます：

1. **デフォルト値の変更** - スクリプト内のデフォルト値を編集
2. **新しいデプロイタイプの追加** - `deploy.sh` に新しい関数を追加
3. **追加の検証ルール** - `validate.sh` に独自の検証ロジックを追加

## 📚 参考情報

- [AWS CLI リファレンス](https://docs.aws.amazon.com/cli/)
- [CloudFormation CLI リファレンス](https://docs.aws.amazon.com/cli/latest/reference/cloudformation/)
- [cfn-lint ドキュメント](https://github.com/aws-cloudformation/cfn-lint)