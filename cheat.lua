script_name("CHEAT MENU")
script_author("Deprau")
local ffi = require("ffi")
local memory = require("memory")
local imgui = require("mimgui")
local gta = ffi.load("GTASA")
local SAMemory = require "SAMemory"
SAMemory.require("CCamera")
local camera = SAMemory.camera
local samem = require "SAMemory"
samem.require("CPed")
samem.require("CPlayerData")
local playerPed = samem.player_ped
local player_ped = samem.cast("CPed **", samem.player_ped)
require 'widgets'
local imgui = require 'mimgui'
local new   = imgui.new
local cf    = require 'jsoncfg'
local ffi   = require("ffi")
local faicons = require('fAwesome6')
local gta = ffi.load("GTASA")
local sampfuncs = require 'sampfuncs'
local raknet = require 'samp.raknet'
require 'samp.synchronization'
local sampev = require "samp.events"
local event = require "lib.samp.events"

ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]
function openLink(url) gta._Z12AND_OpenLinkPKc(url) end

local window = imgui.new.bool(false)

local chbxnoreload = imgui.new.bool(false)
local rapidf = imgui.new.bool(false)
local cbxgm = imgui.new.bool(false)

local inicfg = require 'inicfg'

local cfg = inicfg.load({
    menuC = {
        autoFreeAim      = false,
        aktifFovTrigger  = false,
        aktifAutoTrigger = false,
        norecoil         = false,
        aimCamera        = false,
        antiblock        = false,
        sprintEnabled    = false,
        enableProofs     = false,
        cjrunn           = false,
        aktifFastAim     = false,
        fastRun          = false,
        headingEnable    = false,
        headingValue     = 10.0
    }
}, "menuC")

local autoFreeAim      = imgui.new.bool(cfg.menuC.autoFreeAim)
local aktifFovTrigger  = imgui.new.bool(cfg.menuC.aktifFovTrigger)
local aktifAutoTrigger = imgui.new.bool(cfg.menuC.aktifAutoTrigger)
local norecoil         = imgui.new.bool(cfg.menuC.norecoil)
local aimCamera        = imgui.new.bool(cfg.menuC.aimCamera)
local antiblock        = imgui.new.bool(cfg.menuC.antiblock)
local sprintEnabled    = imgui.new.bool(cfg.menuC.sprintEnabled)
local enableProofs     = imgui.new.bool(cfg.menuC.enableProofs)
local cjrunn           = imgui.new.bool(cfg.menuC.cjrunn)
local aktifFastAim     = imgui.new.bool(cfg.menuC.aktifFastAim)
local on               = imgui.new.bool(cfg.menuC.fastRun)

local heading = {
    enable = imgui.new.bool(cfg.menuC.headingEnable),
    value  = imgui.new.float(cfg.menuC.headingValue)
}

function saveset()
    cfg.menuC.autoFreeAim      = autoFreeAim[0]
    cfg.menuC.aktifFovTrigger  = aktifFovTrigger[0]
    cfg.menuC.aktifAutoTrigger = aktifAutoTrigger[0]
    cfg.menuC.norecoil         = norecoil[0]
    cfg.menuC.aimCamera        = aimCamera[0]
    cfg.menuC.antiblock        = antiblock[0]
    cfg.menuC.sprintEnabled    = sprintEnabled[0]
    cfg.menuC.enableProofs     = enableProofs[0]
    cfg.menuC.cjrunn           = cjrunn[0]
    cfg.menuC.aktifFastAim     = aktifFastAim[0]
    cfg.menuC.fastRun          = on[0]
    cfg.menuC.headingEnable    = heading.enable[0]
    cfg.menuC.headingValue     = heading.value[0]

    inicfg.save(cfg, "menuC")
    sampAddChatMessage("Config disimpan!", -1)
end

local lastWeapon = -1
local lastAmmo = 0
local spd = 2.0

local anim = {
    "GUNMOVE_L", "GUNMOVE_R", "GUNMOVE_FWD", "GUNMOVE_BWD"
}

local function apply()
    if on[0] then
        for _, a in ipairs(anim) do
            setCharAnimSpeed(PLAYER_PED, a, spd)
        end
    end
end

local animAim = {
    "SPRINT_CIVI",
    "SPRINT_PANIC",
    "SWAT_RUN",
    "WOMAN_RUNPANIC",
    "FATSPRINT"
}
local kecepatanAim = 1.27

local ADDRESS = MONET_GTASA_BASE + 0x3C6D50
local ORIGINAL_CAMERA = memory.getfloat(ADDRESS, true)

ffi.cdef[[
typedef struct { float x, y, z; } Vec3;
void _ZN4CPed15GetBonePositionER5RwV3djb(void* ped, void* out, int boneId, bool unknown);
]]

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

local CODIGOFDS  = 4172632
local CODIGOFDS2 = 18288
local CODIGOFDS3 = 2

local vec3 = ffi.new("Vec3[1]")

local ORIGINAL_MEMORY = nil
local PATCH_ACTIVE = false
local tembak = false

local dpi = MONET_DPI_SCALE or 1
local MDS = (MONET_DPI_SCALE or 1.0) * 1.2
local FONT_PATH = getWorkingDirectory() .. '/lib/font/Pricedown.otf'
local fontTitle = nil
local fontAwesome = nil

local wasDead = false

local function isPlayerAlive()
    return isSampAvailable()
    and sampIsLocalPlayerSpawned()
    and doesCharExist(PLAYER_PED)
    and not isCharDead(PLAYER_PED)
end

local function forceDisableAll()
    aktifFovTrigger[0]  = false
    aktifAutoTrigger[0] = false
    norecoil[0]         = false
    aimCamera[0]        = false
    antiblock[0]        = false
    sprintEnabled[0]    = false
    enableProofs[0]     = false
    cjrunn[0]           = false
    aktifFastAim[0]     = false
    on[0]               = false
    autoFreeAim[0]      = false
    rapidf[0]           = false
    chbxnoreload[0]     = false
    cbxgm[0]            = false
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    local style = imgui.GetStyle()
    io.IniFilename = nil

    if doesFileExist(FONT_PATH) then
        fontTitle = io.Fonts:AddFontFromFileTTF(FONT_PATH, 20 * dpi)
        io.Fonts:Build()
    end

    io.FontGlobalScale = MDS
    style:ScaleAllSizes(MDS)

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    fontAwesome = io.Fonts:AddFontFromMemoryCompressedBase85TTF(
        faicons.get_font_data_base85('solid'),
        17,
        config,
        iconRanges
    )
end)

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

local function ambilPosisiTulang(ped, id)
    local ptr = ffi.cast("void*", getCharPointer(ped))
    gta._ZN4CPed15GetBonePositionER5RwV3djb(ptr, vec3, id, false)
    return vec3[0].x, vec3[0].y, vec3[0].z
end

local function terapkanKecepatanAim()
    if aktifFastAim[0] then
        for _, anim in ipairs(animAim) do
            setCharAnimSpeed(PLAYER_PED, anim, kecepatanAim)
        end
    end
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

local function applyPatch()
    if not PATCH_ACTIVE then
        if not ORIGINAL_MEMORY then
            ORIGINAL_MEMORY = memory.read(MONET_GTASA_BASE + CODIGOFDS, CODIGOFDS3, true)
        end
        memory.write(MONET_GTASA_BASE + CODIGOFDS, CODIGOFDS2, CODIGOFDS3, true)
        PATCH_ACTIVE = true
    end
end

local function restorePatch()
    if PATCH_ACTIVE and ORIGINAL_MEMORY then
        memory.write(MONET_GTASA_BASE + CODIGOFDS, ORIGINAL_MEMORY, CODIGOFDS3, true)
        PATCH_ACTIVE = false
    end
end

function sampev.onSendAimSync(data)
    if not isPlayerAiming() then
        tembak = false
        restorePatch()
        return
    end
    if aktifFovTrigger[0] then
        local ped = cariTargetDiMira(DATA.raioFov)
        if ped then
            applyPatch()
            tembak = true
        else
            tembak = false
            restorePatch()
        end
    elseif aktifAutoTrigger[0] then
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

    -- AnalogRun
    if sprintEnabled[0] and isPlayerAlive() and not isCharInAnyCar(PLAYER_PED) then
        local pdata = getPlayerData()
        if pdata then
            pdata.fSprintEnergy = 0.5
        end
        data.keysData = data.keysData + 8
    end
end

function main()
    repeat 
        wait(0) 
    until sampIsLocalPlayerSpawned()

    sampRegisterChatCommand(".cm", function()
        window[0] = not window[0]
    end)
    
    local lastPressedInfo = false
    local lastWeapon = -1
    local fistMode = false

    while true do
        wait(0)

        local alive = isPlayerAlive()

        if not alive then
            if not wasDead then
                wasDead = true
                forceDisableAll()
                restorePatch()
                memory.setfloat(ADDRESS, ORIGINAL_CAMERA, true)
            end
        else
            wasDead = false

            local weapon = getWeapon()
            local pdata = getPlayerData()
            local ped = getPed()

            terapkanKecepatanAim()
            apply()

            if aimCamera[0] then
                memory.setfloat(ADDRESS, 1, true)
            else
                memory.setfloat(ADDRESS, ORIGINAL_CAMERA, true)
            end

            weapon = getCurrentCharWeapon(PLAYER_PED)

            if not autoFreeAim[0] then
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

            if fistMode and spamUntil and os.clock() < spamUntil then
                setCurrentCharWeapon(PLAYER_PED, 0)
            end

            if fistMode and spamUntil and os.clock() >= spamUntil then
                fistMode = false
            end

            if pdata and autoFreeAim[0] then
                weapon = getCurrentCharWeapon(PLAYER_PED)
                if weapon ~= 0 and isFirearmWeapon(weapon) then
                    pdata.bFreeAiming = true
                end
            end

            if norecoil[0] then
                if playerPed[0] ~= nil and playerPed[0] ~= samem.nullptr then
                    if playerPed[0].pPlayerData ~= samem.nullptr then
                        playerPed[0].pPlayerData.fAttackButtonCounter = 0
                    end
                end
            end
        end
    end
end

imgui.OnFrame(
    function() return window[0] end,
    function()
        darkgreentheme()
        imgui.SetNextWindowSize(imgui.ImVec2(0, 0), imgui.Cond.FirstUseEver)

        if imgui.Begin("Cheat Menu", window,
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoScrollbar) then

            local url = "Https://youtube.com/@deprauu"
            local windowWidth = imgui.GetWindowSize().x
            local textWidth = imgui.CalcTextSize(url).x
            local offsetX = 56

            imgui.SetCursorPosX((windowWidth - textWidth) / 2 + offsetX)

            local scale = 0.7
            imgui.SetWindowFontScale(scale)
            imgui.TextColored(imgui.ImVec4(1,1,1,1), url)
            imgui.SetWindowFontScale(1.0)

            if imgui.IsItemClicked() then
                openLink(url)
            end

            -- Line 1
            if imgui.Checkbox("TriggerBot", aktifFovTrigger) then
                addOneOffSound(0,0,0,1149)
                if aktifFovTrigger[0] then
                    aktifAutoTrigger[0] = false
                end
            end

            imgui.SameLine()

            if imgui.Checkbox("AutoShot", aktifAutoTrigger) then
                addOneOffSound(0,0,0,1149)
                if aktifAutoTrigger[0] then
                    aktifFovTrigger[0] = false
                end
            end

            imgui.Spacing()
            imgui.Spacing()

            -- Line 2
            if imgui.Checkbox("NoSpread", norecoil) then
                addOneOffSound(0,0,0,1149)
            end

            imgui.SameLine()

            if imgui.Checkbox("360°", aimCamera) then
                addOneOffSound(0,0,0,1149)
            end

            imgui.Spacing()
            imgui.Spacing()

            -- Line 3
            if imgui.Checkbox("AnalogRun", sprintEnabled) then
                addOneOffSound(0,0,0,1149)
            end

            imgui.SameLine()

            if imgui.Checkbox("AutoScope", autoFreeAim) then
                addOneOffSound(0,0,0,1149)
            end

            imgui.End()
        end
    end)
function onScriptTerminate(script, quitGame)
    if script == thisScript() then
        restorePatch()
        memory.setfloat(ADDRESS, ORIGINAL_CAMERA, true)
    end
end

function darkgreentheme()
    local style = imgui.GetStyle()
    style.Alpha = 1
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 16
    style.WindowBorderSize = 1
    style.WindowMinSize = imgui.ImVec2(32, 32)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildRounding = 12
    style.ChildBorderSize = 1
    style.PopupRounding = 14
    style.PopupBorderSize = 1
    style.FramePadding = imgui.ImVec2(4, 4)
    style.FrameRounding = 6
    style.FrameBorderSize = 0
    style.GrabMinSize = 4
    style.GrabRounding = 4
    style.ScrollbarSize = 10
    style.ScrollbarRounding = 6
    style.TabRounding = 12
end
