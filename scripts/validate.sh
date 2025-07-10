#!/bin/bash

# =============================================================================
# CloudFormation テンプレート検証スクリプト
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
CloudFormation テンプレート検証スクリプト

使用法:
    $0 [OPTIONS] [TEMPLATE_FILE]

オプション:
    -r, --region    AWSリージョン (デフォルト: ap-northeast-1)
    -a, --all       すべてのテンプレートを検証
    -h, --help      このヘルプを表示

例:
    $0 simple-stack.yaml
    $0 --all
    $0 -r us-west-2 simple-stack.yaml

EOF
}

# デフォルト値
AWS_REGION="ap-northeast-1"
TEMPLATE_FILE=""
VALIDATE_ALL=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -a|--all)
            VALIDATE_ALL=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *.yaml|*.yml)
            TEMPLATE_FILE="$1"
            shift
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# AWS認証確認
log_info "AWS認証を確認中..."
if ! aws sts get-caller-identity --region $AWS_REGION &> /dev/null; then
    log_error "AWS認証に失敗しました。aws configure を実行してください"
    exit 1
fi

# テンプレート検証関数
validate_template() {
    local template=$1
    
    if [[ ! -f "$template" ]]; then
        log_error "テンプレートファイルが見つかりません: $template"
        return 1
    fi
    
    log_info "テンプレートを検証中: $template"
    
    # CloudFormation構文チェック
    if aws cloudformation validate-template --template-body file://$template --region $AWS_REGION &> /dev/null; then
        log_success "CloudFormation構文チェック: OK"
    else
        log_error "CloudFormation構文チェック: NG"
        aws cloudformation validate-template --template-body file://$template --region $AWS_REGION
        return 1
    fi
    
    # cfn-lint チェック（インストールされている場合）
    if command -v cfn-lint &> /dev/null; then
        log_info "cfn-lint チェック実行中..."
        if cfn-lint $template; then
            log_success "cfn-lint チェック: OK"
        else
            log_warning "cfn-lint チェックでワーニングまたはエラーが検出されました"
        fi
    else
        log_warning "cfn-lint がインストールされていません。pip install cfn-lint でインストールできます"
    fi
    
    log_success "テンプレート検証完了: $template"
    echo
}

# メイン処理
if [[ "$VALIDATE_ALL" == true ]]; then
    log_info "すべてのテンプレートを検証中..."
    
    # ルートディレクトリのテンプレート
    for template in *.yaml *.yml; do
        if [[ -f "$template" ]]; then
            validate_template "$template"
        fi
    done
    
    # templatesディレクトリのテンプレート
    if [[ -d "templates" ]]; then
        for template in templates/*.yaml templates/*.yml; do
            if [[ -f "$template" ]]; then
                validate_template "$template"
            fi
        done
    fi
    
elif [[ -n "$TEMPLATE_FILE" ]]; then
    validate_template "$TEMPLATE_FILE"
else
    log_error "テンプレートファイルが指定されていません"
    show_help
    exit 1
fi

log_success "検証スクリプトが正常に完了しました！"