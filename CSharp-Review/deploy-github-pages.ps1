# GitHub Pages Deployment Script (PowerShell)
# Deploy index.html to GitHub Pages

function PrintInfo($msg) { Write-Host "[INFO] $msg" -ForegroundColor Blue }
function PrintSuccess($msg) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function PrintWarning($msg) { Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function PrintError($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Step 1: Check index.html
PrintInfo "Step 1: Checking index.html file..."
if (-not (Test-Path "index.html")) {
    PrintError "index.html not found in current directory!"
    exit 1
}
PrintSuccess "Found index.html file"

# Step 2: Check Git
PrintInfo "Step 2: Checking Git installation..."
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    PrintError "Git not installed!"
    Write-Host "Install: winget install Git.Git"
    exit 1
}
PrintSuccess "Git installed"

# Step 3: Check GitHub CLI
PrintInfo "Step 3: Checking GitHub CLI (gh)..."
$GH_AVAILABLE = $false
$ghCmd = Get-Command gh -ErrorAction SilentlyContinue
if ($ghCmd) {
    PrintSuccess "GitHub CLI installed"
    $GH_AVAILABLE = $true
    
    PrintInfo "Checking GitHub login status..."
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        PrintSuccess "Logged in to GitHub"
    } else {
        PrintWarning "Not logged in to GitHub"
        Write-Host "Run: gh auth login"
        $login = Read-Host "Login now? (y/n)"
        if ($login -eq "y") {
            gh auth login
        } else {
            $GH_AVAILABLE = $false
        }
    }
} else {
    PrintWarning "GitHub CLI not installed"
    Write-Host "Install: winget install GitHub.cli"
}

# Step 4: Get configuration
PrintInfo "Step 4: Getting configuration..."

$GH_USER = ""
if ($GH_AVAILABLE) {
    try {
        $GH_USER = gh api user --jq ".login" 2>$null
        if ($GH_USER) {
            PrintInfo "Detected username: $GH_USER"
            $use = Read-Host "Use this username? (y/n)"
            if ($use -ne "y") { $GH_USER = "" }
        }
    } catch {}
}

$GITHUB_USER = ""
if ($GH_USER) {
    $GITHUB_USER = $GH_USER
} else {
    $GITHUB_USER = Read-Host "Enter GitHub username"
}

if (-not $GITHUB_USER) {
    PrintError "Username cannot be empty"
    exit 1
}

$DEFAULT_REPO = "csharp-review"
$REPO_NAME = Read-Host "Enter repo name (default: $DEFAULT_REPO)"
if (-not $REPO_NAME) { $REPO_NAME = $DEFAULT_REPO }

PrintSuccess "Configuration:"
Write-Host "  Username: $GITHUB_USER"
Write-Host "  Repo: $REPO_NAME"
Write-Host "  URL: https://$GITHUB_USER.github.io/$REPO_NAME"

# Step 5: Initialize Git
PrintInfo "Step 5: Initializing Git repository..."
if (Test-Path ".git") {
    PrintWarning "Already a Git repository"
    $reinit = Read-Host "Reinitialize? (y/n)"
    if ($reinit -eq "y") {
        Remove-Item .git -Recurse -Force -ErrorAction SilentlyContinue
        git init
    }
} else {
    git init
}
git branch -M main
PrintSuccess "Git repository initialized"

# Step 6: Create GitHub repo
PrintInfo "Step 6: Creating GitHub repository..."
$REMOTE_URL = "https://github.com/$GITHUB_USER/$REPO_NAME.git"

if ($GH_AVAILABLE) {
    $repoCheck = gh repo view "$GITHUB_USER/$REPO_NAME" 2>&1
    if ($LASTEXITCODE -eq 0) {
        PrintWarning "Repository already exists"
        $useExisting = Read-Host "Use existing repo? (y/n)"
        if ($useExisting -ne "y") { exit 1 }
    } else {
        PrintInfo "Creating public repository..."
        gh repo create $REPO_NAME --public --description "C# Review Webpage"
        PrintSuccess "Repository created"
    }
    
    git remote remove origin 2>$null
    git remote add origin $REMOTE_URL
    PrintSuccess "Remote configured"
} else {
    PrintWarning "=== Manual Deployment ==="
    Write-Host ""
    Write-Host "Create repository on GitHub first:"
    Write-Host "  1. Visit https://github.com/new"
    Write-Host "  2. Repo name: $REPO_NAME"
    Write-Host "  3. Select Public"
    Write-Host "  4. Do NOT check README"
    Write-Host "  5. Click Create repository"
    Write-Host ""
    Read-Host "Press Enter after creating"
    
    git remote remove origin 2>$null
    git remote add origin $REMOTE_URL
}

# Step 7: Commit and push
PrintInfo "Step 7: Committing and pushing..."

if (-not (Test-Path ".nojekyll")) {
    New-Item .nojekyll -ItemType file -Force | Out-Null
}

git add .
git commit -m "Initial commit: C# Review webpage"
PrintSuccess "Code committed"

PrintInfo "Pushing to GitHub..."
git push -u origin main 2>&1
if ($LASTEXITCODE -eq 0) {
    PrintSuccess "Code pushed"
} else {
    PrintError "Push failed"
    Write-Host ""
    Write-Host "Manual push:"
    Write-Host "  git push -u origin main"
    Write-Host ""
    Write-Host "Or configure auth:"
    Write-Host "  1. Visit https://github.com/settings/tokens"
    Write-Host "  2. Create token (repo scope)"
    Write-Host "  3. Use token as password"
    exit 1
}

# Step 8: Enable Pages
PrintInfo "Step 8: Enabling GitHub Pages..."

if ($GH_AVAILABLE) {
    PrintInfo "Configuring Pages..."
    gh api --method POST "/repos/$GITHUB_USER/$REPO_NAME/pages" -f source="{\"branch\":\"main\",\"path\":\"/\"}" 2>$null
    if ($LASTEXITCODE -eq 0) {
        PrintSuccess "Pages configured"
    } else {
        PrintWarning "Auto-config failed, enable manually"
    }
}

Write-Host ""
Write-Host "Confirm Pages enabled:"
Write-Host "  https://github.com/$GITHUB_USER/$REPO_NAME/settings/pages"
Write-Host "  Source: Deploy from a branch"
Write-Host "  Branch: main / (root)"
Write-Host ""

# Done
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
PrintSuccess "Deployment Complete!"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Access URL:" -ForegroundColor White
Write-Host "  https://$GITHUB_USER.github.io/$REPO_NAME" -ForegroundColor Green
Write-Host ""
Write-Host "Mobile: Open URL in mobile browser" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
PrintInfo "Update method:"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  git add . && git commit -m 'update' && git push" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan