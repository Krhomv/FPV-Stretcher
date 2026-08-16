#!/usr/bin/env python3
"""
FPV Stretcher - Build & Install Script for DaVinci Resolve
- Packages the .drfx bundle
- Generates the drag-and-drop Install.lua script
- Installs to the local DaVinci Resolve directory (Windows, macOS, Linux)
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

def generate_install_lua(base_dir, fuse_src, setting_src):
    install_lua_path = os.path.join(base_dir, "Install.lua")
    with open(fuse_src, "r", encoding="utf-8") as f:
        fuse_content = f.read()
    with open(setting_src, "r", encoding="utf-8") as f:
        setting_content = f.read()

    lua_script = f"""-- ==============================================================================
-- FPV Stretcher — Drag-and-Drop Installer for DaVinci Resolve
--
-- INSTALLATION:
-- Open DaVinci Resolve -> Fusion Page -> Drag and drop this file into Fusion!
-- ==============================================================================

local FUSE_CODE = [===[
{fuse_content}
]===]

local SETTING_CODE = [===[
{setting_content}
]===]

local function runInstaller()
    local fu = (bmd and bmd.openfusion and bmd.openfusion()) or fusion
    
    print("========================================")
    print("  FPV Stretcher - Fusion Installer")
    print("========================================")

    local isWindows = (package.config:sub(1,1) == "\\\\")
    
    local fusesDir = nil
    local templatesDir = nil
    
    if fu and fu.MapPath then
        fusesDir = fu:MapPath("UserPaths:Fuses") or fu:MapPath("Fuses:")
        templatesDir = fu:MapPath("UserPaths:Templates") or fu:MapPath("Templates:")
    end
    
    if not fusesDir or fusesDir == "" or fusesDir:find(":") == nil and not isWindows then
        if isWindows then
            local appdata = os.getenv("APPDATA") or ""
            fusesDir = appdata .. "\\\\Blackmagic Design\\\\DaVinci Resolve\\\\Support\\\\Fusion\\\\Fuses"
            templatesDir = appdata .. "\\\\Blackmagic Design\\\\DaVinci Resolve\\\\Support\\\\Fusion\\\\Templates"
        else
            local home = os.getenv("HOME") or ""
            fusesDir = home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Fuses"
            templatesDir = home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Templates"
        end
    end
    
    fusesDir = fusesDir:gsub("[/\\\\]+$", "")
    templatesDir = templatesDir:gsub("[/\\\\]+$", "")
    
    local editEffectsDir = templatesDir .. (isWindows and "\\\\Edit\\\\Effects\\\\Krhom's Shop" or "/Edit/Effects/Krhom's Shop")

    print("[1] Target Fuses Directory: " .. fusesDir)
    print("[2] Target Edit Effects:    " .. editEffectsDir)

    if isWindows then
        os.execute('mkdir "' .. fusesDir .. '" 2>nul')
        os.execute('mkdir "' .. editEffectsDir .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. fusesDir .. '" 2>/dev/null')
        os.execute('mkdir -p "' .. editEffectsDir .. '" 2>/dev/null')
    end

    local fuseFile = fusesDir .. (isWindows and "\\\\FPV_Stretcher.fuse" or "/FPV_Stretcher.fuse")
    local f = io.open(fuseFile, "wb")
    if f then
        f:write(FUSE_CODE)
        f:close()
        print("[+] Installed: " .. fuseFile)
    else
        print("[!] ERROR: Failed to write " .. fuseFile)
        return false
    end

    local settingFile = editEffectsDir .. (isWindows and "\\\\FPV Stretcher.setting" or "/FPV Stretcher.setting")
    local s = io.open(settingFile, "wb")
    if s then
        s:write(SETTING_CODE)
        s:close()
        print("[+] Installed: " .. settingFile)
    else
        print("[!] ERROR: Failed to write " .. settingFile)
        return false
    end

    -- 3. Attempt dynamic live registration in active Fusion runtime
    local liveRegistered = false
    if type(FuRegisterClass) == "function" then
        local ok, err = pcall(function()
            dofile(fuseFile)
        end)
        if ok then
            liveRegistered = true
            print("[+] Live registered FPV Stretcher into active Fusion session!")
        end
    end

    local msg = "FPV Stretcher has been installed successfully!\\n\\n" ..
                "• Fusion Page: Immediately available via Shift+Space -> FPV Stretcher\\n" ..
                "• Edit Page: Available in Toolbox -> Effects -> Krhom's Shop (requires Restart)\\n\\n" ..
                (liveRegistered and "Ready to use in Fusion right now! (Restart Resolve to see in Edit Toolbox)." or "Please restart DaVinci Resolve to complete installation.")

    print("\\n" .. msg)

    if fu and fu.AskUser then
        fu:AskUser("FPV Stretcher Installation", {{ "Notice", "Text", Default = msg, ReadOnly = true, Lines = 7 }})
    end
    
    return true
end

runInstaller()
"""
    with open(install_lua_path, "w", encoding="utf-8") as f:
        f.write(lua_script)
    print(f"  Generated drag-and-drop installer: {install_lua_path}")

def main():
    base_dir = os.path.abspath(os.path.dirname(__file__))
    fuse_src = os.path.join(base_dir, "FPV_Stretcher.fuse")
    setting_src = os.path.join(base_dir, "FPV Stretcher.setting")
    drfx_dist = os.path.join(base_dir, "FPV_Stretcher.drfx")

    print("========================================")
    print("  FPV Stretcher - Build & Install")
    print("========================================")

    if not os.path.exists(fuse_src):
        print(f"Error: Missing {fuse_src}")
        sys.exit(1)
    if not os.path.exists(setting_src):
        print(f"Error: Missing {setting_src}")
        sys.exit(1)

    # 1. Build .drfx bundle
    print("\n[1] Building FPV_Stretcher.drfx bundle...")
    with zipfile.ZipFile(drfx_dist, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write(fuse_src, arcname="Fuses/FPV_Stretcher.fuse")
        zf.write(setting_src, arcname="Edit/Effects/Krhom's Shop/FPV Stretcher.setting")
    print(f"  Created bundle: {drfx_dist}")

    # 2. Build Install.lua (drag & drop installer for Fusion)
    print("\n[2] Building Install.lua...")
    generate_install_lua(base_dir, fuse_src, setting_src)

    # 3. Locate Fusion Directory and install locally
    fusion_dir = get_resolve_fusion_dir()
    if not fusion_dir:
        print("\n[!] Could not determine DaVinci Resolve directory for this OS.")
        return

    print(f"\n[3] Target Resolve Fusion directory: {fusion_dir}")
    
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

    drfx_installed = os.path.join(templates_dir, "FPV_Stretcher.drfx")
    shutil.copy2(drfx_dist, drfx_installed)
    print(f"  Installed DRFX -> {drfx_installed}")

    fuses_dir = os.path.join(fusion_dir, "Fuses")
    os.makedirs(fuses_dir, exist_ok=True)
    fuse_installed = os.path.join(fuses_dir, "FPV_Stretcher.fuse")
    shutil.copy2(fuse_src, fuse_installed)
    print(f"  Installed Fuse -> {fuse_installed}")

    print("\nSUCCESS: FPV Stretcher installed successfully!")
    print("Restart DaVinci Resolve to begin using.")

if __name__ == "__main__":
    main()
