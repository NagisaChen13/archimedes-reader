@echo off
chcp 65001 >nul
echo ========================================================
echo   Archimedes Reader - GitHub 一键推送脚本
echo ========================================================
echo.
set /p REPO_URL="请输入您的 GitHub 仓库地址 (例如 https://github.com/yourname/archimedes-reader.git): "

if "%REPO_URL%"=="" (
    echo [错误] 仓库地址不能为空！
    pause
    exit /b
)

echo.
echo [1/4] 初始化本地 Git 仓库...
git init
git branch -M main

echo.
echo [2/4] 添加全量代码与资源文件...
git add .

echo.
echo [3/4] 提交代码...
git commit -m "feat: complete archimedes reader code and github actions pipeline"

echo.
echo [4/4] 推送到远程 GitHub 仓库...
git remote remove origin 2>nul
git remote add origin %REPO_URL%
git push -u origin main

echo.
echo ========================================================
echo [成功] 代码已成功推送到远程仓库！
echo 请打开该仓库的 Actions 页面查看云端自动化打包进度：
echo %REPO_URL%/actions
echo 约 5~8 分钟后，可在最新运行的 Workflow 底部 Artifacts 区域一键下载 APK 和 IPA 安装包。
echo ========================================================
pause
