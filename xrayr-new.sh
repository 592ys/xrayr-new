#!/bin/bash

# =========================================================
# XrayR 核心替换脚本 (Mtoly版)
# 运行方式: bash <(curl -Ls 你的Raw链接)
# 作用: 仅替换 /usr/local/XrayR/XrayR 二进制文件，不修改配置
# =========================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 目标仓库
GITHUB_OWNER="Mtoly"
GITHUB_REPO="XrayRbackup"
# 核心安装位置 (官方脚本默认位置)
BIN_PATH="/usr/local/XrayR/XrayR"

echo -e "${yellow}=== 开始更新 XrayR 内核 (源: ${GITHUB_OWNER}) ===${plain}"

# 1. 检查权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误: 请使用 root 用户运行！${plain}" && exit 1

# 2. 检查架构
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) FILE_ARCH="64" ;;
    aarch64|arm64) FILE_ARCH="arm64-v8a" ;;
    *) echo -e "${red}不支持的架构: $ARCH${plain}" && exit 1 ;;
esac

# 3. 获取最新版本
echo -e "${yellow}正在检查最新版本...${plain}"
TAG=$(curl -s "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$TAG" ]]; then
    echo -e "${red}获取版本失败，请检查网络。${plain}"
    exit 1
fi
echo -e "最新版本: ${green}${TAG}${plain}"

# 4. 准备临时环境
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# 5. 下载文件
DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${TAG}/XrayR-linux-${FILE_ARCH}.zip"
echo -e "${yellow}正在下载: ${DOWNLOAD_URL}${plain}"
wget -N --no-check-certificate -O XrayR.zip "$DOWNLOAD_URL"

if [[ $? -ne 0 ]]; then
    echo -e "${red}下载失败！${plain}"
    rm -rf $TEMP_DIR
    exit 1
fi

# 6. 解压并替换
echo -e "${yellow}正在安装...${plain}"
unzip -o XrayR.zip > /dev/null

# 停止服务
systemctl stop XrayR

# 备份旧文件 (可选，防止瞬间替换失败文件丢失)
if [[ -f "$BIN_PATH" ]]; then
    mv "$BIN_PATH" "${BIN_PATH}.bak"
fi

# 移动新文件
if [[ -f "XrayR" ]]; then
    cp -f XrayR "$BIN_PATH"
    chmod +x "$BIN_PATH"
    echo -e "${green}内核替换成功！${plain}"
else
    echo -e "${red}解压文件缺失，还原旧版本...${plain}"
    mv "${BIN_PATH}.bak" "$BIN_PATH"
    systemctl start XrayR
    rm -rf $TEMP_DIR
    exit 1
fi

# 7. 清理与重启
rm -rf $TEMP_DIR
# 删除备份 (确认成功后再删，或者保留也行)
rm -f "${BIN_PATH}.bak"

echo -e "${yellow}正在重启服务...${plain}"
systemctl restart XrayR

# 8. 验证
echo -e "------------------------------------------------"
echo -e "当前运行版本 (Mtoly):"
$BIN_PATH version
echo -e "------------------------------------------------"
echo -e "${green}更新完成！正在拉取最后 10 行日志...${plain}"
echo -e "如果需要查看完整日志，请手动输入: xrayr log"
echo -e "------------------------------------------------"
sleep 2
journalctl -u XrayR --no-pager -n 10
