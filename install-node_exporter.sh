#!/bin/bash
set -e

# ===================== 核心修复1：强制从终端读取IP（兼容管道执行） =====================
# 无论是否管道执行，都从/dev/tty读取输入，避免stdin被占用导致输入跳过
read -p "请输入node_exporter监听IP（建议填0.0.0.0，留空则终止）：" LISTEN_IP < /dev/tty

# 空值校验（修复原脚本空值拼接错误）
if [ -z "$LISTEN_IP" ]; then
    echo "❌ 未输入监听IP，脚本终止"
    exit 1
fi
LISTEN_PORT="9100"
LISTEN_ADDR="${LISTEN_IP}:${LISTEN_PORT}"
echo "✅ 已确认监听地址：${LISTEN_ADDR}"

# ===================== 保留原逻辑：获取最新版本 =====================
echo -e "\n🔍 正在获取node_exporter最新版本..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep "tag_name" | cut -d "\"" -f 4)
if [ -z "$LATEST_VERSION" ]; then
    echo "❌ 获取最新版本失败，请检查网络或GitHub访问权限"
    exit 1
fi
VERSION=${LATEST_VERSION#v}  # 去掉版本号前的v
echo "✅ 获取到最新版本: ${LATEST_VERSION}"

# ===================== 保留原逻辑：下载并安装 =====================
echo -e "\n📥 开始下载并安装 node_exporter ${VERSION} ..."
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/${LATEST_VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
# 静默下载，失败则终止
if ! wget -q "${DOWNLOAD_URL}" -O node_exporter.tar.gz; then
    echo "❌ 下载node_exporter失败"
    exit 1
fi
# 解压并复制二进制文件
tar -zxf node_exporter.tar.gz > /dev/null 2>&1
cd node_exporter-${VERSION}.linux-amd64
sudo cp -f node_exporter /usr/local/bin/
cd .. && rm -rf node_exporter.tar.gz node_exporter-${VERSION}.linux-amd64

# ===================== 核心修复2：解决sed分隔符报错（直接生成服务文件，避免sed修改） =====================
echo -e "\n⚙️ 正在配置监听地址，写入服务文件..."
# 直接生成服务文件，避免sed替换的分隔符问题
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${LISTEN_ADDR}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# ===================== 保留原逻辑：启动并启用服务 =====================
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter > /dev/null 2>&1

# 验证安装结果
if sudo systemctl is-active --quiet node_exporter; then
    echo -e "\n✅ node_exporter 安装成功！"
    echo "🔍 监听地址：${LISTEN_ADDR}"
    echo "📌 服务状态：运行中"
else
    echo -e "\n❌ node_exporter 安装失败，请检查日志：sudo journalctl -u node_exporter -f"
    exit 1
fi