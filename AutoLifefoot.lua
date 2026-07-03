local ffi = require("ffi")
local memory = require("memory")
local imgui = require("mimgui")
local gta = ffi.load("GTASA")
local samem = require "SAMemory"
local inicfg = require "inicfg"
local faicons = require('fAwesome6')

samem.require("CPed")
samem.require("CPlayerData")
local imgui  = require "mimgui"
local samem  = require "SAMemory"
local sampev = require "samp.events"

samem.require "CPed"
samem.require "CPlayerData"
local camera = samem.camera
local playerPed = samem.player_ped
local player_ped = samem.cast("CPed **", samem.player_ped)

ffi.cdef[[void _Z12AND_OpenLinkPKc(const char* link);]]

function openLink(url)
    gta._Z12AND_OpenLinkPKc(url)
end

local window = imgui.new.bool(false)

local inicfg = require "inicfg"

local cfg = inicfg.load({
    Setting = {
        EnableMain        = true,
        UseBulletSync     = false,
        UseGiveDamage     = false,
        SprintSpeed       = 1.0,
        ResetDuration     = 2000,
        EnableWeaponReset = true,
        RestoreDelay      = 500
    }
}, "autolifefoot")

local EnableMain        = imgui.new.bool(cfg.Setting.EnableMain)
local UseBulletSync     = imgui.new.bool(cfg.Setting.UseBulletSync)
local UseGiveDamage     = imgui.new.bool(cfg.Setting.UseGiveDamage)
local SprintSpeed       = imgui.new.float(cfg.Setting.SprintSpeed)
local ResetDuration     = imgui.new.int(cfg.Setting.ResetDuration)
local EnableWeaponReset = imgui.new.bool(cfg.Setting.EnableWeaponReset)
local RestoreDelay      = imgui.new.int(cfg.Setting.RestoreDelay)

function saveset()
    cfg.Setting.EnableMain        = EnableMain[0]
    cfg.Setting.UseBulletSync     = UseBulletSync[0]
    cfg.Setting.UseGiveDamage     = UseGiveDamage[0]
    cfg.Setting.SprintSpeed       = SprintSpeed[0]
    cfg.Setting.ResetDuration     = ResetDuration[0]
    cfg.Setting.EnableWeaponReset = EnableWeaponReset[0]
    cfg.Setting.RestoreDelay      = RestoreDelay[0]

    inicfg.save(cfg, "autolifefoot")
    sampAddChatMessage("Config disimpan!", -1)
end

local fontTitle = nil
local fontAwesome = nil

local player_ped = samem.cast("CPed **", samem.player_ped)

local function getPed()
    if not player_ped then return nil end
    local ped = player_ped[0]
    if ped == nil or ped == samem.nullptr then return nil end
    return ped
end

local function getPlayerData()
    local ped = getPed()
    if not ped then return nil end
    return ped.pPlayerData
end

local function nowMs()
    return os.clock() * 1000
end

local resetUntil = 0
local lastWeapon = nil
local restoreAt  = 0
local restoring  = false
local emptyAt    = 0
local toEmpty    = false
local EMPTY_DELAY = 500
local shotAt = 0
local hitDetected = false
local MISS_DELAY = 150

local function triggerReset()
    local now = nowMs()
    resetUntil = now + ResetDuration[0]
    if not EnableWeaponReset[0] then return end
    local curWeapon = getCurrentCharWeapon(PLAYER_PED)
    if curWeapon ~= 0 then lastWeapon = curWeapon end
    if not toEmpty and not restoring then
        emptyAt = now + EMPTY_DELAY
        toEmpty = true
    end
end

function sampev.onSendGiveDamage(playerId, damage, weapon, bodypart)
    if not EnableMain[0] then return end
    if not UseGiveDamage[0] then return end
    if damage > 0 and weapon ~= 0 then
        triggerReset()
    end
end

function sampev.onSendBulletSync(data)
    if not EnableMain[0] then return end
    if not UseBulletSync[0] then return end
    shotAt = nowMs()
    hitDetected = false
end

lua_thread.create(function()
    while true do
        wait(0)
        if EnableMain[0] and resetUntil > nowMs() then
            local ped = getPed()
            if ped then
                local pdata = getPlayerData()
                if pdata then
                    pdata.fSprintEnergy = SprintSpeed[0]
                    pdata.bPlayerSprintDisabled = false
                end
            end
        end
        if EnableWeaponReset[0] and toEmpty and emptyAt > 0 and nowMs() >= emptyAt then
            setCurrentCharWeapon(PLAYER_PED, 0)
            restoreAt = nowMs() + RestoreDelay[0]
            restoring = true
            emptyAt = 0
            toEmpty = false
        end
        if EnableWeaponReset[0] and restoring and restoreAt > 0 and nowMs() >= restoreAt then
            if lastWeapon and lastWeapon ~= 0 then
                setCurrentCharWeapon(PLAYER_PED, lastWeapon)
            else
                setCurrentCharWeapon(PLAYER_PED, 24)
            end
            restoreAt = 0
            restoring = false
        end
    end
end)

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand("alm", function() window[0] = not window[0] end)
    while true do
        wait(0)
        if UseBulletSync[0] then
            if shotAt > 0 and not hitDetected and nowMs() - shotAt >= MISS_DELAY then
                triggerReset()
                shotAt = 0
            end
            if hitDetected then
                shotAt = 0
            end
        end
    end
end

imgui.OnFrame(
    function()
        return window[0]
    end,
    function()
        imgui.SetNextWindowSize(imgui.ImVec2(199, 0), imgui.Cond.FirstUseEver)

        if imgui.Begin("Auto Lifefoot", window,
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoScrollbar) then

            local url = "https://youtube.com/@deprauu"
            local windowWidth = imgui.GetWindowSize().x
            local textWidth = imgui.CalcTextSize(url).x
            local offsetX = 47

            imgui.SetCursorPosX((windowWidth - textWidth) / 2 + offsetX)

            imgui.SetWindowFontScale(0.7)
            imgui.TextColored(imgui.ImVec4(1, 1, 1, 1), url)
            imgui.SetWindowFontScale(1.0)

            if imgui.IsItemClicked() then
                openLink(url)
            end

            imgui.Checkbox("Enable", EnableMain)

            if EnableMain[0] then
                if imgui.Checkbox("BulletSync", UseBulletSync) then
                    if UseBulletSync[0] then
                        UseGiveDamage[0] = false
                    end
                end

                if imgui.Checkbox("GiveDamage", UseGiveDamage) then
                    if UseGiveDamage[0] then
                        UseBulletSync[0] = false
                    end
                end

                imgui.Checkbox("AutoSwitch", EnableWeaponReset)

                imgui.PushItemWidth(250)
                imgui.SliderInt("##ResetDuration", ResetDuration, 0, 10000, "Reset - %d")

                if EnableWeaponReset[0] then
                    imgui.SliderInt("##RestoreDelay", RestoreDelay, 0, 10000, "Switch - %d")
                end

                imgui.PopItemWidth()
            end
        end

        imgui.End()
    end
)
