# ============================================================
# GitHub Pages 手动部署指南
# 适用：无法使用 gh CLI 时的备选方案
# ============================================================

## 步骤 1：在 GitHub 上创建仓库

1. 打开浏览器访问：https://github.com/new
2. 填写仓库信息：
   - Repository name: my-webpage（或你想要的名称）
   - 选择 Public（公开）
   - **不要勾选** "Add a README file"
   - **不要勾选** "Add .gitignore"
   - 点击 "Create repository"

## 步骤 2：在本地初始化并推送

将以下命令复制到终端执行（请替换 YOUR_USERNAME 和 YOUR_REPO）：

```bash
# 初始化 Git 仓库
git init

# 设置默认分支为 main
git branch -M main

# 添加所有文件
git add .

# 提交
git commit -m "Initial commit: deploy webpage to GitHub Pages"

# 添加远程仓库（替换为你的用户名和仓库名）
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 推送到 GitHub
git push -u origin main
```

## 步骤 3：启用 GitHub Pages

1. 打开浏览器访问：https://github.com/YOUR_USERNAME/YOUR_REPO/settings/pages
2. 在 "Source" 部分：
   - 选择 "Deploy from a branch"
   - Branch: main
   - Folder: / (root)
3. 点击 "Save"

## 步骤 4：访问你的网页

等待 1-2 分钟后，访问：
https://YOUR_USERNAME.github.io/YOUR_REPO

## 后续更新命令

每次修改 index.html 后，运行：

```bash
git add . && git commit -m "update" && git push
```

## PowerShell 版本命令

```powershell
git init
git branch -M main
git add .
git commit -m "Initial commit: deploy webpage to GitHub Pages"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

## 认证问题解决

如果推送时提示需要认证：

### 方法 1：使用 Personal Access Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 选择 "repo" 权限
4. 生成并保存 token
5. 推送时输入 token 作为密码

### 方法 2：使用 SSH

1. 生成 SSH 密钥：
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. 查看公钥：
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. 将公钥添加到 GitHub：
   https://github.com/settings/ssh/new

4. 使用 SSH 地址：
   ```bash
   git remote set-url origin git@github.com:YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```

## 常见问题

### Q: 页面显示 404？
A: 等待 1-5 分钟，GitHub Pages 需要时间构建。

### Q: 页面样式不生效？
A: 确保 CSS/JS 文件路径正确，建议使用相对路径。

### Q: 如何查看构建状态？
A: 访问 https://github.com/YOUR_USERNAME/YOUR_REPO/actions

### Q: 如何使用自定义域名？
A: 在仓库 Settings -> Pages -> Custom domain 中设置。