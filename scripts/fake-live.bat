@echo off
REM ============================================
REM 伪直播 FFmpeg 推流脚本 (Windows)
REM 用于循环播放视频文件实现无人直播
REM ============================================

setlocal enabledelayedexpansion

REM 配置参数
set SERVER_HOST=localhost
set RTMP_PORT=1935
set LIVE_PATH=live

REM 检查参数
if "%~1"=="" (
    echo 错误: 缺少直播间ID参数
    echo 用法: fake-live.bat ^<直播间ID^> ^<视频文件^>
    exit /b 1
)

if "%~2"=="" (
    echo 错误: 缺少视频文件参数
    echo 用法: fake-live.bat ^<直播间ID^> ^<视频文件^>
    exit /b 1
)

set ROOM_ID=%~1
set VIDEO_FILE=%~2
set LOOP_COUNT=-1
set USE_COPY=1
set BITRATE=2500k
set RESOLUTION=720

REM 检查视频文件
if not exist "%VIDEO_FILE%" (
    echo 错误: 视频文件不存在 - %VIDEO_FILE%
    exit /b 1
)

REM 检查 FFmpeg
where ffmpeg >nul 2>&1
if errorlevel 1 (
    echo 错误: ffmpeg 未安装或不在 PATH 中
    echo 请先下载安装: https://ffmpeg.org/download.html
    exit /b 1
)

REM 构建推流地址
set RTMP_URL=rtmp://%SERVER_HOST%:%RTMP_PORT%/%LIVE_PATH%/%ROOM_ID%

REM 显示信息
echo.
echo ============================================
echo   伪直播推流已启动
echo ============================================
echo.
echo   直播间ID: %ROOM_ID%
echo   视频文件: %VIDEO_FILE%
echo   推流地址: %RTMP_URL%
echo   循环次数: %LOOP_COUNT%
echo.
echo   正在推流... 按 Ctrl+C 停止
echo.

REM 构建并执行 FFmpeg 命令
if "%USE_COPY%"=="1" (
    ffmpeg -re -stream_loop %LOOP_COUNT% -i "%VIDEO_FILE%" -c copy -tune zerolatency -f flv "%RTMP_URL%"
) else (
    ffmpeg -re -stream_loop %LOOP_COUNT% -i "%VIDEO_FILE%" -c:v libx264 -preset veryfast -crf 23 -b:v %BITRATE% -tune zerolatency -f flv "%RTMP_URL%"
)

echo.
echo 推流已停止
endlocal
