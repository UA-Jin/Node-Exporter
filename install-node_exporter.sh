#!/bin/bash
set -e

# 监听地址配置（修复IP输入逻辑）
read -p "请输入node_exporter监听IP（留空则终止，建议填0.0.0.0）：" LISTEN_IP
if [ -z "$LISTEN_IP" ]; then
    echo "❌ 未输入监听IP，脚本终止"
    exit 1
fi
LISTEN_PORT="9100"
LISTEN_ADDR="${LISTEN_IP}:${LISTEN_PORT}"
echo "✅ 已确认监听地址：${LISTEN_ADDR}"

# 获取最新版本（保留原逻辑）
echo -e "\n🔍 正在获取node_exporter最新版本..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "tag_name" | cut -d "\"" -f 4)
if [ -z "$LATEST_VERSION" ]; then
    echo "❌ 获取最新版本失败"
    exit 1
fi
VERSION=${LATEST_VERSION#v}
echo "✅ 获取到最新版本: ${LATEST_VERSION}"

# 下载安装（保留原逻辑）
echo -e "\n📥 开始下载并安装 node_exporter ${VERSION} ..."
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/${LATEST_VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
wget -q "${DOWNLOAD_URL}" -O node_exporter.tar.gz
tar -zxf node_exporter.tar.gz
cd node_exporter-${VERSION}.linux-amd64
sudo cp node_exporter /usr/local/bin/
cd .. && rm -rf node_exporter.tar.gz node_exporter-${VERSION}.linux-amd64

# 配置服务文件（修复sed分隔符问题）
echo -e "\n⚙️ 正在配置监听地址，写入服务文件..."
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${LISTEN_ADDR}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 替换命令修复（若原脚本用sed修改已有服务文件，替换为如下写法）
# sed -i "s|--web.listen-address=.*|--web.listen-address=${LISTEN_ADDR}|g" /etc/systemd/system/node_exporter.service

# 启动服务（保留原逻辑）
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
echo -e "\n✅ node_exporter 安装完成，监听地址：${LISTEN_ADDR}"
echo "🔍 状态检查：$(sudo systemctl status node_exporter --no-pager | grep Active)"