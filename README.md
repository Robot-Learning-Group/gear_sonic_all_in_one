# GEAR-SONIC all in one

[GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl)（GEAR-SONIC）で Unitree G1 の **PICO VR 全身テレオペ**（MuJoCo シミュレーションと実機）を、Docker イメージ 1 つで動かすためのリポジトリ。
現時点でVLA（データ収集・GR00T の学習と推論）と SONIC の学習（Isaac Lab）は対象外。

ホストに必要なのは NVIDIA ドライバ、Docker、NVIDIA Container Toolkit だけである。それ以外はすべてイメージに入っている（中身は [付録 E](#付録-e-イメージの中身と更新のしかた)）。

## 1. 環境構築

`install_host.sh` は PC ごとに 1 回でよく、準備済みの PC では飛ばしてよい。ドライバを入れたところで止まるので、再起動して再実行する。「docker グループに追加」と出たら再ログインする。

```bash
sudo apt update && sudo apt install -y git git-lfs && git lfs install
git clone --recurse-submodules https://github.com/Robot-Learning-Group/gear_sonic_all_in_one.git
cd gear_sonic_all_in_one

# PC ごとに 1 回（ドライバ・Docker・NVIDIA Container Toolkit）
sudo bash scripts/install_host.sh 

# イメージのビルド
cd docker
docker compose build
```

## 2. テレオペ（シミュレーション）

初めてSONICをテレオペするPICOを使う場合には、先に [付録 B. PICO の準備](#付録-b-pico-の準備初回のみ) を済ませること。

ターミナルを 3 つ使い、どれもリポジトリの直下で実行する。

**ターミナル 1：シミュレータ**
以下を実行してシミュレータが起動した後に、シミュレータにマウスカーソルの焦点を合わせた（すなわちシミュレータのウィンドウを左クリック）状態で9を押下し、吊り下げを解除する。
```bash
./docker/sim.sh
```

**ターミナル 2：C++ デプロイ**

以下を実行すると、`Proceed with deployment? [Y/n]` が出るので、Enter を押し、**`Init Done` が出るまで待つ**。初回はモデルを TensorRT エンジンに変換するので時間がかかる。

```bash
./docker/deploy.sh --policy sonic_v1_1 --input-type zmq_manager sim
```

**ターミナル 3：PICO テレオペ**

以下を実行した後に、PICOのXRoboToolkitと接続する（[B.3 XRoboToolkit アプリ](#b3-xrobotoolkit-アプリ)の通り）。Status が **WORKING** になれば接続できている。

```bash
./docker/teleop.sh
```

**最初の操作**

1. キャリブレーション姿勢をとる。直立して足をそろえ、上腕は体の横に下ろし、肘を 90° 前に曲げて手のひらを内側に向ける
2. **A+B+X+Y** でポリシーを開始する
3. 腕をロボットの姿勢に合わせてから **A+X** で全身テレオペ（POSE モード）に入る
4. もう一度 **A+X** で PLANNER（待機）に戻る
5. もう一度 **A+X** を実行すると全身テレオペ（POSE モード）に入る
6. **A+B+X+Y** で終了する

PLANNER モードでは左スティックで移動、右スティックで向きを変え、A+B / X+Y で歩行・走行・しゃがみなどの移動モードを切り替える。ボタンの全一覧は[PICO Controls](https://nvlabs.github.io/GR00T-WholeBodyControl/tutorials/vr_wholebody_teleop.html#complete-pico-controls) を参照のこと。

## 3. テレオペ（実機）

> [!CAUTION]
> 実機の前に、2. のシミュレーションでテレオペの操作と緊急停止に慣れておくこと。周囲に安全な空間を確保し、キーボードの前に緊急停止係（`O` キー）を置く。PICO 側は **A+B+X+Y** で停止できる。足のトラッカーが隠れると危険な動きになるので、体にぴったりしたズボンを履くこと。POSEモードに切り替える前は、必ず自分の姿勢をロボットの今の姿勢に合わせること。


G1のリモコンで L2+R2 を長押ししてDevelopmentモードにしてから、2つのターミナルで起動する

**ターミナル 1：C++ デプロイ**

`real` は 192.168.123.x の NIC を自動で選ぶ。**`Init Done` が出るまで待ってから**操作する。

```bash
./docker/deploy.sh --policy sonic_v1_1 --input-type zmq_manager real
```

**ターミナル 2：PICO テレオペ**

```bash
./docker/teleop.sh
```

シミュレーションと同じ手順（キャリブレーション姿勢 → A+B+X+Y → A+X）で状態遷移してテレオペが実行できる。

## 付録 A. モデルの切り替え

`deploy.sh` に `--policy` を付けると、使うモデルを切り替えられる。

| `--policy` | モデル | 用途 |
| --- | --- | --- |
| `release`（既定） | 既定の SONIC | 汎用。モーション追従、プランナー、テレオペ |
| `low_latency` | 低遅延テレオペ用 | 参照の先読みが約 80 ms と短く、テレオペの反応がよい |
| `sonic_v1_1` | SONIC v1.1 | ロボットの向きで正規化。向きが安定した全身テレオペ向け |

```bash
./docker/deploy.sh --policy low_latency --input-type zmq_manager real
```

## 付録 B. PICO の準備（初回のみ）

手順は[VR Teleop Setup](https://nvlabs.github.io/GR00T-WholeBodyControl/getting_started/vr_teleop_setup.html)（画像つき）の Step 1 と Step 3 の「PICO App」「Connect XRoboToolkit」である。詳細はそちらを参照されたい。

必要なもの：PICO 4 / 4 Pro、コントローラ 2 本、モーショントラッカー 2 個（両足首）

### B.1 本体の初期セットアップ（新品のとき）

1. 本体を充電し、コントローラに単 3 電池を入れる
2. 電源ボタンを長押しして起動し、ヘッドセットをかぶって画面の案内に従う。言語の選択、Wi-Fi への接続（PC と同じネットワーク）、コントローラのペアリング、PICO アカウントへのログインを済ませる
3. システム更新が出たら入れる
4. Developer を有効にする：設定の端末情報にある「ソフトウェアバージョン」を連続でタップし、設定の左メニューの一番下に **Developer** が出るようにする
5. Developer で **Safeguard** をオフにする

### B.2 モーショントラッカー

1. トラッカーを両足首に 1 個ずつ、ランプのある面を上にして付ける
2. PICO のメニューの Wi-Fi アイコンを押し、ヘッドセットの絵の上にある小さな丸（Motion Tracker）を選ぶ。丸が出ない場合は Motion Tracker アプリを開く
3. 各トラッカーの「i」から登録済みのトラッカーをすべて解除し、右上の **Pair** を押す
4. 各トラッカーの上のボタンを 6 秒長押しする（赤と青に点滅すればペアリングモード）
5. **Calibrate** を押し、画面の案内に従う。コントローラを体の横に下ろしてまっすぐ立ち、次に足元のトラッカーを見下ろしてカメラに認識させる
6. キャリブレーション後は、ヘッドセットを額の位置にずらして付ける（前を向いたままトラッカーを捉え続けるため）

### B.3 XRoboToolkit アプリ

1. PICO のブラウザで [XRoboToolkit-PICO-1.1.1.apk](https://github.com/XR-Robotics/XRoboToolkit-Unity-Client/releases/download/v1.1.1/XRoboToolkit-PICO-1.1.1.apk) をダウンロードし、ブラウザ右上のダウンロード一覧から開いてインストールする。アプリはライブラリの「Unknown」に入る
2. PICO と PC を同じ Wi-Fi（低遅延のプライベートルーター推奨）につなぐ
3. `./docker/teleop.sh` を起動した状態でアプリを開き、「PC Service:」の **Enter** から PC の Wi-Fi 側の IP を入力する。Status が **WORKING** になれば接続できている
4. Tracking の **Head** / **Controller**、Data/Control の **Send**、Pico Motion Tracker の **Full body** を選ぶ

## 付録 C. sim2sim（キーボードでの動作確認、任意）

PICO を使わずに、シミュレーターと C++ デプロイだけを動かす。テレオペがうまく動かないとき、原因が PICO 側かデプロイ側かを切り分けるのに使う。

**ターミナル 1：シミュレーター**

```bash
./docker/sim.sh
```

**ターミナル 2：C++ デプロイ**

**`Init Done` が出るまで待ってから**、下のキーで操作する。

```bash
./docker/deploy.sh --policy sonic_v1_1 sim
```

**操作（ターミナル 2 のキーボード）**

1. `]` で制御ポリシーを開始する
2. MuJoCo のウィンドウをクリックし、`9` でロボットを地面に下ろす
3. ターミナル 2 に戻り、`T` で参照モーションを再生する
4. `N` / `P` で次 / 前のモーションに切り替え、`T` で再生する（`R` で先頭に戻す）
5. `O` で制御を止めて終了する（緊急停止もこのキー）

## 付録 D. トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| ウィンドウが出ない | デスクトップのターミナルから実行する（`DISPLAY` と `XAUTHORITY` が必要）。SSH 越しでは出ない |
| PICO の Status が WORKING にならない | PC と PICO が同じ Wi-Fi か、アプリに入れた IP が PC の Wi-Fi 側の IP かを確認する。ホストに XRoboToolkit PC Service を別に入れて動かしている場合は止める（ポートが衝突する） |
| `real` で違う NIC が選ばれる | `./docker/deploy.sh --input-type zmq_manager <NIC 名>` で直接指定する |
| ロボットがよろける、遅延の警告が出る | Wi-Fi の遅延を疑う。プライベートルーターを使い、PICO と PC を同じネットワークに置く |
| テレオペで動かない（PICO 側かデプロイ側かわからない） | 付録 C の sim2sim で、PICO なしでデプロイが動くか確かめる |

## 付録 E. イメージの中身と更新のしかた

| 部品 | バージョン | 固定している場所 |
| --- | --- | --- |
| ベースイメージ | `nvidia/cuda:12.8.1-devel-ubuntu24.04`（Blackwell には CUDA 12.8 以上が必要） | `docker/Dockerfile` |
| TensorRT | 10.13.3.9 | `docker/Dockerfile`（`TENSORRT_VERSION` / `TENSORRT_URL`） |
| GR00T-WholeBodyControl | submodule のコミット（`git submodule status` で確認） | `GR00T-WholeBodyControl/` |
| モデル（Hugging Face `nvidia/GEAR-SONIC`） | リビジョン | [`docker/models.lock`](docker/models.lock) |
| Python 環境 | upstream の `install_pico.sh` で作る `.venv_teleop`（Python 3.10） | submodule に従う |
| XRoboToolkit PC Service | 1.0.0（Ubuntu 24.04 版） | `docker/Dockerfile`（`XRT_SERVICE_URL`） |

> [!WARNING]
> TensorRT は upstream が x86_64 に指定している 10.13 から変えないこと。違うバージョンでは推論結果が狂い、ロボットが危険な動きをするおそれがある。

**upstream を更新する**

```bash
cd GR00T-WholeBodyControl
git fetch && git checkout <コミット>
git lfs pull
cd ..
git add GR00T-WholeBodyControl && git commit
cd docker && docker compose build
```

upstream の更新で TensorRT の指定バージョンや install スクリプトが変わっていないか、[Installation (Deployment)](https://nvlabs.github.io/GR00T-WholeBodyControl/getting_started/installation_deploy.html) で確認すること。

**モデルを更新する**

`docker/models.lock` の `revision` を新しいリビジョンに差し替え、イメージを再ビルドする。リビジョンは `https://huggingface.co/api/models/nvidia/GEAR-SONIC` の `sha` で確認できる。
