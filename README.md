# GEAR-SONIC all in one

[GR00T-WholeBodyControl](https://github.com/NVlabs/GR00T-WholeBodyControl)（GEAR-SONIC）の **sim2sim** と **Unitree G1 実機の PICO VR 全身テレオペ** を、Docker イメージ 1 つで動かすためのリポジトリ。
現時点でVLA（データ収集・GR00T の学習と推論）と SONIC の学習（Isaac Lab）は対象外。

イメージには次のものが入っている。ホストに必要なのは NVIDIA ドライバ、Docker、NVIDIA Container Toolkit だけである。

| 部品 | バージョン |
| --- | --- |
| ベースイメージ | `nvidia/cuda:12.8.1-devel-ubuntu24.04` |
| TensorRT | 10.13.3.9（公式指定の 10.13。違うバージョンは推論結果が狂い危険） |
| GR00T-WholeBodyControl | submodule で固定（`git submodule status` で確認） |
| モデル（Hugging Face `nvidia/GEAR-SONIC`） | [`docker/models.lock`](docker/models.lock) で固定 |
| Python 環境 | upstream の `install_pico.sh` で作る `.venv_teleop`（Python 3.10） |
| XRoboToolkit PC Service | 1.0.0（Ubuntu 24.04 版） |


## 1. 環境構築
```bash
git clone --recurse-submodules https://github.com/Robot-Learning-Group/gear_sonic_all_in_one.git
cd gear_sonic_all_in_one

# 初めてSONICを使用する場合のみ実行
# NVIDIA ドライバ 580（open）、Docker、NVIDIA Container Toolkit を入れる
# ドライバが入っていなければドライバだけ入れて終了するので、再起動してからもう一度実行する
# 最後にコンテナ内の `nvidia-smi` の結果（GPU 名とドライバのバージョン）が出れば完了
# docker グループに追加されたと表示された場合は、ログアウトして再ログインする
sudo bash scripts/install_host.sh

# イメージのビルド
cd docker
docker compose build
```

## 2. sim2sim（MuJoCo 上での動作確認）

実機の前に、必ずシミュレーションで操作に慣れること。ターミナルを 2 つ使い、どちらもリポジトリの直下で実行する。

**ターミナル 1：シミュレーター**

```bash
./docker/sim.sh
```

MuJoCo のウィンドウが開く。

**ターミナル 2：C++ デプロイ**

```bash
./docker/deploy.sh sim
```

`Proceed with deployment? [Y/n]` と聞かれたら Enter を押す。そのあと **`Init Done` と表示されるまで待ってから** キーを操作すること。それより前に押したキーは効かない。

> [!NOTE]
> 初回はモデルを TensorRT エンジン（`.trt`）に変換するため、`Init Done` までに時間がかかる。変換結果はリポジトリ直下の `.trt_cache/` に保存されるので、2 回目からはすぐに起動する。`--policy` で別のモデルに切り替えたときや、モデルを更新したときは、そのモデルの初回だけ同じ変換が走る。

**操作（ターミナル 2 のキーボード）**

1. `]` で制御ポリシーを開始する
2. MuJoCo のウィンドウをクリックし、`9` でロボットを地面に下ろす
3. ターミナル 2 に戻り、`T` で参照モーションを再生する
4. `N` / `P` で次 / 前のモーションに切り替え、`T` で再生する（`R` で先頭に戻す）
5. `O` で制御を止めて終了する（緊急停止もこのキー）

## 3. PICO の準備（初回のみ）

手順は upstream の [VR Teleop Setup](https://nvlabs.github.io/GR00T-WholeBodyControl/getting_started/vr_teleop_setup.html)（画像つき）の Step 1 と Step 3 の「PICO App」「Connect XRoboToolkit」をもとにしている。PC 側の XRoboToolkit PC Service はイメージに入っているので、ホストへの .deb のインストールは不要である。

必要なもの：PICO 4 / 4 Pro、コントローラ 2 本、モーショントラッカー 2 個（両足首）

### 3.1 本体の初期セットアップ（新品のとき）

1. 本体を充電し、コントローラに単 3 電池を入れる
2. 電源ボタンを長押しして起動し、ヘッドセットをかぶって画面の案内に従う。言語の選択、Wi-Fi への接続（PC と同じネットワーク）、コントローラのペアリング、PICO アカウントへのログインを済ませる
3. システム更新が出たら入れる
4. Developer を有効にする：設定の端末情報にある「ソフトウェアバージョン」を連続でタップし、設定の左メニューの一番下に **Developer** が出るようにする
5. Developer で **Safeguard** をオフにする

### 3.2 モーショントラッカー

1. トラッカーを両足首に 1 個ずつ、ランプのある面を上にして付ける
2. PICO のメニューの Wi-Fi アイコンを押し、ヘッドセットの絵の上にある小さな丸（Motion Tracker）を選ぶ。丸が出ない場合は Motion Tracker アプリを開く
3. 各トラッカーの「i」から登録済みのトラッカーをすべて解除し、右上の **Pair** を押す
4. 各トラッカーの上のボタンを 6 秒長押しする（赤と青に点滅すればペアリングモード）
5. **Calibrate** を押し、画面の案内に従う。コントローラを体の横に下ろしてまっすぐ立ち、次に足元のトラッカーを見下ろしてカメラに認識させる
6. キャリブレーション後は、ヘッドセットを額の位置にずらして付ける（前を向いたままトラッカーを捉え続けるため）

### 3.3 XRoboToolkit アプリ

1. PICO のブラウザで [XRoboToolkit-PICO-1.1.1.apk](https://github.com/XR-Robotics/XRoboToolkit-Unity-Client/releases/download/v1.1.1/XRoboToolkit-PICO-1.1.1.apk) をダウンロードし、ブラウザ右上のダウンロード一覧から開いてインストールする。アプリはライブラリの「Unknown」に入る
2. PICO と PC を同じ Wi-Fi（低遅延のプライベートルーター推奨）につなぐ
3. `./docker/teleop.sh` を起動した状態でアプリを開き、「PC Service:」の **Enter** から PC の Wi-Fi 側の IP を入力する。Status が **WORKING** になれば接続できている
4. Tracking の **Head** / **Controller**、Data/Control の **Send**、Pico Motion Tracker の **Full body** を選ぶ

## 4. テレオペ（シミュレーション）

ターミナルを 3 つ使う。

```bash
# ターミナル 1：シミュレーター
./docker/sim.sh

# ターミナル 2：C++ デプロイ（ZMQ 経由で PICO の姿勢を受け取る）
./docker/deploy.sh --input-type zmq_manager sim
# 「Init Done」が出るまで待つ（キー操作はそのあと）

# ターミナル 3：PICO テレオペ（初回は可視化つき推奨）
./docker/teleop.sh --vis_vr3pt --vis_smpl
```

ターミナル 3 で XRoboToolkit PC Service が自動で起動する。PICO のアプリで Status が **WORKING** になれば接続できている。

**最初の操作**

1. キャリブレーション姿勢をとる：直立して足をそろえ、上腕は体の横に下ろし、肘を 90° 前に曲げて手のひらを内側に向ける
2. **A+B+X+Y** でポリシーを開始する（同時に全身のキャリブレーション）
3. 腕をロボットの姿勢に合わせてから **A+X** で全身テレオペ（POSE モード）に入る
4. もう一度 **A+X** で PLANNER（待機）に戻る
5. **A+B+X+Y** で停止する

PLANNER モードでは左スティックで移動、右スティックで向きを変え、A+B / X+Y で歩行・走行・しゃがみなどの移動モードを切り替える。ボタンの全一覧は upstream の [PICO Controls](https://nvlabs.github.io/GR00T-WholeBodyControl/tutorials/vr_wholebody_teleop.html#complete-pico-controls) を参照のこと。

## 5. テレオペ（実機）

> [!CAUTION]
> シミュレーションで滑らかに操作でき、緊急停止に慣れてから進めること。周囲に安全な空間を確保し、キーボードの前に緊急停止係（`O` キー）を置く。PICO 側は **A+B+X+Y** で停止できる。足のトラッカーが隠れると危険な動きになるので、体にぴったりしたズボンを履くこと。POSE / VR_3PT に切り替える前は、必ず自分の姿勢をロボットの今の姿勢に合わせること。

1. `sim.sh` が動いていたら止める（シミュレーターと実機が同時に動くと衝突する）
2. PC の有線 NIC を G1 につなぎ、192.168.123.x のアドレスになっていることを `ip -br addr` で確認する
3. G1 をガントリーに吊り、リモコンで L2+R2 を長押しして開発者モードにする
4. ターミナル 1 とターミナル 2 で起動する

```bash
# ターミナル 1：C++ デプロイ（real は 192.168.123.x の NIC を自動で選ぶ）
./docker/deploy.sh --input-type zmq_manager real
# 「Init Done」が出るまで待つ（キー操作はそのあと）

# ターミナル 2：PICO テレオペ
./docker/teleop.sh
```

5. ガントリーでロボットを少しゆるめた状態で、シミュレーションと同じ手順（キャリブレーション姿勢 → A+B+X+Y → A+X）で始める

## 6. モデルの切り替え

`deploy.sh` に `--policy` を付けると、使うモデルを切り替えられる。

| `--policy` | モデル | 用途 |
| --- | --- | --- |
| `release`（既定） | 既定の SONIC | 汎用。モーション追従、プランナー、テレオペ |
| `low_latency` | 低遅延テレオペ用 | 参照の先読みが約 80 ms と短く、テレオペの反応がよい |
| `sonic_v1_1` | SONIC v1.1 | ロボットの向きで正規化。向きが安定した全身テレオペ向け |

```bash
./docker/deploy.sh --policy low_latency --input-type zmq_manager real
```

## 7. トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| ウィンドウが出ない | デスクトップのターミナルから実行する（`DISPLAY` と `XAUTHORITY` が必要）。SSH 越しでは出ない |
| PICO の Status が WORKING にならない | PC と PICO が同じ Wi-Fi か、アプリに入れた IP が PC の Wi-Fi 側の IP かを確認する。ホストに XRoboToolkit PC Service を別に入れて動かしている場合は止める（ポートが衝突する） |
| `real` で違う NIC が選ばれる | `./docker/deploy.sh --input-type zmq_manager <NIC 名>` で直接指定する |
| ロボットがよろける、遅延の警告が出る | Wi-Fi の遅延を疑う。プライベートルーターを使い、PICO と PC を同じネットワークに置く |
