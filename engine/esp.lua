-- engine/esp.lua
-- AimHubNext ESP v4
-- Architecture copied from EDD (proven working):
--   - All objects parented to CoreGui folder
--   - Adornee set separately from Parent
--   - Team check: Attribute first, Team object second
--   - Stepped loop pattern (called from lifecycle)
-- Adds: Highlight chams with proper Occluded depth mode
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local ESP = {}

-- ==========================================
-- SETTINGS
-- ==========================================
local DEFAULTS = {
    ESPEnabled             = true,
    ESPShowTeammates       = true,
    ESPEnemyColor          = Color3.fromRGB(255, 80,  80),
    ESPTeamColor           = Color3.fromRGB(80,  200, 255),
    ESPChamsEnabled        = true,
    ESPChamsTransparency        = 0.55,
    ESPChamsOutlineTransparency = 0.15,
    ESPChamsDepthMode      = "Occluded",
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
-- COREGUI STORAGE
-- Critical: ALL objects live here, not in
-- character. This survives respawn.
-- ==========================================
local StorageFolder = nil

local function GetStorage()
    if StorageFolder and StorageFolder.Parent then
        return StorageFolder
    end
    local cg = game:GetService("CoreGui")
    -- Clean up any previous instance
    local old = cg:FindFirstChild("AimHubNext_ESP_Storage")
    if old then pcall(function() old:Destroy() end) end

    local folder = Instance.new("Folder")
    folder.Name   = "AimHubNext_ESP_Storage"
    folder.Parent = cg
    StorageFolder = folder
    return folder
end

-- ==========================================
-- TEAM DETECTION
-- Exact copy of EDD's checkIsEnemy logic,
-- inverted to IsTeammate for our naming.
--
-- EDD's original:
--   if p.Team == LocalPlayer.Team → not enemy
--   if p:GetAttribute("Team") == LocalPlayer:GetAttribute("Team") → not enemy
--
-- The GetAttribute check is what works in Bloxstrike.
-- ==========================================
local function IsTeammate(player)
    local lp = Services.LocalPlayer
    if player == lp then return true end

    -- Check 1: Standard Team object (works in most games)
    if player.Team ~= nil
    and lp.Team ~= nil
    and player.Team == lp.Team then
        return true
    end

    -- Check 2: Attribute-based team (Bloxstrike uses this)
    local lpTeamAttr = nil
    local plTeamAttr = nil
    pcall(function() lpTeamAttr = lp:GetAttribute("Team") end)
    pcall(function() plTeamAttr = player:GetAttribute("Team") end)

    if lpTeamAttr ~= nil
    and plTeamAttr ~= nil
    and lpTeamAttr == plTeamAttr then
        return true
    end

    return false
end

-- ==========================================
-- PER-PLAYER OBJECT CACHE
-- Keyed by player Name string.
-- Objects survive character respawn because
-- they live in CoreGui, not the character.
-- ==========================================
-- { [name] = { highlight = Highlight } }
local Cache = {}

-- ==========================================
-- GET OR CREATE HIGHLIGHT FOR PLAYER
-- Parent = CoreGui storage folder
-- Adornee = character model (set each frame)
-- ==========================================
local function GetHighlight(playerName)
    local entry = Cache[playerName]
    if entry and entry.highlight
    and entry.highlight.Parent then
        return entry.highlight
    end

    -- Create new highlight in CoreGui storage
    local storage = GetStorage()
    local hl = Instance.new("Highlight")
    hl.Name    = "AHN_HL_" .. playerName
    hl.Parent  = storage   -- NOT the character

    if not Cache[playerName] then
        Cache[playerName] = {}
    end
    Cache[playerName].highlight = hl
    return hl
end

-- ==========================================
-- APPLY DEPTH MODE
-- ==========================================
local function GetDepthMode()
    local S = State.Settings
    if S.ESPChamsDepthMode == "AlwaysOnTop" then
        return Enum.HighlightDepthMode.AlwaysOnTop
    end
    return Enum.HighlightDepthMode.Occluded
end

-- ==========================================
-- UPDATE ONE PLAYER
-- Called every Stepped tick.
-- Mirrors EDD's per-player update pattern.
-- ==========================================
local function UpdatePlayer(player)
    local S    = State.Settings
    local name = player.Name
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    -- No valid character: hide highlight
    if not root or not hum or hum.Health <= 0 then
        local entry = Cache[name]
        if entry and entry.highlight then
            entry.highlight.Enabled = false
        end
        return
    end

    local teammate = IsTeammate(player)

    -- Hide teammate if setting off
    if teammate and not S.ESPShowTeammates then
        local entry = Cache[name]
        if entry and entry.highlight then
            entry.highlight.Enabled = false
        end
        return
    end

    local color = teammate
        and S.ESPTeamColor
        or  S.ESPEnemyColor

    -- ---- HIGHLIGHT (chams edge rendering) ----
    if S.ESPEnabled and S.ESPChamsEnabled then
        local hl = GetHighlight(name)

        -- Set adornee to character model every frame
        -- This is what EDD does with box.Adornee = root
        -- For Highlight, Adornee = the character Model
        hl.Adornee  = char
        hl.Enabled  = true
        hl.DepthMode= GetDepthMode()

        hl.FillColor           = color
        hl.OutlineColor        = color
        hl.FillTransparency    = math.clamp(
            S.ESPChamsTransparency, 0, 1)
        hl.OutlineTransparency = math.clamp(
            S.ESPChamsOutlineTransparency, 0, 1)

    elseif S.ESPEnabled and not S.ESPChamsEnabled then
        -- ESP on but chams off: still show but
        -- make fill invisible, keep outline
        local hl = GetHighlight(name)
        hl.Adornee             = char
        hl.Enabled             = true
        hl.DepthMode           = GetDepthMode()
        hl.FillColor           = color
        hl.OutlineColor        = color
        hl.FillTransparency    = 1      -- invisible fill
        hl.OutlineTransparency = math.clamp(
            S.ESPChamsOutlineTransparency, 0, 1)

    else
        -- ESP fully off
        local entry = Cache[name]
        if entry and entry.highlight then
            entry.highlight.Enabled = false
        end
    end
end

-- ==========================================
-- REMOVE ONE PLAYER'S OBJECTS
-- Called on PlayerRemoving.
-- ==========================================
local function RemovePlayer(name)
    local entry = Cache[name]
    if not entry then return end
    if entry.highlight then
        pcall(function() entry.highlight:Destroy() end)
    end
    Cache[name] = nil
end

-- ==========================================
-- TICK
-- Called from lifecycle every Stepped event.
-- Mirrors EDD's RunService.Stepped loop exactly.
-- ==========================================
function ESP.Tick()
    local Players = Services.Players
    local lp      = Services.LocalPlayer

    local active = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        active[player.Name] = true
        pcall(UpdatePlayer, player)
    end

    -- Clean up departed players
    for name in pairs(Cache) do
        if not active[name] then
            RemovePlayer(name)
        end
    end
end

-- ==========================================
-- INIT
-- ==========================================
function ESP.Init()
    EnsureSettings()
    GetStorage()

    -- Clean up on player leave immediately
    Services.Players.PlayerRemoving:Connect(function(player)
        RemovePlayer(player.Name)
    end)
end

-- ==========================================
-- CLEANUP
-- ==========================================
function ESP.Cleanup()
    for name in pairs(Cache) do
        RemovePlayer(name)
    end
    Cache = {}
    pcall(function()
        if StorageFolder and StorageFolder.Parent then
            StorageFolder:Destroy()
        end
    end)
    StorageFolder = nil
end

function ESP.GetDepthModes()
    return { "Occluded", "AlwaysOnTop" }
end

return ESP