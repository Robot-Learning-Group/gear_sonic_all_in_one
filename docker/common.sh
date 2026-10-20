# 起動スクリプト共通の処理。source して使う。
# shellcheck shell=bash

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# コンテナ内のコマンドを 1 つ実行する。GUI を出せるよう X11 を渡す。
run_in_container() {
    local xauthority=${XAUTHORITY:-$HOME/.Xauthority}
    local x11_args=()
    if [[ -n ${DISPLAY:-} && -r $xauthority ]]; then
        x11_args=(
            -e DISPLAY="$DISPLAY"
            -e XAUTHORITY=/tmp/.gear_sonic.Xauthority
            -v /tmp/.X11-unix:/tmp/.X11-unix:ro
            -v "$xauthority:/tmp/.gear_sonic.Xauthority:ro"
        )
    else
        echo "[WARN] DISPLAY か XAUTHORITY がないため、GUI は表示されません。デスクトップのターミナルから実行してください。" >&2
    fi
    # Docker に作らせると root の持ち物になるので、先にホストのユーザーで作っておく
    mkdir -p ../.trt_cache
    exec docker compose run --rm -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
        "${x11_args[@]}" gear-sonic "$@"
}
