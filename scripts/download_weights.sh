#!/bin/bash
# Download pretrained LC2 weights from GitHub Releases
#
# Usage:
#   bash scripts/download_weights.sh
#   bash scripts/download_weights.sh --tag v2.0.0
#   bash scripts/download_weights.sh --output-dir weights/

set -euo pipefail

REPO="alexjunholee/LC2_crossmatching"
TAG="v2.0.0"
WEIGHTS_DIR="pretrained"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            TAG="$2"
            shift 2
            ;;
        --output-dir)
            WEIGHTS_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: bash scripts/download_weights.sh [--tag TAG] [--output-dir DIR]"
            exit 1
            ;;
    esac
done

mkdir -p "$WEIGHTS_DIR"

WEIGHTS=(
    "lc2_kitti360_multi.pth.tar"
    "lc2_kitti360.pth.tar"
    "lc2_vivid.pth.tar"
    "lc2_helipr.pth.tar"
)

echo "Downloading LC2 pretrained weights from $REPO (tag: $TAG)..."

for w in "${WEIGHTS[@]}"; do
    if [[ -s "$WEIGHTS_DIR/$w" ]]; then
        echo "  Skipping $w (already exists)"
        continue
    fi
    echo "  Downloading $w..."
    remote_w="$w"
    if command -v gh &> /dev/null; then
        # Releases can assign the descriptive filename as the asset label.
        remote_w=$(gh release view "$TAG" -R "$REPO" --json assets \
            --jq ".assets[] | select(.name == \"$w\" or .label == \"$w\") | .name")
        if [[ -z "$remote_w" || "$remote_w" == *$'\n'* ]]; then
            echo "Error: no unique release asset named or labelled $w" >&2
            exit 1
        fi
        gh release download "$TAG" -R "$REPO" -p "$remote_w" -O "$WEIGHTS_DIR/$w.part" --clobber
    elif command -v curl &> /dev/null; then
        if [[ "$TAG" == "v2.0.0" && "$w" == "lc2_kitti360_multi.pth.tar" ]]; then
            remote_w="best.pth.tar"
        fi
        curl --fail --location --retry 3 "https://github.com/$REPO/releases/download/$TAG/$remote_w" -o "$WEIGHTS_DIR/$w.part"
    elif command -v wget &> /dev/null; then
        if [[ "$TAG" == "v2.0.0" && "$w" == "lc2_kitti360_multi.pth.tar" ]]; then
            remote_w="best.pth.tar"
        fi
        wget "https://github.com/$REPO/releases/download/$TAG/$remote_w" -O "$WEIGHTS_DIR/$w.part"
    else
        echo "Error: No download tool found. Install gh, curl, or wget."
        exit 1
    fi
    mv "$WEIGHTS_DIR/$w.part" "$WEIGHTS_DIR/$w"
done

echo ""
echo "Done! Weights saved to: $WEIGHTS_DIR/"
ls -lh "$WEIGHTS_DIR/"*.pth.tar 2>/dev/null
echo ""
echo "Recommended (multi-seq, R@1=91%):"
echo "  python eval_bidirectional.py --config configs/train_kitti360_multi.yaml \\"
echo "      --checkpoint $WEIGHTS_DIR/lc2_kitti360_multi.pth.tar --gem --sequences 0000 0009"
