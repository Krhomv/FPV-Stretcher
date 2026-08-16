-- ==============================================================================
-- FPV Stretcher — Drag-and-Drop Installer for DaVinci Resolve
--
-- INSTALLATION:
-- Open DaVinci Resolve -> Fusion Page -> Drag and drop this file into Fusion!
-- ==============================================================================

local FUSE_CODE = [===[
-- ==============================================================================
-- FPV SuperView Stretcher — Fusion Fuse Plugin
-- Dynamic 4:3 to 16:9 Aspect Converter
--
-- Smooth Continuous Stretch + Crop + Tilt + Fisheye + Bicubic + Edge Detail Boost
-- ==============================================================================

FuRegisterClass("FPVStretcher", CT_Tool, {
    REGS_Name          = "FPV Stretcher",
    REGS_Category      = "Fuses\\Transform",
    REGS_OpIconString  = "SVR",
    REGS_OpDescription = "Dynamic 4:3 to 16:9 Stretcher for FPV & Action Cams",
    REGS_Company       = "Custom",
    REG_OpNoMask       = true,
    REG_NoBlendCtrls   = true,
    REG_NoObjMatCtrls  = true,
    REG_NoMotionBlurCtrls = true,
    REG_Fuse_NoEdit    = false,
    REG_Fuse_NoReload  = false,
})

FPVParams = [[
    int srcsize[2];
    int dstsize[2];
    float srcCenter[2];
    float srcHalfSpan[2];
    float widescreenFill;
    float verticalCrop;
    float tiltOffsetY;
    float centerProtection;
    float edgeSqueeze;
    float fisheyeCorrection;
    int filterQuality;
    float edgeDetailBoost;
]]

FPVKernel = [[

__DEVICE__ float safePow(float base, float exponent) {
    if (base <= 0.0f) return 0.0f;
    return _expf(exponent * _logf(base));
}

// Bilinear Sub-Pixel Interpolation
__DEVICE__ float4 sampleBilinear(__TEXTURE2D__ src, float px, float py, int w, int h) {
    float fx = px - 0.5f;
    float fy = py - 0.5f;

    int x0 = (int)fx;
    if (fx < 0.0f && (float)x0 != fx) x0 -= 1;
    int y0 = (int)fy;
    if (fy < 0.0f && (float)y0 != fy) y0 -= 1;

    float tx = fx - (float)x0;
    float ty = fy - (float)y0;

    int x1 = x0 + 1;
    int y1 = y0 + 1;

    if (x0 < 0) x0 = 0; if (x0 >= w) x0 = w - 1;
    if (x1 < 0) x1 = 0; if (x1 >= w) x1 = w - 1;
    if (y0 < 0) y0 = 0; if (y0 >= h) y0 = h - 1;
    if (y1 < 0) y1 = 0; if (y1 >= h) y1 = h - 1;

    float4 c00 = _tex2DVec4(src, x0, y0);
    float4 c10 = _tex2DVec4(src, x1, y0);
    float4 c01 = _tex2DVec4(src, x0, y1);
    float4 c11 = _tex2DVec4(src, x1, y1);

    float4 c0 = c00 * (1.0f - tx) + c10 * tx;
    float4 c1 = c01 * (1.0f - tx) + c11 * tx;

    return c0 * (1.0f - ty) + c1 * ty;
}

// 16-Tap Catmull-Rom Bicubic Interpolation (Ultra Sharp & Alias-Free)
__DEVICE__ float4 sampleCatmullRom(__TEXTURE2D__ src, float px, float py, int w, int h) {
    float fx = px - 0.5f;
    float fy = py - 0.5f;

    int ix = (int)fx;
    if (fx < 0.0f && (float)ix != fx) ix -= 1;
    int iy = (int)fy;
    if (fy < 0.0f && (float)iy != fy) iy -= 1;

    float tx = fx - (float)ix;
    float ty = fy - (float)iy;

    float tx2 = tx * tx;
    float tx3 = tx2 * tx;
    float wx0 = -0.5f * tx3 + tx2 - 0.5f * tx;
    float wx1 =  1.5f * tx3 - 2.5f * tx2 + 1.0f;
    float wx2 = -1.5f * tx3 + 2.0f * tx2 + 0.5f * tx;
    float wx3 =  0.5f * tx3 - 0.5f * tx2;

    float ty2 = ty * ty;
    float ty3 = ty2 * ty;
    float wy0 = -0.5f * ty3 + ty2 - 0.5f * ty;
    float wy1 =  1.5f * ty3 - 2.5f * ty2 + 1.0f;
    float wy2 = -1.5f * ty3 + 2.0f * ty2 + 0.5f * ty;
    float wy3 =  0.5f * ty3 - 0.5f * ty2;

    float wx[4] = {wx0, wx1, wx2, wx3};
    float wy[4] = {wy0, wy1, wy2, wy3};

    float4 result = to_float4(0.0f, 0.0f, 0.0f, 0.0f);

    for (int j = 0; j < 4; j++) {
        int yCoord = iy + (j - 1);
        if (yCoord < 0) yCoord = 0;
        if (yCoord >= h) yCoord = h - 1;

        float4 row = to_float4(0.0f, 0.0f, 0.0f, 0.0f);
        for (int i = 0; i < 4; i++) {
            int xCoord = ix + (i - 1);
            if (xCoord < 0) xCoord = 0;
            if (xCoord >= w) xCoord = w - 1;

            row = row + _tex2DVec4(src, xCoord, yCoord) * wx[i];
        }
        result = result + row * wy[j];
    }

    return result;
}

__KERNEL__ void FPVSuperViewKernel(
    __CONSTANTREF__ FPVParams *params,
    __TEXTURE2D__ src,
    __TEXTURE2D_WRITE__ dst
) {
    DEFINE_KERNEL_ITERATORS_XY(x, y)

    int srcW = params->srcsize[0];
    int srcH = params->srcsize[1];
    int dstW = params->dstsize[0];
    int dstH = params->dstsize[1];

    if (x >= dstW || y >= dstH) return;

    // Normalized destination coordinates [0, 1]
    float nx = ((float)x + 0.5f) / (float)dstW;
    float ny = ((float)y + 0.5f) / (float)dstH;

    // Centered coordinates [-1, 1]
    float cx = (nx - 0.5f) * 2.0f;
    float cy = (ny - 0.5f) * 2.0f;

    // Vertical crop factor:
    float crop = _clampf(params->verticalCrop, 0.0f, 0.25f);
    float cropFactor = 1.0f - crop; // 1.0 to 0.75

    // Vertical offset scaled by available crop margin:
    float tilt = _clampf(params->tiltOffsetY, -1.0f, 1.0f);
    float shiftY = tilt * crop;

    // Sample vertical coordinate in source [-1, 1]
    float srcY = cy * cropFactor + shiftY;

    // Unstretched base footprint (at Fill = 0):
    float baseFootprint = 0.75f / cropFactor; // 0.75 at crop=0, up to 1.00 at crop=0.25
    if (baseFootprint > 1.0f) baseFootprint = 1.0f;

    // Active picture footprint inside 16:9 canvas:
    float fill = _clampf(params->widescreenFill, 0.0f, 1.0f);
    float halfFootprint = baseFootprint + (1.0f - baseFootprint) * fill;

    float4 color = to_float4(0.0f, 0.0f, 0.0f, 1.0f);

    // If within active picture area
    if (_fabs(cx) <= halfFootprint) {
        float u = cx / halfFootprint; // -1 to 1 across active picture
        float ax = _fabs(u);
        float s = (u >= 0.0f) ? 1.0f : -1.0f;

        // Center slope k for 1:1 round geometry:
        float maxK = (baseFootprint > 0.01f) ? (halfFootprint / baseFootprint) : 1.0f;
        float protect = _clampf(params->centerProtection, 0.0f, 1.0f);
        float k = 1.0f + (maxK - 1.0f) * protect;

        // Continuous Smooth Polynomial Curve:
        float power = _fmaxf(params->edgeSqueeze, 1.0f);
        float xPow = safePow(ax, power);
        float srcX = s * ax * (k - (k - 1.0f) * xPow);

        // Lens Fisheye / Barrel Distortion Correction with Auto-Scaled Zoom Out:
        float defish = _clampf(params->fisheyeCorrection, 0.0f, 1.0f);
        if (defish > 1e-4f) {
            float kDist = defish * 0.40f;
            float edgeNorm = 1.0f - kDist * 0.5f;

            float r2 = srcX * srcX + srcY * srcY;
            float kFactor = (1.0f - kDist * (r2 * 0.5f)) / edgeNorm;

            srcX = srcX * kFactor;
            srcY = srcY * kFactor;
        }

        // Convert normalized source coordinates to floating point pixel indices in active source region
        float srcPxX = params->srcCenter[0] + srcX * params->srcHalfSpan[0];
        float srcPxY = params->srcCenter[1] + srcY * params->srcHalfSpan[1];

        // Clamp to active source region boundaries to avoid sampling outside or bleeding into black pillarbox bars
        float minX = params->srcCenter[0] - params->srcHalfSpan[0] + 0.5f;
        float maxX = params->srcCenter[0] + params->srcHalfSpan[0] - 0.5f;
        if (minX < 0.5f) minX = 0.5f;
        if (maxX > (float)srcW - 0.5f) maxX = (float)srcW - 0.5f;

        float minY = params->srcCenter[1] - params->srcHalfSpan[1] + 0.5f;
        float maxY = params->srcCenter[1] + params->srcHalfSpan[1] - 0.5f;
        if (minY < 0.5f) minY = 0.5f;
        if (maxY > (float)srcH - 0.5f) maxY = (float)srcH - 0.5f;

        srcPxX = _clampf(srcPxX, minX, maxX);
        srcPxY = _clampf(srcPxY, minY, maxY);

        // Sub-pixel filtering selection
        int quality = params->filterQuality;
        if (quality == 0) {
            // Nearest (Draft)
            int sx = (int)srcPxX;
            int sy = (int)srcPxY;
            if (sx < 0) sx = 0; if (sx >= srcW) sx = srcW - 1;
            if (sy < 0) sy = 0; if (sy >= srcH) sy = srcH - 1;
            color = _tex2DVec4(src, sx, sy);
        } else if (quality == 1) {
            // Bilinear (Smooth)
            color = sampleBilinear(src, srcPxX, srcPxY, srcW, srcH);
        } else {
            // Catmull-Rom 16-Tap Bicubic (Ultra Sharp)
            color = sampleCatmullRom(src, srcPxX, srcPxY, srcW, srcH);
        }

        // Edge Detail Boost (Texture Compensation):
        // Counteracts the softening of high-frequency texture caused by horizontal stretch
        float detailBoost = _clampf(params->edgeDetailBoost, 0.0f, 1.0f);
        if (detailBoost > 1e-4f && ax > 0.15f) {
            float edgeWeight = ax * ax; // smooth quadratic ramp towards outer edges
            float boostAmount = detailBoost * edgeWeight * 0.75f;

            float4 cL = (quality == 2) ? sampleCatmullRom(src, srcPxX - 1.0f, srcPxY, srcW, srcH)
                                       : sampleBilinear(src, srcPxX - 1.0f, srcPxY, srcW, srcH);
            float4 cR = (quality == 2) ? sampleCatmullRom(src, srcPxX + 1.0f, srcPxY, srcW, srcH)
                                       : sampleBilinear(src, srcPxX + 1.0f, srcPxY, srcW, srcH);

            float4 hDetail = color - (cL + cR) * 0.5f;
            color = color + hDetail * boostAmount;

            if (color.x < 0.0f) color.x = 0.0f;
            if (color.y < 0.0f) color.y = 0.0f;
            if (color.z < 0.0f) color.z = 0.0f;
        }
    }

    _tex2DVec4Write(dst, x, y, color);
}
]]

function Create()
    InSetupNotice = self:AddInput("[NOTE] Apply to Adjustment Clip over 4:3 clip (Edit page) or directly to clip (Fusion page)", "SetupNotice", {
        LINKID_DataType    = "Text",
        INPID_InputControl = "LabelControl",
        INP_External       = false,
        INP_Passive        = true,
        LBLC_MultiLine     = true,
        IC_NoReset         = true,
    })

    -- =========================================================================
    -- Category 1: Framing & Aspect
    -- =========================================================================
    self:BeginControlNest("Framing & Aspect", "FramingAspectNest", true, {})

        InWidescreenFill = self:AddInput("Widescreen Fill", "WidescreenFill", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 1.0,
            INP_MinAllowed     = 0.0,
            INP_MaxAllowed     = 1.0,
            INP_MinScale       = 0.0,
            INP_MaxScale       = 1.0,
            INP_Precision      = 2,
        })

        InVerticalCrop = self:AddInput("Vertical Crop / Zoom", "VerticalCrop", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 0.07,
            INP_MinAllowed     = 0.0,
            INP_MaxAllowed     = 0.25,
            INP_MinScale       = 0.0,
            INP_MaxScale       = 0.25,
            INP_Precision      = 3,
        })

        InTiltOffsetY = self:AddInput("Vertical Offset", "TiltOffsetY", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 0.0,
            INP_MinAllowed     = -1.0,
            INP_MaxAllowed     = 1.0,
            INP_MinScale       = -1.0,
            INP_MaxScale       = 1.0,
            INP_Precision      = 2,
        })

    self:EndControlNest()

    -- =========================================================================
    -- Category 2: Dynamic Stretch Tuning
    -- =========================================================================
    self:BeginControlNest("Dynamic Stretch Tuning", "DynamicStretchNest", true, {})

        InCenterProtection = self:AddInput("Preserve Center", "CenterProtection", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 0.85,
            INP_MinAllowed     = 0.0,
            INP_MaxAllowed     = 1.0,
            INP_MinScale       = 0.0,
            INP_MaxScale       = 1.0,
            INP_Precision      = 2,
        })

        InEdgeSqueeze = self:AddInput("Edge Squeeze", "EdgeSqueeze", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 2.0,
            INP_MinAllowed     = 1.0,
            INP_MaxAllowed     = 4.0,
            INP_MinScale       = 1.0,
            INP_MaxScale       = 4.0,
            INP_Precision      = 2,
        })

    self:EndControlNest()

    -- =========================================================================
    -- Category 3: Lens & Optics
    -- =========================================================================
    self:BeginControlNest("Lens & Optics", "LensOpticsNest", true, {})

        InFisheyeCorrection = self:AddInput("Fisheye Correction", "FisheyeCorrection", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 0.4,
            INP_MinAllowed     = 0.0,
            INP_MaxAllowed     = 1.0,
            INP_MinScale       = 0.0,
            INP_MaxScale       = 1.0,
            INP_Precision      = 2,
        })

    self:EndControlNest()

    -- =========================================================================
    -- Category 4: Render & Quality
    -- =========================================================================
    self:BeginControlNest("Render & Quality", "RenderQualityNest", true, {})

        InFilterQuality = self:AddInput("Filtering Quality", "FilterQuality", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "ComboControl",
            INP_Default        = 2.0, -- Default Catmull-Rom Bicubic
            INP_Integer        = true,
            { CCS_AddString = "Nearest (Draft)" },
            { CCS_AddString = "Bilinear (Smooth)" },
            { CCS_AddString = "Catmull-Rom (Ultra Sharp Bicubic)" },
            CC_LabelPosition   = "Horizontal",
        })

        InEdgeDetailBoost = self:AddInput("Edge Detail Boost", "EdgeDetailBoost", {
            LINKID_DataType    = "Number",
            INPID_InputControl = "SliderControl",
            INP_Default        = 0.0,
            INP_MinAllowed     = 0.0,
            INP_MaxAllowed     = 1.0,
            INP_MinScale       = 0.0,
            INP_MaxScale       = 1.0,
            INP_Precision      = 2,
        })

    self:EndControlNest()

    -- Standard Image Inputs/Outputs
    InImage = self:AddInput("Input", "Input", {
        LINKID_DataType = "Image",
        LINK_Main       = 1,
    })

    OutImage = self:AddOutput("Output", "Output", {
        LINKID_DataType = "Image",
        LINK_Main       = 1,
    })
end

function Process(req)
    local img = InImage:GetValue(req)
    if not img then return end

    local srcW = img.Width
    local srcH = img.Height
    local srcAspect = srcW / srcH

    local dstW = srcW
    local dstH
    local is16x9Canvas = (srcAspect > 1.6)

    if is16x9Canvas then
        -- Applied to a 16:9 canvas (e.g. Adjustment Clip on a 16:9 timeline)
        -- Input image is already 16:9 with the 4:3 clip pillarboxed in the center.
        dstH = srcH
    else
        -- Applied directly to a 4:3 (or non-16:9) clip (e.g. in the Fusion page)
        -- Resize output canvas height to 16:9 widescreen: (9/16) * srcW
        dstH = math.floor(srcW * (9.0 / 16.0) + 0.5)
        if dstH % 2 ~= 0 then dstH = dstH + 1 end
    end

    -- Calculate the active 4:3 source region:
    local activeCenterX = srcW * 0.5
    local activeHalfWidth
    if is16x9Canvas then
        -- 4:3 video inside the 16:9 frame: width is (4/3) * srcH
        activeHalfWidth = (srcH * (4.0 / 3.0)) * 0.5
    else
        -- Native 4:3 image: spans the entire source width
        activeHalfWidth = srcW * 0.5
    end

    local activeCenterY = srcH * 0.5
    local activeHalfHeight = srcH * 0.5

    local imgattrs = {
        IMG_Document   = self.Comp,
        IMG_Width      = dstW,
        IMG_Height     = dstH,
        IMG_XScale     = img.XScale,
        IMG_YScale     = img.YScale,
        IMG_Depth      = img.Depth,
    }

    local out = Image(imgattrs)

    local node = DVIPComputeNode(req, "FPVSuperViewKernel", FPVKernel, "FPVParams", FPVParams)

    if node then
        local params = node:GetParamBlock(FPVParams)

        params.srcsize = {srcW, srcH}
        params.dstsize = {dstW, dstH}
        params.srcCenter = {activeCenterX, activeCenterY}
        params.srcHalfSpan = {activeHalfWidth, activeHalfHeight}
        params.widescreenFill = InWidescreenFill:GetValue(req).Value
        params.verticalCrop = InVerticalCrop:GetValue(req).Value
        params.tiltOffsetY = InTiltOffsetY:GetValue(req).Value
        params.centerProtection = InCenterProtection:GetValue(req).Value
        params.edgeSqueeze = InEdgeSqueeze:GetValue(req).Value
        params.fisheyeCorrection = InFisheyeCorrection:GetValue(req).Value
        params.filterQuality = InFilterQuality:GetValue(req).Value
        params.edgeDetailBoost = InEdgeDetailBoost:GetValue(req).Value

        node:SetParamBlock(params)

        node:AddInput("src", img)
        node:AddOutput("dst", out)

        local success = node:RunSession(req)
        if not success then
            out = img:Copy()
        end
    else
        out = img:Copy()
    end

    OutImage:Set(req, out)
end

]===]

local SETTING_CODE = [===[
{
	Tools = ordered() {
		FPVStretcher = MacroOperator {
			CtrlWZoom = false,
			CustomData = {
				Path = {
					Map = {
						["Setting:"] = "Templates:\\Edit\\Effects\\Krhom's Shop\\"
					}
				},
				Description = "Dynamic 4:3 to 16:9 SuperView Stretcher. Apply to an Adjustment Clip (Edit page) or directly to clips (Fusion page).",
			},
			Inputs = ordered() {
				MainInput1 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "Input",
				},
				Input0 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "SetupNotice",
				},
				Input1 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "WidescreenFill",
					Default = 1,
				},
				Input2 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "VerticalCrop",
					Default = 0.07,
				},
				Input3 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "TiltOffsetY",
					Name = "Vertical Offset",
					Default = 0,
				},
				Input4 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "CenterProtection",
					Name = "Preserve Center",
					Default = 0.85,
				},
				Input5 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "EdgeSqueeze",
					Default = 2,
				},
				Input6 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "FisheyeCorrection",
					Default = 0.4,
				},
				Input7 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "FilterQuality",
					Default = 2,
				},
				Input8 = InstanceInput {
					SourceOp = "FPVStretcher1",
					Source = "EdgeDetailBoost",
					Default = 0,
				},
			},
			Outputs = {
				MainOutput1 = InstanceOutput {
					SourceOp = "FPVStretcher1",
					Source = "Output",
				}
			},
			ViewInfo = GroupInfo { Pos = { 0, 0 } },
			Tools = ordered() {
				FPVStretcher1 = Fuse.FPVStretcher {
					Inputs = {
						WidescreenFill = Input { Value = 1, },
						VerticalCrop = Input { Value = 0.07, },
						TiltOffsetY = Input { Value = 0, },
						CenterProtection = Input { Value = 0.85, },
						EdgeSqueeze = Input { Value = 2, },
						FisheyeCorrection = Input { Value = 0.4, },
						FilterQuality = Input { Value = 2, },
						EdgeDetailBoost = Input { Value = 0, },
					},
					ViewInfo = OperatorInfo { Pos = { 0, 0 } },
				}
			},
		}
	}
}

]===]

local function runInstaller()
    local fu = (bmd and bmd.openfusion and bmd.openfusion()) or fusion
    
    print("========================================")
    print("  FPV Stretcher - Fusion Installer")
    print("========================================")

    local isWindows = (package.config:sub(1,1) == "\\")
    
    local fusesDir = nil
    local templatesDir = nil
    
    if fu and fu.MapPath then
        fusesDir = fu:MapPath("UserPaths:Fuses") or fu:MapPath("Fuses:")
        templatesDir = fu:MapPath("UserPaths:Templates") or fu:MapPath("Templates:")
    end
    
    if not fusesDir or fusesDir == "" or fusesDir:find(":") == nil and not isWindows then
        if isWindows then
            local appdata = os.getenv("APPDATA") or ""
            fusesDir = appdata .. "\\Blackmagic Design\\DaVinci Resolve\\Support\\Fusion\\Fuses"
            templatesDir = appdata .. "\\Blackmagic Design\\DaVinci Resolve\\Support\\Fusion\\Templates"
        else
            local home = os.getenv("HOME") or ""
            fusesDir = home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Fuses"
            templatesDir = home .. "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Templates"
        end
    end
    
    fusesDir = fusesDir:gsub("[/\\]+$", "")
    templatesDir = templatesDir:gsub("[/\\]+$", "")
    
    local editEffectsDir = templatesDir .. (isWindows and "\\Edit\\Effects\\Krhom's Shop" or "/Edit/Effects/Krhom's Shop")

    print("[1] Target Fuses Directory: " .. fusesDir)
    print("[2] Target Edit Effects:    " .. editEffectsDir)

    if isWindows then
        os.execute('mkdir "' .. fusesDir .. '" 2>nul')
        os.execute('mkdir "' .. editEffectsDir .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. fusesDir .. '" 2>/dev/null')
        os.execute('mkdir -p "' .. editEffectsDir .. '" 2>/dev/null')
    end

    local fuseFile = fusesDir .. (isWindows and "\\FPV_Stretcher.fuse" or "/FPV_Stretcher.fuse")
    local f = io.open(fuseFile, "wb")
    if f then
        f:write(FUSE_CODE)
        f:close()
        print("[+] Installed: " .. fuseFile)
    else
        print("[!] ERROR: Failed to write " .. fuseFile)
        return false
    end

    local settingFile = editEffectsDir .. (isWindows and "\\FPV Stretcher.setting" or "/FPV Stretcher.setting")
    local s = io.open(settingFile, "wb")
    if s then
        s:write(SETTING_CODE)
        s:close()
        print("[+] Installed: " .. settingFile)
    else
        print("[!] ERROR: Failed to write " .. settingFile)
        return false
    end

    local msg = "FPV Stretcher has been installed successfully!\n\n" ..
                "• Edit Page: Toolbox -> Effects -> Krhom's Shop -> FPV Stretcher\n" ..
                "• Fusion Page: Shift+Space -> FPV Stretcher\n\n" ..
                "Please RESTART DaVinci Resolve to complete installation."

    print("\n" .. msg)

    if fu and fu.AskUser then
        fu:AskUser("FPV Stretcher Installation", { "Notice", "Text", Default = msg, ReadOnly = true, Lines = 7 })
    end
    
    return true
end

runInstaller()
