#!/bin/bash
# ============================================
# 伪直播 FFmpeg 推流脚本
# 用于循环播放视频文件实现无人直播
# ============================================

# 配置参数
SERVER_HOST="localhost"
RTMP_PORT="1935"
LIVE_PATH="live"
VIDEO_DIR="/Users/season/AI编程/billd-live-project/videos"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 显示帮助
show_help() {
  echo -e "${GREEN}伪直播 FFmpeg 推流工具${NC}"
  echo ""
  echo "用法:"
  echo "  ./fake-live.sh <直播间ID> <视频文件> [选项]"
  echo ""
  echo "参数:"
  echo "  直播间ID    直播间的唯一标识"
  echo "  视频文件    要循环播放的视频文件路径"
  echo ""
  echo "选项:"
  echo "  -h, --help  显示帮助信息"
  echo "  -l, --loop  循环次数 (默认 -1 无限循环)"
  echo "  -c, --copy  直接复制不重新编码"
  echo "  -t, --trans 重新编码以提高兼容性"
  echo "  -b, --bitrate 码率 (默认 2500k)"
  echo "  -r, --resolution 分辨率 (默认 720p)"
  echo ""
  echo "示例:"
  echo "  ./fake-live.sh 1 video.mp4"
  echo "  ./fake-live.sh 1 /path/to/video.mp4 -c -l 3"
  echo "  ./fake-live.sh 1 video.mp4 -t -b 4000k -r 1080"
  echo ""
  echo "按 Ctrl+C 停止推流"
}

# 默认参数
ROOM_ID=""
VIDEO_FILE=""
LOOP_COUNT=-1
USE_COPY=true
BITRATE="2500k"
RESOLUTION="720"
LOW_LATENCY=true

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -l|--loop)
      LOOP_COUNT=$2
      shift 2
      ;;
    -c|--copy)
      USE_COPY=true
      shift
      ;;
    -t|--trans)
      USE_COPY=false
      shift
      ;;
    -b|--bitrate)
      BITRATE=$2
      shift 2
      ;;
    -r|--resolution)
      RESOLUTION=$2
      shift 2
      ;;
    -*)
      echo -e "${RED}未知选项: $1${NC}"
      echo "使用 -h 查看帮助"
      exit 1
      ;;
    *)
      if [ -z "$ROOM_ID" ]; then
        ROOM_ID=$1
      elif [ -z "$VIDEO_FILE" ]; then
        VIDEO_FILE=$1
      fi
      shift
      ;;
  esac
done

# 检查参数
if [ -z "$ROOM_ID" ] || [ -z "$VIDEO_FILE" ]; then
  echo -e "${RED}错误: 缺少必要参数${NC}"
  echo "使用 -h 查看帮助"
  exit 1
fi

# 检查视频文件是否存在
if [ ! -f "$VIDEO_FILE" ]; then
  echo -e "${RED}错误: 视频文件不存在 - $VIDEO_FILE${NC}"
  exit 1
fi

# 检查 FFmpeg 是否存在
if ! command -v ffmpeg &> /dev/null; then
  echo -e "${RED}错误: ffmpeg 未安装${NC}"
  echo "请先安装: brew install ffmpeg"
  exit 1
fi

# 构建推流地址
RTMP_URL="rtmp://${SERVER_HOST}:${RTMP_PORT}/${LIVE_PATH}/${ROOM_ID}"

# 构建 FFmpeg 命令
FFMPEG_CMD="ffmpeg -re -stream_loop ${LOOP_COUNT} -i \"${VIDEO_FILE}\""

# 编码参数
if [ "$USE_COPY" = true ]; then
  FFMPEG_CMD+=" -c copy"
else
  FFMPEG_CMD+=" -c:v libx264 -preset veryfast -crf 23 -b:v ${BITRATE}"
fi

# 低延迟优化
if [ "$LOW_LATENCY" = true ]; then
  FFMPEG_CMD+=" -tune zerolatency"
fi

# 分辨率
if [ "$RESOLUTION" != "720" ]; then
  FFMPEG_CMD+=" -s ${RESOLUTION}x${RESOLUTION}p"
fi

# 输出格式
FFMPEG_CMD+=" -f flv \"${RTMP_URL}\""

# 显示信息
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  伪直播推流已启动${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  直播间ID: ${YELLOW}${ROOM_ID}${NC}"
echo -e "  视频文件: ${YELLOW}${VIDEO_FILE}${NC}"
echo -e "  推流地址: ${YELLOW}${RTMP_URL}${NC}"
echo -e "  循环次数: ${YELLOW}${LOOP_COUNT}${NC}"
echo -e "  编码方式: ${YELLOW}$([ "$USE_COPY" = true ] && echo "直接复制" || echo "重新编码")${NC}"
echo ""
echo -e "${GREEN}  正在推流... 按 Ctrl+C 停止${NC}"
echo ""

# 执行推流
eval $FFMPEG_CMD

# 退出处理
echo ""
echo -e "${YELLOW}推流已停止${NC}"
