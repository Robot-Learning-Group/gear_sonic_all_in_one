# syntax=docker/dockerfile:1
# GEAR-SONIC（GR00T-WholeBodyControl）の sim2sim と PICO テレオペを 1 つのイメージで動かす。
# RTX PRO 6000 Blackwell（sm_120）で動かすため、CUDA 12.8 以上のベースを使う。
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Tokyo \
    LANG=C.UTF-8 \
    NVIDIA_DRIVER_CAPABILITIES=all \
    UV_LINK_MODE=copy \
    PATH=/root/.local/bin:$PATH

# 基本ツールと GUI（MuJoCo ビューア、PyVista）・XRoboToolkit PC Service が使う共有ライブラリ
RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo ca-certificates curl wget git git-lfs lsb-release iproute2 tzdata \
      libgl1 libegl1 libglu1-mesa libglib2.0-0 libx11-6 libxext6 libxrender1 libxrandr2 \
      libxinerama1 libxcursor1 libxi6 libxkbcommon-x11-0 libxt6 libsm6 \
      libicu74 libdouble-conversion3 libb2-1 libpcre2-16-0 libproxy1v5 \
      libgssapi-krb5-2 libbrotli1 libzstd1 \
    && rm -rf /var/lib/apt/lists/*

# TensorRT 10.13（公式が x86_64 に指定しているバージョン。違うバージョンは推論結果が狂う）
# 約 7 GB あるので、BuildKit のキャッシュに置いて再ビルド時のダウンロードを省く。
ARG TENSORRT_VERSION=10.13.3.9
ARG TENSORRT_URL=https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.13.3/tars/TensorRT-10.13.3.9.Linux.x86_64-gnu.cuda-12.9.tar.gz
RUN --mount=type=cache,target=/var/cache/tensorrt <<'BASH'
set -euo pipefail
archive=/var/cache/tensorrt/$(basename "$TENSORRT_URL")
if [[ ! -f $archive ]]; then
    curl -fL --retry 3 -o "$archive.part" "$TENSORRT_URL"
    mv "$archive.part" "$archive"
fi
tar -xzf "$archive" -C /opt
mv "/opt/TensorRT-${TENSORRT_VERSION}" /opt/TensorRT
rm -rf /opt/TensorRT/{data,doc,python,samples} /opt/TensorRT/lib/*.a
BASH
ENV TensorRT_ROOT=/opt/TensorRT \
    LD_LIBRARY_PATH=/opt/TensorRT/lib:/opt/onnxruntime/lib

# XRoboToolkit PC Service（PICO から姿勢を受け取るサービス）。
# postinst はデスクトップ連携だけなので、dpkg -x で展開のみ行う。
ARG XRT_SERVICE_URL=https://github.com/XR-Robotics/XRoboToolkit-PC-Service/releases/download/v1.0.0/XRoboToolkit_PC_Service_1.0.0_ubuntu_24.04_amd64.deb
RUN curl -fsSL -o /tmp/xrt.deb "$XRT_SERVICE_URL" && \
    dpkg -x /tmp/xrt.deb / && \
    rm -rf /tmp/xrt.deb /opt/apps/roboticsservice/SDKDemo

# uv（Python 環境の管理。upstream の install スクリプトが使う）
ARG UV_VERSION=0.13.1
RUN curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | sh

WORKDIR /workspace/GR00T-WholeBodyControl

# C++ デプロイの依存（ONNX Runtime、just、cppzmq など）は upstream のスクリプトで入れる。
# スクリプトは自分の位置を基準に third_party/ を作るので、同じパスに置いて実行する。
COPY GR00T-WholeBodyControl/gear_sonic_deploy/scripts/install_deps.sh gear_sonic_deploy/scripts/install_deps.sh
RUN bash gear_sonic_deploy/scripts/install_deps.sh && rm -rf /var/lib/apt/lists/*

COPY GR00T-WholeBodyControl/ ./

# Python 環境（.venv_teleop）。sim の extra も含むので、シミュレーターもこの venv で動く。
RUN --mount=type=cache,target=/root/.cache/uv bash install_scripts/install_pico.sh

# 配備用モデル。docker/models.lock で Hugging Face のリビジョンを固定する。
COPY docker/models.lock docker/fetch_models.py /opt/gear_sonic_aio/
RUN --mount=type=cache,target=/root/.cache \
    uv run --no-project --with huggingface_hub==1.33.0 \
      python /opt/gear_sonic_aio/fetch_models.py /opt/gear_sonic_aio/models.lock gear_sonic_deploy

# TensorRT エンジン（.trt）はホストの .trt_cache/ に保存し、次回の起動から再利用する。
# C++ 側は ONNX の隣に .trt を探すので、その位置にキャッシュへのシンボリックリンクを置く。
# ONNX や GPU が変わったときは .trt 内のハッシュで C++ 側が検出して作り直すので、
# ここでは TensorRT のバージョンごとに置き場所を分けるだけでよい。
RUN cd gear_sonic_deploy && \
    cache=/cache/trt/${TENSORRT_VERSION} && \
    for v in release low_latency sonic_v1_1; do \
      ln -s "$cache/policy/$v/policy_model_decoder.trt" "policy/$v/policy_model_decoder.trt" && \
      ln -s "$cache/policy/$v/encoder_model_encoder.trt" "policy/$v/encoder_model_encoder.trt"; \
    done && \
    ln -s "$cache/planner/planner_planner_sonic.trt" planner/target_vel/V2/planner_planner_sonic.trt

# C++ デプロイスタックのビルド（deploy.sh は起動のたびに just build を呼ぶが、差分がなければすぐ終わる）
RUN cd gear_sonic_deploy && \
    set +eu && source scripts/setup_env.sh && set -eu && \
    just build

COPY docker/entrypoint.sh /usr/local/bin/gear-sonic
ENTRYPOINT ["/usr/local/bin/gear-sonic"]
CMD ["shell"]
