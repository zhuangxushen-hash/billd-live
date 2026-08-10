#!/bin/bash
# ============================================
# 一键启动脚本
# 启动所有服务并配置伪直播环境
# ============================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║       直播系统一键启动脚本                    ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# 检查 Node.js
echo -e "${YELLOW}[1/5] 检查环境...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}错误: Node.js 未安装${NC}"
    exit 1
fi
echo -e "  Node.js: $(node -v)"

# 检查 FFmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${YELLOW}警告: FFmpeg 未安装，伪直播功能不可用${NC}"
else
    echo -e "  FFmpeg: $(ffmpeg -version | head -1)"
fi

# 安装依赖
echo -e "${YELLOW}[2/5] 安装依赖...${NC}"

echo "  安装后端依赖..."
cd live-server
if [ ! -d "node_modules" ]; then
    npm install --silent
fi
cd "$PROJECT_DIR"

echo "  安装前端依赖..."
cd live-client
if [ ! -d "node_modules" ]; then
    npm install --silent
fi
cd "$PROJECT_DIR"

echo "  安装管理后台依赖..."
cd live-admin
if [ ! -d "node_modules" ]; then
    npm install --silent
fi
cd "$PROJECT_DIR"

echo -e "${GREEN}  依赖安装完成${NC}"

# 创建数据目录
echo -e "${YELLOW}[3/5] 初始化数据...${NC}"
mkdir -p data videos
if [ ! -f data/users.json ]; then
    echo '[{"id":1,"username":"admin","password":"123456","role":"admin","nickname":"管理员"}]' > data/users.json
fi
if [ ! -f data/rooms.json ]; then
    echo '[]' > data/rooms.json
fi
if [ ! -f data/danmaku.json ]; then
    echo '[]' > data/danmaku.json
fi
if [ ! -f data/gifts.json ]; then
    echo '[{"id":1,"name":"小心心","icon":"heart","price":1},{"id":2,"name":"棒棒糖","icon":"lollipop","price":10},{"id":3,"name":"蛋糕","icon":"cake","price":50},{"id":4,"name":"跑车","icon":"car","price":520},{"id":5,"name":"火箭","icon":"rocket","price":1314}]' > data/gifts.json
fi
echo -e "${GREEN}  数据初始化完成${NC}"

# 启动服务
echo -e "${YELLOW}[4/5] 启动服务...${NC}"

# 生成演示视频（如果没有）
if [ ! -f videos/demo.mp4 ]; then
    echo "  生成演示视频..."
    ffmpeg -f lavfi -i "testsrc=duration=10:size=1280x720:rate=25" -f lavfi -i "sine=frequency=1000:duration=10" -c:v libx264 -preset veryfast -c:a aac -shortest videos/demo.mp4 -y 2>/dev/null || true
fi

# 启动后端服务
echo "  启动后端服务 (端口: 3000)..."
cd live-server
node index.js &
BACKEND_PID=$!
cd "$PROJECT_DIR"

sleep 2

# 启动前端开发服务器
echo "  启动前端客户端 (端口: 5173)..."
cd live-client
npm run dev &
CLIENT_PID=$!
cd "$PROJECT_DIR"

sleep 2

# 启动管理后台
echo "  启动管理后台 (端口: 5174)..."
cd live-admin
npm run dev &
ADMIN_PID=$!
cd "$PROJECT_DIR"

# 等待服务就绪
sleep 3

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║       启动完成!                               ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "  ${BLUE}后端服务:${NC}    http://localhost:3000"
echo -e "  ${BLUE}前端客户端:${NC}  http://localhost:5173"
echo -e "  ${BLUE}管理后台:${NC}    http://localhost:5174"
echo -e "  ${BLUE}API接口:${NC}     http://localhost:3000/api"
echo ""
echo -e "  ${YELLOW}默认账号: admin / 123456${NC}"
echo ""
echo -e "${YELLOW}创建直播间后，在管理后台查看推流地址，使用以下命令启动伪直播:${NC}"
echo ""
echo -e "  ./scripts/fake-live.sh <直播间ID> videos/demo.mp4"
echo ""
echo -e "${GREEN}按 Ctrl+C 停止所有服务${NC}"

# 保存 PID
echo $BACKEND_PID > .backend.pid
echo $CLIENT_PID > .client.pid
echo $ADMIN_PID > .admin.pid

# 等待用户中断
trap "echo -e '${YELLOW}正在停止服务...${NC}'; kill $BACKEND_PID $CLIENT_PID $ADMIN_PID 2>/dev/null; echo -e '${GREEN}已停止${NC}'; exit" SIGINT SIGTERM

wait
