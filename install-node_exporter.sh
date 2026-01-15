@ -0,0 +1,63 @@
#!/bin/bash
set -euo pipefail
# node_exporter默认监听端口，固定9100，请勿修改
LISTEN_PORT="9100"

# ===================== 核心交互：执行脚本后 手动输入IP =====================
echo -e "\033[32m===== Prometheus node_exporter 一键安装脚本(自动获取最新版) =====\033[0m"
read -p "请输入本机需要监听的IP地址(内网/外网IP均可，推荐内网IP)：" LISTEN_IP
# 校验用户是否输入了IP，为空则终止脚本
if [ -z "${LISTEN_IP}" ]; then
    echo -e "\033[31m错误：IP地址不能为空！\033[0m"
    exit 1
fi
echo -e "✅ 已确认监听地址：\033[32m${LISTEN_IP}:${LISTEN_PORT}\033[0m\n"

# 1. 定义项目地址+获取node_exporter最新版本tag
github_project="prometheus/node_exporter"
echo "🔍 正在获取node_exporter最新版本..."
tag=$(wget -qO- -t1 -T2 "https://api.github.com/repos/${github_project}/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
echo "✅ 获取到最新版本: ${tag}"
version=${tag#*v}

# 2. 下载+解压+安装最新版二进制文件
echo -e "\n📥 开始下载并安装 node_exporter ${version} ..."
wget -q https://github.com/prometheus/node_exporter/releases/download/${tag}/node_exporter-${version}.linux-amd64.tar.gz && \
tar xvfz node_exporter-*.tar.gz && \
rm -f node_exporter-*.tar.gz
sudo mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin
rm -rf node_exporter-*.linux-amd64*

# 3. 创建无登录权限的专用运行用户(已存在则跳过，不报错)
sudo useradd -rs /bin/false node_exporter >/dev/null 2>&1 || echo "ℹ️ 用户node_exporter已存在，跳过创建"

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

# ========== 核心配置：自动写入【用户输入的IP+端口】到启动参数 ==========
echo -e "\n⚙️ 正在配置监听地址，写入服务文件..."
sudo sed -i "s#ExecStart=\/usr\/local\/bin\/node_exporter#ExecStart=\/usr\/local\/bin\/node_exporter --web.listen-address=${LISTEN_IP}:${LISTEN_PORT}#" /etc/systemd/system/node_exporter.service

# 5. 重载系统服务+开机自启+重启服务+查看运行状态
echo -e "\n🚀 重载配置并启动服务..."
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl restart node_exporter
echo -e "\033[32m==================== 服务运行状态 ====================\033[0m"
sudo systemctl status node_exporter -l