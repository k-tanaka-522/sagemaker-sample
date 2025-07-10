#!/bin/bash

# =============================================================================
# SageMaker CloudFormation デプロイスクリプト
# =============================================================================

set -e  # エラーで停止

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ヘルプ表示
show_help() {
    cat << EOF
SageMaker CloudFormation デプロイスクリプト

使用法:
    $0 [OPTIONS] [COMMAND]

コマンド:
    deploy          ネストスタックをデプロイ
    multiple        複数のノートブックをデプロイ

オプション:
    -n, --name      スタック名 (デフォルト: my-sagemaker-notebook)
    -r, --region    AWSリージョン (デフォルト: ap-northeast-1)
    -p, --params    パラメータファイル (デフォルト: simple-parameters.json)
    -h, --help      このヘルプを表示

例:
    $0 deploy
    $0 deploy -n my-notebook-dev -r us-west-2
    $0 deploy -n production-notebook
    $0 multiple -n notebook-team

EOF
}

# デフォルト値
STACK_NAME="my-sagemaker-notebook"
AWS_REGION="ap-northeast-1"
PARAMS_FILE="simple-parameters.json"
COMMAND=""

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            STACK_NAME="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -p|--params)
            PARAMS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy|multiple)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# コマンドが指定されていない場合
if [[ -z "$COMMAND" ]]; then
    log_error "コマンドが指定されていません"
    show_help
    exit 1
fi

# AWS認証確認
log_info "AWS認証を確認中..."
if ! aws sts get-caller-identity --region $AWS_REGION &> /dev/null; then
    log_error "AWS認証に失敗しました。aws configure を実行してください"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS認証成功 (Account: $ACCOUNT_ID)"

# 各デプロイメント関数
deploy_stack() {
    log_info "ネストスタックをデプロイ中..."
    
    # S3バケット作成
    BUCKET_NAME="${ACCOUNT_ID}-cfn-templates"
    log_info "S3バケットを作成中: $BUCKET_NAME"
    
    aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION 2>/dev/null || log_warning "S3バケットは既に存在します"
    
    # テンプレートアップロード
    log_info "テンプレートをS3にアップロード中..."
    aws s3 cp templates/ s3://$BUCKET_NAME/sagemaker/templates/ --recursive --region $AWS_REGION
    
    # デプロイ実行
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://main-stack.yaml \
        --parameters ParameterKey=NotebookInstanceName,ParameterValue=${STACK_NAME}-notebook \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $AWS_REGION
    
    log_info "デプロイを開始しました。完了まで約10分お待ちください..."
    
    # 完了待機
    aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME \
        --region $AWS_REGION
    
    log_success "デプロイが完了しました！"
    
    # 出力表示
    log_info "スタックの出力情報:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $AWS_REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
}

deploy_multiple() {
    log_info "複数のノートブックをデプロイ中..."
    
    # S3バケット作成
    BUCKET_NAME="${ACCOUNT_ID}-cfn-templates"
    log_info "S3バケットを作成中: $BUCKET_NAME"
    
    aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION 2>/dev/null || log_warning "S3バケットは既に存在します"
    
    # テンプレートアップロード
    log_info "テンプレートをS3にアップロード中..."
    aws s3 cp templates/ s3://$BUCKET_NAME/sagemaker/templates/ --recursive --region $AWS_REGION
    
    # 1つ目のノートブック
    FIRST_STACK="${STACK_NAME}-first"
    log_info "1つ目のノートブック ($FIRST_STACK) をデプロイ中..."
    
    aws cloudformation create-stack \
        --stack-name $FIRST_STACK \
        --template-body file://main-stack.yaml \
        --parameters ParameterKey=NotebookInstanceName,ParameterValue=first-notebook \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $AWS_REGION
    
    # 2つ目のノートブック
    SECOND_STACK="${STACK_NAME}-second"
    log_info "2つ目のノートブック ($SECOND_STACK) をデプロイ中..."
    
    aws cloudformation create-stack \
        --stack-name $SECOND_STACK \
        --template-body file://main-stack.yaml \
        --parameters ParameterKey=NotebookInstanceName,ParameterValue=second-notebook \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $AWS_REGION
    
    log_info "両方のデプロイを開始しました。完了まで約10分お待ちください..."
    
    # 両方の完了待機
    log_info "1つ目のノートブックの完了を待機中..."
    aws cloudformation wait stack-create-complete \
        --stack-name $FIRST_STACK \
        --region $AWS_REGION
    
    log_info "2つ目のノートブックの完了を待機中..."
    aws cloudformation wait stack-create-complete \
        --stack-name $SECOND_STACK \
        --region $AWS_REGION
    
    log_success "両方のデプロイが完了しました！"
    
    # 出力表示
    log_info "1つ目のノートブック ($FIRST_STACK):"
    aws cloudformation describe-stacks \
        --stack-name $FIRST_STACK \
        --region $AWS_REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    log_info "2つ目のノートブック ($SECOND_STACK):"
    aws cloudformation describe-stacks \
        --stack-name $SECOND_STACK \
        --region $AWS_REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
}

# メイン処理
case $COMMAND in
    deploy)
        deploy_stack
        ;;
    multiple)
        deploy_multiple
        ;;
    *)
        log_error "サポートされていないコマンド: $COMMAND"
        exit 1
        ;;
esac

log_success "デプロイスクリプトが正常に完了しました！"