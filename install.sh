#!/usr/bin/env bash
# ========================================================
#   FPV Stretcher - One-Click Installer for macOS & Linux
# ========================================================

set -e

echo "========================================================"
echo "   FPV Stretcher - Installer for macOS & Linux"
echo "========================================================"
echo ""

if [[ "$OSTYPE" == "darwin"* ]]; then
    FUSION_DIR="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion"
else
    FUSION_DIR="$HOME/.local/share/DaVinciResolve/Fusion"
fi

if [ ! -d "$FUSION_DIR" ]; then
    echo "[INFO] Creating Fusion directories at $FUSION_DIR..."
    mkdir -p "$FUSION_DIR"
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$FUSION_DIR/Fuses"
mkdir -p "$FUSION_DIR/Templates"

echo "[1/2] Installing FPV_Stretcher.fuse..."
cp -f "$SCRIPT_DIR/FPV_Stretcher.fuse" "$FUSION_DIR/Fuses/FPV_Stretcher.fuse"
echo "      -> Copied to $FUSION_DIR/Fuses/FPV_Stretcher.fuse"

echo "[2/2] Installing FPV_Stretcher.drfx..."
cp -f "$SCRIPT_DIR/FPV_Stretcher.drfx" "$FUSION_DIR/Templates/FPV_Stretcher.drfx"
echo "      -> Copied to $FUSION_DIR/Templates/FPV_Stretcher.drfx"

echo ""
echo "========================================================"
echo "  Installation Successful!"
echo "========================================================"
echo "Please restart DaVinci Resolve to begin using FPV Stretcher."
echo ""
