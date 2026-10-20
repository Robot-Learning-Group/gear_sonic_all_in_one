#!/usr/bin/env bash
# MuJoCo シミュレーター（sim2sim の 1 つ目のターミナル）。引数は run_sim_loop.py にそのまま渡る。
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
run_in_container sim "$@"
