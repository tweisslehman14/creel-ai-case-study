#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
# These are local defaults verified on this Mac. Each processing action still requires a click.
export CREEL_OLLAMA_MODEL="${CREEL_OLLAMA_MODEL:-llama3.1:8b}"
if command -v whisper-cli >/dev/null 2>&1 && [ -f "$PWD/models/ggml-base.en.bin" ]; then
  export CREEL_WHISPER_EXECUTABLE="${CREEL_WHISPER_EXECUTABLE:-$(command -v whisper-cli)}"
  export CREEL_WHISPER_MODEL="${CREEL_WHISPER_MODEL:-$PWD/models/ggml-base.en.bin}"
fi
exec python3 -u server.py "$@"
