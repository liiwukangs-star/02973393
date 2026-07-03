require('sa_renderfix')
local memory  = require("memory")
local imgui   = require("mimgui")
local new     = imgui.new
local jsoncfg = require("jsoncfg")
local faicons = require('fAwesome6')
local ffi     = require("ffi")
local gta     = ffi.load("GTASA")

ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]
function openLink(url) gta._Z12AND_OpenLinkPKc(url) end

local CONFIG_FILE = "adjustable.json"
local defaultConfig = {
    widgets = {
        ATTACK           = {x=200,y=200,w=100,h=100,s=1.0},
        ENTER_TARGETING  = {x=200,y=200,w=100,h=100,s=1.0},
        VC_SHOOT         = {x=200,y=200,w=100,h=100,s=1.0},
        VC_SHOOT_ALT     = {x=200,y=200,w=100,h=100,s=1.0},
        SPRINT           = {x=200,y=200,w=100,h=100,s=1.0},
        ENTER_CAR        = {x=200,y=200,w=100,h=100,s=1.0},
        ACCELERATE       = {x=200,y=200,w=100,h=100,s=1.0},
        BRAKE            = {x=200,y=200,w=100,h=100,s=1.0},
        HAND_BRAKE       = {x=200,y=200,w=100,h=100,s=1.0},
        HORN             = {x=200,y=200,w=100,h=100,s=1.0},
        REPLAY           = {x=200,y=200,w=100,h=100,s=1.0},
        PLAYER_INFO      = {x=450,y=93,w=56,h=56,s=1.0},
        RADAR            = {x=200,y=200,w=150,h=150,s=1.0},
        ANALOG           = {x=200,y=200,w=120,h=120,s=1.0},
    }
}

local config = jsoncfg.load(defaultConfig, CONFIG_FILE)
if not config or not config.widgets then config = defaultConfig end

local function newWidget(name,data)
    return {
        name = name,
        x = imgui.new.float(data.x or 200),
        y = imgui.new.float(data.y or 200),
        w = imgui.new.float(data.w or 100),
        h = imgui.new.float(data.h or 100),
        s = imgui.new.float(data.s or 1.0)
    }
end

local widgets = {}
for k,v in pairs(defaultConfig.widgets) do
    widgets[k] = newWidget(k, config.widgets[k])
end

function saveset()
    for k,v in pairs(widgets) do
        config.widgets[k] = {
            x=v.x[0], y=v.y[0],
            w=v.w[0], h=v.h[0],
            s=v.s[0]
        }
    end
    jsoncfg.save(config, CONFIG_FILE)
    sampAddChatMessage('[Deprau] Save successful!', 0xFFFFFF)
end

local socket = require 'socket.http'
local ltn12 = require 'ltn12'
local lfs = require 'lfs'
local faicons = require 'fAwesome6'

local dpi = MONET_DPI_SCALE or 1
local MDS = dpi * 1.0
local BASE_DIR = getWorkingDirectory() .. '/lib/deprau'
local FONT_DIR = BASE_DIR .. '/font'
local FONT_PATH = FONT_DIR .. '/baflion-sans.black.otf'
local FONT_URL = 'https://raw.githubusercontent.com/Kekenenehshsjjshs/Lakskebdudnsvshsue/refs/heads/main/baflion-sans.black.otf'

local fontTitle, fontAwesome = nil, nil

local function ensureDir(path)
    if not lfs.attributes(path, "mode") then
        pcall(lfs.mkdir, path)
    end
end

local function safeDownload(url, path)
    if doesFileExist(path) then return true end
    local body, code = socket.request(url)
    if code ~= 200 or not body then return false end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(body)
    f:close()
    return true
end

imgui.OnInitialize(function()
    local io = imgui.GetIO()
    local style = imgui.GetStyle()
    io.IniFilename = nil

    ensureDir(getWorkingDirectory() .. '/lib')
    ensureDir(BASE_DIR)
    ensureDir(FONT_DIR)

    safeDownload(FONT_URL, FONT_PATH)

    if doesFileExist(FONT_PATH) then
        fontTitle = io.Fonts:AddFontFromFileTTF(FONT_PATH, 15 * dpi)
        io.Fonts:Build()
    end

    io.FontGlobalScale = MDS
    style:ScaleAllSizes(MDS)

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    fontAwesome = io.Fonts:AddFontFromMemoryCompressedBase85TTF(
        faicons.get_font_data_base85('solid'), 18, config, iconRanges
    )
end)


local window = imgui.new.bool(false)

local widgetLabels = {
    ATTACK          = "Adjust Attack",
    ENTER_TARGETING = "Adjust Enter Targeting",
    VC_SHOOT        = "Adjust VC Shoot",
    VC_SHOOT_ALT    = "Adjust VC Shoot Alt",
    SPRINT          = "Adjust Sprint",
    ENTER_CAR       = "Adjust Enter Car",
    ACCELERATE      = "Adjust Accelerate",
    BRAKE           = "Adjust Brake",
    HAND_BRAKE      = "Adjust Hand Brake",
    HORN            = "Adjust Horn",
    REPLAY          = "Adjust Replay",
    PLAYER_INFO     = "Adjust Player Info",
    RADAR           = "Adjust Radar",
    ANALOG          = "Adjust Analog",
}

local function drawWidget(w)
    local label = widgetLabels[w.name] or w.name
    if imgui.CollapsingHeader(label) then
        local step = 0.06
        local scaleStep = 0.01
        local repeatInterval = 0.01
        if w.buttonTimeX == nil then w.buttonTimeX=0 end
        if w.buttonTimeY == nil then w.buttonTimeY=0 end
        if w.buttonTimeW == nil then w.buttonTimeW=0 end
        if w.buttonTimeH == nil then w.buttonTimeH=0 end
        if w.buttonTimeS == nil then w.buttonTimeS=0 end

        imgui.SetNextItemWidth(180)
        imgui.SliderFloat("##x"..w.name, w.x, 0, 1000, "Pos X = %.0f")
        imgui.SameLine()
        if imgui.Button("-##x"..w.name,imgui.ImVec2(33,30))then w.x[0]=w.x[0]-step w.buttonTimeX=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeX>=repeatInterval then w.x[0]=w.x[0]-step w.buttonTimeX=os.clock() end
        imgui.SameLine()
        if imgui.Button("+##x"..w.name,imgui.ImVec2(33,30))then w.x[0]=w.x[0]+step w.buttonTimeX=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeX>=repeatInterval then w.x[0]=w.x[0]+step w.buttonTimeX=os.clock() end

        imgui.SetNextItemWidth(180)
        imgui.SliderFloat("##y"..w.name, w.y, 0, 1000, "Pos Y = %.0f")
        imgui.SameLine()
        if imgui.Button("-##y"..w.name,imgui.ImVec2(33,30))then w.y[0]=w.y[0]-step w.buttonTimeY=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeY>=repeatInterval then w.y[0]=w.y[0]-step w.buttonTimeY=os.clock() end
        imgui.SameLine()
        if imgui.Button("+##y"..w.name,imgui.ImVec2(33,30))then w.y[0]=w.y[0]+step w.buttonTimeY=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeY>=repeatInterval then w.y[0]=w.y[0]+step w.buttonTimeY=os.clock() end

        imgui.SetNextItemWidth(180)
        imgui.SliderFloat("##w"..w.name, w.w, 1, 500, "Width = %.0f")
        imgui.SameLine()
        if imgui.Button("-##w"..w.name,imgui.ImVec2(33,30))then w.w[0]=w.w[0]-step w.buttonTimeW=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeW>=repeatInterval then w.w[0]=w.w[0]-step w.buttonTimeW=os.clock() end
        imgui.SameLine()
        if imgui.Button("+##w"..w.name,imgui.ImVec2(33,30))then w.w[0]=w.w[0]+step w.buttonTimeW=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeW>=repeatInterval then w.w[0]=w.w[0]+step w.buttonTimeW=os.clock() end

        imgui.SetNextItemWidth(180)
        imgui.SliderFloat("##h"..w.name, w.h, 1, 500, "Height = %.0f")
        imgui.SameLine()
        if imgui.Button("-##h"..w.name,imgui.ImVec2(33,30))then w.h[0]=w.h[0]-step w.buttonTimeH=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeH>=repeatInterval then w.h[0]=w.h[0]-step w.buttonTimeH=os.clock() end
        imgui.SameLine()
        if imgui.Button("+##h"..w.name,imgui.ImVec2(33,30))then w.h[0]=w.h[0]+step w.buttonTimeH=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeH>=repeatInterval then w.h[0]=w.h[0]+step w.buttonTimeH=os.clock() end

        imgui.SetNextItemWidth(180)
        imgui.SliderFloat("##s"..w.name, w.s, 0.1, 5, "Scale = %.2f")
        imgui.SameLine()
        if imgui.Button("-##s"..w.name,imgui.ImVec2(33,30))then w.s[0]=w.s[0]-scaleStep w.buttonTimeS=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeS>=repeatInterval then w.s[0]=w.s[0]-scaleStep w.buttonTimeS=os.clock() end
        imgui.SameLine()
        if imgui.Button("+##s"..w.name,imgui.ImVec2(33,30))then w.s[0]=w.s[0]+scaleStep w.buttonTimeS=os.clock() end
        if imgui.IsItemActive()and os.clock()-w.buttonTimeS>=repeatInterval then w.s[0]=w.s[0]+scaleStep w.buttonTimeS=os.clock() end
    end
end

local autoHeight = imgui.new.float(0)
local onFootWidgets = {"ATTACK","ANALOG","VC_SHOOT_ALT","VC_SHOOT","ENTER_TARGETING","SPRINT","RADAR","PLAYER_INFO"}
local inCarWidgets = {"HORN","ACCELERATE","ENTER_CAR","BRAKE","HAND_BRAKE","REPLAY"}

imgui.OnFrame(function() return window[0] end,function()
    darkgreentheme()
    local winWidth = 460*MDS
    imgui.SetNextWindowSize(imgui.ImVec2(winWidth, autoHeight[0]), imgui.Cond.Always)
    if imgui.BeginCustomTitle("Customizable Widget Controller",26*MDS,window,
        imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then
        
local url = "https://youtube.com/@deprauu"
local windowWidth = imgui.GetWindowSize().x
local textWidth = imgui.CalcTextSize(url).x
local offsetX = 105

local scale = 0.7
imgui.SetWindowFontScale(scale)
imgui.SetCursorPosX(windowWidth - textWidth - offsetX)  
imgui.TextColored(imgui.ImVec4(0.90, 0.90, 0.80, 1.00), url)
imgui.SetWindowFontScale(1.0)

if imgui.IsItemClicked() then
    openLink(url)
end
        local childWidth = (winWidth-20)/2
        local childHeight = 0
        imgui.BeginChild("OnFootChild",imgui.ImVec2(childWidth,childHeight),true)
        imgui.SetCursorPosX((childWidth-imgui.CalcTextSize("OnFoot").x)*0.5)
        imgui.Text("OnFoot")
        imgui.Separator()
        for _,name in ipairs(onFootWidgets) do drawWidget(widgets[name]) end
        local leftEndY = imgui.GetCursorPosY()
        imgui.EndChild()
        imgui.SameLine()
        imgui.BeginChild("InCarChild",imgui.ImVec2(childWidth,childHeight),true)
        imgui.SetCursorPosX((childWidth-imgui.CalcTextSize("InVehicle").x)*0.5)
        imgui.Text("InVehicle")
        imgui.Separator()
        for _,name in ipairs(inCarWidgets) do drawWidget(widgets[name]) end
        local rightEndY = imgui.GetCursorPosY()
        imgui.EndChild()
        autoHeight[0] = math.max(leftEndY,rightEndY)+(28*MDS)+40
        imgui.End()
        imgui.PopStyleVar(2)
    end
end)

local function apply(w, ptr)
    if ptr==0 then return end
    memory.setfloat(ptr+0xC,w.x[0],false)
    memory.setfloat(ptr+0x10,w.y[0],false)
    memory.setfloat(ptr+0x14,w.w[0]*w.s[0],false)
    memory.setfloat(ptr+0x18,w.h[0]*w.s[0],false)
end

local function getWidgets()
    local ptr = memory.getuint32(MONET_GTASA_BASE + 0x67947C,false)
    return ptr~=0 and ptr or nil
end

function main()
    repeat wait(100) until isSampAvailable()
    sampRegisterChatCommand("adjust",function() window[0]=not window[0] end)
    local base = getWidgets()
    local map = {
        {1,widgets.ATTACK},
        {19,widgets.ENTER_TARGETING},{20,widgets.ENTER_TARGETING},
        {21,widgets.VC_SHOOT},{22,widgets.VC_SHOOT_ALT},
        {31,widgets.SPRINT},
        {0,widgets.ENTER_CAR},
        {2,widgets.ACCELERATE},{3,widgets.BRAKE},
        {4,widgets.HAND_BRAKE},
        {7,widgets.HORN},
        {18,widgets.REPLAY},
        {160,widgets.PLAYER_INFO},
        {161,widgets.RADAR},
        {167,widgets.ANALOG},
    }
    while true do
        wait(0)
        for _,v in pairs(map) do
            local ptr = memory.getuint32(base+v[1]*4,false)
            apply(v[2],ptr)
        end
    end
end

function darkgreentheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col

    style.Alpha = 1
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 15
    style.WindowBorderSize = 20
    style.WindowMinSize = imgui.ImVec2(32, 32)
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildRounding = 15
    style.ChildBorderSize = 4
    style.PopupRounding = 14
    style.PopupBorderSize = 1
    style.FramePadding = imgui.ImVec2(10, 2)
    style.FrameRounding = 6
    style.FrameBorderSize = 0
    style.ItemSpacing = imgui.ImVec2(10, 10)
    style.ItemInnerSpacing = imgui.ImVec2(6, 6)
    style.GrabMinSize = 8
    style.GrabRounding = 4
    style.ScrollbarSize = 14
    style.ScrollbarRounding = 10
    style.TabRounding = 12

    colors[clr.Text]                 = imgui.ImVec4(0.90, 0.90, 0.80, 1.00)
    colors[clr.TextDisabled]         = imgui.ImVec4(0.60, 0.50, 0.50, 1.00)
    colors[clr.WindowBg]             = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[clr.ChildBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    colors[clr.PopupBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    colors[clr.Border]               = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[clr.FrameBg]              = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[clr.FrameBgHovered]       = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[clr.FrameBgActive]        = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)
    colors[clr.TitleBg]              = imgui.ImVec4(0.15, 0.15, 0.15, 1.00)
    colors[clr.TitleBgCollapsed]     = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[clr.TitleBgActive]        = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[clr.SliderGrab]           = imgui.ImVec4(0.66, 0.66, 0.66, 1.00)
    colors[clr.SliderGrabActive]     = imgui.ImVec4(0.70, 0.70, 0.73, 1.00)
    colors[clr.Button]               = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[clr.ButtonHovered]        = imgui.ImVec4(0.40, 0.40, 0.40, 1.00)
    colors[clr.ButtonActive]         = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.Header]               = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[clr.HeaderHovered]        = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[clr.HeaderActive]         = imgui.ImVec4(0.25, 0.25, 0.25, 1.00)    
end

function imgui.BeginCustomTitle(title, titleSizeY, var, flags, titleOffsetX, titleOffsetY)
    titleOffsetX = titleOffsetX or 10
    titleOffsetY = titleOffsetY or 2

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(5,5))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0)

    local opened = imgui.Begin(title, var, imgui.WindowFlags.NoTitleBar + (flags or 0))
    if opened then
        local style = imgui.GetStyle()
        local p = imgui.GetWindowPos()
        local size = imgui.GetWindowSize()
        local dl = imgui.GetWindowDrawList()

        dl:AddRectFilled(p, imgui.ImVec2(p.x + size.x, p.y + titleSizeY),
            imgui.GetColorU32Vec4(imgui.ImVec4(0.20,0.20,0.20,1)), style.WindowRounding, 3)

        local textSize
        if fontTitle then imgui.PushFont(fontTitle); textSize = imgui.CalcTextSize(title); imgui.PopFont()
        else textSize = imgui.CalcTextSize(title) end

        local textPos = imgui.ImVec2(p.x + titleOffsetX, p.y + titleSizeY - textSize.y - titleOffsetY)

        local offsets = {
            imgui.ImVec2(-1,-1), imgui.ImVec2(-1,1),
            imgui.ImVec2(1,-1),  imgui.ImVec2(1,1)
        }

        if fontTitle then imgui.PushFont(fontTitle) end
        for _, offset in ipairs(offsets) do
            dl:AddText(imgui.ImVec2(textPos.x + offset.x, textPos.y + offset.y),
                imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,1)), title)
        end
        dl:AddText(textPos, imgui.GetColorU32Vec4(imgui.ImVec4(0.90,0.90,0.80,1)), title)
        if fontTitle then imgui.PopFont() end

        local radius = titleSizeY * 0.36
        local padding = 6
        local yOffset = 0
        local closeCenter = imgui.ImVec2(p.x + size.x - radius - padding, p.y + titleSizeY/2 - yOffset)
        local closeHovered = imgui.IsMouseHoveringRect(
            imgui.ImVec2(closeCenter.x - radius, closeCenter.y - radius),
            imgui.ImVec2(closeCenter.x + radius, closeCenter.y + radius)
        )
        if closeHovered and imgui.IsMouseClicked(0) then var[0] = false end
        dl:AddCircleFilled(closeCenter, radius,
            imgui.GetColorU32Vec4(closeHovered and imgui.ImVec4(0.50,0.50,0.50,1) or imgui.ImVec4(0.30,0.30,0.30,1)), 32)
        dl:AddCircle(closeCenter, radius, imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,1)), 32, 2)

        local saveOffset = imgui.ImVec2(-radius*2 - padding, 0)
        local saveCenter = imgui.ImVec2(closeCenter.x + saveOffset.x, closeCenter.y)
        local saveHovered = imgui.IsMouseHoveringRect(
            imgui.ImVec2(saveCenter.x - radius, saveCenter.y - radius),
            imgui.ImVec2(saveCenter.x + radius, saveCenter.y + radius)
        )
        if saveHovered and imgui.IsMouseClicked(0) then saveset() end

        if fontAwesome then imgui.PushFont(fontAwesome) end
        local iconText = faicons('FLOPPY_DISK')
        local iconSize = imgui.CalcTextSize(iconText)
        local iconPos = imgui.ImVec2(saveCenter.x - iconSize.x/2, saveCenter.y - iconSize.y/2 + 1.9)

        local iconStrokeOffsets = {
            imgui.ImVec2(-1,-1), imgui.ImVec2(-1,1),
            imgui.ImVec2(1,-1),  imgui.ImVec2(1,1)
        }

        for _, offset in ipairs(iconStrokeOffsets) do
            dl:AddText(imgui.ImVec2(iconPos.x + offset.x, iconPos.y + offset.y),
                imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,1)), iconText)
        end
        dl:AddText(iconPos, imgui.GetColorU32Vec4(imgui.ImVec4(0.90,0.90,0.80,1)), iconText)
        if fontAwesome then imgui.PopFont() end

        imgui.SetCursorPosY(titleSizeY + 10)
    end
    return opened
end
