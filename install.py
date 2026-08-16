#!/usr/bin/env python3
"""
FPV Stretcher - Build & Install Script for DaVinci Resolve
Packages the .drfx bundle and installs to the local DaVinci Resolve directory.
Supports Windows, macOS, and Linux.
"""

import os
import sys
import shutil
import zipfile
import platform

def get_resolve_fusion_dir():
    system = platform.system()
    home = os.path.expanduser("~")
    
    if system == "Windows":
        appdata = os.environ.get("APPDATA")
        if appdata:
            return os.path.join(appdata, "Blackmagic Design", "DaVinci Resolve", "Support", "Fusion")
    elif system == "Darwin":  # macOS
        return os.path.join(home, "Library", "Application Support", "Blackmagic Design", "DaVinci Resolve", "Fusion")
    elif system == "Linux":
        return os.path.join(home, ".local", "share", "DaVinciResolve", "Fusion")
    
    return None

def main():
    base_dir = os.path.abspath(os.path.dirname(__file__))
    fuse_src = os.path.join(base_dir, "FPV_Stretcher.fuse")
    setting_src = os.path.join(base_dir, "FPV Stretcher.setting")
    drfx_dist = os.path.join(base_dir, "FPV_Stretcher.drfx")

    print("========================================")
    print("  FPV Stretcher - Build & Install")
    print("========================================")

    # 1. Build .drfx bundle
    print("\n[1] Building FPV_Stretcher.drfx bundle...")
    if not os.path.exists(fuse_src):
        print(f"Error: Missing {fuse_src}")
        sys.exit(1)
    if not os.path.exists(setting_src):
        print(f"Error: Missing {setting_src}")
        sys.exit(1)

    with zipfile.ZipFile(drfx_dist, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(fuse_src, arcname="Fuses/FPV_Stretcher.fuse")
        zf.write(setting_src, arcname="Edit/Effects/Krhom's Shop/FPV Stretcher.setting")
    
    print(f"  Created bundle: {drfx_dist}")

    # 2. Locate Fusion Directory
    fusion_dir = get_resolve_fusion_dir()
    if not fusion_dir:
        print("\n[!] Could not automatically determine DaVinci Resolve Fusion directory for this OS.")
        print(f"    You can double-click {drfx_dist} to install via Resolve UI.")
        return

    print(f"\n[2] Target Resolve Fusion directory: {fusion_dir}")
    
    # 3. Clean up any stale legacy versions in Templates
    templates_dir = os.path.join(fusion_dir, "Templates")
    os.makedirs(templates_dir, exist_ok=True)
    
    for f in os.listdir(templates_dir):
        if any(k in f.lower() for k in ['fpv_4_3', 'fpv 4-3', 'fpv_superview']):
            p = os.path.join(templates_dir, f)
            try:
                if os.path.isfile(p): os.remove(p)
                elif os.path.isdir(p): shutil.rmtree(p)
                print(f"  Cleaned legacy template: {p}")
            except Exception as e:
                print(f"  Warning cleaning {p}: {e}")

    # 4. Install DRFX bundle
    drfx_installed = os.path.join(templates_dir, "FPV_Stretcher.drfx")
    shutil.copy2(drfx_dist, drfx_installed)
    print(f"  Installed DRFX -> {drfx_installed}")

    # 5. Install standalone Fuse (for direct Fusion page node access)
    fuses_dir = os.path.join(fusion_dir, "Fuses")
    os.makedirs(fuses_dir, exist_ok=True)
    fuse_installed = os.path.join(fuses_dir, "FPV_Stretcher.fuse")
    shutil.copy2(fuse_src, fuse_installed)
    print(f"  Installed Fuse -> {fuse_installed}")

    print("\nSUCCESS: FPV Stretcher installed successfully!")
    print("Restart DaVinci Resolve to begin using.")

if __name__ == "__main__":
    main()
