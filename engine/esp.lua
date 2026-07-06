-- engine/esp.lua
-- AimHubNext ESP System v3
-- Clean rewrite based on confirmed-working Bloxstrike detection.
-- Uses BoxHandleAdornment (like EDD) + Highlight for chams.
-- Team detection: Attribute-first (Bloxstrike), Team-fallback.
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local ESP = {}

-- ==========================================
-- SETTINGS
-- ==========================================
local DEFAULTS = {
    ESPEnabled       = true,
    ESPShowTeammates = true,
    ESPEnemyColor    = Color3.fromRGB(255, 80,  80),
    ESPTeamColor     = Color3.fromRGB(80,  200, 255),
    ESPBoxSize       = Vector3.new(3.8, 5.5, 3.8),
    ESPBoxTransparency = 0.65,
    ESPChamsEnabled  = true,
    ESPChamsTransparency       = 0.55,
    ESPChamsOutlineTransparency= 0.15,
    -- DepthMode for Highlight chams
    -- "Occluded"    = renders actual mesh edges (proper outline)
    -- "AlwaysOnTop" = renders through walls (wallhack box)
    ESPChamsDepthMode= "Occluded",
}

local function EnsureSettings()
    local S  = State.Settings
    local DS = State.DefaultSettings
    for k, v in pairs(DEFAULTS) do
        if S[k]  == nil then S[k]  = v end
        if DS[k] == nil then DS[k] = v end
    end
end

-- ==========================================
-- STORAGE FOLDER
-- BoxHandleAdornments must be parented to
-- CoreGui or they flicker. We mirror EDD's
-- proven storage pattern.
-- ==========================================
local Storage = nil

local function GetStorage()
    if Storage and Storage.Parent then return Storage end
    -- Try to find existing
    local cg = game:GetService("CoreGui")
    Storage = cg:FindFirstChild("AimHubNext_ESP_Storage")
    if not Storage then
        Storage = Instance.new("Folder")
        Storage.Name   = "AimHubNext_ESP_Storage"
        Storage.Parent = cg
    end
    return Storage
end

-- ==========================================
-- TEAM DETECTION
-- Priority:
--   1. Attribute "Team" (Bloxstrike method — confirmed working)
--   2. player.Team object (standard Roblox)
--   3. TeamColor comparison (fallback)
-- Returns true if teammate, false if enemy.
-- ==========================================
local function IsTeammate(player)
    local lp = Services.LocalPlayer
    if player == lp then return true end

    -- Method 1: Attribute-based (Bloxstrike)
    local ok1, lpAttr = pcall(function()
        return lp:GetAttribute("Team")
    end)
    local ok2, plAttr = pcall(function()
        return player:GetAttribute("Team")
    end)
    if ok1 and ok2
    and lpAttr ~= nil and plAttr ~= nil then
        return lpAttr == plAttr
    end

    -- Method 2: Standard Team object
    if player.Team ~= nil and lp.Team ~= nil then
        return player.Team == lp.Team
    end

    -- Method 3: TeamColor
    if player.TeamColor ~= nil and lp.TeamColor ~= nil then
        if player.TeamColor == lp.TeamColor then
            -- Guard against default BrickColor (white/gray)
            -- which all players share before teams are assigned
            local neutral = BrickColor.new("Medium stone grey")
            local white   = BrickColor.new("White")
            local col     = player.TeamColor
            if col ~= neutral and col ~= white then
                return true
            end
        end
    end

    return false
end

-- ==========================================
-- PER-PLAYER ESP OBJECT CACHE
-- { [playerName] = { box, highlight } }
-- Keyed by name string so cleanup works
-- even after Player instance is gone.
-- ==========================================
local Cache = {}

local function GetColor(player)
    local S = State.Settings
    return IsTeammate(player)
        and S.ESPTeamColor
        or  S.ESPEnemyColor
end

-- ==========================================
-- GET OR CREATE BOX + HIGHLIGHT
-- ==========================================
local function GetObjects(player)
    local name = player.Name
    if Cache[name] then return Cache[name] end

    local storage = GetStorage()
    local objs    = {}

    -- BoxHandleAdornment (the EDD-style ESP box)
    local box = Instance.new("BoxHandleAdornment")
    box.Name        = "AHN_Box_" .. name
    box.AlwaysOnTop = true
    box.ZIndex      = 4
    box.Visible     = false
    box.Parent      = storage
    objs.box        = box

    -- Highlight (chams — mesh-edge or wallhack depending on setting)
    local hl = Instance.new("Highlight")
    hl.Name    = "AHN_Chams_" .. name
    hl.Visible = false
    hl.Parent  = storage
    objs.highlight = hl

    Cache[name] = objs
    return objs
end

-- ==========================================
-- REMOVE ONE PLAYER'S ESP OBJECTS
-- ==========================================
local function RemoveObjects(name)
    local objs = Cache[name]
    if not objs then return end
    pcall(function()
        if objs.box       then objs.box:Destroy()       end
        if objs.highlight then objs.highlight:Destroy() end
    end)
    Cache[name] = nil
end

-- ==========================================
-- UPDATE ONE PLAYER
-- ==========================================
local function UpdatePlayer(player)
    local S    = State.Settings
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local name = player.Name

    -- No valid character → hide and return
    if not hrp or not hum or hum.Health <= 0 then
        local objs = Cache[name]
        if objs then
            if objs.box       then objs.box.Visible       = false end
            if objs.highlight then objs.highlight.Visible = false end
        end
        return
    end

    local teammate = IsTeammate(player)

    -- Hide teammates if setting off
    if teammate and not S.ESPShowTeammates then
        local objs = Cache[name]
        if objs then
            if objs.box       then objs.box.Visible       = false end
            if objs.highlight then objs.highlight.Visible = false end
        end
        return
    end

    local color = teammate and S.ESPTeamColor or S.ESPEnemyColor
    local objs  = GetObjects(player)

    -- ---- BOX ----
    if S.ESPEnabled then
        objs.box.Adornee     = hrp
        objs.box.Color3      = color
        objs.box.Size        = S.ESPBoxSize
        objs.box.Transparency= math.clamp(S.ESPBoxTransparency, 0, 1)
        objs.box.Visible     = true
    else
        objs.box.Visible = false
    end

    -- ---- HIGHLIGHT CHAMS ----
    if S.ESPChamsEnabled then
        -- Adornee must be the character model for mesh-edge rendering
        objs.highlight.Adornee  = char

        -- DepthMode selection
        local depthMode = Enum.HighlightDepthMode.Occluded
        if S.ESPChamsDepthMode == "AlwaysOnTop" then
            depthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
        objs.highlight.DepthMode = depthMode

        objs.highlight.FillColor           = color
        objs.highlight.OutlineColor        = color
        objs.highlight.FillTransparency    = math.clamp(
            S.ESPChamsTransparency, 0, 1)
        objs.highlight.OutlineTransparency = math.clamp(
            S.ESPChamsOutlineTransparency, 0, 1)
        objs.highlight.Visible = true
    else
        objs.highlight.Visible = false
    end
end

-- ==========================================
-- TICK — called every frame from lifecycle
-- ==========================================
function ESP.Tick()
    local S       = State.Settings
    local Players = Services.Players
    local lp      = Services.LocalPlayer

    -- If everything off, clean up and exit
    if not S.ESPEnabled and not S.ESPChamsEnabled then
        ESP.Cleanup()
        return
    end

    -- Track which players are active this frame
    local active = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        active[player.Name] = true
        pcall(UpdatePlayer, player)
    end

    -- Remove objects for players who left
    for name, _ in pairs(Cache) do
        if not active[name] then
            RemoveObjects(name)
        end
    end
end

-- ==========================================
-- INIT
-- ==========================================
function ESP.Init()
    EnsureSettings()
    GetStorage()

    -- Clean up when player leaves
    Services.Players.PlayerRemoving:Connect(function(player)
        RemoveObjects(player.Name)
    end)
end

-- ==========================================
-- CLEANUP — called by UniversalDestruct
-- ==========================================
function ESP.Cleanup()
    for name, _ in pairs(Cache) do
        RemoveObjects(name)
    end
    Cache = {}
    -- Destroy storage folder
    pcall(function()
        local existing = game:GetService("CoreGui")
            :FindFirstChild("AimHubNext_ESP_Storage")
        if existing then existing:Destroy() end
    end)
    Storage = nil
end

-- ==========================================
-- GET DEPTH MODES (for UI dropdown)
-- ==========================================
function ESP.GetDepthModes()
    return { "Occluded", "AlwaysOnTop" }
end

return ESP