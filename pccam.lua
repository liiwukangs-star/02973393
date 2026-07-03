require 'widgets'

local imgui = require 'mimgui'
local ffi = require 'ffi'
local memory = require 'memory'
local SAMemory = require 'SAMemory'
local inicfg = require 'inicfg'

SAMemory.require('CCamera')
local camera = SAMemory.camera
local BASE = MONET_GTASA_BASE

local cfg2 = inicfg.load({
    [1] = {
        senso = 1.0,
        smootho = 1.0,
        enable = true
    }
}, "pcc")

local senso = imgui.new.float(cfg2[1].senso)
local smootho = imgui.new.float(cfg2[1].smootho)
local enable = imgui.new.bool(cfg2[1].enable ~= false)

local function saveOnFoot()
    cfg2[1].senso = senso[0]
    cfg2[1].smootho = smootho[0]
    cfg2[1].enable = enable[0]
    inicfg.save(cfg2, "pcc")
end

local lastTick = os.clock()
local currentPhi, currentTheta = 0.0, 0.0
local velocityPhi, velocityTheta = 0.0, 0.0
local velocityDecay = 0.28
local initialized = false

local function smoothDamp(current, target, speed, dt)
    if dt <= 0 or dt > 0.1 then dt = 0.016 end
    return current + (target - current) * (1 - math.exp(-speed * dt))
end

local function getDT()
    local now = os.clock()
    local dt = now - lastTick
    lastTick = now
    if dt <= 0 or dt > 0.1 then dt = 0.016 end
    return dt
end

local function getCameraAngles()
    return camera.aCams[0].fHorizontalAngle,
           camera.aCams[0].fVerticalAngle
end

local function setCameraAngles(phi, theta)
    camera.aCams[0].fHorizontalAngle = phi
    camera.aCams[0].fVerticalAngle   = theta
end

local addr_ped = MONET_GTASA_BASE + 0x003C2D50
local imm8H = 37
local imm8V = 33
local scanned = {}
local nopOn   = false

local function applyNop()
    if nopOn then return end
    for _, p in ipairs(scanned) do
        local ptr = ffi.cast('uint8_t*', p.addr)
        ptr[0]=0x00; ptr[1]=0xBF; ptr[2]=0x00; ptr[3]=0xBF
    end
    nopOn = true
end

local function restoreNop()
    if not nopOn then return end
    for _, p in ipairs(scanned) do
        local ptr = ffi.cast('uint8_t*', p.addr)
        ptr[0]=p.orig[1]; ptr[1]=p.orig[2]; ptr[2]=p.orig[3]; ptr[3]=p.orig[4]
    end
    nopOn = false
end

local function updateCameraControl()
    -- Jangan jalankan sama sekali jika fitur dimatikan
    if not enable[0] then
        restoreNop()
        initialized = false
        velocityPhi = 0
        velocityTheta = 0
        return
    end

    -- Jangan jalankan kontrol kamera jika di kendaraan
    if isCharInAnyCar(PLAYER_PED) then
        restoreNop()
        initialized = false
        velocityPhi = 0
        velocityTheta = 0
        return
    end

    applyNop()

    local camMode = camera.aCams[0].nMode
    local aiming = camMode == 7 or camMode == 8 or camMode == 51 or camMode == 53

    if aiming then
        initialized = false
        return
    end

    if not doesCharExist(PLAYER_PED) then
        initialized = false
        return
    end

    local s = senso[0] / 1000
    local spd = smootho[0]

    local pressed, x, y = isWidgetPressedEx(0xAF, 0)
    x = tonumber(x) or 0
    y = tonumber(y) or 0

    local phi, theta = getCameraAngles()

    if pressed then
        if not initialized then
            currentPhi, currentTheta = phi, theta
            initialized = true
        end

        velocityPhi   = velocityPhi - x * s
        velocityTheta = velocityTheta - y * s
    end

    if initialized then
        local dt = getDT()

        currentPhi   = smoothDamp(currentPhi + velocityPhi, currentPhi, spd, dt)
        currentTheta = smoothDamp(currentTheta + velocityTheta, currentTheta, spd, dt)

        velocityPhi   = velocityPhi * velocityDecay
        velocityTheta = velocityTheta * velocityDecay

        setCameraAngles(currentPhi, currentTheta)
    end
end

function main()
    repeat wait(0) until isSampAvailable()

    local base = ffi.cast('uint8_t*', bit.band(addr_ped, bit.bnot(1)))
    memory.unprotect(tonumber(ffi.cast('uintptr_t', base)), 8304)

    for i = 0, 8304 - 4 do
        if base[i+1] == 0xED and bit.band(base[i+3],0x0F)==0x0A then
            if base[i+2]==imm8H or base[i+2]==imm8V then
                table.insert(scanned,{
                    addr = tonumber(ffi.cast('uintptr_t', base+i)),
                    orig = {base[i],base[i+1],base[i+2],base[i+3]}
                })
            end
        end
    end

    while true do
        wait(-0)
        updateCameraControl()
    end
end

addEventHandler('onScriptTerminate', function(scr)
    if scr == script.this then
        restoreNop()
        saveOnFoot()
    end
end)

local mainGui = { state = false }

imgui.OnFrame(function()
    return mainGui.state
end, function()
    imgui.Begin("Deprau")

    imgui.Checkbox("Enable", enable)

    imgui.SliderFloat("Senso", senso, 0.0, 10.0, "%.1f")
    imgui.SliderFloat("Smootho", smootho, 0.0, 30.0, "%.1f")

    imgui.End()
end)

sampRegisterChatCommand("cpcs", function()
    mainGui.state = not mainGui.state
end)

sampRegisterChatCommand("cpc", function()
    enable[0] = not enable[0]
end)
