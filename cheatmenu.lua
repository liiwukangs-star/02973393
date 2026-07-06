script_name('Cheat Menu | Deprau')
script_version('2.0')
script_author('Deprau')
script_description('use: /cheatmenu')

local imgui    = require("mimgui")
local ffi      = require("ffi")
local memory   = require("memory")
local samem    = require("SAMemory")
local sampev   = require("samp.events")
local gta      = ffi.load("GTASA")
local hook     = require("monethook")
local json     = require("dkjson")
local inicfg   = require("inicfg")
local ltn12    = require("ltn12")
local widgets  = require("widgets")
local fa_solid = require("fAwesome6_solid")
local vector3d = require("vector3d")
local http     = require("socket.http")
local SAM = require("SAMemory")
SAM.require("CCamera")
local cam = SAM.camera
local mem   = require("memory")

function openLink(url)
    gta._Z12AND_OpenLinkPKc(url)
end

local gBase = MONET_GTASA_BASE
local gAddr = gBase + 0x002C1958

local gOld = mem.tostring(gAddr, 4, true)

local gPat = "\x00\x20\x70\x47"

local base = MONET_GTASA_BASE
local dpi  = MONET_DPI_SCALE or 1
local MDS  = (MONET_DPI_SCALE or 1.0) * 0.9

samem.require("CPed")
samem.require("CPlayerData")
samem.require("CCamera")
samem.require("CCamera")

ffi.cdef([[
    typedef struct {
        float x, y, z;
    } Vec3;

    typedef struct RwV3d {
        float x;
        float y;
        float z;
    } RwV3d;

    typedef struct CPed CPed;
    typedef struct CVector CVector;

    void _Z12AND_OpenLinkPKc(const char* link);

    void _ZN4CPed15GetBonePositionER5RwV3djb(
        void* ped,
        void* out,
        int boneId,
        bool unknown
    );

    void _ZN4CPed15GetBonePositionER5RwV3djb(
        void* thiz,
        RwV3d* posn,
        uint32_t bone,
        bool calledFromCam
    );

    void _ZN10CPlayerPed14ProcessControlEv(void* ped);
    void _ZN6CCheat25TogglePlayerInvincibilityEv();
    CPed _ZN4CCam17Process_AimWeaponERK7CVectorfff(
        CPed* Player,
        CVector* a2,
        float a3,
        float a4,
        float a5
    );

    float _ZN6CTimer12ms_fTimeStepE;
    void _Z12AND_OpenLinkPKc(const char* link);
    void _ZN6CCheat17WeaponSkillsCheatEv();
]])

local function ToggleWeaponSkills()
    gta._ZN6CCheat17WeaponSkillsCheatEv()
end

function openLink(url)
    gta._Z12AND_OpenLinkPKc(url)
end

local camera     = samem.camera
local player_ped = samem.cast("CPed **", samem.player_ped)

local ADDRESS         = base + 0x3C6D50
local ORIGINAL_CAMERA = memory.getfloat(ADDRESS, true)

local screenWidth, screenHeight = getScreenResolution()

local SCREEN_W = screenWidth
local SCREEN_H = screenHeight

local sizeX = screenWidth
local sizeY = screenHeight

local sw, sh = getScreenResolution()

local ignoredPlayers = {}

local vec3 = ffi.new("Vec3[1]")

local savedWeapon = -1
local lastWeapon  = -1
local lastAmmo    = 0

local active       = false
local tembak       = false
local PATCH_ACTIVE = false

local ORIGINAL_MEMORY = nil
local orig_get_water_level

local spd            = 2.0
local kecepatanAim   = 1.27
local circuloFOVAIM  = false

local BOTAO = 2

local qpqpqp = 4172632
local ununun = 18288
local zxzc   = 2

local tab       = imgui.new.int(1)
local activeTab = 2

local playerIdToAdd = ffi.new("int[1]", 0)
local mainGui = imgui.new.bool(false)

local bones = {
    3, 4, 5,
    51, 52,
    41, 42,
    31, 32, 33,
    21, 22, 23,
    2
}

local anim = {
    "GUNMOVE_L",
    "GUNMOVE_R",
    "GUNMOVE_FWD",
    "GUNMOVE_BWD"
}

local animAim = {
    "SPRINT_CIVI",
    "SPRINT_PANIC",
    "SWAT_RUN",
    "WOMAN_RUNPANIC",
    "FATSPRINT"
}

local DATA = {
    raioFov = 16.0,

    daftarTulang = {
        0,1,2,3,4,5,6,7,8,
        21,22,23,24,25,26,
        31,32,33,34,35,36,
        41,42,43,44,
        51,52,53,54,
        201,301,302
    }
}

local font = renderCreateFont("Arial", 12 * dpi, 1 + 4)

local tabOffsetX = -3 * dpi
local tabOffsetY =  0 * dpi
local tabSpacing =  0 * dpi
local tabSize    = 63 * dpi

local CFG = getWorkingDirectory() .. "/citmenudeprau.json"

local FONT_URL  = "https://github.com/konkeymong123-crypto/Pngjpg/raw/refs/heads/main/baflion-sans.black.otf"
local FONT_PATH = getWorkingDirectory() .. "/lib/deprau/baflion-sans.black.otf"

local fontTitle  = nil

local function isCamMode()
    local idx = tonumber(ffi.cast("uint8_t", camera.nActiveCam))

    if idx >= 0 and idx < 3 then
        local cam = camera.aCams[idx]
        local mode = tonumber(cam.nMode)

        return mode == 0x5 or mode == 0x7 or mode == 0x35 or mode == 0x41
    end

    return false
end

local function aimChk()
    if not cam or not cam.aCams then return false end

    local c = cam.aCams[0]
    if not c or not c.nMode then return false end

    local m = tonumber(c.nMode)

    return (
        m == 7  or
        m == 8  or
        m == 51 or
        m == 53
    )
end

local last = nil

local function setPatch(st)
    if last == st then return end
    last = st

    mem.copy(gAddr, st and gPat or gOld, 4, true)
end

local function setWeapon(id)
    setCurrentCharWeapon(PLAYER_PED, id)
end

local function getWeapon()
    return getCurrentCharWeapon(PLAYER_PED)
end

local function downloadFile(url, path)
    local file = io.open(path, "wb")

    if not file then
        return false
    end

    local ok = http.request({
        url  = url,
        sink = ltn12.sink.file(file)
    })

    return ok ~= nil
end

local function ensureFont()
    if not doesFileExist(FONT_PATH) then
        downloadFile(FONT_URL, FONT_PATH)
    end
end

local smoothSpeedValue = imgui.new.float(100.0)
local disableduck = imgui.new.bool(false)
local WeaponSkills = imgui.new.bool(false)
local enable = imgui.new.bool(false)
local sprinthook = imgui.new.bool(false)
local neverTired = imgui.new.bool(false)
local sensValue = imgui.new.float(5000.0)
local cjrunn = imgui.new.bool(false)
local delay = imgui.new.int(200)
local pt = imgui.new.int(1)
local fovktl = imgui.new.bool(false)
local fov = imgui.new.float(2.0)
local noanim = imgui.new.bool(false)
local double = imgui.new.bool(false)
local fastAim = imgui.new.bool(false)
local godmode = imgui.new.bool(false)
local collision = imgui.new.bool(false)
local waitt = imgui.new.int(200)
local on = imgui.new.bool(false)
local lastVehicle = nil
local heading = {
    enable = imgui.new.bool(false),
    value  = imgui.new.float(10.0)
}
local var1  = imgui.new.bool(false)
local var2  = imgui.new.bool(false)
local var3  = imgui.new.bool(false)
local var4  = imgui.new.bool(false)
local var5  = imgui.new.bool(false)
local var6  = imgui.new.bool(false)
local var7  = imgui.new.bool(false)
local var8  = imgui.new.bool(false)
local var9  = imgui.new.bool(false)
local var10 = imgui.new.bool(false)
local var19 = imgui.new.bool(false)
local var20 = imgui.new.bool(false)
local var21 = imgui.new.bool(false)
local var22 = imgui.new.bool(false)
local var23 = imgui.new.bool(false)
local var24 = imgui.new.bool(false)
local var25 = imgui.new.bool(false)
local var26 = imgui.new.bool(false)
local var27 = imgui.new.bool(false)
local var28 = imgui.new.bool(false)
local var29 = imgui.new.bool(false)
local var30 = imgui.new.bool(false)

local CFG = "config/cheatmenudeprau.json"

local function saveCfg()
    local data = {
        smoothSpeedValue = smoothSpeedValue[0],

        disableduck = disableduck[0],
        WeaponSkills = WeaponSkills[0],
        enable = enable[0],
        sprinthook = sprinthook[0],
        neverTired = neverTired[0],

        sensValue = sensValue[0],
        cjrunn = cjrunn[0],

        delay = delay[0],
        pt = pt[0],

        fovktl = fovktl[0],
        fov = fov[0],

        noanim = noanim[0],
        double = double[0],
        fastAim = fastAim[0],
        godmode = godmode[0],
        collision = collision[0],

        waitt = waitt[0],
        on = on[0],

        heading_enable = heading.enable[0],
        heading_value  = heading.value[0],

        var1  = var1[0],
        var2  = var2[0],
        var3  = var3[0],
        var4  = var4[0],
        var5  = var5[0],
        var6  = var6[0],
        var7  = var7[0],
        var8  = var8[0],
        var9  = var9[0],
        var10 = var10[0],

        var19 = var19[0],
        var20 = var20[0],
        var21 = var21[0],
        var22 = var22[0],
        var23 = var23[0],
        var24 = var24[0],
        var25 = var25[0],
        var26 = var26[0],
        var27 = var27[0],
        var28 = var28[0],
        var29 = var29[0],
        var30 = var30[0]
    }

    os.execute("mkdir config")

    local f = io.open(CFG, "w")
    if f then
        f:write(json.encode(data))
        f:close()
    end
end

local function loadCfg()
    local f = io.open(CFG, "r")
    if not f then return end

    local content = f:read("*a")
    f:close()

    local data = json.decode(content)
    if not data then return end

    if data.smoothSpeedValue ~= nil then smoothSpeedValue[0] = data.smoothSpeedValue end

    if data.disableduck ~= nil then disableduck[0] = data.disableduck end
    if data.WeaponSkills ~= nil then WeaponSkills[0] = data.WeaponSkills end
    if data.enable ~= nil then enable[0] = data.enable end
    if data.sprinthook ~= nil then sprinthook[0] = data.sprinthook end
    if data.neverTired ~= nil then neverTired[0] = data.neverTired end

    if data.sensValue ~= nil then sensValue[0] = data.sensValue end
    if data.cjrunn ~= nil then cjrunn[0] = data.cjrunn end

    if data.delay ~= nil then delay[0] = data.delay end
    if data.pt ~= nil then pt[0] = data.pt end

    if data.fovktl ~= nil then fovktl[0] = data.fovktl end
    if data.fov ~= nil then fov[0] = data.fov end

    if data.noanim ~= nil then noanim[0] = data.noanim end
    if data.double ~= nil then double[0] = data.double end
    if data.fastAim ~= nil then fastAim[0] = data.fastAim end
    if data.godmode ~= nil then godmode[0] = data.godmode end
    if data.collision ~= nil then collision[0] = data.collision end

    if data.waitt ~= nil then waitt[0] = data.waitt end
    if data.on ~= nil then on[0] = data.on end

    if data.heading_enable ~= nil then heading.enable[0] = data.heading_enable end
    if data.heading_value ~= nil then heading.value[0] = data.heading_value end

    if data.var1 ~= nil then var1[0] = data.var1 end
    if data.var2 ~= nil then var2[0] = data.var2 end
    if data.var3 ~= nil then var3[0] = data.var3 end
    if data.var4 ~= nil then var4[0] = data.var4 end
    if data.var5 ~= nil then var5[0] = data.var5 end
    if data.var6 ~= nil then var6[0] = data.var6 end
    if data.var7 ~= nil then var7[0] = data.var7 end
    if data.var8 ~= nil then var8[0] = data.var8 end
    if data.var9 ~= nil then var9[0] = data.var9 end
    if data.var10 ~= nil then var10[0] = data.var10 end

    if data.var19 ~= nil then var19[0] = data.var19 end
    if data.var20 ~= nil then var20[0] = data.var20 end
    if data.var21 ~= nil then var21[0] = data.var21 end
    if data.var22 ~= nil then var22[0] = data.var22 end
    if data.var23 ~= nil then var23[0] = data.var23 end
    if data.var24 ~= nil then var24[0] = data.var24 end
    if data.var25 ~= nil then var25[0] = data.var25 end
    if data.var26 ~= nil then var26[0] = data.var26 end
    if data.var27 ~= nil then var27[0] = data.var27 end
    if data.var28 ~= nil then var28[0] = data.var28 end
    if data.var29 ~= nil then var29[0] = data.var29 end
    if data.var30 ~= nil then var30[0] = data.var30 end
end

imgui.OnInitialize(function()
        darkgreentheme()

    fa_solid.Init(23 * dpi)

    local io = imgui.GetIO()

    io.IniFilename     = nil
    io.FontGlobalScale = MDS

    ensureFont()

    if doesFileExist(FONT_PATH) then
        fontTitle = io.Fonts:AddFontFromFileTTF(
            FONT_PATH,
            18 * dpi
        )

        io.Fonts:Build()
    end
end)

function darkgreentheme()
    imgui.SwitchContext()

    local style  = imgui.GetStyle()
    local colors = style.Colors
    local clr    = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowRounding    = 18.0 * dpi
    style.ChildRounding     = 12.0 * dpi
    style.FrameRounding     = 10.0 * dpi
    style.ScrollbarRounding = 10.0 * dpi
    style.GrabRounding      = 8.0 * dpi

    style.WindowBorderSize = 3.0 * dpi
    style.ChildBorderSize  = 2.0 * dpi
    style.FrameBorderSize  = 2.0 * dpi

    style.ScrollbarSize = 20.0 * dpi
    style.GrabMinSize   = 14.0 * dpi
    style.IndentSpacing = 25.0 * dpi

    style.ItemSpacing      = ImVec2(12 * dpi, 8 * dpi)
    style.ItemInnerSpacing = ImVec2(8 * dpi, 6 * dpi)

    style.WindowTitleAlign = ImVec2(0.5, 0.5)

    colors[clr.WindowBg] = ImVec4(1.00, 1.00, 0.00, 1.00)
    colors[clr.ChildBg]  = ImVec4(1.00, 1.00, 0.00, 1.00)

    colors[clr.Text]         = ImVec4(0.0, 0.0, 0.0, 1.0)
    colors[clr.Border]       = ImVec4(0.0, 0.0, 0.0, 1.0)
    colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)

    colors[clr.FrameBg]        = ImVec4(0.97, 0.97, 0.97, 1.00)
    colors[clr.FrameBgHovered] = ImVec4(0.97, 0.97, 0.97, 1.00)
    colors[clr.FrameBgActive]  = ImVec4(0.97, 0.97, 0.97, 1.00)

    colors[clr.SliderGrab]       = ImVec4(0.0, 0.0, 0.0, 1.0)
    colors[clr.SliderGrabActive] = ImVec4(0.0, 0.0, 0.0, 1.0)

    colors[clr.CheckMark] = ImVec4(0.0, 0.0, 0.0, 1.0)

    colors[clr.Button]        = ImVec4(0.0, 0.0, 0.0, 1.0)
    colors[clr.ButtonHovered] = ImVec4(0.90, 0.35, 0.25, 1.00)
    colors[clr.ButtonActive]  = ImVec4(0.70, 0.20, 0.10, 1.00)

colors[clr.ScrollbarBg]          = ImVec4(0.10, 0.10, 0.10, 0.50)
colors[clr.ScrollbarGrab]        = ImVec4(0.0, 0.0, 0.0, 1.0)
colors[clr.ScrollbarGrabHovered] = ImVec4(0.0, 0.0, 0.0, 1.0)
colors[clr.ScrollbarGrabActive]  = ImVec4(0.0, 0.0, 0.0, 1.0)
end

local function ambilPosisiTulang(ped, id)
    local ptr = ffi.cast("void*", getCharPointer(ped))
    gta._ZN4CPed15GetBonePositionER5RwV3djb(ptr, vec3, id, false)
    return vec3[0].x, vec3[0].y, vec3[0].z
end

local function posisiMiraLayar()
    if isCurrentCharWeapon(PLAYER_PED,34)
    or isCurrentCharWeapon(PLAYER_PED,35)
    or isCurrentCharWeapon(PLAYER_PED,36) then
        return convertGameScreenCoordsToWindowScreenCoords(319.9,224.7)
    else
        return convertGameScreenCoordsToWindowScreenCoords(332.9,194.7)
    end
end

local function cariTargetDiMira(fov)

    local mx,my = posisiMiraLayar()
    local px,py,pz = getCharCoordinates(PLAYER_PED)
    pz = pz + 0.7

    local closestPed = nil
    local closestDist = fov * fov

    for _, ped in ipairs(getAllChars()) do

        if ped ~= PLAYER_PED
        and doesCharExist(ped)
        and not isCharDead(ped)
        and isCharOnScreen(ped) then

            for i = 1, #DATA.daftarTulang do

                local id = DATA.daftarTulang[i]
                local x,y,z = ambilPosisiTulang(ped,id)

                if isLineOfSightClear(px,py,pz,x,y,z,true,true,false,true,false) then

                    local sx,sy = convert3DCoordsToScreen(x,y,z)

                    if sx and sy then

                        local dx = sx-mx
                        local dy = sy-my
                        local dist = dx*dx + dy*dy

                        if dist < closestDist then
                            closestDist = dist
                            closestPed = ped
                            break
                        end

                    end

                end

            end

        end

    end

    return closestPed
end

local wasDead = false

local function isPlayerAlive()
    return isSampAvailable()
    and sampIsLocalPlayerSpawned()
    and doesCharExist(PLAYER_PED)
    and not isCharDead(PLAYER_PED)
end

local function apply()
    if on[0] then
        for _, a in ipairs(anim) do
            setCharAnimSpeed(PLAYER_PED, a, spd)
        end
    end
end


local function isPlayerAiming()
    local camMode = camera.aCams[0].nMode
    return camMode == 7 or camMode == 8 or camMode == 51 or camMode == 53
end

local function isFirearmWeapon(id)
    return (id >= 22 and id <= 34) or id == 38
end

local function getPed()
    local ped = player_ped[0]
    if ped == nil or ped == samem.nullptr then return nil end
    return ped
end

local function getPlayerData()
    local ped = getPed()
    return ped and ped.pPlayerData or nil
end

local function getWeapon()
    if not doesCharExist(PLAYER_PED) then return -1 end
    return getCurrentCharWeapon(PLAYER_PED)
end

local function setWeaponSafe(id)
    if doesCharExist(PLAYER_PED) then
        setCurrentCharWeapon(PLAYER_PED, id)
    end
end

local function terapkanKecepatanAim()
    if var3[0] then
        for _, anim in ipairs(animAim) do
            setCharAnimSpeed(PLAYER_PED, anim, kecepatanAim)
        end
    end
end

local function applyPatch()
    if not PATCH_ACTIVE then
        if not ORIGINAL_MEMORY then
            ORIGINAL_MEMORY = memory.read(MONET_GTASA_BASE + qpqpqp, zxzc, true)
        end
        memory.write(MONET_GTASA_BASE + qpqpqp, ununun, zxzc, true)
        PATCH_ACTIVE = true
    end
end

local function restorePatch()
    if PATCH_ACTIVE and ORIGINAL_MEMORY then
        memory.write(MONET_GTASA_BASE + qpqpqp, ORIGINAL_MEMORY, zxzc, true)
        PATCH_ACTIVE = false
    end
end

function sampev.onSendAimSync(data)
    if not isPlayerAiming() then
        tembak = false
        restorePatch()
        return
    end
    if var25[0] then
        local ped = cariTargetDiMira(DATA.raioFov)
        if ped then
            applyPatch()
            tembak = true
        else
            tembak = false
            restorePatch()
        end
    elseif var26[0] then
        if isPlayerAiming() then
            applyPatch()
            tembak = true
        else
            tembak = false
            restorePatch()
        end
    else
        tembak = false
        restorePatch()
    end
end

function sampev.onSendPlayerSync(data)
    if not isPlayerAiming() then
        tembak = false
        restorePatch()
    end
    if tembak then
        local ped = PLAYER_PED
        if doesCharExist(ped) and not isCharInAnyCar(ped) then
            local weapon = getCurrentCharWeapon(ped)
            if isFirearmWeapon(weapon) then
                data.keys.secondaryFire_shoot = 1
            end
        end
    end
    if var23[0] and isPlayerAlive() and not isCharInAnyCar(PLAYER_PED) then
        local pdata = getPlayerData()
        if pdata then
            pdata.fSprintEnergy = 0.5
        end
        data.keysData = data.keysData + 8
    end
end

local whiteLine = imgui.ImVec4(0.0, 0.0, 0.0, 1.0)

local lineAnim = {}

local function getAnim(id)
    if not lineAnim[id] then
        lineAnim[id] = { t = 0 }
    end
    return lineAnim[id]
end

local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end
function CustomButton(label, subtitle, size)
    local pos = imgui.GetCursorScreenPos()

    imgui.InvisibleButton(label, size)

    local clicked = imgui.IsItemClicked()

    imgui.PushFont(fontTitle)
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.0, 0.0, 0.0, 1.0))

    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + 12 * dpi, pos.y + 5 * dpi))
    imgui.SetWindowFontScale(0.60)
    imgui.Text(label)

    imgui.SetCursorScreenPos(imgui.ImVec2(pos.x + 12 * dpi, pos.y + 26 * dpi))
    imgui.SetWindowFontScale(0.45)
    imgui.Text(subtitle)

    imgui.SetWindowFontScale(1.0)

    imgui.PopStyleColor()
    imgui.PopFont()

    return clicked
end

local function iconTab(icon, id)

    local selected = (tab[0] == id)

    imgui.SetCursorPosX(imgui.GetCursorPosX() + tabOffsetX)
    imgui.Dummy(imgui.ImVec2(0, tabOffsetY))

    local p = imgui.GetCursorScreenPos()
    local size = imgui.ImVec2(tabSize, tabSize)

    imgui.InvisibleButton("##tab" .. id, size)

    local clicked = imgui.IsItemClicked()
    local active = imgui.IsItemActive()

    if clicked then
        tab[0] = id
        getAnim(id).start = os.clock()
    end

    local draw = imgui.GetWindowDrawList()

    local bgCol = selected
        and imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
        or imgui.ImVec4(0.0, 0.0, 0.0, 1.0)

    if selected or active then
        draw:AddRectFilled(
            p,
            imgui.ImVec2(p.x + size.x, p.y + size.y),
            imgui.GetColorU32Vec4(bgCol),
            8.0
        )
    else
        draw:AddRectFilled(
            p,
            imgui.ImVec2(p.x + size.x, p.y + size.y),
            imgui.GetColorU32Vec4(bgCol),
            8.0
        )
    end
    
    local a = getAnim(id)
    local target = selected and 1.0 or 0.0
    local speed = 9 * dpi
    a.t = a.t + (target - a.t) * (speed * imgui.GetIO().DeltaTime)
    a.t = clamp(a.t, 0.0, 1.0)
    local smooth = a.t * a.t * (3 - 2 * a.t)
    local maxH = tabSize - 10 * dpi
    local h = smooth * maxH

    if h > 0.05 then
        local centerY = p.y + (size.y / 2)
        local thickness = 5 * dpi

        draw:AddRectFilled(
            imgui.ImVec2(p.x - thickness, centerY - (h / 2)),
            imgui.ImVec2(p.x, centerY + (h / 2)),
            imgui.GetColorU32Vec4(whiteLine),
            3.0
        )
    end

    local iconSize = imgui.CalcTextSize(icon)
    draw:AddText(
        imgui.ImVec2(
            p.x + (size.x - iconSize.x) / 2,
            p.y + (size.y - iconSize.y) / 2 + 9 * dpi
        ),
        imgui.GetColorU32Vec4(
            selected and imgui.ImVec4(0.0, 0.0, 0.0, 1.0) or imgui.ImVec4(1,1,1,1)
        ),
        icon
    )

    imgui.Dummy(imgui.ImVec2(0, tabSpacing))
end

local headerPos   = imgui.ImVec2(80 * dpi, 6 * dpi)
local headerSize  = imgui.ImVec2(283 * dpi, 45 * dpi)
local textOffset  = imgui.ImVec2(10 * dpi, 13 * dpi)

local closeCfg = {
    x = 260 * dpi,   -- sebelumnya -23*dpi (dihitung dari kanan header)
    y = -12 * dpi,
    scale = 1.2
}

local aimAddr    = gta._ZN4CCam17Process_AimWeaponERK7CVectorfff

local origAimProcess

local aimLocked = false
local animAim = {
    "SPRINT_CIVI",
    "SPRINT_PANIC",
    "SWAT_RUN",
    "WOMAN_RUNPANIC",
    "FATSPRINT"
}
local kecepatanAim = 1.27
local function terapkanKecepatanAim()
    if sprinthook[0] then
        for _, anim in ipairs(animAim) do
            setCharAnimSpeed(PLAYER_PED, anim, kecepatanAim)
        end
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then
    restorePatch()
        memory.setfloat(ADDRESS, ORIGINAL_CAMERA, true)
    mem.copy(gAddr, gOld, 4, true)
ffi.copy(ptr, orig, 4)
        if origPlayerProcess then
            hook.delete(origPlayerProcess)
        end
        if origAimProcess then
            hook.delete(origAimProcess)
        end
    end
end

function getAmmoInClip()
    local pedPtr = getCharPointer(PLAYER_PED)
    local weaponId = getCurrentCharWeapon(PLAYER_PED)
    local slot = getWeapontypeSlot(weaponId)
    local weaponAddr = pedPtr + 0x5A0 + slot * 0x1C
    return memory.getuint32(weaponAddr + 0x0C)
end

imgui.OnFrame(
function() return mainGui[0] end,
function()

imgui.SetNextWindowSize(imgui.ImVec2(370*dpi,264*dpi),imgui.Cond.Always)

imgui.Begin("Crosshair Only",mainGui,
imgui.WindowFlags.NoResize+
imgui.WindowFlags.NoCollapse+
imgui.WindowFlags.NoScrollbar+
imgui.WindowFlags.NoTitleBar)

imgui.Columns(2,nil,false)
imgui.SetColumnWidth(0,80*dpi)

imgui.SetWindowFontScale(1.4)
iconTab(fa_solid.GUN,1)
iconTab(fa_solid.USER,2)
iconTab(fa_solid.ELLIPSIS,3)
imgui.SetWindowFontScale(1.1)

imgui.NextColumn()
imgui.SetCursorPos(headerPos)

imgui.PushStyleColor(imgui.Col.ChildBg,imgui.ImVec4(1,1,1,1))
imgui.PushStyleColor(imgui.Col.Border,imgui.ImVec4(0,0,0,1))
imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize,2*dpi)

imgui.BeginChild("##header",headerSize,true,
imgui.WindowFlags.NoScrollbar+
imgui.WindowFlags.NoScrollWithMouse)

local p=imgui.GetCursorScreenPos()
local dl=imgui.GetWindowDrawList()
local radius=9*dpi*closeCfg.scale

imgui.SetCursorPos(textOffset)

local function drawTitle()
imgui.PushFont(fontTitle)
if tab[0]==1 then imgui.Text("Weapon")
elseif tab[0]==2 then imgui.Text("Player")
else imgui.Text("Other") end
imgui.PopFont()
end

drawTitle()

imgui.SetCursorPos(imgui.ImVec2(
imgui.GetCursorPosX()+146*dpi,   -- sebelumnya +170*dpi
imgui.GetCursorPosY()-41*dpi     -- sebelumnya -36*dpi
))

local closeCenter=imgui.ImVec2(
p.x+closeCfg.x,          -- sebelumnya p.x+headerSize.x+closeCfg.x
p.y+headerSize.y/2+closeCfg.y
)

if CustomButton(
        "  DEPRAU",
        "©05/24/2026",
        imgui.ImVec2(93 * dpi, 35 * dpi),
        imgui.ImVec4(1, 1, 1, 1),
        imgui.ImVec4(0.9, 0.9, 0.9, 1),
        imgui.ImVec4(0.8, 0.8, 0.8, 1),
        imgui.ImVec4(1, 0, 0, 1)
    ) then
        openLink("https://youtube.com/@deprauu")
    end
    
local closeHovered=imgui.IsMouseHoveringRect(
imgui.ImVec2(closeCenter.x-radius,closeCenter.y-radius),
imgui.ImVec2(closeCenter.x+radius,closeCenter.y+radius)
)

if closeHovered and imgui.IsMouseClicked(0) then
mainGui[0]=false end

dl:AddCircleFilled(closeCenter,radius,
imgui.GetColorU32Vec4(
closeHovered and imgui.ImVec4(1,0.3,0.3,1)
or imgui.ImVec4(0.0, 0.0, 0.0, 1.0)
),32)

imgui.EndChild()
imgui.PopStyleVar()
imgui.PopStyleColor(2)
local function drawTab1()
imgui.BeginChild("##scroll_checkbox",imgui.ImVec2(0,0),false,imgui.WindowFlags.AlwaysVerticalScrollbar)

if imgui.Checkbox("360°",var21) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Unlimited Ammo",var29) then saveCfg() end
if imgui.Checkbox("Trigger Bot",var25) then
    if var25[0] then var26[0]=false end
    saveCfg()
end
imgui.SameLine()
if imgui.Checkbox("Auto Shot",var26) then
    if var26[0] then var25[0]=false end
    saveCfg()
end

if imgui.Checkbox("Auto Scroll",var22) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("No Spread",var20) then saveCfg() end

if imgui.Checkbox("No Reload",var30) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Auto Scope",var24) then saveCfg() end

if imgui.Checkbox("Rapid Fire",var27) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Max Dmg",double) then saveCfg() end

if imgui.Checkbox("Auto Switch",enable) then saveCfg() end
imgui.PushItemWidth(130 * dpi)
if imgui.SliderInt("##delay", delay, 0, 1000, "%.1f") then
    saveCfg()
end
imgui.PopItemWidth()
imgui.EndChild()
end


local function drawTab2()
imgui.BeginChild("##scroll_vehicle",imgui.ImVec2(0,0),false,imgui.WindowFlags.AlwaysVerticalScrollbar)

if imgui.Checkbox("Anti Stun",var19) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Sprint Hook",sprinthook) then saveCfg() end

if imgui.Checkbox("Infinity Run",neverTired) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Anti Duck",disableduck) then saveCfg() end

if imgui.Checkbox("No Anim",noanim) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Weapon Skills",WeaponSkills) then
    ToggleWeaponSkills()
    saveCfg()
end

if imgui.Checkbox("Fast Jiggle",fastAim) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("Analog Run",var23) then saveCfg() end

if imgui.Checkbox("God Mode",godmode) then saveCfg() end
imgui.SameLine()
if imgui.Checkbox("No Collision",collision) then saveCfg() end

if imgui.Checkbox("Fast Rotation ##heading",heading.enable) then
    saveCfg()
end
imgui.SameLine()
if imgui.Checkbox("Cj Run",cjrunn) then saveCfg() end
imgui.PushItemWidth(130 * dpi)
if imgui.SliderFloat("##heading_value", heading.value, 10.0, 100.0, "%.1f") then
    saveCfg()
end
imgui.PopItemWidth()
imgui.EndChild()
end


local function drawTab3()
imgui.BeginChild("##scroll_other",imgui.ImVec2(0,0),false,imgui.WindowFlags.AlwaysVerticalScrollbar)

if imgui.Checkbox("FOV",fovktl) then
    saveCfg()
end

imgui.PushItemWidth(130 * dpi)
if imgui.SliderFloat("##fov", fov, 0.0, 140.0, "%.1f") then
    saveCfg()
end
imgui.PopItemWidth()

imgui.EndChild()
end


if tab[0]==1 then drawTab1()
elseif tab[0]==2 then drawTab2()
elseif tab[0]==3 then drawTab3() end

imgui.Columns(1)
imgui.End()
end)
sampRegisterChatCommand("cheatmenu", function()
    mainGui[0] = not mainGui[0]
end)

local function isAimMode()
    local idx = tonumber(ffi.cast("uint8_t", camera.nActiveCam))

    if idx >= 0 and idx < 3 then
        local cam = camera.aCams[idx]
        local mode = tonumber(cam.nMode)

        return mode == 0x5 or mode == 0x7 or mode == 0x35 or mode == 0x41
    end

    return false
end

function isAiming()
    local camMode = camera.aCams[0].nMode
    return camMode == 7 or camMode == 8 or camMode == 51 or camMode == 53
end

function onReceiveRpc(rpcId, data)
    if noanim[0] and rpcId == 86 then
        return false
    end
end

function onSendRpc(rpcId, bs, priority, reliability, orderingChannel, shiftTs)
	if rpcId == 115 then
		local act = raknetBitStreamReadBool(bs)
		local playerId = raknetBitStreamReadInt16(bs)
		local playerDamage = raknetBitStreamReadFloat(bs)
		local playerWeapon = raknetBitStreamReadInt32(bs)
		local playerBodypart = raknetBitStreamReadInt32(bs)

		if not act then
			if double[0] then
				sampSendGiveDamage(playerId, playerDamage, playerWeapon, playerBodypart)
				sampSendGiveDamage(playerId, playerDamage, playerWeapon, playerBodypart)
				sampSendGiveDamage(playerId, playerDamage, playerWeapon, playerBodypart)
				sampSendGiveDamage(playerId, playerDamage, playerWeapon, playerBodypart)
			end
		end
	end
end

local animsAim = {
    "GUNMOVE_L",
    "GUNMOVE_R",
    "GUNMOVE_FWD",
    "GUNMOVE_BWD"
}

local function applyAimSpeed()
    local speed = fastAim[0] and 1.50 or 1.0

    for _, anim in ipairs(animsAim) do
        setCharAnimSpeed(PLAYER_PED, anim, speed)
    end
end


function main()
    repeat wait(100) until isSampAvailable()
    loadCfg()         
    local lastPress = false
    local lastWep = -1
    local lastAmmo = 0
    local fistMode = false
    local deadState = false
    local spamUntil = 0
    terapkanKecepatanAim()
    while true do
        wait(0)
        applyAimSpeed()
        local alive = isPlayerAlive()

        local aimState = false
        if disableduck[0] and alive then
            aimState = aimChk()
        end
        setPatch(aimState)

        if not alive then
            if not deadState then
                deadState = true

                
                restorePatch()

                memory.setfloat(ADDRESS, ORIGINAL_CAMERA, true)

                local p = getPlayerData()
                if p then
                    p.bFreeAiming = false
                end
            end

        else
            deadState = false

            local ped = getPed()
            local pdata = getPlayerData()

            if ped then

                terapkanKecepatanAim()
                apply()

                ped.fHeadingChangeRate =
                    heading.enable[0] and heading.value[0] or 10.0

                if var2[0] then
                    setAnimGroupForChar(PLAYER_PED, "PLAYER")
                else
                    setAnimGroupForChar(
                        PLAYER_PED,
                        usePlayerAnimGroup and "PLAYER"
                        or (isCharMale(PLAYER_PED) and "MAN" or "WOMAN")
                    )
                end

                if var19[0] then
                    local animList = {
                        "DAM_armL_frmBK","DAM_armL_frmFT","DAM_armL_frmLT",
                        "DAM_armR_frmBK","DAM_armR_frmFT","DAM_armR_frmRT",
                        "DAM_LegL_frmBK","DAM_LegL_frmFT","DAM_LegL_frmLT",
                        "DAM_LegR_frmBK","DAM_LegR_frmFT","DAM_LegR_frmRT",
                        "DAM_stomach_frmBK","DAM_stomach_frmFT",
                        "DAM_stomach_frmLT","DAM_stomach_frmRT"
                    }

                    for _, a in ipairs(animList) do
                        setCharAnimSpeed(PLAYER_PED, a, 999.0)
                    end

                    setCharProofs(
                        PLAYER_PED,
                        true,
                        true,
                        true,
                        true,
                        true
                    )
                else
                    setCharProofs(
                        PLAYER_PED,
                        false,
                        false,
                        false,
                        false,
                        false
                    )
                end

                memory.setfloat(
                    ADDRESS,
                    var21[0] and 1.0 or ORIGINAL_CAMERA,
                    true
                )

                local wep = getCurrentCharWeapon(PLAYER_PED)

                            if not var24[0] then
                fistMode = false
                lastPressedInfo = false
            else
                if isWidgetPressed(WIDGET_PLAYER_INFO) then
                    if not lastPressedInfo and weapon ~= 0 then
                        fistMode = true
                        spamUntil = os.clock() + 0.35
                    end
                    lastPressedInfo = true
                else
                    lastPressedInfo = false
                end
            end

            if fistMode and spamUntil then
                if os.clock() < spamUntil then
                    setCurrentCharWeapon(PLAYER_PED, 0)
                else
                    fistMode = false
                end
            end

            if pdata and var24[0] then
                weapon = getCurrentCharWeapon(PLAYER_PED)
                if weapon ~= 0 and isFirearmWeapon(weapon) then
                    pdata.bFreeAiming = true
                end
            end
            
                if fovktl[0] then
            cameraSetLerpFov(
                fov[0],
                fov[0],
                1000,
                false
            )
        end
                if var27[0] then
                    local animList = {
                        "PYTHON_CROUCHFIRE","PYTHON_FIRE",
                        "PYTHON_FIRE_POOR","PYTHON_CROCUCHRELOAD",

                        "RIFLE_CROUCHFIRE","RIFLE_CROUCHLOAD",
                        "RIFLE_FIRE","RIFLE_FIRE_POOR","RIFLE_LOAD",

                        "SHOTGUN_CROUCHFIRE","SHOTGUN_FIRE",
                        "SHOTGUN_FIRE_POOR",

                        "SILENCED_CROUCH_RELOAD",
                        "SILENCED_CROUCH_FIRE",
                        "SILENCED_FIRE",
                        "SILENCED_RELOAD",

                        "TEC_crouchfire","TEC_crouchreload",
                        "TEC_fire","TEC_reload",

                        "UZI_crouchfire","UZI_crouchreload",
                        "UZI_fire","UZI_fire_poor","UZI_reload",

                        "idle_rocket","Rocket_Fire",
                        "run_rocket","walk_rocket",
                        "WALK_start_rocket","WEAPON_sniper"
                    }

                    for _, a in ipairs(animList) do
                        setCharAnimSpeed(PLAYER_PED, a, 1.3)
                    end
                end

                if var30[0] then
                    if isCharShooting(PLAYER_PED)
                    and not isCharDead(PLAYER_PED) then

                        local w = getCurrentCharWeapon(PLAYER_PED)

                        if w ~= 0 then
                            giveWeaponToChar(PLAYER_PED, w, 9999)
                        end
                    end
                end

                if var22[0] and isAimMode() then
                    local w = getCurrentCharWeapon(PLAYER_PED)

                    if w ~= 0 then
                        local ammo = getAmmoInClip()

                        if ammo <= pt[0] then
                            setCurrentCharWeapon(PLAYER_PED, 0)
                            wait(waitt[0])
                            setCurrentCharWeapon(PLAYER_PED, w)
                        end
                    end
                end
if cjrunn[0] then
                setAnimGroupForChar(PLAYER_PED, "PLAYER")
		else
			setAnimGroupForChar(PLAYER_PED, usePlayerAnimGroup and "PLAYER" or isCharMale(PLAYER_PED) and "MAN" or "WOMAN")
		end
                if var29[0] then
                    local w = getCurrentCharWeapon(PLAYER_PED)

                    if w ~= 0 then
                        local ammo = getAmmoInCharWeapon(PLAYER_PED, w)

                        if w ~= lastWep then
                            lastWep = w
                            lastAmmo = ammo
                        end

                        if ammo < lastAmmo then
                            setCharAmmo(PLAYER_PED, w, lastAmmo)
                        else
                            lastAmmo = ammo
                        end
                    end
                end
                if collision[0] then
    for _, ped in ipairs(getAllChars()) do
        if doesCharExist(ped) and ped ~= PLAYER_PED then
            setCharCollision(ped, false)
        end
    end
end
if neverTired[0] then
            setPlayerNeverGetsTired(PLAYER_HANDLE, true)
        else
            setPlayerNeverGetsTired(PLAYER_HANDLE, false)
        end
                if var20[0] then
                    local p = player_ped[0]

                    if p ~= nil and p ~= samem.nullptr then
                        if p.pPlayerData ~= samem.nullptr then
                            p.pPlayerData.fAttackButtonCounter = 0.0
                        end
                    end
                end
            end
        end

        if enable[0] and alive then

            local camMode = isCamMode()
            local pressed = isWidgetPressedEx(0xA0, 0)

            if camMode and pressed and not active then

                savedWeapon = getWeapon()

                if savedWeapon ~= 0 then
                    setWeapon(0)
                end

                active = true

                lua_thread.create(function()
                    wait(delay[0])

                    if active and savedWeapon ~= 0 then
                        setWeapon(savedWeapon)
                    end

                    active = false
                end)
            end

        else
            active = false
        end
    end
end
