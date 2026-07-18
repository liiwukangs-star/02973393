script_name("RearLights")
script_author("Deprau")

local imgui   = require("mimgui")
local mem     = require("SAMemory")
local ffi     = require("ffi")
local hk      = require('monethook')
local memory  = require('memory')
local widgets = require('widgets')
local cs      = ffi.cast

mem.require('CVehicle')
mem.require('CAutomobile')
mem.require('CDamageManager')
mem.require('CEntity')
mem.require('CPlaceable')
mem.require('RenderWare')

ffi.cdef[[
typedef struct { float x, y, z; } RwV3d;

void _ZN8CCoronas14RegisterCoronaEjP7CEntityhhhhRK7CVectorffhhhhhfbfbfbb(
    uintptr_t id, void* entity,
    uint8_t r, uint8_t g, uint8_t b, uint8_t a,
    RwV3d const* pos,
    float size, float dist,
    uint8_t coronaType, uint8_t flareType,
    bool enableReflection, bool checkObstacles,
    int unused, float normalAngle,
    bool longDistance, float nearClip,
    bool facingCamera, float farClip,
    bool unk1, bool unk2
);

void _ZN8CVehicle9PreRenderEv(void* thisVeh);
void _ZN14CDamageManager14SetLightStatusE7eLightsj(void* thisDM, int light, unsigned int status);
bool _ZN10CModelInfo10IsCarModelEi(int modelIndex);
void _ZN11CAutomobile25GetComponentWorldPositionEiR7CVector(void* thisVeh, int nodeIndex, RwV3d* outPos);

typedef struct {
    RwV3D   pos;
    RwV3D   normal;
    RwColor color;
    float   u, v;
} TrailVertex;

int   _Z16RwRenderStateSet13RwRenderStatePv(int state, void* value);
bool  _Z15RwIm3DTransformP18RxObjSpace3DVertexjP11RwMatrixTagj(TrailVertex* verts, uint32_t numVerts, RwMatrix* mat, uint32_t flags);
void  _Z28RwIm3DRenderIndexedPrimitive15RwPrimitiveTypePti(int primType, uint16_t* indices, int numIndices);
void  _Z9RwIm3DEndv();
int   _Z16RwTextureDestroyP9RwTexture(void* tex);
void  _ZN13CBulletTraces6RenderEv();
]]

local gt = ffi.load("GTASA")

local DAMSTATE_OK = 0
local LIGHT_REAR_RIGHT = 2
local LIGHT_REAR_LEFT  = 3
local dmOffset = ffi.offsetof('CAutomobile', 'damageManager')

local MAX_MODEL_INDEX = 20000

local trailTexPath = getWorkingDirectory() .. '/resource/trail.png'

local currentPlayerModelId = -1
local prevPlayerModelId    = -1

-- Hardcoded per-model configs. ONLY these model IDs get rear coronas / trails.
local vehicleConfigs = {
[410]={posX=-0.993000,posY=-1.960000,height=0.123000,spacing=0.585000},
[411]={posX=-1.079000,posY=-2.653000,height=0.242000,spacing=0.699000},
[419]={posX=-1.083000,posY=-2.534000,height=-0.007000,spacing=0.596000},
[421]={posX=-1.010000,posY=-2.838000,height=0.090000,spacing=0.552000},
[420]={posX=-1.079000,posY=-2.812000,height=-0.040000,spacing=0.750000},
[565]={posX=-0.936000,posY=-1.752000,height=-0.040000,spacing=0.785000},
[451]={posX=-1.035000,posY=-2.235000,height=-0.161000,spacing=0.677000},
[536]={posX=-1.076000,posY=-2.924000,height=0.048000,spacing=0.852000},
[494]={posX=-1.013000,posY=-2.588000,height=0.457000,spacing=0.677000},
[541]={posX=-0.994000,posY=-1.785000,height=0.148000,spacing=0.765000},
[480]={posX=-1.013000,posY=-2.074000,height=-0.019000,spacing=0.677000},
[429]={posX=-0.974000,posY=-1.881000,height=0.109000,spacing=0.701000},
[600]={posX=-1.076000,posY=-2.733000,height=0.038000,spacing=1.010000},
[404]={posX=-0.928000,posY=-2.502000,height=0.047000,spacing=0.785000},
[405]={posX=-1.010000,posY=-2.588000,height=-0.029000,spacing=0.471000},
[552]={posX=-1.145000,posY=-3.637000,height=0.436000,spacing=0.965000},
[478]={posX=-1.053000,posY=-2.480000,height=-0.202000,spacing=1.029000},
[400]={posX=-1.010000,posY=-2.242000,height=-0.116000,spacing=0.866000},
[401]={posX=-1.112000,posY=-2.333000,height=0.095000,spacing=0.655000},
[402]={posX=-1.112000,posY=-2.458000,height=0.177000,spacing=0.671000},
[560]={posX=-1.035000,posY=-2.347000,height=-0.040000,spacing=0.677000},
[412]={posX=-1.123000,posY=-3.000000,height=-0.061000,spacing=0.823000},
[413]={posX=-1.024000,posY=-1.893000,height=-1.417000,spacing=0.823000},
[506]={posX=-1.019000,posY=-2.048000,height=-0.057000,spacing=0.614000},
[415]={posX=-1.036000,posY=-2.181000,height=0.144000,spacing=0.791000},
[477]={posX=-1.186000,posY=-2.524000,height=-0.006000,spacing=0.669000},
[575]={posX=-1.101000,posY=-2.653000,height=-0.029000,spacing=0.910000},
}

local new = imgui.new

local uiOpen      = new.bool(false)
local uEnabled    = new.bool(true)

local uNodeIndex  = new.int(8)
local uSpacing    = new.float(0.677)
local uForward    = new.float(-1.000)
local uHeight     = new.float(-0.040)
local uPosX       = new.float(-1.035)
local uPosY       = new.float(-2.347)

local uSize       = new.float(0.684)
local mmkScale = new.float(1.000)
local uAlpha      = new.int(255)
local uRenderDist = new.float(300.0)

local uCoronaType = new.int(0)
local uFlareType  = new.int(0)
local uReflection = new.bool(true)
local uCheckObstacles = new.bool(true)
local uNormalAngle    = new.float(-1.000)
local uLongDistance   = new.bool(false)
local uNearClip       = new.float(2.000)
local uFacingCamera   = new.bool(true)
local uFarClip        = new.float(0.000)
local uUnk1           = new.bool(true)
local uUnk2           = new.bool(true)

local uColor = new.float[3](1.0, 0.0, 0.0)

local MAX_POINTS_CAP = 26

local uTrailEnabled  = new.bool(true)
local uTrailPoints   = new.int(26)
local uTrailMinDist  = new.float(0.020)
local uTrailSmooth   = new.float(0.000)
local uTrailWeight   = new.float(0.080)
local uTrailAlpha    = new.int(174)
local uTrailTipFade  = new.int(0)
local uTrailOffsetX  = new.float(0.005)

local uSpeedLow     = new.float(5.0)
local uSpeedHigh    = new.float(40.0)
local uMinIntensity = new.float(0.20)

local uIdleIntensity = new.float(0.30)
local uNitroAttack   = new.float(0.15)
local uNitroRelease  = new.float(2.00)

local MAX_SHAKE = 40

local nodePos  = ffi.new('RwV3d')

local nextId = 1
local idMap  = setmetatable({}, {__mode = 'k'})

local function getIdFor(vehPtr, side)
    local key = tostring(vehPtr)
    if not idMap[key] then
        idMap[key] = nextId
        nextId = nextId + 2
        if nextId > 4000 then nextId = 1 end
    end
    return idMap[key] + side
end

local function forceRearLightsOn(vehPtr)
    local dmPtr = cs('void*', cs('uintptr_t', vehPtr) + dmOffset)
    gt._ZN14CDamageManager14SetLightStatusE7eLightsj(dmPtr, LIGHT_REAR_LEFT, DAMSTATE_OK)
    gt._ZN14CDamageManager14SetLightStatusE7eLightsj(dmPtr, LIGHT_REAR_RIGHT, DAMSTATE_OK)
end

local posLeft  = ffi.new('RwV3d')
local posRight = ffi.new('RwV3d')

local function registerRearCorona(id, pos, entity, intensityMul)
    intensityMul = intensityMul or 1.0

    local r = math.floor(uColor[0] * 255 + 0.5)
    local g = math.floor(uColor[1] * 255 + 0.5)
    local b = math.floor(uColor[2] * 255 + 0.5)
    local a = math.floor(uAlpha[0] * intensityMul + 0.5)
    local sz = uSize[0] * mmkScale[0] * (0.75 + 0.25 * intensityMul)

    if a <= 0 then return false end

    return pcall(
        gt._ZN8CCoronas14RegisterCoronaEjP7CEntityhhhhRK7CVectorffhhhhhfbfbfbb,
        id, entity,
        r, g, b, a,
        pos,
        sz, uRenderDist[0],
        uCoronaType[0], uFlareType[0],
        uReflection[0], uCheckObstacles[0], 0, uNormalAngle[0],
        uLongDistance[0], uNearClip[0], uFacingCamera[0], uFarClip[0],
        uUnk1[0], uUnk2[0]
    )
end

local FADE_DURATION = 2.0

local nitroActive  = false
local playerVehPtr = nil
local playerVehHandle = nil

local currentSpeedMul = 1.0
local frozenSpeedMul  = 1.0

local nitroBlend    = 0.0
local lastBlendTime = nil

local vehicleFadeState = { active = false, releasedAt = 0 }

local frozenLeft  = ffi.new('RwV3d')
local frozenRight = ffi.new('RwV3d')
local frozenId0   = 0
local frozenId1   = 0

local function ptrEq(a, b)
    if a == nil or b == nil then return false end
    return cs('uintptr_t', a) == cs('uintptr_t', b)
end

local function clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

local function updateSpeedMul(vehHandle)
    if not vehHandle then
        currentSpeedMul = uMinIntensity[0]
        return
    end

    local ok, speed = pcall(getCarSpeed, vehHandle)
    if not ok or not speed then
        currentSpeedMul = uMinIntensity[0]
        return
    end

    local low, high = uSpeedLow[0], uSpeedHigh[0]
    local t = 0
    if high > low then
        t = clamp01((speed - low) / (high - low))
    end

    currentSpeedMul = uMinIntensity[0] + (1.0 - uMinIntensity[0]) * t
end

local function registerFrozenCorona(id, pos, fadeMul)
    local intensityMul = fadeMul * frozenSpeedMul
    local a = math.floor(uAlpha[0] * intensityMul + 0.5)
    if a <= 0 then return end

    local r = math.floor(uColor[0] * 255 + 0.5)
    local g = math.floor(uColor[1] * 255 + 0.5)
    local b = math.floor(uColor[2] * 255 + 0.5)
    local sz = uSize[0] * mmkScale[0] * (0.75 + 0.25 * frozenSpeedMul)

    pcall(
        gt._ZN8CCoronas14RegisterCoronaEjP7CEntityhhhhRK7CVectorffhhhhhfbfbfbb,
        id, cs('void*', 0),
        r, g, b, a,
        pos,
        sz, uRenderDist[0],
        uCoronaType[0], uFlareType[0],
        uReflection[0], uCheckObstacles[0], 0, uNormalAngle[0],
        uLongDistance[0], uNearClip[0], uFacingCamera[0], uFarClip[0],
        uUnk1[0], uUnk2[0]
    )
end

local function worldToLocalOffset(m, wx, wy, wz)
    local dx = wx - m.pos.x
    local dy = wy - m.pos.y
    local dz = wz - m.pos.z

    local lx = dx * m.right.x + dy * m.right.y + dz * m.right.z
    local ly = dx * m.up.x    + dy * m.up.y    + dz * m.up.z
    local lz = dx * m.at.x    + dy * m.at.y    + dz * m.at.z

    return lx, ly, lz
end

local function localToWorld(m, lx, ly, lz)
    local wx = m.pos.x + lx * m.right.x + ly * m.up.x + lz * m.at.x
    local wy = m.pos.y + lx * m.right.y + ly * m.up.y + lz * m.at.y
    local wz = m.pos.z + lx * m.right.z + ly * m.up.z + lz * m.at.z
    return wx, wy, wz
end

local function applyConfigToSliders(modelIndex)
    local cfg = vehicleConfigs[modelIndex]
    if cfg then
        uPosX[0]    = cfg.posX
        uPosY[0]    = cfg.posY
        uHeight[0]  = cfg.height
        uSpacing[0] = cfg.spacing
    end
end

-- Only returns a config for models present in vehicleConfigs.
-- Returns nil if the model is not in the whitelist.
local function getConfigFor(modelIndex)
    local cfg = vehicleConfigs[modelIndex]
    if not cfg then return nil end

    if modelIndex == currentPlayerModelId then
        return uPosX[0], uPosY[0], uHeight[0], uSpacing[0]
    end

    return cfg.posX, cfg.posY, cfg.height, cfg.spacing
end

local trailHistory = {}
local trailRw, trailRaster = nil, nil

local TRAIL_MAX_VEH  = 40
local SEG_PER_SIDE   = MAX_POINTS_CAP - 1
local VERT_PER_SIDE  = SEG_PER_SIDE * 4
local IDX_PER_SIDE   = SEG_PER_SIDE * 6
local TRAIL_TOT_VERT = TRAIL_MAX_VEH * 2 * VERT_PER_SIDE
local TRAIL_TOT_IDX  = TRAIL_MAX_VEH * 2 * IDX_PER_SIDE

local vt2 = ffi.new('TrailVertex[?]', TRAIL_TOT_VERT)
local id2 = ffi.new('uint16_t[?]',    TRAIL_TOT_IDX)

local identMat = ffi.new('RwMatrix')
identMat.right.x=1; identMat.right.y=0; identMat.right.z=0
identMat.up.x=0;    identMat.up.y=1;    identMat.up.z=0
identMat.at.x=0;    identMat.at.y=0;    identMat.at.z=1
identMat.pos.x=0;   identMat.pos.y=0;   identMat.pos.z=0

local T1 = 1
local T2 = 7
local T3 = 8
local T4 = 10
local T5 = 11
local T6 = 12
local T7 = 20
local PT = 3

local function fileExists(path)
    local f = io.open(path, 'rb')
    if f then f:close(); return true end
    return false
end

local function RS(st, vl)
    pcall(function()
        gt._Z16RwRenderStateSet13RwRenderStatePv(st, cs('void*', vl))
    end)
end

local function loadRwTex(path)
    local ok, tx = pcall(renderLoadTextureFromFile, path)
    if not ok or not tx then return nil, nil end
    local rwPtr  = cs('RwTexture*', tx)
    local raster = cs('void*', cs('uintptr_t', rwPtr.raster))
    return rwPtr, raster
end

local function loadTrailTexture()
    if not fileExists(trailTexPath) then
        print('[RearLightCorona] trail.png tidak ditemukan di ' .. trailTexPath)
        return
    end
    local rwPtr, raster = loadRwTex(trailTexPath)
    if not rwPtr then
        print('[RearLightCorona] gagal load trail.png')
        return
    end
    trailRw, trailRaster = rwPtr, raster
end

local function sV2(v, x, y, z, u, vv, r, g, b, a)
    v.pos.x=x; v.pos.y=y; v.pos.z=z
    v.normal.x=0; v.normal.y=1; v.normal.z=0
    v.color.r=r; v.color.g=g; v.color.b=b; v.color.a=a
    v.u=u; v.v=vv
end

local function iF(v)
    return v == v and v ~= math.huge and v ~= -math.huge
end

local function newSide()
    return { x = {}, y = {}, z = {}, rx = {}, ry = {}, rz = {}, n = 0 }
end

local function pushTrailPoint(list, x, y, z, rx, ry, rz, maxPoints, minDist, smooth)
    local n = list.n

    if n > 0 then
        local lx, ly, lz = list.x[n], list.y[n], list.z[n]
        local dx, dy, dz = x - lx, y - ly, z - lz

        if (dx*dx + dy*dy + dz*dz) < minDist*minDist then
            list.x[n], list.y[n], list.z[n] = x, y, z
            list.rx[n], list.ry[n], list.rz[n] = rx, ry, rz
            return
        end

        if smooth > 0 then
            x = lx + (x - lx) * (1 - smooth)
            y = ly + (y - ly) * (1 - smooth)
            z = lz + (z - lz) * (1 - smooth)
        end
    end

    n = n + 1
    list.x[n], list.y[n], list.z[n] = x, y, z
    list.rx[n], list.ry[n], list.rz[n] = rx, ry, rz

    if n > maxPoints then
        for i = 1, n - 1 do
            list.x[i], list.y[i], list.z[i] = list.x[i+1], list.y[i+1], list.z[i+1]
            list.rx[i], list.ry[i], list.rz[i] = list.rx[i+1], list.ry[i+1], list.rz[i+1]
        end
        n = maxPoints
    end

    list.n = n
end

local rCol, gCol, bCol = 255, 0, 0
local aHeadVal, aTailVal, halfWeight = 174, 0, 0.040

local function buildSide(pts, vc, ic, bv, intensityMul)
    local n = pts.n
    if n < 2 then return vc, ic, bv end

    local px, py, pz = pts.x, pts.y, pts.z
    local prx, pry, prz = pts.rx, pts.ry, pts.rz
    local invLen = 1 / (n - 1)

    local weightMul = 0.6 + 0.4 * intensityMul
    local hw = halfWeight * weightMul

    for i = n, 2, -1 do
        if vc + 4 > TRAIL_TOT_VERT or ic + 6 > TRAIL_TOT_IDX then break end

        local x1, y1, z1 = px[i], py[i], pz[i]
        local x2, y2, z2 = px[i-1], py[i-1], pz[i-1]

        if iF(x1) and iF(x2) then
            local a1x, a1y, a1z = prx[i]*hw, pry[i]*hw, prz[i]*hw
            local a2x, a2y, a2z = prx[i-1]*hw, pry[i-1]*hw, prz[i-1]*hw

            local t1 = (n - i) * invLen
            local t2 = (n - (i - 1)) * invLen
            local al1 = math.floor((aHeadVal + (aTailVal - aHeadVal) * t1) * intensityMul + 0.5)
            local al2 = math.floor((aHeadVal + (aTailVal - aHeadVal) * t2) * intensityMul + 0.5)

            sV2(vt2[bv+0], x1+a1x, y1+a1y, z1+a1z, 0, t1, rCol, gCol, bCol, al1)
            sV2(vt2[bv+1], x1-a1x, y1-a1y, z1-a1z, 1, t1, rCol, gCol, bCol, al1)
            sV2(vt2[bv+2], x2+a2x, y2+a2y, z2+a2z, 0, t2, rCol, gCol, bCol, al2)
            sV2(vt2[bv+3], x2-a2x, y2-a2y, z2-a2z, 1, t2, rCol, gCol, bCol, al2)

            id2[ic+0]=bv+0; id2[ic+1]=bv+1; id2[ic+2]=bv+2
            id2[ic+3]=bv+1; id2[ic+4]=bv+3; id2[ic+5]=bv+2

            bv = bv + 4; vc = vc + 4; ic = ic + 6
        end
    end

    return vc, ic, bv
end

local function bT()
    rCol = math.floor(uColor[0] * 255 + 0.5)
    gCol = math.floor(uColor[1] * 255 + 0.5)
    bCol = math.floor(uColor[2] * 255 + 0.5)
    aHeadVal = uTrailAlpha[0]
    aTailVal = uTrailTipFade[0]
    halfWeight = uTrailWeight[0] * 0.5

    local vc, ic, bv = 0, 0, 0

    for _, hist in pairs(trailHistory) do
        local fadeMul = hist.fade or 1.0
        local speedMul = hist.speedMul or 1.0
        local intensityMul = fadeMul * speedMul
        vc, ic, bv = buildSide(hist.left, vc, ic, bv, intensityMul)
        vc, ic, bv = buildSide(hist.right, vc, ic, bv, intensityMul)
    end

    return vc, ic
end

local trailRenderActive = false

local function renderTrails()
    if trailRenderActive then return end
    if not uTrailEnabled[0] or not trailRaster then
        trailHistory = {}
        return
    end

    trailRenderActive = true

    pcall(function()
        RS(T3, 0)
        RS(T2, 4)
        RS(T6, 1)
        RS(T4, 5)
        RS(T5, 6)
        RS(T7, 1)
        RS(13,3); RS(14,3); RS(15,3)

        local vc, ic = bT()
        if vc > 0 then
            local ok2 = gt._Z15RwIm3DTransformP18RxObjSpace3DVertexjP11RwMatrixTagj(vt2, vc, identMat, 1)
            if ok2 then
                RS(T1, trailRaster)
                gt._Z28RwIm3DRenderIndexedPrimitive15RwPrimitiveTypePti(PT, id2, ic)
                gt._Z9RwIm3DEndv()
            end
        end

        RS(T7, 3)
        RS(T2, 4)
        RS(T3, 1)
        RS(T6, 0)
        RS(13,1); RS(14,1); RS(15,1)
    end)

    trailRenderActive = false
end

local function injectRearCoronas(vehPtr, modelIndex)
    local posX, posY, posZ, spacing = getConfigFor(modelIndex)
    if posX == nil then return end -- model not whitelisted

    local pl = cs('CPlaceable*', vehPtr)
    local m = pl.pMatrix
    if m == nil then return end

    local ok, baseX, baseY, baseZ = pcall(function()
        gt._ZN11CAutomobile25GetComponentWorldPositionEiR7CVector(vehPtr, uNodeIndex[0], nodePos)
        return worldToLocalOffset(m, nodePos.x, nodePos.y, nodePos.z)
    end)
    if not ok or baseX == nil then return end

    baseX = baseX + posX
    baseY = baseY + posY + uForward[0]
    baseZ = baseZ + posZ

    posLeft.x  = baseX - spacing
    posLeft.y  = baseY
    posLeft.z  = baseZ

    posRight.x = baseX + spacing
    posRight.y = baseY
    posRight.z = baseZ

    frozenId0 = getIdFor(vehPtr, 0)
    frozenId1 = getIdFor(vehPtr, 1)

    local blendMul   = uIdleIntensity[0] + (1.0 - uIdleIntensity[0]) * nitroBlend
    local effectiveMul = currentSpeedMul * blendMul

    registerRearCorona(frozenId0, posLeft, vehPtr, effectiveMul)
    registerRearCorona(frozenId1, posRight, vehPtr, effectiveMul)

    frozenSpeedMul = effectiveMul

    local wxL, wyL, wzL = localToWorld(m, posLeft.x, posLeft.y, posLeft.z)
    local wxR, wyR, wzR = localToWorld(m, posRight.x, posRight.y, posRight.z)
    frozenLeft.x, frozenLeft.y, frozenLeft.z    = wxL, wyL, wzL
    frozenRight.x, frozenRight.y, frozenRight.z = wxR, wyR, wzR

    if uTrailEnabled[0] and trailRaster then
        local trailLX = baseX - spacing + uTrailOffsetX[0]
        local trailRX = baseX + spacing + uTrailOffsetX[0]

        local sxL, syL, szL = localToWorld(m, trailLX, baseY, baseZ)
        local sxR, syR, szR = localToWorld(m, trailRX, baseY, baseZ)

        local key = tonumber(cs('intptr_t', vehPtr))
        local hist = trailHistory[key]
        if not hist then
            hist = { left = newSide(), right = newSide(), fade = 1.0, speedMul = 1.0 }
            trailHistory[key] = hist
        end
        hist.fade = 1.0
        hist.speedMul = effectiveMul

        local maxPts = uTrailPoints[0]
        if maxPts > MAX_POINTS_CAP then maxPts = MAX_POINTS_CAP end

        pushTrailPoint(hist.left, sxL, syL, szL, m.right.x, m.right.y, m.right.z, maxPts, uTrailMinDist[0], uTrailSmooth[0])
        pushTrailPoint(hist.right, sxR, syR, szR, m.right.x, m.right.y, m.right.z, maxPts, uTrailMinDist[0], uTrailSmooth[0])
    end
end

local hPreRender
hPreRender = hk.new(
    "void(*)(void*)",
    function(thisVeh)
        hPreRender(thisVeh)

        if not uEnabled[0] then return end

        pcall(function()
            local ent = cs('CEntity*', thisVeh)
            local modelIndex = ent.nModelIndex

            if modelIndex < 0 or modelIndex >= MAX_MODEL_INDEX then return end
            if not vehicleConfigs[modelIndex] then return end -- only whitelisted models
            if not gt._ZN10CModelInfo10IsCarModelEi(modelIndex) then return end

            forceRearLightsOn(thisVeh)

            if ptrEq(thisVeh, playerVehPtr) then
                injectRearCoronas(thisVeh, modelIndex)
            end
        end)
    end,
    cs("uintptr_t", cs("void*", gt._ZN8CVehicle9PreRenderEv))
)

local hTrailRender
hTrailRender = hk.new(
    "void(*)()",
    function()
        pcall(function() hTrailRender() end)

        pcall(function()
            if vehicleFadeState.active then
                local elapsed = os.clock() - vehicleFadeState.releasedAt

                if elapsed < FADE_DURATION then
                    local fade = 1.0 - (elapsed / FADE_DURATION)

                    registerFrozenCorona(frozenId0, frozenLeft, fade)
                    registerFrozenCorona(frozenId1, frozenRight, fade)

                    for _, hist in pairs(trailHistory) do
                        hist.fade = fade
                    end
                else
                    vehicleFadeState.active = false
                    trailHistory = {}
                end
            end
        end)

        pcall(renderTrails)
    end,
    cs("uintptr_t", cs("void*", gt._ZN13CBulletTraces6RenderEv))
)

local uiConfigPath = getWorkingDirectory() .. '/config/RearLights.lua'

local function loadUiConfig()
    local f = io.open(uiConfigPath, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    local chunk = loadstring(content)
    if not chunk then return nil end
    local ok, result = pcall(chunk)
    if ok and type(result) == 'table' then return result end
    return nil
end

local function saveUiConfig()
    local f = io.open(uiConfigPath, 'w')
    if not f then return end
    f:write(string.format(
        'return {r=%.6f,g=%.6f,b=%.6f,scale=%.6f}\n',
        uColor[0], uColor[1], uColor[2], mmkScale[0]
    ))
    f:close()
end

do
    local saved = loadUiConfig()
    if saved then
        uColor[0] = saved.r or uColor[0]
        uColor[1] = saved.g or uColor[1]
        uColor[2] = saved.b or uColor[2]
        mmkScale[0] = saved.scale or mmkScale[0]
    end
end

imgui.OnFrame(
    function() return uiOpen[0] end,
    function(player)
        imgui.SetNextWindowSize(imgui.ImVec2(340, 400), imgui.Cond.FirstUseEver)
        imgui.Begin('Deprau - RearLights', uiOpen, imgui.WindowFlags.AlwaysAutoResize)
            if imgui.ColorEdit3('Color', uColor) then
                saveUiConfig()
            end
            if imgui.SliderFloat('Scale', mmkScale, 0.1, 5.0, '%.2f') then
                saveUiConfig()
            end
        imgui.End()
    end
)

local NITRO_FORCE_OFFSET = 0x8B8
local currentVehiclePtrAddr = memory.getuint32(MONET_GTASA_BASE + 0x676968)
local lastNitroVehicle = nil

addEventHandler('onD3DPresent', function()
    local vehiclePtr = memory.getuint32(currentVehiclePtrAddr)
    local wasInVehicle = playerVehPtr ~= nil

    if vehiclePtr ~= 0 and isCharInAnyCar(PLAYER_PED) then
        local currentVehicle = storeCarCharIsInNoSave(PLAYER_PED)
        local isDriver = getDriverOfCar(currentVehicle) == PLAYER_PED

        if currentVehicle ~= lastNitroVehicle then
            lastNitroVehicle = currentVehicle
            giveNonPlayerCarNitro(currentVehicle)
        end

        local pressed = isDriver and isWidgetPressed(WIDGET_NITRO)

        if pressed then
            memory.setfloat(vehiclePtr + NITRO_FORCE_OFFSET, -0.5)
        else
            memory.setfloat(vehiclePtr + NITRO_FORCE_OFFSET, 0.0)
        end

        playerVehPtr    = cs('void*', vehiclePtr)
        playerVehHandle = currentVehicle
        updateSpeedMul(currentVehicle)

        if pressed then
            shakeCam(math.floor(currentSpeedMul * MAX_SHAKE + 2.8))
        end

        nitroActive = pressed
        vehicleFadeState.active = false
    else
        lastNitroVehicle = nil
        playerVehPtr = nil
        playerVehHandle = nil
        nitroActive = false

        if wasInVehicle then
            vehicleFadeState.active = true
            vehicleFadeState.releasedAt = os.clock()
        end
    end

    local now = os.clock()
    local dt = now - (lastBlendTime or now)
    lastBlendTime = now
    if dt < 0 or dt > 0.5 then dt = 0 end

    local target = nitroActive and 1.0 or 0.0
    local attackT  = math.max(uNitroAttack[0], 0.01)
    local releaseT = math.max(uNitroRelease[0], 0.01)
    local rate = (target > nitroBlend) and (1 / attackT) or (1 / releaseT)

    if nitroBlend < target then
        nitroBlend = math.min(target, nitroBlend + rate * dt)
    elseif nitroBlend > target then
        nitroBlend = math.max(target, nitroBlend - rate * dt)
    end

    if isCharInAnyCar(PLAYER_PED) then
        local veh = storeCarCharIsInNoSave(PLAYER_PED)
        currentPlayerModelId = getCarModel(veh)
    else
        currentPlayerModelId = -1
    end

    if currentPlayerModelId ~= prevPlayerModelId then
        if vehicleConfigs[currentPlayerModelId] then
            applyConfigToSliders(currentPlayerModelId)
        end
        prevPlayerModelId = currentPlayerModelId
    end
end)

addEventHandler('onScriptTerminate', function(scr)
    if scr == thisScript() then
        pcall(function()
            if trailRw ~= nil then
                gt._Z16RwTextureDestroyP9RwTexture(trailRw)
            end
        end)
        pcall(function() if hPreRender and hPreRender.remove then hPreRender:remove() end end)
        pcall(function() if hTrailRender and hTrailRender.remove then hTrailRender:remove() end end)
    end
end)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand('rearl', function()
        uiOpen[0] = not uiOpen[0]
    end)

    loadTrailTexture()
    wait(0)
end
