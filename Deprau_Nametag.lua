script_name("Custom Nametag")
script_author('https://youtube.com/@deprauu')
script_description('cmd /.cn')

local ffi = require("ffi")
local gta = ffi.load("GTASA")
local imgui = require("mimgui")
local ev = require 'samp.events'
local inicfg = require 'inicfg'

local fontSize = 13
local font = renderCreateFont("Arial", fontSize, 0x4)

ffi.cdef[[
typedef struct {
    unsigned char r, g, b, a;
} CRGBA;

typedef unsigned short GxtChar;

typedef struct {
    float left, bottom, right, top;
} CRect;

void _ZN5CFont12SetFontStyleEh(unsigned char style);
void _ZN5CFont8SetScaleEf(float fHeight);
void _ZN5CFont10SetJustifyEh(unsigned char justify);
void _ZN5CFont14SetOrientationEh(unsigned char orientation);
void _ZN5CFont15SetProportionalEh(unsigned char prop);
void _ZN5CFont7SetEdgeEa(signed char amount);
void _ZN5CFont12SetDropColorE5CRGBA(CRGBA* dropcolor);
void _ZN5CFont8SetColorE5CRGBA(CRGBA* color);
void _ZN5CFont11PrintStringEffPt(float x, float y, GxtChar* pCharacters);
void _ZN5CFont16RenderFontBufferEv();
typedef struct {
    float x,y,z;
} RwV3d;

void _ZN4CPed15GetBonePositionER5RwV3djb(
    void* thiz,
    RwV3d* posn,
    uint32_t bone,
    bool calledFromCam
);
void _ZN7CSprite18RenderOneXLUSpriteEfffffhhhsfhhhff(
    float, float, float, float, float,
    unsigned char, unsigned char, unsigned char,
    short,
    float,
    unsigned char, unsigned char, unsigned char,
    float, float
);

void _ZN9CSprite2d4DrawEffffRK5CRGBA(
    void*, float, float, float, float, CRGBA*
);

void _ZN17CWidgetPlayerInfo14DrawWeaponIconEP4CPed5CRectf(
    void*, void*, CRect, float
);

void _ZN9CSprite2d12DrawBarChartEffthfahh5CRGBAS0_(
    float x, float y,
    unsigned short w,
    unsigned char h,
    float value,
    signed char increase,
    unsigned char legend,
    unsigned char border,
    CRGBA* c,
    CRGBA* c2
);

extern void* _ZN4CHud7SpritesE;
extern bool _ZN6CTimer11m_UserPauseE;
]]

local function getBonePos(ped, bone)
    local pedPtr = ffi.cast("void*", getCharPointer(ped))
    if pedPtr == nil then
        return nil
    end

    local pos = ffi.new("RwV3d[1]")

    gta._ZN4CPed15GetBonePositionER5RwV3djb(
        pedPtr,
        pos,
        bone,
        false
    )

    return pos[0].x, pos[0].y, pos[0].z
end


local new = imgui.new
local window = new.bool(false)
local globalX = new.float(-11.650)
local globalY = new.float(9.709)
local weaponOffsetX = ffi.new("float[1]", -32.687)
local weaponOffsetY = ffi.new("float[1]", -51.524)
local weaponScale   = ffi.new("float[1]", 1.289)
local nameOffsetX   = ffi.new("float[1]", -11.650)
local nameOffsetY   = ffi.new("float[1]", -64.078)
local nameScale     = ffi.new("float[1]", 0.456)
local hpOffsetX     = ffi.new("float[1]", -13.850)
local hpOffsetY     = ffi.new("float[1]", -44.660)
local hpWidthScale  = ffi.new("float[1]", 59.272)
local hpHeightScale = ffi.new("float[1]", 6.757)
local arOffsetX     = ffi.new("float[1]", -13.850)
local arOffsetY     = ffi.new("float[1]", -54.369)
local arWidthScale  = ffi.new("float[1]", 59.272)
local arHeightScale = ffi.new("float[1]", 6.757)
local fontStyle = imgui.new.int(3)
local fontEdge = imgui.new.int(1)
local iconSize = ffi.new("float[1]", 28)
local justify = new.int(0)
local ignoreWalls = new.bool(false)
local maxDistance = ffi.new("float[1]", 150.0)
local hpCol = new.float[4](1.0, 0.84, 0.0, 1.0) -- gold
local hpBg  = new.float[4](0.0, 0.0, 0.0, 0.7)
local showIcon = new.bool(true)
local showNick = new.bool(true)
local showBar  = new.bool(true)
local useServerNickColor = imgui.new.bool(true)
local color = new.float[4](0.8, 0.8, 0.8, 1.0)
local arCol = new.float[4](0.8, 0.8, 0.8, 1.0)
local arBg  = new.float[4](0.0, 0.0, 0.0, 0.7)

local json = require("json")

local configPath = "nametag_deprau.json"

local function saveConfig()
    local cfg = {
        globalX = globalX[0],
        globalY = globalY[0],

        weaponOffsetX = weaponOffsetX[0],
        weaponOffsetY = weaponOffsetY[0],
        weaponScale = weaponScale[0],

        nameOffsetX = nameOffsetX[0],
        nameOffsetY = nameOffsetY[0],
        nameScale = nameScale[0],

        hpOffsetX = hpOffsetX[0],
        hpOffsetY = hpOffsetY[0],
        hpWidthScale = hpWidthScale[0],
        hpHeightScale = hpHeightScale[0],

        arOffsetX = arOffsetX[0],
        arOffsetY = arOffsetY[0],
        arWidthScale = arWidthScale[0],
        arHeightScale = arHeightScale[0],

        fontStyle = fontStyle[0],
        fontEdge = fontEdge[0],
        iconSize = iconSize[0],
        justify = justify[0],

        ignoreWalls = ignoreWalls[0],
        maxDistance = maxDistance[0],

        showIcon = showIcon[0],
        showNick = showNick[0],
        showBar = showBar[0],
        useServerNickColor = useServerNickColor[0],

        color = {
            color[0], color[1], color[2], color[3]
        },

        hpCol = {
            hpCol[0], hpCol[1], hpCol[2], hpCol[3]
        },

        hpBg = {
            hpBg[0], hpBg[1], hpBg[2], hpBg[3]
        },

        arCol = {
            arCol[0], arCol[1], arCol[2], arCol[3]
        },

        arBg = {
            arBg[0], arBg[1], arBg[2], arBg[3]
        }
    }

    local file = io.open(configPath, "w")
    if file then
        file:write(json.encode(cfg))
        file:close()

        sampAddChatMessage("[Nametag] Config saved successfully.", -1)
    else
        sampAddChatMessage("[Nametag] Failed to save config.", 0xFF0000)
    end
end
local function loadConfig()
    local file = io.open(configPath, "r")
    if not file then return end

    local data = json.decode(file:read("*a"))
    file:close()

    if not data then return end

    globalX[0] = data.globalX or globalX[0]
    globalY[0] = data.globalY or globalY[0]

    weaponOffsetX[0] = data.weaponOffsetX or weaponOffsetX[0]
    weaponOffsetY[0] = data.weaponOffsetY or weaponOffsetY[0]
    weaponScale[0] = data.weaponScale or weaponScale[0]

    nameOffsetX[0] = data.nameOffsetX or nameOffsetX[0]
    nameOffsetY[0] = data.nameOffsetY or nameOffsetY[0]
    nameScale[0] = data.nameScale or nameScale[0]

    hpOffsetX[0] = data.hpOffsetX or hpOffsetX[0]
    hpOffsetY[0] = data.hpOffsetY or hpOffsetY[0]
    hpWidthScale[0] = data.hpWidthScale or hpWidthScale[0]
    hpHeightScale[0] = data.hpHeightScale or hpHeightScale[0]

    arOffsetX[0] = data.arOffsetX or arOffsetX[0]
    arOffsetY[0] = data.arOffsetY or arOffsetY[0]
    arWidthScale[0] = data.arWidthScale or arWidthScale[0]
    arHeightScale[0] = data.arHeightScale or arHeightScale[0]

    fontStyle[0] = data.fontStyle or fontStyle[0]
    fontEdge[0] = data.fontEdge or fontEdge[0]
    iconSize[0] = data.iconSize or iconSize[0]
    justify[0] = data.justify or justify[0]

    ignoreWalls[0] = data.ignoreWalls or false
    maxDistance[0] = data.maxDistance or maxDistance[0]

    showIcon[0] = data.showIcon
    showNick[0] = data.showNick
    showBar[0] = data.showBar
    useServerNickColor[0] = data.useServerNickColor

    if data.color then
        color[0], color[1], color[2], color[3] =
            data.color[1], data.color[2], data.color[3], data.color[4]
    end

    if data.hpCol then
        hpCol[0], hpCol[1], hpCol[2], hpCol[3] =
            data.hpCol[1], data.hpCol[2], data.hpCol[3], data.hpCol[4]
    end

    if data.hpBg then
        hpBg[0], hpBg[1], hpBg[2], hpBg[3] =
            data.hpBg[1], data.hpBg[2], data.hpBg[3], data.hpBg[4]
    end

    if data.arCol then
        arCol[0], arCol[1], arCol[2], arCol[3] =
            data.arCol[1], data.arCol[2], data.arCol[3], data.arCol[4]
    end

    if data.arBg then
        arBg[0], arBg[1], arBg[2], arBg[3] =
            data.arBg[1], data.arBg[2], data.arBg[3], data.arBg[4]
    end
end
local function toGxt(str)
    local buf = ffi.new("GxtChar[256]")
    for i = 1, #str do
        buf[i-1] = string.byte(str,i)
    end
    buf[#str] = 0
    return buf
end

local function isPaused()
    return gta._ZN6CTimer11m_UserPauseE or isPauseMenuActive()
end

local function refreshWeaponIcon(ped)
    if isPaused() then return end
    local rect = ffi.new("CRect",{9999,9999,9999,9999})

    gta._ZN17CWidgetPlayerInfo14DrawWeaponIconEP4CPed5CRectf(
        nil,
        ffi.cast("void*", getCharPointer(ped)),
        rect,
        0.0
    )
end

local showNametags = true
local drawMethod = 2

local nametagOffsetX = 0
local nametagOffsetY = 0

local function drawBars(sx, sy, id)
    local hp = sampGetPlayerHealth(id) or 0
    local ar = sampGetPlayerArmor(id) or 0

    local hpX = sx + hpOffsetX[0] + globalX[0]
    local hpY = sy + hpOffsetY[0] + globalY[0]

    local arX = sx + arOffsetX[0] + globalX[0]
    local arY = sy + arOffsetY[0] + globalY[0]

    local hpColor = ffi.new("CRGBA",
    hpCol[0]*255,
    hpCol[1]*255,
    hpCol[2]*255,
    hpCol[3]*255
)

local hpBack = ffi.new("CRGBA",
    hpBg[0]*255,
    hpBg[1]*255,
    hpBg[2]*255,
    hpBg[3]*255
)

local arColor = ffi.new("CRGBA",
    arCol[0]*255,
    arCol[1]*255,
    arCol[2]*255,
    arCol[3]*255
)

local arBack = ffi.new("CRGBA",
    arBg[0]*255,
    arBg[1]*255,
    arBg[2]*255,
    arBg[3]*255
)

    gta._ZN9CSprite2d12DrawBarChartEffthfahh5CRGBAS0_(
    hpX, hpY,
    hpWidthScale[0],
    hpHeightScale[0],
    hp,
    1,0,1,
    hpColor, hpBack
)

if ar > 0 then
    gta._ZN9CSprite2d12DrawBarChartEffthfahh5CRGBAS0_(
        arX, arY,
        arWidthScale[0],
        arHeightScale[0],
        ar,
        1,0,1,
        arColor, arBack
    )
    end
end

local function drawText(x, y, text, col)

    local drop = ffi.new("CRGBA", 0,0,0,255)

    if not col then
        col = ffi.new("CRGBA",255,255,255,255)
    end

    gta._ZN5CFont12SetFontStyleEh(fontStyle[0])
    gta._ZN5CFont8SetScaleEf(nameScale[0])
    gta._ZN5CFont15SetProportionalEh(1)
    gta._ZN5CFont7SetEdgeEa(fontEdge[0])
    gta._ZN5CFont10SetJustifyEh(justify[0])
    gta._ZN5CFont14SetOrientationEh(1)

    gta._ZN5CFont12SetDropColorE5CRGBA(drop)
    gta._ZN5CFont8SetColorE5CRGBA(col)

    gta._ZN5CFont11PrintStringEffPt(
        x + nameOffsetX[0] + globalX[0],
        y + nameOffsetY[0] + globalY[0],
        toGxt(text)
    )
end

local function isVisible(px, py, pz, tx, ty, tz)
    if ignoreWalls[0] then
        return true
    end

    if isLineOfSightClear then
        return isLineOfSightClear(px, py, pz, tx, ty, tz, true, false, false, true, false)
    end

    return true
end

local function drawESP()
    if isPaused() then return end

    for _, ped in ipairs(getAllChars()) do
        if ped ~= PLAYER_PED then

            local ok, id = sampGetPlayerIdByCharHandle(ped)

            if ok
            and doesCharExist(ped)
            and isCharOnScreen(ped)
            and sampIsPlayerConnected(id)
            and not sampIsPlayerNpc(id) then

                local bx, by, bz = getBonePos(ped, 8)

                if bx then

                    local px, py, pz = getCharCoordinates(PLAYER_PED)
                    local dist = getDistanceBetweenCoords3d(px, py, pz, bx, by, bz)

                    if dist <= maxDistance[0] then

                        if not isVisible(px, py, pz + 0.2, bx, by, bz + 0.2) then
                        else

                            local ok2, sx, sy = convert3DCoordsToScreenEx(
                                bx,
                                by,
                                bz + 0.05
                            )

                            if ok2 then

                                if showIcon[0] then

                                    refreshWeaponIcon(ped)

                                    local wx = sx + weaponOffsetX[0] + globalX[0]
                                    local wy = sy + weaponOffsetY[0] + globalY[0]

                                    local s = weaponScale[0]
                                    local w = iconSize[0] * s
                                    local h = iconSize[0] * s

                                    local wep = getCurrentCharWeapon(ped)

                                    if wep == 0 then

                                        local r = color[0] * 255
                                        local g = color[1] * 255
                                        local b = color[2] * 255
                                        local a = color[3] * 255

                                        local c = ffi.new("CRGBA", r, g, b, a)

                                        gta._ZN9CSprite2d4DrawEffffRK5CRGBA(
                                            ffi.cast("void*", gta._ZN4CHud7SpritesE),
                                            wx - w / 2,
                                            wy - h / 2,
                                            w,
                                            h,
                                            c
                                        )

                                    else

                                        gta._ZN7CSprite18RenderOneXLUSpriteEfffffhhhsfhhhff(
                                            wx,
                                            wy,
                                            10.0,
                                            w * 0.5,
                                            h * 0.5,
                                            color[0] * 255,
                                            color[1] * 255,
                                            color[2] * 255,
                                            255,
                                            1.0,
                                            color[3] * 255,
                                            0,
                                            0,
                                            0.0,
                                            0.0
                                        )

                                    end
                                end

if showNick[0] then

    local ar = sampGetPlayerArmor(id) or 0
    local nickY = (ar <= 0 and showBar[0]) and 9 or 0

    local sampColor = sampGetPlayerColor(id)

    local r, g, b

    if useServerNickColor[0] then
        r = bit.band(bit.rshift(sampColor, 16), 0xFF)
        g = bit.band(bit.rshift(sampColor, 8), 0xFF)
        b = bit.band(sampColor, 0xFF)
    else
        r, g, b = 255, 255, 255
    end

    local nickColor = ffi.new("CRGBA", r, g, b, 255)

    local name = sampGetPlayerNickname(id) .. " (" .. id .. ")"

    if sampIsPlayerPaused(id) then
        name = name .. " ~r~~w~"
    end

    drawText(
        sx,
        sy + nickY,
        name,
        nickColor
    )
end

                                if showBar[0] then
                                    drawBars(sx, sy, id)
                                end

                            end
                        end
                    end
                end
            end
        end
    end

    gta._ZN5CFont16RenderFontBufferEv()
end

imgui.OnFrame(
    function() return window[0] end,
    function()
        imgui.SetNextWindowSize(imgui.ImVec2(320, 0), imgui.Cond.FirstUseEver)

        if imgui.Begin("Deprau Nametag", window, imgui.WindowFlags.NoCollapse +
            imgui.WindowFlags.AlwaysAutoResize) then

            local function addAdjustInt(label, var, step, minv, maxv)
                imgui.PushItemWidth(280)
                imgui.SliderInt("##"..label, var, minv, maxv)
                imgui.PopItemWidth()

                imgui.SameLine()

                if imgui.Button("-##"..label, imgui.ImVec2(29, 29)) then
                    var[0] = math.max(minv, var[0] - step)
                end

                imgui.SameLine()

                if imgui.Button("+##"..label, imgui.ImVec2(29, 29)) then
                    var[0] = math.min(maxv, var[0] + step)
                end
            end

            local function addAdjust(label, var, step, minv, maxv, format)
                if type(var) ~= "cdata" then return end
                if var[0] == nil then return end

                imgui.PushItemWidth(280)
                imgui.SliderFloat("##"..label, var, minv, maxv, format)
                imgui.PopItemWidth()

                imgui.SameLine()

                if imgui.Button("-##"..label, imgui.ImVec2(29, 29)) then
                    var[0] = var[0] - step
                    if var[0] < minv then var[0] = minv end
                end

                imgui.SameLine()

                if imgui.Button("+##"..label, imgui.ImVec2(29, 29)) then
                    var[0] = var[0] + step
                    if var[0] > maxv then var[0] = maxv end
                end
            end

            imgui.Checkbox("Wall Hack??", ignoreWalls)
            imgui.SameLine()
    if imgui.Button("Save Config", imgui.ImVec2(110,24)) then saveConfig() end
            addAdjust("MaxDistance", maxDistance, 5.0, 10.0, 500.0, "Distance %.0f")
            addAdjust("GlobalX", globalX, 1.0, -200, 200, "Position X %.1f")
            addAdjust("GlobalY", globalY, 1.0, -200, 200, "Position Y %.1f")

            if imgui.CollapsingHeader("Icon Settings") then
                imgui.Checkbox("Show Icon", showIcon)

                addAdjust("WeaponOffsetX", weaponOffsetX, 1.0, -200, 200, "Position X %.1f")
                addAdjust("WeaponOffsetY", weaponOffsetY, 1.0, -200, 200, "Position Y %.1f")
                addAdjust("WeaponScale", weaponScale, 0.05, 0.1, 3.0, "Scale %.2f")

                imgui.ColorEdit4("##IconColor", color)
            end

            if imgui.CollapsingHeader("Nickname Settings") then
                imgui.Checkbox("Show Nickname", showNick)
                imgui.Checkbox("Use Server Nick Color", useServerNickColor)

                addAdjust("NameOffsetX", nameOffsetX, 1.0, -200, 200, "Position X %.1f")
                addAdjust("NameOffsetY", nameOffsetY, 1.0, -200, 200, "Position Y %.1f")
                addAdjust("NameScale", nameScale, 0.05, 0.2, 3.0, "Scale %.2f")

                addAdjustInt("FontStyle", fontStyle, 1, 1, 4)
                addAdjustInt("FontEdge", fontEdge, 1, 0, 3)
            end

            if imgui.CollapsingHeader("Health Settings") then
                imgui.Checkbox("Show Bar", showBar)

                addAdjust("HP_X", hpOffsetX, 1.0, -200, 200, "Position X %.1f")
                addAdjust("HP_Y", hpOffsetY, 1.0, -200, 200, "Position Y %.1f")
                addAdjust("HP_W", hpWidthScale, 2.0, 10, 300, "Width %.1f")
                addAdjust("HP_H", hpHeightScale, 0.5, 2, 30, "Height %.1f")

                imgui.ColorEdit4("##HPColor", hpCol)
            end

            if imgui.CollapsingHeader("Armor Settings") then
                addAdjust("AR_X", arOffsetX, 1.0, -200, 200, "Position X %.1f")
                addAdjust("AR_Y", arOffsetY, 1.0, -200, 200, "Position Y %.1f")
                addAdjust("AR_W", arWidthScale, 2.0, 10, 300, "Width %.1f")
                addAdjust("AR_H", arHeightScale, 0.5, 2, 30, "Height %.1f")

                imgui.ColorEdit4("##ArmorColor", arCol)
            end
        end
        imgui.End()
    end
)

function ev.onInitGame(playerId, hostName, settings, vehicleModels, friendlyFire)
    if not a0k then return end
    if not settings or type(settings) ~= "table" then return end
    settings.showPlayerTags = false
    settings.playerMarkersMode = 0
    local f9m = {}
    for i = 1, 212 do
        f9m[i] = vehicleModels[i] or vehicleModels[i-1] or 0
    end
    return {playerId, hostName, settings, f9m, friendlyFire}
end

function checkScriptName()
    local name = "Deprau_Nametag.lua"
    local currentName = thisScript().filename
    local currentPath = thisScript().path

    if currentName ~= name then
        lua_thread.create(function()
            while true do
                print("NO RANAME FILE!")
                wait(0)
            end
        end)

        os.remove(currentPath)
        return false
    end

    return true
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    addEventHandler("onD3DPresent", drawESP)
    checkScriptName()
    loadConfig()
    sampRegisterChatCommand(".cn", function()
        window[0] = not window[0]
    end)
    while not isSampAvailable() do wait(100) end
    wait(-1)
end
