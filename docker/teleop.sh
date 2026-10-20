#!/usr/bin/env bash
# PICO テレオペ。XRoboToolkit PC Service を起動してから pico_manager_thread_server.py --manager を動かす。
# 引数はそのまま渡る（例: --vis_vr3pt --vis_smpl で可視化ウィンドウを出す）。
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_in_container teleop "$@"
