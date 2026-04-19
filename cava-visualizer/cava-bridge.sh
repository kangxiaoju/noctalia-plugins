#!/usr/bin/env bash
# cava-bridge.sh — 被 BarWidget.qml 通过 Process 调用
# 输出格式：
#   ACTIVE:<bars>   当音频活跃时，每帧输出一次
#   IDLE            当没有音频时输出

BARS="${1:-12}"
FRAMERATE="${2:-30}"         # 可选参数，控制 cava 输出帧率，默认为 30 FPS
KEEP_CAVA_RUNNING="${3:-0}"  # 1 时无音频也保持 cava 运行，输出原生空闲帧
ASCII_MAX=16                  # cava 输出值域上限，QML 侧 /10.0 归一化依赖此值
RUNTIME_DIR=""
CONF=""
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

log_error() {
  printf '[cava-bridge] %s\n' "$*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "missing required command: $1"
    return 1
  fi
}

setup_runtime() {
  if [[ -n "$RUNTIME_DIR" ]]; then
    rm -rf "$RUNTIME_DIR"
  fi

  RUNTIME_DIR=$(mktemp -d /tmp/noctalia_cava_XXXXXX) || {
    log_error "failed to create runtime directory"
    return 1
  }

  CONF="$RUNTIME_DIR/cava.conf"
  FIFO="$RUNTIME_DIR/cava.fifo"

  if ! mkfifo "$FIFO"; then
    log_error "failed to create fifo: $FIFO"
    rm -rf "$RUNTIME_DIR"
    RUNTIME_DIR=""
    CONF=""
    FIFO=""
    return 1
  fi
}

cleanup() {
  trap - EXIT INT TERM
  stop_cava
  if [[ -n "$RUNTIME_DIR" ]]; then
    rm -rf "$RUNTIME_DIR"
  fi
  echo "IDLE"
  exit 0
}
trap cleanup EXIT INT TERM

is_audio_active() {
  LC_ALL=C pactl list sink-inputs 2>/dev/null | grep -q "Corked: no"
}

wait_for_sink_event() {
  local timeout_secs="${1:-5}"

  if ! command -v timeout >/dev/null 2>&1; then
    sleep "$timeout_secs"
    return 0
  fi

  timeout "${timeout_secs}s" sh -c '
    LC_ALL=C pactl subscribe 2>/dev/null |
      grep --line-buffered "sink-input" |
      head -n 1 >/dev/null
  '
}

start_cava() {
  if [[ -z "$CONF" || -z "$FIFO" ]]; then
    log_error "runtime paths are not initialized"
    return 1
  fi

  cat >"$CONF" <<EOF
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

  # 让 cava 和转发循环都有独立 PID，避免 stop 时只杀掉管道的子 shell、留下 cava 残留。
  while IFS= read -r line; do
    echo "ACTIVE:$line"
  done <"$FIFO" &
  READER_PID=$!

  # cava 会按 framerate 主动控制输出频率；这里不再额外 sleep，避免双时钟导致积压/延迟。
  cava -p "$CONF" >"$FIFO" 2>/dev/null &
  CAVA_PID=$!

  if ! kill -0 "$CAVA_PID" 2>/dev/null; then
    log_error "failed to start cava"
    if [[ -n "$CAVA_PID" ]]; then
      wait "$CAVA_PID" 2>/dev/null
    fi
    if [[ -n "$READER_PID" ]] && kill -0 "$READER_PID" 2>/dev/null; then
      kill "$READER_PID" 2>/dev/null
      wait "$READER_PID" 2>/dev/null
    fi
    CAVA_PID=""
    READER_PID=""
    return 1
  fi
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

}

if ! require_command pactl || ! require_command cava || ! require_command mkfifo || ! setup_runtime; then
  trap - EXIT INT TERM
  echo "IDLE"
  exit 1
fi

echo "IDLE"

while true; do
  if [[ "$KEEP_CAVA_RUNNING" == "1" ]] || is_audio_active; then
    # 保持运行模式下始终确保 cava 在跑；否则仅在音频活跃时运行
    if [[ -z "$CAVA_PID" ]] || ! kill -0 "$CAVA_PID" 2>/dev/null; then
      stop_cava
      if ! start_cava; then
        stop_cava
        echo "IDLE"
        wait_for_sink_event 2 >/dev/null 2>&1
        continue
      fi
    fi

    if [[ "$KEEP_CAVA_RUNNING" == "1" ]]; then
      wait_for_sink_event 5 >/dev/null 2>&1
    else
      wait_for_sink_event 2 >/dev/null 2>&1
    fi
  else
    # 无音频且未启用保持运行时，停掉 cava
    if [[ -n "$CAVA_PID" ]] && kill -0 "$CAVA_PID" 2>/dev/null; then
      stop_cava
      echo "IDLE"
    fi
    # 被动等待，不轮询
    wait_for_sink_event 5 >/dev/null 2>&1
  fi
done
