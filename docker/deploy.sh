#!/usr/bin/env bash
# C++ デプロイスタック。引数は upstream の deploy.sh にそのまま渡る。
#   ./docker/deploy.sh sim                                  # sim2sim（キーボード操作）
#   ./docker/deploy.sh --input-type zmq_manager sim         # sim でテレオペ
#   ./docker/deploy.sh --input-type zmq_manager real        # 実機でテレオペ
#   --policy release|low_latency|sonic_v1_1 で使うモデルを切り替える（既定: release）
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_in_container deploy "$@"
