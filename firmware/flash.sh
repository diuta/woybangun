#!/usr/bin/env bash
set -euo pipefail

FQBN="esp32:esp32:esp32c6:CDCOnBoot=cdc"
SKETCH="${1:?usage: ./flash.sh <sketch-folder> [monitor]}"
DIR="$(cd "$(dirname "$0")" && pwd)/$SKETCH"

PORT="$(arduino-cli board list | awk '/ESP32/ {print $1; exit}')"
[ -z "$PORT" ] && PORT="$(arduino-cli board list | awk '/usbmodem/ {print $1; exit}')"

if [ -z "$PORT" ]; then
  echo "No board found. Plug the ESP32-C6 in and try again." >&2
  exit 1
fi

echo "→ $SKETCH  ⇒  $PORT"
arduino-cli compile --fqbn "$FQBN" -u -p "$PORT" "$DIR"

if [ "${2:-}" = "monitor" ]; then
  echo "→ serial (Ctrl+C to stop)"
  arduino-cli monitor -p "$PORT" -c baudrate=115200
fi
