"""models.lock に従って nvidia/GEAR-SONIC から配備用モデルを取得する。"""

import argparse
import shutil
from pathlib import Path

from huggingface_hub import hf_hub_download

REPO_ID = "nvidia/GEAR-SONIC"


def read_lock(path):
    revision = None
    files = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        remote, local = line.split()
        if remote == "revision":
            revision = local
        else:
            files.append((remote, local))
    if revision is None:
        raise SystemExit(f"{path}: revision がありません")
    return revision, files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lock", type=Path, help="models.lock のパス")
    parser.add_argument("dest", type=Path, help="配置先（gear_sonic_deploy/）")
    args = parser.parse_args()

    revision, files = read_lock(args.lock)
    for remote, local in files:
        target = args.dest / local
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(hf_hub_download(REPO_ID, remote, revision=revision), target)
        print(f"{remote} -> {target}")


if __name__ == "__main__":
    main()
