运行命令：
wget -qO- 'https://github.com/UA-Jin/Node-Exporter/raw/main/install-node_exporter.sh' | sed 's/read -p /read -p & < \/dev\/tty /' | sudo bash
