#!/usr/bin/env bash
# ホスト PC の準備（初回のみ）。NVIDIA ドライバ 580（open）、Docker、NVIDIA Container Toolkit を入れる。
# CUDA Toolkit や TensorRT はコンテナに入っているので、ホストには入れない。
#
#   sudo bash scripts/install_host.sh
#
# ドライバが入っていない場合はドライバだけ入れて終了する。再起動してからもう一度実行する。
set -euo pipefail

info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "sudo bash $0 で実行してください。"

. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID =~ ^(22\.04|24\.04)$ && $(dpkg --print-architecture) == amd64 ]] \
    || fail "Ubuntu 22.04 / 24.04 の x86_64 が対象です（検出: $PRETTY_NAME $(dpkg --print-architecture)）。"

target_user=${SUDO_USER:-}
[[ -n $target_user && $target_user != root ]] || fail "一般ユーザーから sudo で実行してください。"

info "基本ツールを入れます"
apt-get update
apt-get install -y ca-certificates curl gnupg git git-lfs
sudo -u "$target_user" git lfs install

# ── 1. NVIDIA ドライバ ──────────────────────────────────────────────
if ! nvidia-smi >/dev/null 2>&1; then
    info "NVIDIA ドライバ 580（open）を入れます"
    apt-get install -y nvidia-driver-580-open
    ok "ドライバを入れました。再起動してから、もう一度 sudo bash $0 を実行してください。"
    exit 0
fi
ok "NVIDIA ドライバ: $(nvidia-smi --query-gpu=driver_version,name --format=csv,noheader)"

# ── 2. Docker ───────────────────────────────────────────────────────
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
    info "Docker を入れます"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
ok "$(docker --version) / $(docker compose version)"

# ── 3. NVIDIA Container Toolkit ─────────────────────────────────────
if ! command -v nvidia-ctk >/dev/null; then
    info "NVIDIA Container Toolkit を入れます"
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y nvidia-container-toolkit
fi
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
ok "$(nvidia-ctk --version | head -1)"

# ── 4. docker グループ ──────────────────────────────────────────────
if ! id -nG "$target_user" | grep -qw docker; then
    usermod -aG docker "$target_user"
    info "$target_user を docker グループに追加しました。ログアウトして再ログインしてください。"
fi

info "GPU がコンテナから見えるか確認します"
docker run --rm --gpus all nvidia/cuda:12.8.1-base-ubuntu24.04 nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
ok "ホストの準備が終わりました。"
