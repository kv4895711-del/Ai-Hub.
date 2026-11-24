#!/data/data/com.termux/files/usr/bin/bash
# AI Hub: starts the FreeLLMAPI gateway in the background (if it is not already running).
# Copy this file to your Termux home folder as ~/startgateway.sh and run: chmod +x ~/startgateway.sh

GATEWAY_DIR="$HOME/freellmapi"
LOG_FILE="$HOME/gateway.log"
URL="http://localhost:3001"

# Keep the phone from killing Termux when the screen turns off (needs Termux:API).
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock
fi

# Already running? Then do nothing.
if curl -s --max-time 3 "$URL" >/dev/null 2>&1; then
  echo "Gateway already running."
  exit 0
fi

if [ ! -d "$GATEWAY_DIR" ]; then
  echo "ERROR: $GATEWAY_DIR not found. Install FreeLLMAPI first." >> "$LOG_FILE"
  exit 1
fi

cd "$GATEWAY_DIR" || exit 1
nohup npm run dev >> "$LOG_FILE" 2>&1 &
echo "Gateway starting. Log: $LOG_FILE"
exit 0
