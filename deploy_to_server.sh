#!/bin/bash

# 服务器信息
SERVER_IP="3.0.25.131"
SERVER_USER="ubuntu"
SERVER_DIR="/data/xaa/auto-deploy-contract"

# Git分支名称
GIT_BRANCH=${1:-"main"}

# 在服务器上拉取最新代码并部署
echo "连接服务器并部署..."
ssh $SERVER_USER@$SERVER_IP "cd $SERVER_DIR && \
    git fetch && \
    git checkout $GIT_BRANCH && \
    git pull origin $GIT_BRANCH && \
    rm -rf ./build && \
    mkdir -p ./build && \
    go build -o ./build/auto-deploy-contract ./main.go && \
    cp .env ./build/ && \
    cd build && \
    nohup ./auto-deploy-contract > output.log 2>&1 &"

echo "部署完成！"