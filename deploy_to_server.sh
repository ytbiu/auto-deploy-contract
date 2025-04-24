#!/bin/bash

# 服务器信息
SERVER_IP="3.0.25.131"
SERVER_USER="ubuntu"
SERVER_DIR="/data/xaa/auto-deploy-contract"

# Git分支名称
GIT_BRANCH=${1:-"main"}

# 本地编译
echo "开始本地编译..."
rm -rf ./build
mkdir -p ./build
GOOS=linux GOARCH=amd64 go build -o ./build/auto-deploy-contract ./main.go
cp .env ./build/

# 先停止服务器上运行的程序
echo "检查并停止服务器上运行的程序..."
ssh $SERVER_USER@$SERVER_IP "pid=\$(ps aux | grep '[a]uto-deploy-contract' | awk '{print \$2}'); \
    if [ ! -z \"\$pid\" ]; then \
        echo \"终止已运行的程序 (PID: \$pid)...\"; \
        kill \$pid; \
        sleep 2; \
    fi"

# 上传到服务器
echo "上传文件到服务器..."
ssh $SERVER_USER@$SERVER_IP "rm  $SERVER_DIR/auto-deploy-contract"
scp ./build/auto-deploy-contract $SERVER_USER@$SERVER_IP:$SERVER_DIR/
scp ./build/.env $SERVER_USER@$SERVER_IP:$SERVER_DIR/

# 在服务器上启动服务
echo "启动服务..."
ssh $SERVER_USER@$SERVER_IP << 'EOF'
cd /data/xaa/auto-deploy-contract
pid=$(pgrep auto-deploy-contract)
if [ ! -z "$pid" ]; then
    echo "终止已运行的程序 (PID: $pid)..."
    kill $pid
    sleep 2
fi
nohup ./auto-deploy-contract --env prod > output.log 2>&1 &
EOF

echo "部署完成！"