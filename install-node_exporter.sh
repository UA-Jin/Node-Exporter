#!/bin/bash
set -euo pipefail
# 核心配置：【必须修改】替换成你的服务器真实IP(内网/外网均可)
LISTEN_IP="192.168.1.100"
# 监听端口固定9100(node_exporter默认端口，无需修改)
LISTEN_PORT="9100"

# 1. 定义项目地址+获取最新版本tag
github_project="prometheus/node_exporter"
echo "正在获取node_exporter最新版本..."
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
echo "获取到最新版本: ${tag}"
version=${tag#*v}

# 2. 下载+解压+安装最新版node_exporter二进制文件
echo "开始下载并安装 node_exporter ${version} ..."
wget -q https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${version}.linux-amd64.tar.gz && \
tar xvfz node_exporter-*.tar.gz && \
rm -f node_exporter-*.tar.gz
sudo mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin
rm -rf node_exporter-*.linux-amd64*

# 3. 创建无登录权限的专用运行用户
sudo useradd -rs /bin/false node_exporter >/dev/null 2>&1 || echo "用户node_exporter已存在，跳过创建"

# 4. 生成node_exporter的systemd系统服务文件
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

# ========== 核心新增：修改服务文件，指定仅监听【你的IP+端口】 ==========
echo "正在配置监听地址: ${LISTEN_IP}:${LISTEN_PORT}"
sudo sed -i "s#ExecStart=\/usr\/local\/bin\/node_exporter#ExecStart=\/usr\/local\/bin\/node_exporter --web.listen-address=${LISTEN_IP}:${LISTEN_PORT}#" /etc/systemd/system/node_exporter.service

# 5. 重载系统服务+开机自启+立即重启+查看运行状态
echo "重载配置并启动服务..."
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl restart node_exporter
sudo systemctl status node_exporter -l