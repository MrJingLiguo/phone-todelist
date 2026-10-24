#!/usr/bin/env bash
# 下载 sherpa-onnx 流式中英双语小模型（int8）到 assets/models/
set -euo pipefail

MODEL="sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${MODEL}.tar.bz2"

dest="$(pwd)/assets/models"
if [ -f "$dest/tokens.txt" ] && [ -n "$(find "$dest" -name 'encoder*.int8.onnx' -print -quit 2>/dev/null)" ]; then
  echo "model already present, skip"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading $URL"
curl -L --retry 3 --silent --show-error -o "$tmp/model.tar.bz2" "$URL"

mkdir -p "$tmp/x"
tar -xjf "$tmp/model.tar.bz2" -C "$tmp/x"

src="$(find "$tmp/x" -type d -name "$MODEL" | head -1)"
if [ -z "$src" ]; then
  echo "ERROR: model dir not found in archive" >&2
  find "$tmp/x" -maxdepth 2 >&2
  exit 1
fi

mkdir -p "$dest"
for stem in encoder decoder joiner; do
  # 该模型 int8 文件命名为 *.int8.onnx（点分，非 -int8.onnx）
  f="$src/${stem}-epoch-99-avg-1.int8.onnx"
  [ -f "$f" ] || f="$src/${stem}-epoch-99-avg-1-int8.onnx"
  [ -f "$f" ] || { echo "ERROR: ${stem} int8 onnx not found" >&2; ls "$src" >&2; exit 1; }
  cp "$f" "$dest/${stem}-epoch-99-avg-1.int8.onnx"
done
cp "$src/tokens.txt" "$dest/"

echo "model files:"
ls -la "$dest"
