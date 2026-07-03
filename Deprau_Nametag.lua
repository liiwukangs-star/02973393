script_name("Custom Nametag")
script_author('https://youtube.com/@deprauu')
script_description('cmd /.cn')

local ffi    = require("ffi")
local g7a    = ffi.load("GTASA")
local imgui  = require("mimgui")
local s4e    = require("samp.events")
local cfg    = require("var_")

local a0k = true

ffi.cdef[[
typedef struct { unsigned char r, g, b, a; } CRGBA;
typedef unsigned short GxtChar;
typedef struct { float left, bottom, right, top; } CRect;

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

typedef struct { float x, y, z; } RwV3d;
void _ZN4CPed15GetBonePositionER5RwV3djb(void* thiz, RwV3d* posn, uint32_t bone, bool calledFromCam);

void* _Z13RwTextureReadPKcS0_(const char* name, const char* mask);
typedef struct RwRaster RwRaster;
typedef struct {
    RwRaster*    raster;
    void*        dict;
    void*        lnext;
    void*        lprev;
    unsigned int refCount;
    char         name[32];
    char         mask[32];
    unsigned int filterAddressing;
    int          pad;
} RwTexture;
typedef struct { RwTexture* m_pTexture; } CSprite2d;
void _ZN9CSprite2dC1Ev(CSprite2d* self);
void _ZN9CSprite2d14SetRenderStateEv(CSprite2d* self);
void _ZN9CSprite2d4DrawERK5CRectRK5CRGBA(CSprite2d* self, CRect* rect, CRGBA* col);
void _ZN9CSprite2d18RenderVertexBufferEv(CSprite2d* self);

void _ZN9CSprite2d12DrawBarChartEffthfahh5CRGBAS0_(
    float x, float y, unsigned short w, unsigned char h,
    float value, signed char increase, unsigned char legend,
    unsigned char border, CRGBA* c, CRGBA* c2
);

extern bool _ZN6CTimer11m_UserPauseE;
]]

local b3t = {
    {0,'fist'},{1,'BRASSKNUCKLEicon'},{2,'golfclubicon'},{3,'nitestickicon'},
    {4,'knifecuricon'},{5,'baticon'},{6,'shovelicon'},{7,'poolcueicon'},
    {8,'katanaicon'},{9,'chnsawicon'},{10,'gun_dildo1icon'},{11,'gun_dildo2icon'},
    {12,'gun_vibe1icon'},{13,'gun_vibe2icon'},{14,'floweraicon'},{15,'gun_caneicon'},
    {16,'grenadeicon'},{17,'teargasicon'},{18,'molotovicon'},{22,'colt45icon'},
    {23,'silencedicon'},{24,'desert_eagleicon'},{25,'chromegunicon'},{26,'sawnofficon'},
    {27,'shotgspaicon'},{28,'micro_uziicon'},{29,'mp5lngicon'},{30,'ak47icon'},
    {31,'M4icon'},{32,'tec9icon'},{33,'cuntgunicon'},{34,'SNIPERicon'},
    {35,'rocketlaicon'},{36,'heatseekicon'},{37,'flameicon'},{38,'minigunicon'},
    {39,'satchelicon'},{40,'bombicon'},{41,'SPRAYCANicon'},{42,'fire_exicon'},
    {43,'cameraicon'},{44,'nvgogglesicon'},{45,'irgogglesicon'},{46,'gun_paraicon'},
}

local v2p = {}
local k1l = false

local function e5r()
    if k1l then return end
    for _, x9 in ipairs(b3t) do
        local m4d = x9[1]
        local t8n = x9[2]
        local r3w = g7a._Z13RwTextureReadPKcS0_(t8n, nil)
        if r3w ~= nil then
            local p6s = ffi.new("CSprite2d")
            g7a._ZN9CSprite2dC1Ev(p6s)
            p6s.m_pTexture = ffi.cast("RwTexture*", r3w)
            v2p[m4d] = p6s
        end
    end
    k1l = true
end

local function q8i(m4d, wx, wy, w, h)
    local p6s = v2p[m4d]
    if not p6s then return end
    local c9a = ffi.new("CRGBA",
        math.floor(cfg.c0l[0]*255), math.floor(cfg.c0l[1]*255),
        math.floor(cfg.c0l[2]*255), math.floor(cfg.c0l[3]*255))
    local r3c = ffi.new("CRect", wx - w/2, wy + h/2, wx + w/2, wy - h/2)
    g7a._ZN9CSprite2d14SetRenderStateEv(p6s)
    g7a._ZN9CSprite2d4DrawERK5CRectRK5CRGBA(p6s, r3c, c9a)
    g7a._ZN9CSprite2d18RenderVertexBufferEv(p6s)
end

local function u6b(ped, b0n)
    local p7r = ffi.cast("void*", getCharPointer(ped))
    if p7r == nil then return nil end
    local v3d = ffi.new("RwV3d[1]")
    g7a._ZN4CPed15GetBonePositionER5RwV3djb(p7r, v3d, b0n, false)
    return v3d[0].x, v3d[0].y, v3d[0].z
end

local function z1p()
    return g7a._ZN6CTimer11m_UserPauseE or isPauseMenuActive()
end

local function y4g(str)
    local buf = ffi.new("GxtChar[256]")
    for i = 1, #str do buf[i-1] = string.byte(str, i) end
    buf[#str] = 0
    return buf
end

local function o3d(x, y, text, col)
    local drp = ffi.new("CRGBA", 0, 0, 0, 255)
    if not col then col = ffi.new("CRGBA", 255, 255, 255, 255) end
    g7a._ZN5CFont12SetFontStyleEh(cfg.f5t[0])
    g7a._ZN5CFont8SetScaleEf(cfg.n7s[0])
    g7a._ZN5CFont15SetProportionalEh(1)
    g7a._ZN5CFont7SetEdgeEa(cfg.f8e[0])
    g7a._ZN5CFont10SetJustifyEh(cfg.j0t[0])
    g7a._ZN5CFont14SetOrientationEh(1)
    g7a._ZN5CFont12SetDropColorE5CRGBA(drp)
    g7a._ZN5CFont8SetColorE5CRGBA(col)
    g7a._ZN5CFont11PrintStringEffPt(
        x + cfg.n3x[0] + cfg.g1x[0],
        y + cfg.n3y[0] + cfg.g1y[0],
        y4g(text)
    )
end

local function l5v(sx, sy, id)
    local hp = sampGetPlayerHealth(id) or 0
    local ar = sampGetPlayerArmor(id)  or 0

    local h0x = sx + cfg.h2x[0] + cfg.g1x[0]
    local h0y = sy + cfg.h2y[0] + cfg.g1y[0]
    local a0x = sx + cfg.a1x[0] + cfg.g1x[0]
    local a0y = sy + cfg.a1y[0] + cfg.g1y[0]

    local c1h = ffi.new("CRGBA", cfg.p4c[0]*255, cfg.p4c[1]*255, cfg.p4c[2]*255, cfg.p4c[3]*255)
    local c2h = ffi.new("CRGBA", cfg.p4b[0]*255, cfg.p4b[1]*255, cfg.p4b[2]*255, cfg.p4b[3]*255)
    local c1a = ffi.new("CRGBA", cfg.r6c[0]*255, cfg.r6c[1]*255, cfg.r6c[2]*255, cfg.r6c[3]*255)
    local c2a = ffi.new("CRGBA", cfg.r6b[0]*255, cfg.r6b[1]*255, cfg.r6b[2]*255, cfg.r6b[3]*255)

    g7a._ZN9CSprite2d12DrawBarChartEffthfahh5CRGBAS0_(
        h0x, h0y,
        math.floor(cfg.h6w[0]), math.floor(cfg.h6h[0]),
        hp, 1, 0, 1, c1h, c2h)

    if ar > 0 then
        g7a._ZN9CSprite2d12DrawBarChartEffthfahh5CRGBAS0_(
            a0x, a0y,
            math.floor(cfg.a5w[0]), math.floor(cfg.a5h[0]),
            ar, 1, 0, 1, c1a, c2a)
    end
end

local function f3c(px, py, pz, tx, ty, tz)
    if cfg.q3w[0] then return true end
    if isLineOfSightClear then
        return isLineOfSightClear(px, py, pz, tx, ty, tz, true, false, false, true, false)
    end
    return true
end

local function d7w()
    if z1p() then return end
    e5r()

    for _, ped in ipairs(getAllChars()) do
        if ped ~= PLAYER_PED then
            local ok, id = sampGetPlayerIdByCharHandle(ped)
            if ok
            and doesCharExist(ped)
            and isCharOnScreen(ped)
            and sampIsPlayerConnected(id)
            and not sampIsPlayerNpc(id) then

                local bx, by, bz = u6b(ped, 8)
                if bx then
                    local px, py, pz = getCharCoordinates(PLAYER_PED)
                    local dst = getDistanceBetweenCoords3d(px, py, pz, bx, by, bz)

                    if dst <= cfg.d9m[0] and f3c(px, py, pz+0.2, bx, by, bz+0.2) then
                        local ok2, sx, sy = convert3DCoordsToScreenEx(bx, by, bz+0.05)
                        if ok2 then

                            if cfg.s1i[0] then
                                local s9  = cfg.w9s[0]
                                local w1  = cfg.i2z[0] * s9
                                local h1  = cfg.i2z[0] * s9
                                local w0x = sx + cfg.w4x[0] + cfg.g1x[0]
                                local w0y = sy + cfg.w4y[0] + cfg.g1y[0]
                                q8i(getCurrentCharWeapon(ped), w0x, w0y, w1, h1)
                            end

                            if cfg.s2n[0] then
                                local ar    = sampGetPlayerArmor(id) or 0
                                local n9y   = (ar <= 0 and cfg.s3b[0]) and 9 or 0
                                local s0c   = sampGetPlayerColor(id) or 0xFFFFFFFF
                                local r, g, b
                                if cfg.u7c[0] then
                                    r = bit.band(bit.rshift(s0c, 16), 0xFF)
                                    g = bit.band(bit.rshift(s0c,  8), 0xFF)
                                    b = bit.band(s0c, 0xFF)
                                else
                                    r, g, b = 255, 255, 255
                                end
                                local n0c  = ffi.new("CRGBA", r, g, b, 255)
                                local n0m  = sampGetPlayerNickname(id) .. " (" .. id .. ")"
                                if sampIsPlayerPaused and sampIsPlayerPaused(id) then
                                    n0m = n0m .. " ~r~~w~"
                                end
                                o3d(sx, sy + n9y, n0m, n0c)
                            end

                            if cfg.s3b[0] then
                                l5v(sx, sy, id)
                            end

                        end
                    end
                end
            end
        end
    end

    g7a._ZN5CFont16RenderFontBufferEv()
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    io.IniFilename = nil
    io.Fonts:Build()
    imgui.SwitchContext()
    local s8y  = imgui.GetStyle()
    local v2i  = imgui.ImVec2
    s8y.WindowRounding    = 18.0
    s8y.ItemSpacing       = v2i(12, 8)
    s8y.ItemInnerSpacing  = v2i(8, 6)
    s8y.IndentSpacing     = 25.0
    s8y.ScrollbarSize     = 25.0
    s8y.ScrollbarRounding = 10.0
    s8y.GrabMinSize       = 20.0
    s8y.GrabRounding      = 20.0
    s8y.ChildRounding     = 12.0
    s8y.FrameRounding     = 10.0
    s8y.WindowTitleAlign  = v2i(0.5, 0.5)
end)

local w0w = imgui.new.bool(false)

imgui.OnFrame(function() return w0w[0] end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(306, 31*6+80), imgui.Cond.FirstUseEver)
    if not imgui.Begin("Custom Nametag by Deprau", w0w, imgui.WindowFlags.NoCollapse) then return end

    local function r1i(label, var, step, mn, mx)
        imgui.PushItemWidth(180)
        imgui.SliderInt("##"..label, var, mn, mx)
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button("-##"..label, imgui.ImVec2(29,29)) then var[0] = math.max(mn, var[0]-step) end
        imgui.SameLine()
        if imgui.Button("+##"..label, imgui.ImVec2(29,29)) then var[0] = math.min(mx, var[0]+step) end
    end

    local function t2f(label, var, step, mn, mx, fmt)
        if type(var) ~= "cdata" or var[0] == nil then return end
        imgui.PushItemWidth(180)
        imgui.SliderFloat("##"..label, var, mn, mx, fmt)
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button("-##"..label, imgui.ImVec2(29,29)) then var[0] = math.max(mn, var[0]-step) end
        imgui.SameLine()
        if imgui.Button("+##"..label, imgui.ImVec2(29,29)) then var[0] = math.min(mx, var[0]+step) end
    end

    imgui.BeginChild("##scroll", imgui.ImVec2(0,0), false)

    imgui.Checkbox("Wall Hack??", cfg.q3w)
    imgui.SameLine()
    if imgui.Button("Save Config", imgui.ImVec2(110,24)) then cfg.save() end

    t2f("MaxDist",  cfg.d9m, 5.0, 10.0, 500.0, "Distance %.0f")
    t2f("GlobalX",  cfg.g1x, 1.0, -200,  200,  "Position X %.1f")
    t2f("GlobalY",  cfg.g1y, 1.0, -200,  200,  "Position Y %.1f")

    if imgui.CollapsingHeader("Icon Settings") then
        imgui.Checkbox("Show Icon", cfg.s1i)
        t2f("WepX",   cfg.w4x, 1.0,  -200, 200,  "Position X %.1f")
        t2f("WepY",   cfg.w4y, 1.0,  -200, 200,  "Position Y %.1f")
        t2f("WepScl", cfg.w9s, 0.05, 0.1,  3.0,  "Scale %.2f")
        imgui.ColorEdit4("##IconColor", cfg.c0l)
    end

    if imgui.CollapsingHeader("Nickname Settings") then
        imgui.Checkbox("Show Nickname",        cfg.s2n)
        imgui.Checkbox("Use Server Nick Color", cfg.u7c)
        t2f("NickX",    cfg.n3x, 1.0,  -200, 200, "Position X %.1f")
        t2f("NickY",    cfg.n3y, 1.0,  -200, 200, "Position Y %.1f")
        t2f("NickScl",  cfg.n7s, 0.05, 0.2,  3.0, "Scale %.2f")
        r1i("FontStyle", cfg.f5t, 1, 1, 4)
        r1i("FontEdge",  cfg.f8e, 1, 0, 3)
    end

    if imgui.CollapsingHeader("Health Settings") then
        imgui.Checkbox("Show Bar", cfg.s3b)
        t2f("HP_X", cfg.h2x, 1.0, -200, 200, "Position X %.1f")
        t2f("HP_Y", cfg.h2y, 1.0, -200, 200, "Position Y %.1f")
        t2f("HP_W", cfg.h6w, 2.0,   10, 300, "Width %.1f")
        t2f("HP_H", cfg.h6h, 0.5,    2,  30, "Height %.1f")
        imgui.ColorEdit4("##HPColor", cfg.p4c)
    end

    if imgui.CollapsingHeader("Armor Settings") then
        t2f("AR_X", cfg.a1x, 1.0, -200, 200, "Position X %.1f")
        t2f("AR_Y", cfg.a1y, 1.0, -200, 200, "Position Y %.1f")
        t2f("AR_W", cfg.a5w, 2.0,   10, 300, "Width %.1f")
        t2f("AR_H", cfg.a5h, 0.5,    2,  30, "Height %.1f")
        imgui.ColorEdit4("##ArmorColor", cfg.r6c)
    end

    imgui.EndChild()
    imgui.End()
end)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    addEventHandler("onD3DPresent", d7w)

    local n9f = "Deprau_Nametag.luac"
    if thisScript().filename ~= n9f then
        lua_thread.create(function()
            while true do print("NO RENAME FILE!") wait(0) end
        end)
        os.remove(thisScript().path)
        return
    end

    cfg.load()
    sampRegisterChatCommand(".cn", function() w0w[0] = not w0w[0] end)
    while not isSampAvailable() do wait(100) end
    wait(-1)
end


function s4e.onInitGame(playerId, hostName, settings, vehicleModels, friendlyFire)
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
