local imgui  = require 'mimgui'
local ffi    = require("ffi")
local hook   = require("monethook")
local gta    = ffi.load("GTASA")
local mm     = require('SAMemory')
local json   = require("dkjson")
local io     = require("io")
local cast   = ffi.cast
script_author("Deprau")

mm.require('RenderWare')
mm.require('FxSystem_c')
mm.require('CVehicle')
mm.require('CAutomobile')
mm.require('CDamageManager')

math.randomseed(os.time())

ffi.cdef([[
    typedef struct { float x, y, z; } cvec;

    int  _Z16RwTextureDestroyP9RwTexture(void* tex);

    void _ZN8CShadows23StoreShadowToBeRenderedEhP9RwTextureP7CVectorffffshhhfbfP15CRealTimeShadowb(
        uint8_t shadowType, void* texture, cvec* position,
        float frontX, float frontY, float sideX, float sideY,
        int16_t intensity, uint8_t r, uint8_t g, uint8_t b,
        float zDistance, bool drawOnWater, float scale,
        void* pRealTimeShadow, bool dontRender
    );
    void _ZN8CVehicle13SetupLightingEv(void* thisVeh);
    void _ZN14CDamageManager14SetLightStatusE7eLightsj(void* thisDM, int light, unsigned int status);
    bool _ZN10CModelInfo10IsCarModelEi(int modelId);
    void _ZN8CShadows19RenderStoredShadowsEb(bool);
]])

local new = imgui.new

local config_dir  = "config"
local config_file = config_dir .. "/CarLightsFX.json"

local ui_open = new.bool(false)

local neon_enabled     = new.bool(true)
local neon_scale       = new.float(3.036)
local neon_width       = new.float(1.893)
local neon_offset_x    = new.float(0.0)
local neon_offset_y    = new.float(0.0)
local neon_spacing     = new.float(0.5)
local neon_rotation_a  = new.float(0.0)
local neon_rotation_b  = new.float(0.0)
local neon_color       = new.float[3](0.0, 0.66667771339417, 1.0)

local neon_blink_enabled = new.bool(false)
local style_blink_4x    = new.bool(false)
local style_normal      = new.bool(false)
local style_left_right  = new.bool(true)
local neon_blink_speed = new.float(6.629)

local taillight_enabled = new.bool(true)
local taillight_scale   = new.float(1.429)
local taillight_width   = new.float(1.732)
local taillight_offset_x = new.float(0.0)
local taillight_offset_y = new.float(-2.97)
local taillight_rotation = new.float(0.0)
local taillight_color   = new.float[3](0.65205895900726, 1.0, 0.0)

local taillight_blink_enabled = new.bool(false)
local taillight_blink_speed   = new.float(1.754)

local tmp_offset_x_a = new.float(0.0)
local tmp_offset_x_b = new.float(0.0)

local only_engine_on   = new.bool(true)
local distance_limit_enabled = new.bool(true)
local max_distance      = new.float(60.0)

local desync_blink_enabled = new.bool(true)

local shadow_type     = 2
local shadow_zdist    = 20.0
local shadow_layers   = 1
local draw_on_water   = false
local flash_intensity = 32767

local neon_texture, neon_loaded = nil, false
local taillight_texture, taillight_loaded = nil, false

local render_shadows_hook = nil
local setup_lighting_hook = nil
local chat_command_registered = false

os.execute('mkdir -p ' .. config_dir)

-- Muted gray section header, used across every tab for a consistent aesthetic
local SECTION_COLOR = imgui.ImVec4(0.62, 0.62, 0.62, 1.0)
local function section_title(text)
    imgui.TextColored(SECTION_COLOR, text)
end

local function get_neon_style_index()
    if style_blink_4x[0] then return 0
    elseif style_normal[0] then return 1
    elseif style_left_right[0] then return 2
    else return 0 end
end

local function set_neon_style(idx)
    style_blink_4x[0]   = (idx == 0)
    style_normal[0]     = (idx == 1)
    style_left_right[0] = (idx == 2)
end

local strobe_enabled = new.bool(true)
local strobe_speed   = new.float(3.763)

local function save_config()
    local ok, file = pcall(io.open, config_file, "w")
    if not ok or not file then return end
    file:write(json.encode({
        neon_enabled = neon_enabled[0],
        scale0      = neon_scale[0],
        width0      = neon_width[0],
        offsetX0    = neon_offset_x[0],
        offsetY0    = neon_offset_y[0],
        spacing0    = neon_spacing[0],
        rotation0A  = neon_rotation_a[0],
        rotation0B  = neon_rotation_b[0],
        colorR0     = neon_color[0],
        colorG0     = neon_color[1],
        colorB0     = neon_color[2],
        neon_blink_enabled = neon_blink_enabled[0],
        neon_style = get_neon_style_index(),
        blinkSpeed0 = neon_blink_speed[0],

        taillight_enabled = taillight_enabled[0],
        scale3      = taillight_scale[0],
        width3      = taillight_width[0],
        offsetX3    = taillight_offset_x[0],
        offsetY3    = taillight_offset_y[0],
        rotation3   = taillight_rotation[0],
        colorR3     = taillight_color[0],
        colorG3     = taillight_color[1],
        colorB3     = taillight_color[2],
        taillight_blink_enabled = taillight_blink_enabled[0],
        blinkSpeed3 = taillight_blink_speed[0],

        only_engine_on         = only_engine_on[0],
        distance_limit_enabled = distance_limit_enabled[0],
        max_distance           = max_distance[0],

        desync_blink_enabled = desync_blink_enabled[0],

        strobe_enabled = strobe_enabled[0],
        strobe_speed   = strobe_speed[0]
    }, { indent = true }))
    file:close()
end

local function load_config()
    local ok, file = pcall(io.open, config_file, "r")
    if not ok or not file then return end
    local content = file:read("*a")
    file:close()

    local okd, data = pcall(json.decode, content)
    if not okd or not data then return end

    if data.neon_enabled ~= nil then neon_enabled[0] = data.neon_enabled end
    neon_scale[0]      = data.scale0 or 3.036
    neon_width[0]      = data.width0 or 1.893
    neon_offset_x[0]   = data.offsetX0 or 0.0
    neon_offset_y[0]   = data.offsetY0 or 0.0
    neon_spacing[0]    = data.spacing0 or 0.5
    neon_rotation_a[0] = data.rotation0A or 0.0
    neon_rotation_b[0] = data.rotation0B or 0.0
    neon_color[0]      = data.colorR0 or 0.0
    neon_color[1]      = data.colorG0 or 0.66667771339417
    neon_color[2]      = data.colorB0 or 1.0
    if data.neon_blink_enabled ~= nil then neon_blink_enabled[0] = data.neon_blink_enabled end
    set_neon_style(data.neon_style or 2)
    neon_blink_speed[0] = data.blinkSpeed0 or 6.629

    if data.taillight_enabled ~= nil then taillight_enabled[0] = data.taillight_enabled end
    taillight_scale[0]    = data.scale3 or 1.429
    taillight_width[0]    = data.width3 or 1.732
    taillight_offset_x[0] = data.offsetX3 or 0.0
    taillight_offset_y[0] = data.offsetY3 or -2.97
    taillight_rotation[0] = data.rotation3 or 0.0
    taillight_color[0]    = data.colorR3 or 0.65205895900726
    taillight_color[1]    = data.colorG3 or 1.0
    taillight_color[2]    = data.colorB3 or 0.0
    if data.taillight_blink_enabled ~= nil then taillight_blink_enabled[0] = data.taillight_blink_enabled end
    taillight_blink_speed[0] = data.blinkSpeed3 or 1.754

    if data.only_engine_on ~= nil then only_engine_on[0] = data.only_engine_on end
    if data.distance_limit_enabled ~= nil then distance_limit_enabled[0] = data.distance_limit_enabled end
    max_distance[0] = data.max_distance or 60.0

    if data.desync_blink_enabled ~= nil then desync_blink_enabled[0] = data.desync_blink_enabled end

    if data.strobe_enabled ~= nil then strobe_enabled[0] = data.strobe_enabled end
    strobe_speed[0] = data.strobe_speed or 3.763
end

local function is_finite_number(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

local VEHICLE_TYPE_CAR = 0

local function is_vehicle_car(this_veh)
    if this_veh == nil then return false end

    local ok1, model_ok = pcall(function()
        local model_id = cast('CVehicle*', this_veh).nModelIndex
        return gta._ZN10CModelInfo10IsCarModelEi(model_id)
    end)
    if not ok1 or not model_ok then return false end

    local ok2, vtype = pcall(function()
        return cast('CVehicle*', this_veh).m_vehicleType
    end)
    if ok2 and vtype ~= nil then
        return vtype == VEHICLE_TYPE_CAR
    end

    return model_ok
end

local function has_driver(this_veh)
    if this_veh == nil then return false end
    local ok, driver_ptr = pcall(function()
        return cast('CVehicle*', this_veh).pDriver
    end)
    if not ok then return false end
    return driver_ptr ~= nil and driver_ptr ~= ffi.NULL
end

-- Per-vehicle time offset, used to desync the blink phase so lights don't sync up
local vehicle_time_offset = {}

local function get_vehicle_key(veh_ptr)
    local ok, addr = pcall(function() return tonumber(cast('uintptr_t', veh_ptr)) end)
    if not ok then return tostring(veh_ptr) end
    return addr
end

local function get_vehicle_offset(veh_ptr)
    if not desync_blink_enabled[0] then return 0.0 end
    local key = get_vehicle_key(veh_ptr)
    local off = vehicle_time_offset[key]
    if off == nil then
        off = math.random() * 1000.0
        vehicle_time_offset[key] = off
    end
    return off
end

local function get_entity_matrix(entity_ptr)
    local ok, mat_ptr = pcall(function()
        return cast('uintptr_t*', entity_ptr + 0x14)[0]
    end)
    if not ok or mat_ptr == 0 then return nil end
    local okm, m = pcall(cast, 'RwMatrix*', mat_ptr)
    if not okm then return nil end
    return m
end

local function get_entity_pos_and_axes(entity_ptr)
    local m = get_entity_matrix(entity_ptr)
    if not m then return nil end

    local ok2, x, y, z, rx, ry, fx, fy = pcall(function()
        return m.pos.x, m.pos.y, m.pos.z,
               m.right.x, m.right.y,
               m.up.x, m.up.y
    end)
    if not ok2 then return nil end
    if not (is_finite_number(x) and is_finite_number(y) and is_finite_number(z)
        and is_finite_number(rx) and is_finite_number(ry) and is_finite_number(fx) and is_finite_number(fy)) then
        return nil
    end

    local len = math.sqrt(fx * fx + fy * fy)
    if len < 0.0001 then return nil end
    fx, fy = fx / len, fy / len
    rx, ry = fy, -fx

    return x, y, z, rx, ry, fx, fy
end

-- Pull every vehicle currently in the world instead of tracking one reference vehicle
local function get_vehicle_pointers()
    local list = {}
    local ok, vehicles = pcall(getAllVehicles)
    if not ok or not vehicles then return list end
    for _, v in ipairs(vehicles) do
        local okp, ptr = pcall(getCarPointer, v)
        if okp and ptr and ptr ~= 0 then
            list[#list + 1] = cast('uintptr_t', ptr)
        end
    end
    return list
end

local shadow_pos = ffi.new('cvec')

local function fire_shadow(tex, x, y, z, rx, ry, fx, fy, scale, width, off_x, off_y, rot, color)
    shadow_pos.x = x + rx * off_x[0] + fx * off_y[0]
    shadow_pos.y = y + ry * off_x[0] + fy * off_y[0]
    shadow_pos.z = z

    local r = math.floor(color[0] * 255 + 0.5)
    local g = math.floor(color[1] * 255 + 0.5)
    local b = math.floor(color[2] * 255 + 0.5)

    local rad = math.rad(rot[0])
    local cosr, sinr = math.cos(rad), math.sin(rad)
    local rfx = fx * cosr - fy * sinr
    local rfy = fx * sinr + fy * cosr
    local rrx = rx * cosr - ry * sinr
    local rry = rx * sinr + ry * cosr

    local w = scale[0]
    local h = width[0]

    local front_x = rfx * w
    local front_y = rfy * w
    local side_x  = rrx * h
    local side_y  = rry * h

    for i = 1, shadow_layers do
        pcall(
            gta._ZN8CShadows23StoreShadowToBeRenderedEhP9RwTextureP7CVectorffffshhhfbfP15CRealTimeShadowb,
            shadow_type, tex, shadow_pos,
            front_x, front_y, side_x, side_y,
            flash_intensity, r, g, b,
            shadow_zdist, draw_on_water, 1.0,
            nil, false
        )
    end
end

local function get_neon_blink_state(t)
    if not neon_blink_enabled[0] then
        return true, true
    end

    local period = 1.0 / math.max(neon_blink_speed[0], 0.01)
    local style = get_neon_style_index()

    if style == 0 then
        local total = (8 * period) + 1.0
        local tm = t % total
        if tm < (8 * period) then
            local idx = math.floor(tm / period)
            local on = (idx % 2 == 0)
            return on, on
        else
            return false, false
        end
    elseif style == 1 then
        local idx = math.floor(t / period)
        local on = (idx % 2 == 0)
        return on, on
    else
        local idx = math.floor(t / period)
        local phase = idx % 2
        if phase == 0 then
            return true, false
        else
            return false, true
        end
    end
end

-- Player position, used to filter vehicles by distance_limit
local function get_player_pos()
    local ok, x, y, z = pcall(getCharCoordinates, PLAYER_PED)
    if not ok then return nil end
    return x, y, z
end

local function apply_vehicle_shadows(veh_ptr, t, px, py)
    if not is_vehicle_car(veh_ptr) then return end
    if only_engine_on[0] and not has_driver(veh_ptr) then return end

    local x, y, z, rx, ry, fx, fy = get_entity_pos_and_axes(veh_ptr)
    if not x then return end

    if distance_limit_enabled[0] and px and py then
        local dx, dy = x - px, y - py
        if (dx * dx + dy * dy) > (max_distance[0] * max_distance[0]) then return end
    end

    local vt = t + get_vehicle_offset(veh_ptr)

    if neon_enabled[0] and neon_texture ~= nil then
        local on_a, on_b = get_neon_blink_state(vt)
        local half = neon_spacing[0] * 0.5
        if on_a then
            tmp_offset_x_a[0] = neon_offset_x[0] - half
            fire_shadow(neon_texture, x, y, z, rx, ry, fx, fy, neon_scale, neon_width,
                tmp_offset_x_a, neon_offset_y, neon_rotation_a, neon_color)
        end
        if on_b then
            tmp_offset_x_b[0] = neon_offset_x[0] + half
            fire_shadow(neon_texture, x, y, z, rx, ry, fx, fy, neon_scale, neon_width,
                tmp_offset_x_b, neon_offset_y, neon_rotation_b, neon_color)
        end
    end

    if taillight_enabled[0] and taillight_loaded and taillight_texture ~= nil then
        local on_t = true
        if taillight_blink_enabled[0] then
            local period_t = 1.0 / math.max(taillight_blink_speed[0], 0.01)
            on_t = (math.floor(vt / period_t) % 2 == 0)
        end
        if on_t then
            fire_shadow(taillight_texture, x, y, z, rx, ry, fx, fy, taillight_scale, taillight_width,
                taillight_offset_x, taillight_offset_y, taillight_rotation, taillight_color)
        end
    end
end

local function inject_shadow_flashes()
    local t = os.clock()
    local px, py = get_player_pos()
    local vehicles = get_vehicle_pointers()
    for _, veh_ptr in ipairs(vehicles) do
        pcall(apply_vehicle_shadows, veh_ptr, t, px, py)
    end
end

render_shadows_hook = hook.new(
    "void(*)(bool)",
    function(a1)
        pcall(inject_shadow_flashes)
        return render_shadows_hook(a1)
    end,
    cast("uintptr_t", cast("void*", gta._ZN8CShadows19RenderStoredShadowsEb))
)

local function load_textures()
    local ok2, tx2 = pcall(renderLoadTextureFromFile, getWorkingDirectory() .. '/resource/0.png')
    if ok2 and tx2 then
        neon_texture = cast('RwTexture*', tx2)
        neon_loaded = true
    end

    local ok3, tx3 = pcall(renderLoadTextureFromFile, getWorkingDirectory() .. '/resource/2.png')
    if ok3 and tx3 then
        taillight_texture = cast('RwTexture*', tx3)
        taillight_loaded = true
    end

    return neon_loaded or taillight_loaded
end

local damstate_ok      = 0
local damstate_damaged = 2

local light_front_left  = 0
local light_front_right = 1

local dm_offset = ffi.offsetof('CAutomobile', 'damageManager')

strobe_enabled = new.bool(true)
strobe_speed   = new.float(2.5)

local touched_vehicles = {}

local function set_light_status(veh_ptr, light, status)
    local dm_ptr = cast('void*', cast('uintptr_t', veh_ptr) + dm_offset)
    gta._ZN14CDamageManager14SetLightStatusE7eLightsj(dm_ptr, light, status)
end

local function restore_lights()
    for key, veh_ptr in pairs(touched_vehicles) do
        pcall(function()
            set_light_status(veh_ptr, light_front_left, damstate_ok)
            set_light_status(veh_ptr, light_front_right, damstate_ok)
        end)
        touched_vehicles[key] = nil
    end
end

setup_lighting_hook = hook.new(
    "void(*)(void*)",
    function(this_veh)
        setup_lighting_hook(this_veh)

        if not strobe_enabled[0] then return end
        if not is_vehicle_car(this_veh) then return end
        if not has_driver(this_veh) then return end

        pcall(function()
            local key = tostring(this_veh)
            touched_vehicles[key] = this_veh

            local blink_dur = 1.0 / strobe_speed[0]
            local cycle_dur = blink_dur * 4.0

            local t = (os.clock() + get_vehicle_offset(this_veh)) % cycle_dur
            local blink_index = math.floor(t / blink_dur)
            local t_in_blink = t % blink_dur

            local left_side = blink_index < 2
            local lamp_on = t_in_blink < (blink_dur * 0.5)

            local left_status  = (left_side and lamp_on) and damstate_ok or damstate_damaged
            local right_status = ((not left_side) and lamp_on) and damstate_ok or damstate_damaged

            set_light_status(this_veh, light_front_left,  left_status)
            set_light_status(this_veh, light_front_right, right_status)
        end)
    end,
    cast("uintptr_t", cast("void*", gta._ZN8CVehicle13SetupLightingEv))
)

local function cleanup_all()
    restore_lights()

    if neon_texture then
        pcall(gta._Z16RwTextureDestroyP9RwTexture, neon_texture)
        neon_texture = nil
    end
    neon_loaded = false

    if taillight_texture then
        pcall(gta._Z16RwTextureDestroyP9RwTexture, taillight_texture)
        taillight_texture = nil
    end
    taillight_loaded = false

    if render_shadows_hook and render_shadows_hook.remove then
        pcall(render_shadows_hook.remove, render_shadows_hook)
    end
    if setup_lighting_hook and setup_lighting_hook.remove then
        pcall(setup_lighting_hook.remove, setup_lighting_hook)
    end

    if chat_command_registered then
        pcall(sampUnregisterChatCommand, 'carl')
        chat_command_registered = false
    end

    ui_open[0] = false
end

addEventHandler('onScriptTerminate', function(scr)
    if scr == script.this then
        pcall(cleanup_all)
    end
end)

imgui.OnFrame(
    function() return ui_open[0] end,
    function(player)
        local ok = pcall(function()
            imgui.SetNextWindowSize(imgui.ImVec2(380, 0), imgui.Cond.FirstUseEver)
            imgui.Begin('CarLightsFX', ui_open, imgui.WindowFlags.AlwaysAutoResize)

            if imgui.BeginTabBar('Deprau - CarLightsFX') then

                if imgui.BeginTabItem('Neon') then
                    section_title('Neon Light')
                    if imgui.Checkbox('Enabled##neon', neon_enabled) then save_config() end

                    section_title('Dimensions & Position')
                    if imgui.SliderFloat('Height##0', neon_scale, 0.0, 5.0) then save_config() end
                    if imgui.SliderFloat('Width##0', neon_width, 0.0, 5.0) then save_config() end
                    if imgui.DragFloat('Offset X##0', neon_offset_x, 0.01, -5.0, 5.0) then save_config() end
                    if imgui.DragFloat('Offset Y##0', neon_offset_y, 0.01, -5.0, 5.0) then save_config() end
                    imgui.Spacing()

                    section_title('Color')
                    if imgui.ColorEdit3('##neon_color', neon_color) then save_config() end

                    imgui.Spacing()

                    section_title('Blink Settings')
                    if imgui.Checkbox('Blink Enabled##0', neon_blink_enabled) then save_config() end

                    if neon_blink_enabled[0] then
                        imgui.Spacing()
                        section_title('Blink Mode')
                        if imgui.Checkbox('4x Blink then Pause 1s##0', style_blink_4x) then
                            if style_blink_4x[0] then set_neon_style(0) else style_blink_4x[0] = true end
                            save_config()
                        end
                        if imgui.Checkbox('Normal Blink##0', style_normal) then
                            if style_normal[0] then set_neon_style(1) else style_normal[0] = true end
                           save_config()
                        end
                        if imgui.Checkbox('Left to Right Sweep##0', style_left_right) then
                            if style_left_right[0] then set_neon_style(2) else style_left_right[0] = true end
                            save_config()
                        end
                        imgui.Spacing()
                        if imgui.SliderFloat('Blink Speed##0', neon_blink_speed, 0.5, 20.0) then save_config() end
                    end

                    imgui.EndTabItem()
                end

                if imgui.BeginTabItem('Taillight') then
                    section_title('Taillight')
                    if imgui.Checkbox('Enabled##taillight', taillight_enabled) then save_config() end

                    section_title('Dimensions & Position')
                    if imgui.SliderFloat('Height##3', taillight_scale, 0.0, 5.0) then save_config() end
                    if imgui.SliderFloat('Width##3', taillight_width, 0.0, 5.0) then save_config() end
                    if imgui.DragFloat('Offset X##3', taillight_offset_x, 0.01, -5.0, 5.0) then save_config() end
                    if imgui.DragFloat('Offset Y##3', taillight_offset_y, 0.01, -5.0, 5.0) then save_config() end
                    imgui.Spacing()

                    section_title('Color')
                    if imgui.ColorEdit3('##taillight_color', taillight_color) then save_config() end

                    imgui.Spacing()

                    section_title('Blink Settings')
                    if imgui.Checkbox('Blink Enabled##3', taillight_blink_enabled) then save_config() end
                    if taillight_blink_enabled[0] then
                        imgui.Spacing()
                        if imgui.SliderFloat('Blink Speed##3', taillight_blink_speed, 0.5, 20.0) then save_config() end
                    end

                    imgui.EndTabItem()
                end

                if imgui.BeginTabItem('Strobe') then
                    section_title('Strobe Light')
                    if imgui.Checkbox('Enabled##strobe', strobe_enabled) then
                        if not strobe_enabled[0] then restore_lights() end
                        save_config()
                    end
                    imgui.Spacing()

                    if imgui.SliderFloat('Blink Speed##strobe', strobe_speed, 0.5, 4.0) then save_config() end

                    imgui.EndTabItem()
                end

                imgui.EndTabBar()
            end

            imgui.End()
        end)
        if not ok then
            pcall(imgui.End)
        end
    end
)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    load_config()
    if not load_textures() then return end

    if not chat_command_registered then
        pcall(sampUnregisterChatCommand, 'carl')
        local ok = pcall(sampRegisterChatCommand, 'carl', function()
            ui_open[0] = not ui_open[0]
        end)
        chat_command_registered = ok
    end

    wait(-1)
end
