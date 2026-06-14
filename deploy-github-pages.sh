#!/bin/bash
# ============================================================
# GitHub Pages 自动部署脚本
# 功能：将 index.html 部署到 GitHub Pages
# 适用：macOS/Linux/Git Bash (Windows)
# ============================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================
# 第一步：检查 index.html 文件是否存在
# ============================================================
print_info "第一步：检查 index.html 文件..."

if [ ! -f "index.html" ]; then
    print_error "当前目录下没有找到 index.html 文件！"
    print_info "请将此脚本放在包含 index.html 的目录中运行。"
    exit 1
fi

print_success "找到 index.html 文件 ✓"

# ============================================================
# 第二步：检查 Git 是否安装
# ============================================================
print_info "第二步：检查 Git 是否安装..."

if ! command -v git &> /dev/null; then
    print_error "Git 未安装！"
    echo ""
    echo "请先安装 Git："
    echo "  macOS:   brew install git"
    echo "  Linux:   sudo apt install git  或  sudo yum install git"
    echo "  Windows: 从 https://git-scm.com/download/win 下载安装"
    echo ""
    exit 1
fi

GIT_VERSION=$(git --version)
print_success "Git 已安装: $GIT_VERSION ✓"

# ============================================================
# 第三步：检查 GitHub CLI (gh) 是否安装
# ============================================================
print_info "第三步：检查 GitHub CLI (gh) 是否安装..."

GH_AVAILABLE=false
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -1)
    print_success "GitHub CLI 已安装: $GH_VERSION ✓"
    GH_AVAILABLE=true
    
    # 检查 gh 登录状态
    print_info "检查 GitHub 登录状态..."
    if gh auth status &> /dev/null; then
        print_success "已登录 GitHub ✓"
    else
        print_warning "未登录 GitHub，请先登录："
        echo "  运行命令: gh auth login"
        echo "  按提示选择 GitHub.com -> HTTPS -> 使用浏览器登录"
        echo ""
        read -p "是否现在登录？(y/n): " login_choice
        if [ "$login_choice" = "y" ]; then
            gh auth login
        else
            print_warning "将使用手动部署方案..."
            GH_AVAILABLE=false
        fi
    fi
else
    print_warning "GitHub CLI (gh) 未安装"
    echo ""
    echo "建议安装 GitHub CLI 以获得全自动部署体验："
    echo "  macOS:   brew install gh"
    echo "  Linux:   sudo apt install gh  或访问 https://github.com/cli/cli/releases"
    echo "  Windows: winget install GitHub.cli  或从 GitHub CLI releases 页面下载"
    echo ""
    read -p "是否继续使用手动部署方案？(y/n): " continue_choice
    if [ "$continue_choice" != "y" ]; then
        exit 1
    fi
fi

# ============================================================
# 第四步：获取用户输入
# ============================================================
print_info "第四步：获取配置信息..."

# 获取 GitHub 用户名
if $GH_AVAILABLE; then
    # 尝试从 gh 获取当前用户名
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    if [ -n "$GH_USER" ]; then
        print_info "检测到 GitHub 用户名: $GH_USER"
        read -p "使用此用户名？(y/n，输入n可自定义): " use_detected
        if [ "$use_detected" = "y" ]; then
            GITHUB_USER="$GH_USER"
        fi
    fi
fi

if [ -z "$GITHUB_USER" ]; then
    read -p "请输入 GitHub 用户名: " GITHUB_USER
    if [ -z "$GITHUB_USER" ]; then
        print_error "用户名不能为空！"
        exit 1
    fi
fi

# 获取仓库名
DEFAULT_REPO="my-webpage"
read -p "请输入仓库名 (默认: $DEFAULT_REPO): " REPO_NAME
if [ -z "$REPO_NAME" ]; then
    REPO_NAME="$DEFAULT_REPO"
fi

print_success "配置信息："
echo "  GitHub 用户名: $GITHUB_USER"
echo "  仓库名称: $REPO_NAME"
echo "  访问地址: https://$GITHUB_USER.github.io/$REPO_NAME"
echo ""

# ============================================================
# 第五步：初始化 Git 仓库
# ============================================================
print_info "第五步：初始化 Git 仓库..."

# 检查是否已经是 Git 仓库
if [ -d ".git" ]; then
    print_warning "当前目录已是 Git 仓库"
    read -p "是否重新初始化？(y/n): " reinit
    if [ "$reinit" = "y" ]; then
        rm -rf .git
        git init
        print_success "Git 仓库已重新初始化 ✓"
    fi
else
    git init
    print_success "Git 仓库已初始化 ✓"
fi

# 设置默认分支为 main
git branch -M main
print_success "默认分支设置为 main ✓"

# ============================================================
# 第六步：创建或连接 GitHub 仓库
# ============================================================
print_info "第六步：创建 GitHub 仓库..."

REMOTE_URL="https://github.com/$GITHUB_USER/$REPO_NAME.git"

if $GH_AVAILABLE; then
    # 检查仓库是否已存在
    print_info "检查仓库是否已存在..."
    if gh repo view "$GITHUB_USER/$REPO_NAME" &> /dev/null; then
        print_warning "仓库 $REPO_NAME 已存在"
        read -p "是否使用现有仓库？(y/n): " use_existing
        if [ "$use_existing" != "y" ]; then
            print_error "请手动删除现有仓库或使用不同的仓库名"
            exit 1
        fi
    else
        # 自动创建仓库
        print_info "正在创建公开仓库..."
        gh repo create "$REPO_NAME" \
            --public \
            --description "个人网页 - 部署于 GitHub Pages" \
            --enable-issues=false \
            --enable-wiki=false
        print_success "仓库创建成功 ✓"
    fi
    
    # 添加远程仓库
    git remote remove origin 2>/dev/null || true
    git remote add origin "$REMOTE_URL"
    print_success "远程仓库已配置 ✓"
else
    # 手动部署方案
    print_warning "=== 手动部署方案 ==="
    echo ""
    echo "请按以下步骤操作："
    echo ""
    echo "1. 打开浏览器访问: https://github.com/new"
    echo "2. 创建一个新仓库："
    echo "   - Repository name: $REPO_NAME"
    echo "   - 选择 Public (公开)"
    echo "   - 不要勾选 'Add a README file'"
    echo "   - 点击 'Create repository'"
    echo ""
    read -p "创建完成后按回车继续..."
    
    # 添加远程仓库
    git remote remove origin 2>/dev/null || true
    git remote add origin "$REMOTE_URL"
    print_success "远程仓库已配置 ✓"
fi

# ============================================================
# 第七步：提交并推送代码
# ============================================================
print_info "第七步：提交并推送代码..."

# 创建 .nojekyll 文件（可选，防止 Jekyll 处理）
touch .nojekyll
print_info "创建 .nojekyll 文件 ✓"

# 添加所有文件
git add .
print_success "文件已添加到暂存区 ✓"

# 提交
git commit -m "Initial commit: deploy webpage to GitHub Pages"
print_success "代码已提交 ✓"

# 推送
print_info "正在推送到 GitHub..."
if $GH_AVAILABLE; then
    # 使用 gh 认证推送
    git push -u origin main
else
    # 可能需要认证
    print_warning "如果推送失败，请确保已配置 Git 认证："
    echo "  方式1: 使用 Personal Access Token"
    echo "  方式2: 使用 SSH 密钥"
    echo ""
    git push -u origin main || {
        print_error "推送失败！"
        echo ""
        echo "请尝试以下命令手动推送："
        echo "  git push -u origin main"
        echo ""
        echo "或配置认证后重试："
        echo "  git config --global credential.helper store"
        exit 1
    }
fi
print_success "代码已推送到 GitHub ✓"

# ============================================================
# 第八步：启用 GitHub Pages
# ============================================================
print_info "第八步：启用 GitHub Pages..."

if $GH_AVAILABLE; then
    print_info "正在配置 GitHub Pages..."
    
    # 使用 gh api 启用 GitHub Pages
    gh api --method POST \
        "/repos/$GITHUB_USER/$REPO_NAME/pages" \
        -f source="{\"branch\":\"main\",\"path\":\"/\"}" \
        2>/dev/null || {
        print_warning "自动启用失败，请手动启用"
    }
    
    # 检查 Pages 状态
    sleep 3
    PAGES_STATUS=$(gh api "/repos/$GITHUB_USER/$REPO_NAME/pages" --jq '.status' 2>/dev/null || echo "unknown")
    
    if [ "$PAGES_STATUS" = "built" ]; then
        print_success "GitHub Pages 已启用并构建完成 ✓"
    else
        print_info "GitHub Pages 正在构建中，请稍候..."
    fi
else
    print_warning "请手动启用 GitHub Pages："
    echo ""
    echo "1. 打开浏览器访问: https://github.com/$GITHUB_USER/$REPO_NAME/settings/pages"
    echo "2. 在 'Source' 部分："
    echo "   - 选择 'Deploy from a branch'"
    echo "   - Branch: main"
    echo "   - Folder: / (root)"
    echo "3. 点击 'Save'"
    echo ""
fi

# ============================================================
# 完成！输出访问地址
# ============================================================
echo ""
echo "============================================================"
print_success "🎉 部署完成！"
echo "============================================================"
echo ""
echo "🌐 公开访问地址："
echo "   https://$GITHUB_USER.github.io/$REPO_NAME"
echo ""
echo "📱 手机访问："
echo "   直接在手机浏览器中打开上述地址即可"
echo ""
echo "⚙️  管理页面："
echo "   https://github.com/$GITHUB_USER/$REPO_NAME/settings/pages"
echo ""
echo "============================================================"
print_info "后续更新方法："
echo "============================================================"
echo ""
echo "修改 index.html 后，运行以下命令即可更新："
echo ""
echo "  git add ."
echo "  git commit -m \"update\""
echo "  git push"
echo ""
echo "或者一条命令："
echo "  git add . && git commit -m \"update\" && git push"
echo ""
echo "============================================================"
print_success "感谢使用！祝您使用愉快！"
echo "============================================================"