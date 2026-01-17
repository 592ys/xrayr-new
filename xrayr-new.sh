#!/usr/bin/env bash
set -euo pipefail

# ================== 固定参数（与官方一致） ==================
REPO="Mtoly/XrayRbackup"
XRAYR_DIR="/usr/local/XrayR"
XRAYR_BIN="${XRAYR_DIR}/XrayR"
SERVICE="XrayR"

# ================== 颜色输出 ==================
red()   { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow(){ echo -e "\033[33m$*\033[0m"; }

# ================== 基本检查 ==================
[[ $EUID -ne 0 ]] && red "请使用 root 运行" && exit 1
[[ ! -f "$XRAYR_BIN" ]] && red "未检测到官方 XrayR：$XRAYR_BIN" && exit 1

OS=$(uname -s | tr 'A-Z' 'a-z')
ARCH=$(uname -m)

[[ "$OS" != "linux" ]] && red "仅支持 Linux" && exit 1

case "$ARCH" in
  x86_64|amd64)
    ARCH_FILTER="linux.*(64|amd64|x86_64)"
    ;;
  aarch64|arm64)
    ARCH_FILTER="linux.*(arm64|aarch64)"
    ;;
  *)
    red "不支持的架构：$ARCH"
    exit 1
    ;;
esac

# ================== 获取 Release ==================
green "获取 XrayRbackup 最新 Release..."

json=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")

tag=$(echo "$json" | grep -m1 '"tag_name"' | cut -d '"' -f4)

url=$(echo "$json" \
  | grep '"browser_download_url"' \
  | grep -Ei "$ARCH_FILTER" \
  | grep -vi 'android' \
  | grep -vi 'darwin' \
  | grep -vi 'windows' \
  | head -n1 \
  | cut -d '"' -f4)

[[ -z "$url" ]] && red "未找到匹配当前系统的 Release 资产" && exit 1

green "版本: $tag"
green "下载: $url"

# ================== 下载 & 解压 ==================
tmpdir=$(mktemp -d)
cd "$tmpdir"

curl -fL -o release "$url"

filetype=$(file release)

if echo "$filetype" | grep -qi 'gzip'; then
    tar -xzf release
elif echo "$filetype" | grep -qi 'zip'; then
    unzip -o release
else
    red "未知 Release 格式"
    exit 1
fi

bin=$(find . -type f -name XrayR | head -n1)
[[ -z "$bin" ]] && red "Release 中未找到 XrayR 二进制" && exit 1

# ================== 停服 + 备份 ==================
green "停止官方 XrayR 服务"
systemctl stop "$SERVICE"

backup="${XRAYR_BIN}.bak.$(date +%F-%H%M%S)"
green "备份原 XrayR -> $backup"
cp "$XRAYR_BIN" "$backup"

# ================== 原子替换 ==================
green "更新 XrayR 程序（二进制覆盖）"
cp "$bin" "${XRAYR_BIN}.new"
chmod +x "${XRAYR_BIN}.new"
mv -f "${XRAYR_BIN}.new" "$XRAYR_BIN"

# ================== 启动 & 回滚保护 ==================
green "启动 XrayR 服务"
if ! systemctl start "$SERVICE"; then
    red "启动失败，正在回滚..."
    cp "$backup" "$XRAYR_BIN"
    systemctl start "$SERVICE"
    exit 1
fi

# ================== 清理 ==================
rm -rf "$tmpdir"

green "✅ 已成功使用 XrayRbackup $tag 覆盖官方 XrayR"
