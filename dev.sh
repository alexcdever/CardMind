#!/bin/bash

echo "Starting CardMind development servers..."

# Install dependencies
echo "Installing dependencies..."
pnpm install
if [ $? -ne 0 ]; then
    echo "Failed to install dependencies"
    exit 1
fi

# 创建一个新的tmux会话
if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
    tmux new-session -d -s cardmind

    # 创建后端窗口
    tmux send-keys -t cardmind:0 'cd server && cargo run' C-m

    # 创建前端窗口
    tmux split-window -h
    tmux send-keys 'pnpm dev' C-m

    # 附加到会话
    tmux attach-session -t cardmind
else
    # 如果没有tmux，使用后台进程
    echo "Starting backend server..."
    cd server && cargo run &
    BACKEND_PID=$!

    # 等待后端启动
    sleep 5

    echo "Starting frontend server..."
    cd .. && pnpm dev &
    FRONTEND_PID=$!

    # 等待用户中断
    echo "Development servers are running..."
    echo "Backend is available at http://localhost:3001"
    echo "Frontend is available at http://localhost:3000"
    echo "Press Ctrl+C to stop all servers"

    # 捕获中断信号
    trap "kill $BACKEND_PID $FRONTEND_PID; exit" INT TERM
    wait
fi
