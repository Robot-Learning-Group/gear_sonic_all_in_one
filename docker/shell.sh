#!/usr/bin/env bash
# コンテナ内の bash（.venv_teleop を有効にした状態）。調査や手作業用。
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_in_container shell "$@"
