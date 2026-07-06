-- engine/esp.lua
-- AimHubNext ESP System v2
-- Proper mesh-edge rendering, name/distance/health labels,
-- Bloxstrike multi-method team detection, distance fade,
-- health-based color, per-player Drawing text.
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local ESP = {}

-- ==========================================
-- ESP SETTINGS DEFAULTS
-- ==========================================
local ESP_DEFAULTS = {
    ESPEnabled             = true,
    ESPShowTeammates       = true,
    ESPShowNames           = true,
    ESPShowDistance        = true,
    ESPShowHealth          = true,
    ESPShowWeapon          = true,    -- Bloxstrike shows weapon in billboard
    ESPTeammateColor       = Color3.fromRGB(100, 180, 255),
    ESPEnemyColor          = Color3.fromRGB(255, 80,  80),
    ESPUnknownColor        = Color3.fromRGB(200, 200, 200),
    ESPTransparency        = 0.4,
    ESPOutlineTransparency = 0.15,
    ESPMode                = "Auto",
    ESPMaxDistance         = 1000,
    ESPDistanceFade        = true,    -- fade transparency with distance
    ESPHealthColor         = true,    -- lerp color green→red by health
    ESPDepthMode           = "Occluded",  -- "Occluded"=mesh edges, "AlwaysOnTop"=box
}

local function EnsureSettings()
    local S  = State.Settings
    local DS = State.DefaultSettings
    for k, v in pairs(ESP_DEFAULTS) do
        if S[k]  == nil then S[k]  = v end
        if DS[k] == nil then DS[k] = v end
    end
end

-- ==========================================
-- CONSTANTS
-- ==========================================
local ESP_HIGHLIGHT_TAG = "AimHubNext_ESP_Highlight"
local ESP_LABEL_PREFIX  = "AimHubNext_ESP_Label_"
local CACHE_LIFETIME    = 4.0
local SCOREBOARD_RATE   = 5.0
local BILLBOARD_RATE    = 3.0
local LABEL_UPDATE_RATE = 0.05  -- update text labels every 50ms not every frame

-- ==========================================
-- PER-PLAYER ESP DATA
-- Stores highlight + drawing objects per player
-- ==========================================
-- {
--   [player] = {
--     highlight  = Highlight instance,
--     nameLabel  = Drawing Text,
--     distLabel  = Drawing Text,
--     healthBar  = Drawing Line,
--     healthBg   = Drawing Line,
--     boxLines   = {} (Drawing Lines for manual box),
--   }
-- }
local PlayerESPObjects = {}

-- Team resolution cache
local TeamCache      = {}
local LastCacheReset = 0

-- Scoreboard scan cache
local ScoreboardCache    = {}
local LastScoreboardScan = 0

-- Local billboard color cache
local LocalBillboardColor  = nil
local LastBillboardRefresh = 0

-- Label update throttle
local LastLabelUpdate = 0

-- ==========================================
-- DRAWING OBJECT FACTORY
-- Creates text labels via Drawing API.
-- Falls back gracefully if Drawing unavailable.
-- ==========================================
local DrawingAvailable = (Drawing ~= nil)

local function NewDrawingText()
    if not DrawingAvailable then return nil end
    local ok, obj = pcall(function()
        local t = Drawing.new("Text")
        t.Visible   = false
        t.Center    = true
        t.Outline   = true
        t.OutlineColor = Color3.fromRGB(0, 0, 0)
        t.Size      = 13
        t.Font      = Drawing and Drawing.Fonts and Drawing.Fonts.Plex
                   or 2
        t.Color     = Color3.fromRGB(255, 255, 255)
        return t
    end)
    return ok and obj or nil
end

local function NewDrawingLine()
    if not DrawingAvailable then return nil end
    local ok, obj = pcall(function()
        local l = Drawing.new("Line")
        l.Visible   = false
        l.Thickness = 1.5
        l.Color     = Color3.fromRGB(0, 255, 0)
        return l
    end)
    return ok and obj or nil
end

-- ==========================================
-- TEAM DETECTION: METHOD 1 — STANDARD
-- ==========================================
local function GetStandardTeamInfo(player)
    local lp = Services.LocalPlayer
    if player.Team ~= nil and lp.Team ~= nil then
        local isTeammate = (player.Team == lp.Team)
        local color = player.TeamColor and player.TeamColor.Color or nil
        return isTeammate, color
    end
    return nil, nil
end

-- ==========================================
-- TEAM DETECTION: METHOD 2 — SCOREBOARD
-- Scans Bloxstrike's Tab scoreboard ScreenGui
-- even when hidden (data still populated).
-- ==========================================
local SCOREBOARD_NAMES = {
    "ScoreboardGui","Scoreboard","TabMenu",
    "ScoreGui","TeamGui","HUDScoreboard",
    "ScoreboardFrame","TabScoreboard",
}

local function ScanBloxstrikeScoreboard()
    local now = tick()
    if now - LastScoreboardScan < SCOREBOARD_RATE then return end
    LastScoreboardScan = now
    ScoreboardCache    = {}

    local lp        = Services.LocalPlayer
    local playerGui = lp:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local scoreboardGui = nil
    for _, name in ipairs(SCOREBOARD_NAMES) do
        local found = playerGui:FindFirstChild(name, true)
        if found and found:IsA("ScreenGui") then
            scoreboardGui = found
            break
        end
    end
    if not scoreboardGui then return end

    local localName  = lp.Name
    local localColor = nil
    local teamEntries= {}

    local function ScanFrame(frame, depth)
        if depth > 10 then return end
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                local bgColor = Color3.fromRGB(0,0,0)
                pcall(function() bgColor = child.BackgroundColor3 end)

                local r, g, b    = bgColor.R, bgColor.G, bgColor.B
                local saturation = math.max(r,g,b) - math.min(r,g,b)
                local brightness = r + g + b

                -- Colored team frame heuristic:
                -- saturation > 0.15 (not gray/white/black)
                -- brightness between 0.4 and 2.5
                local isColoredFrame = saturation > 0.15
                                   and brightness > 0.4
                                   and brightness < 2.5

                if isColoredFrame then
                    local entry = { color = bgColor, names = {} }
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            local text = ""
                            pcall(function() text = desc.Text end)
                            text = text:match("^%s*(.-)%s*$") or text
                            for _, plr in ipairs(
                                Services.Players:GetPlayers()
                            ) do
                                if text == plr.Name
                                or text == plr.DisplayName then
                                    table.insert(entry.names, plr.Name)
                                end
                            end
                        end
                    end
                    if #entry.names > 0 then
                        table.insert(teamEntries, entry)
                    end
                end
                ScanFrame(child, depth + 1)
            end
        end
    end

    pcall(ScanFrame, scoreboardGui, 0)

    -- Find local player's team color
    for _, entry in ipairs(teamEntries) do
        for _, name in ipairs(entry.names) do
            if name == localName then
                localColor = entry.color
                break
            end
        end
        if localColor then break end
    end

    -- Build name → {isTeammate, color} cache
    for _, entry in ipairs(teamEntries) do
        local sameTeam = localColor ~= nil
            and math.abs(entry.color.R - localColor.R) < 0.1
            and math.abs(entry.color.G - localColor.G) < 0.1
            and math.abs(entry.color.B - localColor.B) < 0.1

        for _, name in ipairs(entry.names) do
            ScoreboardCache[name] = {
                isTeammate = sameTeam,
                color      = entry.color,
            }
        end
    end
end

local function GetScoreboardTeamInfo(player)
    pcall(ScanBloxstrikeScoreboard)
    local cached = ScoreboardCache[player.Name]
    if cached then return cached.isTeammate, cached.color end
    return nil, nil
end

-- ==========================================
-- TEAM DETECTION: METHOD 3 — BILLBOARD
-- ==========================================
local function GetBillboardColor(character)
    if not character then return nil end
    local head = character:FindFirstChild("Head")
    if not head then return nil end
    for _, obj in ipairs(head:GetChildren()) do
        if obj:IsA("BillboardGui") then
            for _, child in ipairs(obj:GetDescendants()) do
                local col = nil
                pcall(function()
                    if child:IsA("Frame") then
                        col = child.BackgroundColor3
                    elseif child:IsA("TextLabel") then
                        col = child.TextColor3
                    end
                end)
                if col then
                    local r, g, b = col.R, col.G, col.B
                    local sat     = math.max(r,g,b) - math.min(r,g,b)
                    local bri     = r + g + b
                    if sat > 0.15 and bri > 0.3 and bri < 2.8 then
                        return col
                    end
                end
            end
        end
    end
    return nil
end

-- ==========================================
-- TEAM DETECTION: METHOD 4 — WEAPON LABEL
-- Bloxstrike shows weapon name in a
-- BillboardGui TextLabel above the player.
-- We can also read team from this context.
-- ==========================================
local function GetBloxstrikeWeaponName(character)
    if not character then return nil end
    local head = character:FindFirstChild("Head")
    if not head then return nil end
    for _, obj in ipairs(head:GetChildren()) do
        if obj:IsA("BillboardGui") then
            for _, child in ipairs(obj:GetDescendants()) do
                if child:IsA("TextLabel") then
                    local text = ""
                    pcall(function() text = child.Text end)
                    -- Weapon names are typically short
                    -- and don't match player names
                    if text ~= "" and #text < 30 then
                        local lp = Services.LocalPlayer
                        if text ~= lp.Name
                        and text ~= lp.DisplayName then
                            -- Check against all player names
                            local isPlayerName = false
                            for _, plr in ipairs(
                                Services.Players:GetPlayers()
                            ) do
                                if text == plr.Name
                                or text == plr.DisplayName then
                                    isPlayerName = true
                                    break
                                end
                            end
                            if not isPlayerName then
                                return text
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- ==========================================
-- TEAM DETECTION: METHOD 5 — CHAR VALUE
-- ==========================================
local function GetCharValueTeamInfo(player)
    local lp     = Services.LocalPlayer
    local lpChar = lp.Character
    local epChar = player.Character
    if not lpChar or not epChar then return nil, nil end
    local names = { "Team","TeamIndex","TeamID","TeamValue","TeamName" }
    for _, name in ipairs(names) do
        local lpV = lpChar:FindFirstChild(name)
        local epV = epChar:FindFirstChild(name)
        if lpV and epV then
            local a, b = nil, nil
            pcall(function() a = lpV.Value end)
            pcall(function() b = epV.Value end)
            if a ~= nil and b ~= nil then
                return a == b, nil
            end
        end
    end
    return nil, nil
end

-- ==========================================
-- MASTER TEAM RESOLVER
-- Returns isTeammate (bool), displayColor (Color3),
-- weaponName (string or nil)
-- ==========================================
local function ResolvePlayer(player)
    local S    = State.Settings
    local mode = S.ESPMode or "Auto"
    local lp   = Services.LocalPlayer

    if player == lp then
        return true, S.ESPTeammateColor, nil
    end

    -- Check cache
    local cached = TeamCache[player]
    if cached then
        return cached.isTeammate, cached.color, cached.weapon
    end

    if mode == "AllEnemy" then
        TeamCache[player] = {
            isTeammate = false,
            color      = S.ESPEnemyColor,
            weapon     = nil,
        }
        return false, S.ESPEnemyColor, nil
    end

    local isTeammate = nil
    local color      = nil

    -- Weapon name (Bloxstrike specific, independent of team)
    local weapon = nil
    if S.ESPShowWeapon then
        pcall(function()
            weapon = GetBloxstrikeWeaponName(player.Character)
        end)
    end

    -- Method priority based on mode
    if mode == "Bloxstrike" or mode == "Auto" then
        local tm, col = GetScoreboardTeamInfo(player)
        if tm ~= nil then isTeammate = tm color = col end
    end

    if isTeammate == nil and (mode == "Standard" or mode == "Auto") then
        local tm, col = GetStandardTeamInfo(player)
        if tm ~= nil then isTeammate = tm color = col end
    end

    if isTeammate == nil and mode == "Auto" then
        local tm, _ = GetCharValueTeamInfo(player)
        if tm ~= nil then isTeammate = tm end
    end

    if isTeammate == nil and mode == "Auto" then
        -- Billboard color last resort
        local now = tick()
        if now - LastBillboardRefresh > BILLBOARD_RATE then
            LastBillboardRefresh = now
            local lpChar = lp.Character
            LocalBillboardColor = lpChar
                and GetBillboardColor(lpChar) or nil
        end
        if LocalBillboardColor then
            local enemyCol = GetBillboardColor(player.Character)
            if enemyCol then
                local r1,g1,b1 = LocalBillboardColor.R,
                                  LocalBillboardColor.G,
                                  LocalBillboardColor.B
                local r2,g2,b2 = enemyCol.R, enemyCol.G, enemyCol.B
                local match = math.abs(r1-r2) < 0.12
                          and math.abs(g1-g2) < 0.12
                          and math.abs(b1-b2) < 0.12
                isTeammate = match
                color      = enemyCol
            end
        end
    end

    -- Default: unknown
    if isTeammate == nil then
        isTeammate = false
        color      = S.ESPUnknownColor
    end

    -- Override display color for clarity
    if isTeammate then
        color = color or S.ESPTeammateColor
    else
        color = color or S.ESPEnemyColor
    end

    -- Cache
    TeamCache[player] = {
        isTeammate = isTeammate,
        color      = color,
        weapon     = weapon,
    }

    return isTeammate, color, weapon
end

-- ==========================================
-- GET OR CREATE ESP OBJECTS FOR PLAYER
-- ==========================================
local function GetOrCreateESPObjects(player)
    if PlayerESPObjects[player] then
        return PlayerESPObjects[player]
    end

    local objs = {
        highlight  = nil,
        nameLabel  = nil,
        distLabel  = nil,
        healthLabel= nil,
        weaponLabel= nil,
    }

    -- Highlight (mesh-edge rendering)
    -- Created when character is available
    -- nameLabel, distLabel, healthLabel are Drawing objects
    objs.nameLabel   = NewDrawingText()
    objs.distLabel   = NewDrawingText()
    objs.healthLabel = NewDrawingText()
    objs.weaponLabel = NewDrawingText()

    -- Style the labels
    if objs.distLabel then
        objs.distLabel.Size  = 11
        objs.distLabel.Color = Color3.fromRGB(200, 200, 200)
    end
    if objs.healthLabel then
        objs.healthLabel.Size  = 11
    end
    if objs.weaponLabel then
        objs.weaponLabel.Size  = 10
        objs.weaponLabel.Color = Color3.fromRGB(255, 220, 100)
    end

    PlayerESPObjects[player] = objs
    return objs
end

-- ==========================================
-- DESTROY ESP OBJECTS FOR PLAYER
-- ==========================================
local function DestroyESPObjects(player)
    local objs = PlayerESPObjects[player]
    if not objs then return end

    if objs.highlight then
        pcall(function() objs.highlight:Destroy() end)
    end
    for _, key in ipairs({ "nameLabel","distLabel","healthLabel","weaponLabel" }) do
        if objs[key] then
            pcall(function() objs[key]:Remove() end)
        end
    end

    PlayerESPObjects[player] = nil
end

-- ==========================================
-- COMPUTE DEPTH MODE FROM SETTING
-- ==========================================
local function GetDepthMode()
    local S = State.Settings
    if S.ESPDepthMode == "AlwaysOnTop" then
        return Enum.HighlightDepthMode.AlwaysOnTop
    end
    -- Default: Occluded = renders actual mesh edges
    return Enum.HighlightDepthMode.Occluded
end

-- ==========================================
-- HEALTH COLOR LERP
-- Green (full) → Yellow (half) → Red (low)
-- ==========================================
local function HealthToColor(healthFraction)
    healthFraction = math.clamp(healthFraction, 0, 1)
    if healthFraction > 0.5 then
        -- Green to Yellow
        local t = (1 - healthFraction) * 2
        return Color3.fromRGB(
            math.floor(255 * t),
            255,
            0
        )
    else
        -- Yellow to Red
        local t = healthFraction * 2
        return Color3.fromRGB(
            255,
            math.floor(255 * t),
            0
        )
    end
end

-- ==========================================
-- APPLY ESP FOR ONE PLAYER
-- ==========================================
local function UpdatePlayerESP(player)
    local S  = State.Settings
    local lp = Services.LocalPlayer
    local Camera = Services.Camera

    local char = player.Character
    if not char then
        DestroyESPObjects(player)
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum or hum.Health <= 0 then
        DestroyESPObjects(player)
        return
    end

    -- Distance check
    local myChar = lp.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local dist   = 0
    if myHRP then
        dist = (hrp.Position - myHRP.Position).Magnitude
    end

    if dist > S.ESPMaxDistance then
        DestroyESPObjects(player)
        return
    end

    -- Resolve team info
    local isTeammate, baseColor, weaponName = ResolvePlayer(player)

    -- Hide teammates if setting says so
    if isTeammate and not S.ESPShowTeammates then
        DestroyESPObjects(player)
        return
    end

    -- Get or create ESP objects
    local objs = GetOrCreateESPObjects(player)

    -- ---- HIGHLIGHT ----
    if not objs.highlight
    or not objs.highlight.Parent
    or objs.highlight.Parent ~= char then
        -- Clean up old one if misparented
        if objs.highlight then
            pcall(function() objs.highlight:Destroy() end)
        end
        local hl = Instance.new("Highlight")
        hl.Name      = ESP_HIGHLIGHT_TAG
        hl.DepthMode = GetDepthMode()
        hl.Parent    = char
        objs.highlight = hl
    end

    -- Distance-based transparency fade
    local distFraction = math.clamp(dist / S.ESPMaxDistance, 0, 1)
    local fillTrans    = S.ESPTransparency
    local outlineTrans = S.ESPOutlineTransparency

    if S.ESPDistanceFade then
        -- Objects further away become more transparent
        fillTrans    = math.clamp(fillTrans    + distFraction * 0.4, 0, 0.95)
        outlineTrans = math.clamp(outlineTrans + distFraction * 0.3, 0, 0.95)
    end

    -- Health-based color
    local displayColor = baseColor
    if S.ESPHealthColor and not isTeammate then
        local healthFrac = hum.Health / math.max(hum.MaxHealth, 1)
        displayColor = HealthToColor(healthFrac)
    end

    objs.highlight.FillColor           = displayColor
    objs.highlight.OutlineColor        = displayColor
    objs.highlight.FillTransparency    = fillTrans
    objs.highlight.OutlineTransparency = outlineTrans

    -- ---- DRAWING LABELS ----
    -- Only update labels on throttle interval
    local now = tick()
    local doLabelUpdate = (now - LastLabelUpdate) >= LABEL_UPDATE_RATE

    -- Get screen position of head for label anchor
    local headPos = Vector3.new(0, 0, 0)
    local head    = char:FindFirstChild("Head")
    if head then
        pcall(function() headPos = head.Position end)
    else
        headPos = hrp.Position + Vector3.new(0, 1.5, 0)
    end

    local screenPos, onScreen = Vector2.new(0, 0), false
    pcall(function()
        local sp, os = Camera:WorldToViewportPoint(
            headPos + Vector3.new(0, 1.2, 0)
        )
        screenPos = Vector2.new(sp.X, sp.Y)
        onScreen  = os
    end)

    -- Name label
    if objs.nameLabel then
        if onScreen and S.ESPShowNames and doLabelUpdate then
            local displayName = player.DisplayName
            if displayName ~= player.Name then
                displayName = displayName .. " (" .. player.Name .. ")"
            end
            objs.nameLabel.Text     = displayName
            objs.nameLabel.Position = screenPos
            objs.nameLabel.Color    = displayColor
            objs.nameLabel.Visible  = true
        elseif not onScreen or not S.ESPShowNames then
            objs.nameLabel.Visible = false
        end
    end

    -- Distance label (below name)
    if objs.distLabel then
        if onScreen and S.ESPShowDistance and doLabelUpdate then
            objs.distLabel.Text     = string.format("%.0fm", dist)
            objs.distLabel.Position = screenPos + Vector2.new(0, 14)
            objs.distLabel.Visible  = true
        elseif not onScreen or not S.ESPShowDistance then
            objs.distLabel.Visible = false
        end
    end

    -- Health label
    if objs.healthLabel then
        if onScreen and S.ESPShowHealth and doLabelUpdate then
            local hp    = math.floor(hum.Health)
            local maxHp = math.floor(hum.MaxHealth)
            local hFrac = hum.Health / math.max(hum.MaxHealth, 1)
            objs.healthLabel.Text     = hp .. " / " .. maxHp
            objs.healthLabel.Position = screenPos + Vector2.new(0, 28)
            objs.healthLabel.Color    = HealthToColor(hFrac)
            objs.healthLabel.Visible  = true
        elseif not onScreen or not S.ESPShowHealth then
            objs.healthLabel.Visible = false
        end
    end

    -- Weapon label (Bloxstrike specific)
    if objs.weaponLabel then
        if onScreen and S.ESPShowWeapon and doLabelUpdate then
            local wName = weaponName or ""
            -- Also try to read from cache
            local cached = TeamCache[player]
            if cached and cached.weapon then
                wName = cached.weapon
            end
            if wName ~= "" then
                objs.weaponLabel.Text     = "[" .. wName .. "]"
                objs.weaponLabel.Position = screenPos + Vector2.new(0, 42)
                objs.weaponLabel.Visible  = true
            else
                objs.weaponLabel.Visible = false
            end
        elseif not onScreen or not S.ESPShowWeapon then
            objs.weaponLabel.Visible = false
        end
    end
end

-- ==========================================
-- APPLY ESP — ALL PLAYERS
-- ==========================================
function ESP.ApplyVisuals()
    local S       = State.Settings
    local Players = Services.Players

    if not S.ESPEnabled then
        ESP.Cleanup()
        return
    end

    -- Reset team cache periodically
    local now = tick()
    if now - LastCacheReset > CACHE_LIFETIME then
        LastCacheReset = now
        TeamCache      = {}
    end

    -- Update label throttle timer
    if now - LastLabelUpdate >= LABEL_UPDATE_RATE then
        LastLabelUpdate = now
    end

    -- Process all players
    local activePlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Services.LocalPlayer then
            activePlayers[player] = true
            pcall(UpdatePlayerESP, player)
        end
    end

    -- Clean up objects for players who left
    for player, _ in pairs(PlayerESPObjects) do
        if not activePlayers[player] then
            DestroyESPObjects(player)
        end
    end
end

-- ==========================================
-- TICK
-- ==========================================
function ESP.Tick()
    pcall(ESP.ApplyVisuals)
end

-- ==========================================
-- INIT
-- ==========================================
function ESP.Init()
    EnsureSettings()
end

-- ==========================================
-- CLEANUP
-- ==========================================
function ESP.Cleanup()
    -- Remove all ESP objects
    for player, _ in pairs(PlayerESPObjects) do
        DestroyESPObjects(player)
    end
    PlayerESPObjects = {}
    TeamCache        = {}
    ScoreboardCache  = {}
    LocalBillboardColor = nil
end

-- ==========================================
-- GET MODES (for UI dropdown)
-- ==========================================
function ESP.GetModes()
    return { "Auto", "Bloxstrike", "Standard", "AllEnemy" }
end

function ESP.GetDepthModes()
    return { "Occluded", "AlwaysOnTop" }
end

return ESP