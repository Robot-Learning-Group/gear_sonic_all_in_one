#!/usr/bin/env bash
# コンテナ内のコマンド。docker/ の起動スクリプトから呼ばれる。
#   sim     MuJoCo シミュレーター（run_sim_loop.py）
#   deploy  C++ デプロイスタック（deploy.sh）。--policy で使うモデルを選べる
#   teleop  PICO テレオペ（pico_manager_thread_server.py）。XRoboToolkit PC Service も起動する
#   shell   bash
set -euo pipefail

REPO=/workspace/GR00T-WholeBodyControl
XRT_DIR=/opt/apps/roboticsservice

command=${1:-shell}
if (($#)); then shift; fi

# 使うモデルを --policy で選び、deploy.sh の --cp / --obs-config に変換する
policy_args() {
    case "$1" in
        release|low_latency|sonic_v1_1)
            echo "--cp policy/$1/model --obs-config policy/$1/observation_config.yaml"
            ;;
        *)
            echo "未対応の --policy: $1（release / low_latency / sonic_v1_1）" >&2
            exit 2
            ;;
    esac
}

# コンテナは毎回新しく作るので、サービスがすでに動いていることはない
start_xrt_service() {
    echo "[INFO] XRoboToolkit PC Service を起動します（ログ: /tmp/xrt_service.log）"
    (
        cd "$XRT_DIR"
        export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:$XRT_DIR:$XRT_DIR/lib:$XRT_DIR/SDK/x64"
        export QT_PLUGIN_PATH="$XRT_DIR/plugins/"
        exec ./RoboticsServiceProcess
    ) >/tmp/xrt_service.log 2>&1 &
    local pid=$!
    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "[ERROR] XRoboToolkit PC Service が起動しませんでした。/tmp/xrt_service.log:" >&2
        cat /tmp/xrt_service.log >&2
        exit 1
    fi
}

case "$command" in
    sim)
        source "$REPO/.venv_teleop/bin/activate"
        cd "$REPO"
        exec python gear_sonic/scripts/run_sim_loop.py "$@"
        ;;
    deploy)
        args=()
        while (($#)); do
            case "$1" in
                --policy)
                    read -ra extra <<<"$(policy_args "${2:-}")"
                    args+=("${extra[@]}")
                    shift 2
                    ;;
                --policy=*)
                    read -ra extra <<<"$(policy_args "${1#--policy=}")"
                    args+=("${extra[@]}")
                    shift
                    ;;
                *)
                    args+=("$1")
                    shift
                    ;;
            esac
        done
        cd "$REPO/gear_sonic_deploy"
        # .trt のシンボリックリンク先（ホストの .trt_cache/）にディレクトリを用意する
        find . -lname '/cache/trt/*' -exec sh -c 'mkdir -p "$(dirname "$(readlink "$1")")"' _ {} \;
        # コンテナは root で動くので、キャッシュをホストのユーザーの持ち物に戻す。
        # 強制終了で終了時の chown が走らなかった場合に備えて、起動時にも行う。
        # HOST_UID / HOST_GID は起動スクリプトが渡す。直接 docker compose で起動した場合はキャッシュの持ち主に合わせる
        cache_owner="${HOST_UID:-$(stat -c %u /cache/trt)}:${HOST_GID:-$(stat -c %g /cache/trt)}"
        chown -R "$cache_owner" /cache/trt
        status=0
        ./deploy.sh "${args[@]}" || status=$?
        chown -R "$cache_owner" /cache/trt
        exit "$status"
        ;;
    teleop)
        # IsaacTeleop（CloudXR）を使うときは XRoboToolkit のサービスは要らない
        if [[ " $* " != *" --input-source isaac-teleop "* && " $* " != *" --input-source=isaac-teleop "* ]]; then
            start_xrt_service
        fi
        source "$REPO/.venv_teleop/bin/activate"
        cd "$REPO"
        exec python gear_sonic/scripts/pico_manager_thread_server.py --manager "$@"
        ;;
    shell)
        source "$REPO/.venv_teleop/bin/activate"
        cd "$REPO"
        exec bash "$@"
        ;;
    *)
        exec "$command" "$@"
        ;;
esac
