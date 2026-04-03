#! /bin/bash
# cava-bridge.sh — 被 BarWidget.qml 通过 Process 调用
# 输出格式：
#   ACTIVE:<bars>   当音频活跃时，每帧输出一次
#   IDLE            当没有音频时输出

BARS="${1:-12}"
FRAMERATE="${2:-30}" # 可选参数，控制 cava 输出帧率，默认为 30 FPS
KEEP_CAVA_RUNNING="${3:-0}" # 1 时无音频也保持 cava 运行，输出原生空闲帧
ASCII_MAX=16  # cava 输出值域上限，QML 侧 /10.0 归一化依赖此值
CONF=$(mktemp /tmp/noctalia_cava_XXXXXX.conf)
FIFO=""
CAVA_PID=""
READER_PID=""

if ! [[ "$FRAMERATE" =~ ^[0-9]+$ ]] || [[ "$FRAMERATE" -lt 1 ]]; then
    FRAMERATE=30
fi
if ! [[ "$BARS" =~ ^[0-9]+$ ]] || [[ "$BARS" -lt 2 ]]; then
    BARS=12
fi
if [[ "$KEEP_CAVA_RUNNING" != "1" ]]; then
    KEEP_CAVA_RUNNING=0
fi

cleanup() {
    trap - EXIT INT TERM
    stop_cava
    rm -f "$CONF"
    echo "IDLE"
    exit 0
}
trap cleanup EXIT INT TERM

is_audio_active() {
    pactl list sink-inputs 2>/dev/null | grep -q "Corked: no"
}

start_cava() {
    cat > "$CONF" <<EOF
[general]
bars = $BARS
framerate = $FRAMERATE

[input]
method = pulse
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = $ASCII_MAX
EOF

    FIFO=$(mktemp -u /tmp/noctalia_cava_fifo_XXXXXX)
    mkfifo "$FIFO"

    # 让 cava 和转发循环都有独立 PID，避免 stop 时只杀掉管道的子 shell、留下 cava 残留。
    while IFS= read -r line; do
        echo "ACTIVE:$line"
    done < "$FIFO" &
    READER_PID=$!

    # cava 会按 framerate 主动控制输出频率；这里不再额外 sleep，避免双时钟导致积压/延迟。
    cava -p "$CONF" > "$FIFO" 2>/dev/null &
    CAVA_PID=$!
}

stop_cava() {
    if [[ -n "$CAVA_PID" ]] && kill -0 "$CAVA_PID" 2>/dev/null; then
        kill "$CAVA_PID" 2>/dev/null
        wait "$CAVA_PID" 2>/dev/null
    fi
    CAVA_PID=""

    if [[ -n "$READER_PID" ]] && kill -0 "$READER_PID" 2>/dev/null; then
        kill "$READER_PID" 2>/dev/null
        wait "$READER_PID" 2>/dev/null
    fi
    READER_PID=""

    if [[ -n "$FIFO" ]]; then
        rm -f "$FIFO"
    fi
    FIFO=""
}

echo "IDLE"

while true; do
    if [[ "$KEEP_CAVA_RUNNING" == "1" ]] || is_audio_active; then
        # 保持运行模式下始终确保 cava 在跑；否则仅在音频活跃时运行
        if [[ -z "$CAVA_PID" ]] || ! kill -0 "$CAVA_PID" 2>/dev/null; then
            stop_cava
            start_cava
        fi
        sleep 1
    else
        # 无音频且未启用保持运行时，停掉 cava
        if [[ -n "$CAVA_PID" ]] && kill -0 "$CAVA_PID" 2>/dev/null; then
            stop_cava
            echo "IDLE"
        fi
        # 被动等待，不轮询
        timeout 5s pactl subscribe 2>/dev/null \
            | grep --line-buffered "sink-input" \
            | head -n 1 > /dev/null
    fi
done
