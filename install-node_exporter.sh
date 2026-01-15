#!/bin/bash
set -euo pipefail
LISTEN_PORT="9100"

# ===================== 交互式输入IP【修复：为空则重新输入】 =====================
echo -e "\033[32m===== Prometheus node_exporter 一键安装脚本(自动获取最新版) =====\033[0m"
while true; do
    read -p "请输入本机需要监听的IP地址(内网/外网IP均可，推荐内网IP)：" LISTEN_IP
    if [ -n "${LISTEN_IP}" ]; then
        break
    fi
    echo -e "\033[31m错误：IP地址不能为空，请重新输入！\033[0m"
done
echo -e "✅ 已确认监听地址：\033[32m${LISTEN_IP}:${LISTEN_PORT}\033[0m\n"

# 1. 获取最新版本
github_project="prometheus/node_exporter"
echo "🔍 正在获取node_exporter最新版本..."
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
echo "✅ 获取到最新版本: ${tag}"
version=${tag#*v}

# 2. 下载解压安装
echo -e "\n📥 开始下载并安装 node_exporter ${version} ..."
wget -q https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${version}.linux-amd64.tar.gz && \
tar xvfz node_exporter-*.tar.gz && \
rm -f node_exporter-*.tar.gz
sudo mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin
rm -rf node_exporter-*.linux-amd64*

# 3. 创建专用用户
sudo useradd -rs /bin/false node_exporter >/dev/null 2>&1 || echo "ℹ️ 用户node_exporter已存在，跳过创建"

# 4. 生成服务文件
sudo cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# ========== 核心修复：sed用@做分隔符，彻底解决unknown option to s报错 ==========
echo -e "\n⚙️ 正在配置监听地址，写入服务文件..."
sudo sed -i "s@ExecStart=/usr/local/bin/node_exporter@ExecStart=/usr/local/bin/node_exporter --web.listen-address=${LISTEN_IP}:${LISTEN_PORT}@" /etc/systemd/system/node_exporter.service

# 5. 重载+启动服务
echo -e "\n🚀 重载配置并启动服务..."
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl restart node_exporter
echo -e "\033[32m==================== 服务运行状态 ====================\033[0m"
sudo systemctl status node_exporter -l