#!/usr/bin/env bash
# 下载 icefall 流式 zipformer 中文模型（WenetSpeech，官方 demo APK 同款）到 assets/models/
set -euo pipefail

MODEL="icefall-asr-zipformer-streaming-wenetspeech-20230615"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${MODEL}.tar.bz2"

dest="$(pwd)/assets/models"
if [ -f "$dest/tokens.txt" ] && [ -n "$(find "$dest" -name 'encoder*.onnx' -print -quit 2>/dev/null)" ]; then
  echo "model already present, skip"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading $URL"
curl -L --retry 3 --silent --show-error -o "$tmp/model.tar.bz2" "$URL"

mkdir -p "$tmp/x"
tar -xjf "$tmp/model.tar.bz2" -C "$tmp/x"

# 弹性定位四个文件（兼容不同打包布局），统一改成固定文件名
tokens=$(find "$tmp/x" -name 'tokens.txt' | head -1)
enc=$(find "$tmp/x" -name 'encoder*.onnx' | grep -i int8 | head -1)
[ -z "$enc" ] && enc=$(find "$tmp/x" -name 'encoder*.onnx' | head -1)
dec=$(find "$tmp/x" -name 'decoder*.onnx' | grep -iv int8 | head -1)
[ -z "$dec" ] && dec=$(find "$tmp/x" -name 'decoder*.onnx' | head -1)
joi=$(find "$tmp/x" -name 'joiner*.onnx' | grep -iv int8 | head -1)
[ -z "$joi" ] && joi=$(find "$tmp/x" -name 'joiner*.onnx' | head -1)

for f in "$tokens" "$enc" "$dec" "$joi"; do
  [ -n "$f" ] || { echo "ERROR: model file not found" >&2; find "$tmp/x" -name '*.onnx' >&2; exit 1; }
done

mkdir -p "$dest"
rm -f "$dest"/*.onnx "$dest"/tokens.txt
cp "$tokens" "$dest/tokens.txt"
cp "$enc" "$dest/encoder.int8.onnx"
cp "$dec" "$dest/decoder.onnx"
cp "$joi" "$dest/joiner.onnx"

echo "model files:"
ls -la "$dest"
