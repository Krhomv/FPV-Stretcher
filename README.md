# 🎬 FPV Stretcher for DaVinci Resolve

[![DaVinci Resolve](https://img.shields.io/badge/DaVinci_Resolve-17%20%7C%2018%20%7C%2019-blue?logo=blackmagicdesign&logoColor=white)](https://www.blackmagicdesign.com/products/davinciresolve)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Format: DRFX](https://img.shields.io/badge/Package-DRFX%20%2F%20Fuse-green.svg)](#installation)

**FPV Stretcher** is a GPU-accelerated aspect ratio converter plugin for DaVinci Resolve (Fusion & Edit pages), inspired by GoPro's **SuperView**. 

It converts **4:3 footage into 16:9 widescreen** using a smooth $C^\infty$-continuous non-linear horizontal stretch. The central subject maintains natural, 1:1 round proportions while the stretch accelerates progressively toward the outer peripheral edges — completely avoiding the flat, squished look of standard linear stretches.

Designed for FPV drones, action cameras (GoPro, DJI, Insta360, Walksnail, HDZero, analog), and retro 4:3 video sources.

---

## ✨ Features

- **Smooth Non-Linear Stretch**: $C^\infty$-continuous polynomial stretching curve with zero abrupt seams.
- **Center Geometry Protection**: Keeps subjects, horizons, and vehicles in the center completely undistorted.
- **Fisheye / Barrel Distortion Correction**: Corrects ultra-wide FPV action-cam barrel distortion with automatic zoom-out compensation to preserve 100% of your FOV.
- **Smart Framing**: Proportional vertical crop/zoom with vertical offset/tilt shifting.
- **Sub-Pixel Filtering**: 16-tap Catmull-Rom bicubic reconstruction filter for ultra-sharp rendering.
- **Edge Detail Boost**: Micro-contrast enhancement algorithm that restores high-frequency texture softened by horizontal expansion.
- **Zero Pre-Scaling Required**: Works directly on standard 4:3 clips in Fusion or via Adjustment Clips on 16:9 Edit timelines without pre-scaling degradation.
- **All-In-One Distribution**: Packaged as a standard `.drfx` bundle for one-click installation across both Edit and Fusion pages.

---

## 📦 Installation

### Option 1: One-Click Installer (Recommended)
1. Download or locate [`FPV_Stretcher.drfx`](FPV_Stretcher.drfx).
2. Double-click the `.drfx` file.
3. DaVinci Resolve will prompt: **"Install FPV Stretcher?"** → Click **Install**.
4. Restart DaVinci Resolve.

### Option 2: Automated Script
Run the included python script to build and install to your local Resolve directory:
```bash
python install.py
```

### Option 3: Manual Installation
- Copy `FPV_Stretcher.fuse` to:
  - **Windows**: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Fuses\`
  - **macOS**: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Fuses/`
  - **Linux**: `~/.local/share/DaVinciResolve/Fusion/Fuses/`
- Copy `FPV_Stretcher.drfx` to:
  - **Windows**: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\`
  - **macOS**: `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Templates/`
  - **Linux**: `~/.local/share/DaVinciResolve/Fusion/Templates/`
- Restart DaVinci Resolve.

---

## 🚀 How to Use

### 🎬 Workflow A: Edit Page (via Adjustment Clip)
1. Create a standard **16:9 timeline** (e.g., 1920×1080 or 3840×2160).
2. Place your **4:3 clip** on **Video Track 1** (keep the default `Scale to Fit` scaling).
3. From the **Effects Library** (`Toolbox -> Effects`), drag an **Adjustment Clip** onto **Video Track 2** over your clip.
4. Drag **`FPV Stretcher`** (found under `Toolbox -> Effects -> Krhom's Shop`) onto the **Adjustment Clip**.
5. Select the Adjustment Clip and open the **Inspector → Effects** panel to fine-tune.

### 🔮 Workflow B: Fusion Page (Direct Clip)
1. Open your 4:3 video in the **Fusion** page.
2. Press <kbd>Shift</kbd> + <kbd>Space</kbd> and search for **`FPV Stretcher`**.
3. Insert the node between `MediaIn` and `MediaOut`.
4. The output canvas automatically expands to 16:9 widescreen.

---

## 🎛️ Parameter Guide

| Parameter | Range | Default | Description |
| :--- | :---: | :---: | :--- |
| **Widescreen Fill** | `0.0 — 1.0` | `1.0` | `0.0` preserves the original 4:3 pillarbox. `1.0` expands fully to 16:9 widescreen. |
| **Vertical Crop / Zoom** | `0.0 — 0.25` | `0.07` | Crops top/bottom (default ~7% like GoPro SuperView), reducing required horizontal stretch. At `0.25` (25%), achieves a pure 16:9 center crop. |
| **Vertical Offset** | `-1.0 — +1.0` | `0.0` | Shifts vertical framing within the cropped headroom (useful for drone uptilt). |
| **Preserve Center** | `0.0 — 1.0` | `0.85` | `1.0` enforces strict 1:1 round center geometry. `0.7 — 0.85` allows a subtle center stretch for smoother edge transitions. |
| **Edge Squeeze** | `1.0 — 4.0` | `2.0` | Stretch curvature power exponent. `2.0` gives the classic action-cam look. |
| **Fisheye Correction** | `0.0 — 1.0` | `0.40` | Straightens barrel distortion from wide-angle lenses with auto zoom-out. |
| **Filtering Quality** | Dropdown | `Catmull-Rom` | `Catmull-Rom (Ultra Sharp Bicubic)`, `Bilinear (Smooth)`, or `Nearest (Draft)`. |
| **Edge Detail Boost** | `0.0 — 1.0` | `0.0` | Micro-contrast edge reconstruction to counteract horizontal stretch softening. |

---

## 🛠️ Repository Structure

```
├── FPV_Stretcher.drfx     # Pre-built DRFX bundle for DaVinci Resolve
├── FPV_Stretcher.fuse     # Core GPU-accelerated Fusion Fuse plugin
├── FPV Stretcher.setting  # Edit page Macro template
├── install.py             # Packaging and automated local installation script
├── LICENSE                # MIT License
└── README.md              # Documentation
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
