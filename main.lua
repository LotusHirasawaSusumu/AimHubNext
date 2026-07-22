-- main.lua
-- AimHubNext Entry Point (GitHub Remote Loadstring Version)
-- All modules are fetched via HttpGet and executed via loadstring.
-- NO require(), NO Root.core.anything — fully executor-safe.
-- Mod Author: CookieLee

-- ==========================================
-- GITHUB RAW BASE URL
-- Change this to your own fork if needed.
-- All module URLs are derived from this.
-- ==========================================
local GITHUB_RAW = "https://raw.githubusercontent.com/LotusHirasawaSusumu/AimHubNext/refs/heads/main/"

-- ==========================================
-- SERVICES (bare minimum for boot,
-- loaded directly here before any module)
-- ==========================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- REMOTE MODULE LOADER
-- Fetches Lua source from GitHub and
-- executes it via loadstring.
-- Returns the module's return value,
-- exactly like require() would.
--
-- Each module must end with: return ModuleTable
--
-- Uses a simple in-memory cache so modules
-- are only downloaded once per session.
-- ==========================================
local ModuleCache = {}

local function RemoteRequire(path)
    -- Return cached result if already loaded
    if ModuleCache[path] then
        return ModuleCache[path]
    end

    local url = GITHUB_RAW .. path
    local src = nil

    -- Attempt HTTP fetch
    local fetchOk, fetchResult = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not fetchOk or not fetchResult or fetchResult == "" then
        error("[AimHubNext] HTTP fetch failed for: " .. path
            .. "\n" .. tostring(fetchResult))
    end

    src = fetchResult

    -- Execute the Lua source
    local fn, compileErr = loadstring(src, "=" .. path)
    if not fn then
        error("[AimHubNext] Compile error in: " .. path
            .. "\n" .. tostring(compileErr))
    end

    -- Run the module function
    -- Pass RemoteRequire as upvalue so sub-modules
    -- can call it to load their own dependencies.
    -- Each module receives it as the first argument.
    local runOk, moduleResult = pcall(fn, RemoteRequire)
    if not runOk then
        error("[AimHubNext] Runtime error in: " .. path
            .. "\n" .. tostring(moduleResult))
    end

    -- Cache and return
    ModuleCache[path] = moduleResult
    return moduleResult
end

-- ==========================================
-- BOOT SPLASH UI
-- Minimal floating card, no full-screen overlay.
-- Shows in corner so game is still visible.
-- No dim layer — just a small status window.
-- ==========================================
local function CreateBootSplash()
    local existing = PlayerGui:FindFirstChild("AimHubNext_Boot")
    if existing then existing:Destroy() end

    local BootGui = Instance.new("ScreenGui")
    BootGui.Name           = "AimHubNext_Boot"
    BootGui.ResetOnSpawn   = false
    BootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    BootGui.DisplayOrder   = 999
    BootGui.Parent         = PlayerGui

    -- Small floating card, bottom-right corner
    local Card = Instance.new("Frame", BootGui)
    Card.Name             = "BootCard"
    Card.AnchorPoint      = Vector2.new(1, 1)
    Card.Size             = UDim2.new(0, 260, 0, 110)
    Card.Position         = UDim2.new(1, -16, 1, -16)
    Card.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
    Card.BackgroundTransparency = 0.08
    Card.BorderSizePixel  = 0
    Card.ZIndex           = 2
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 10)

    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Thickness = 1.2
    CardStroke.Color     = Color3.fromRGB(35, 37, 45)

    -- Thin accent line at top of card
    local AccentBar = Instance.new("Frame", Card)
    AccentBar.Size             = UDim2.new(1, 0, 0, 2)
    AccentBar.Position         = UDim2.new(0, 0, 0, 0)
    AccentBar.BackgroundColor3 = Color3.fromRGB(0, 230, 115)
    AccentBar.BorderSizePixel  = 0
    AccentBar.ZIndex           = 3
    Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 10)

    -- Title row
    local Title = Instance.new("TextLabel", Card)
    Title.Size               = UDim2.new(1, -12, 0, 20)
    Title.Position           = UDim2.new(0, 10, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text               = "Aim Hub Next"
    Title.Font               = Enum.Font.GothamBold
    Title.TextSize           = 13
    Title.TextColor3         = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment     = Enum.TextXAlignment.Left
    Title.ZIndex             = 3

    -- Author tag inline with title
    local AuthorTag = Instance.new("TextLabel", Card)
    AuthorTag.Size               = UDim2.new(1, -12, 0, 14)
    AuthorTag.Position           = UDim2.new(0, 10, 0, 26)
    AuthorTag.BackgroundTransparency = 1
    AuthorTag.Text               = "Mod by CookieLee"
    AuthorTag.Font               = Enum.Font.Gotham
    AuthorTag.TextSize           = 9
    AuthorTag.TextColor3         = Color3.fromRGB(0, 230, 115)
    AuthorTag.TextXAlignment     = Enum.TextXAlignment.Left
    AuthorTag.ZIndex             = 3

    -- Divider
    local Divider = Instance.new("Frame", Card)
    Divider.Size             = UDim2.new(1, -20, 0, 1)
    Divider.Position         = UDim2.new(0, 10, 0, 44)
    Divider.BackgroundColor3 = Color3.fromRGB(35, 37, 45)
    Divider.BorderSizePixel  = 0
    Divider.ZIndex           = 3

    -- Status text
    local StatusLabel = Instance.new("TextLabel", Card)
    StatusLabel.Name             = "StatusLabel"
    StatusLabel.Size             = UDim2.new(1, -12, 0, 14)
    StatusLabel.Position         = UDim2.new(0, 10, 0, 50)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text             = "Initializing..."
    StatusLabel.Font             = Enum.Font.Gotham
    StatusLabel.TextSize         = 9
    StatusLabel.TextColor3       = Color3.fromRGB(120, 125, 140)
    StatusLabel.TextXAlignment   = Enum.TextXAlignment.Left
    StatusLabel.ZIndex           = 3

    -- Progress bar track
    local BarTrack = Instance.new("Frame", Card)
    BarTrack.Size             = UDim2.new(1, -20, 0, 4)
    BarTrack.Position         = UDim2.new(0, 10, 0, 68)
    BarTrack.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
    BarTrack.BorderSizePixel  = 0
    BarTrack.ZIndex           = 3
    Instance.new("UICorner", BarTrack).CornerRadius = UDim.new(1, 0)

    -- Progress bar fill
    local BarFill = Instance.new("Frame", BarTrack)
    BarFill.Name              = "BarFill"
    BarFill.Size              = UDim2.new(0, 0, 1, 0)
    BarFill.BackgroundColor3  = Color3.fromRGB(0, 230, 115)
    BarFill.BorderSizePixel   = 0
    BarFill.ZIndex            = 4
    Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

    -- Percentage label
    local PctLabel = Instance.new("TextLabel", Card)
    PctLabel.Name               = "PctLabel"
    PctLabel.Size               = UDim2.new(1, -12, 0, 12)
    PctLabel.Position           = UDim2.new(0, 10, 0, 76)
    PctLabel.BackgroundTransparency = 1
    PctLabel.Text               = "0%"
    PctLabel.Font               = Enum.Font.GothamBold
    PctLabel.TextSize           = 8
    PctLabel.TextColor3         = Color3.fromRGB(0, 230, 115)
    PctLabel.TextXAlignment     = Enum.TextXAlignment.Right
    PctLabel.ZIndex             = 3

    -- Version line
    local Ver = Instance.new("TextLabel", Card)
    Ver.Size                 = UDim2.new(1, -12, 0, 10)
    Ver.Position             = UDim2.new(0, 10, 1, -14)
    Ver.BackgroundTransparency = 1
    Ver.Text                 = "v39  github.com/CookieLee/AimHubNext"
    Ver.Font                 = Enum.Font.Gotham
    Ver.TextSize             = 7
    Ver.TextColor3           = Color3.fromRGB(45, 48, 58)
    Ver.TextXAlignment       = Enum.TextXAlignment.Left
    Ver.ZIndex               = 3

    -- Slide in from bottom-right
    Card.Position = UDim2.new(1, 16, 1, 16)
    TweenService:Create(Card,
        TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -16, 1, -16) }
    ):Play()

    return {
        Gui         = BootGui,
        Card        = Card,
        CardStroke  = CardStroke,
        BarFill     = BarFill,
        StatusLabel = StatusLabel,
        PctLabel    = PctLabel,
    }
end

-- ==========================================
-- PROGRESS UPDATER
-- ==========================================
local function SetProgress(splash, fraction, message)
    fraction = math.clamp(fraction or 0, 0, 1)
    local pct = math.floor(fraction * 100)

    TweenService:Create(splash.BarFill,
        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.new(fraction, 0, 1, 0) }
    ):Play()

    splash.PctLabel.Text    = pct .. "%"
    splash.StatusLabel.Text = message or ""
end

-- ==========================================
-- DISMISS SPLASH
-- Slides card back out to bottom-right.
-- ==========================================
local function DismissSplash(splash, callback)
    -- Fill to 100%
    TweenService:Create(splash.BarFill,
        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.new(1, 0, 1, 0) }
    ):Play()
    splash.PctLabel.Text    = "100%"
    splash.StatusLabel.Text = "Ready."

    task.wait(0.4)

    -- Slide out
    TweenService:Create(splash.Card,
        TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        { Position = UDim2.new(1, 16, 1, 16) }
    ):Play()

    task.wait(0.4)
    pcall(function() splash.Gui:Destroy() end)

    if callback then callback() end
end

-- ==========================================
-- MODULE PATH MANIFEST
-- Maps friendly name -> GitHub path
-- relative to GITHUB_RAW base.
-- Edit these paths to match your repo layout.
-- ==========================================
local MODULE_PATHS = {
    -- Core
    i18n       = "core/i18n.lua",
    State      = "core/state.lua",
    Services   = "core/services.lua",
    Styles     = "core/styles.lua",
    Utils      = "core/utils.lua",
    Lifecycle  = "core/lifecycle.lua",
    -- Engine
    Drawings   = "engine/drawings.lua",
    Chams      = "engine/chams.lua",
    ESP        = "engine/esp.lua",
    AntiAim    = "engine/antiaim.lua",
    Rage       = "engine/rage.lua",
    Aimbot     = "engine/aimbot.lua",
    Movement   = "engine/movement.lua",
    -- Hooks
    SilentAim  = "hooks/silentaim.lua",
    -- UI
    UIWindow   = "ui/window.lua",
    UIBuilder  = "ui/builder.lua",
    UITabs     = "ui/tabs.lua",
    UIDiscord  = "ui/discord.lua",
}

-- Load order matters: dependencies first
local LOAD_ORDER = {
    { name = "i18n",      progress = 0.06,  msg = "Loading language pack..."      },
    { name = "State",     progress = 0.12,  msg = "Loading state manager..."       },
    { name = "Services",  progress = 0.18,  msg = "Acquiring Roblox services..."   },
    { name = "Styles",    progress = 0.24,  msg = "Loading style definitions..."   },
    { name = "Utils",     progress = 0.30,  msg = "Loading utilities..."           },
    { name = "Lifecycle", progress = 0.37,  msg = "Loading lifecycle manager..."   },
    { name = "Drawings",  progress = 0.44,  msg = "Initializing drawing objects..." },
    { name = "Chams",     progress = 0.51,  msg = "Loading CHAMS system..."        },
    { name = "ESP",       progress = 0.57,  msg = "Loading ESP system..."          },
    { name = "AntiAim",   progress = 0.63,  msg = "Loading Anti-Aim engine..."     },
    { name = "Rage",      progress = 0.69,  msg = "Loading Rage systems..."        },
    { name = "Aimbot",    progress = 0.76,  msg = "Loading Aimbot core..."         },
    { name = "Movement",  progress = 0.78,  msg = "Loading Movement system..."     },
    { name = "SilentAim", progress = 0.82,  msg = "Installing Silent Aim hook..."  },
    { name = "UIBuilder", progress = 0.86,  msg = "Loading UI builder..."          },
    { name = "UITabs",    progress = 0.89,  msg = "Loading UI tabs..."             },
    { name = "UIDiscord", progress = 0.92,  msg = "Loading Discord module..."      },
    { name = "UIWindow",  progress = 0.95,  msg = "Building window..."             },
}

-- ==========================================
-- BOOT
-- ==========================================
local splash = CreateBootSplash()
task.wait(0.25)

-- ==========================================
-- INJECT RemoteRequire INTO EACH MODULE
-- Each module's loadstring-compiled function
-- receives RemoteRequire as arg #1.
-- Modules that need to load sub-dependencies
-- should declare: local require = ...
-- at the top and call require("core/i18n.lua")
-- etc. via that reference.
--
-- IMPORTANT: All inter-module dependencies
-- inside each .lua file must also use
-- RemoteRequire style paths, NOT Roblox
-- instance paths. See note in each module.
-- ==========================================

local loadedModules = {}
local loadErrors    = {}

for _, entry in ipairs(LOAD_ORDER) do
    local name     = entry.name
    local path     = MODULE_PATHS[name]
    local progress = entry.progress
    local msg      = entry.msg

    SetProgress(splash, progress, msg)

    local ok, result = pcall(RemoteRequire, path)
    if ok and result then
        loadedModules[name] = result
    else
        table.insert(loadErrors, name .. ": " .. tostring(result))
        warn("[AimHubNext] Module load failed: " .. name)
        warn(tostring(result))
    end

    task.wait(0.05)
end

-- ==========================================
-- CRITICAL MODULE CHECK
-- ==========================================
local CRITICAL = {
    "State", "Services", "Utils",
    "Lifecycle", "Aimbot", "Drawings"
}

for _, name in ipairs(CRITICAL) do
    if not loadedModules[name] then
        SetProgress(splash, 1,
            "FATAL: " .. name .. " failed. Check console.")
        task.wait(4)
        pcall(function() splash.Gui:Destroy() end)
        return
    end
end

-- ==========================================
-- UNPACK MODULES INTO LOCALS
-- ==========================================
local i18n      = loadedModules.i18n
local State     = loadedModules.State
local Services  = loadedModules.Services
local Utils     = loadedModules.Utils
local Styles    = loadedModules.Styles
local Lifecycle = loadedModules.Lifecycle
local Drawings  = loadedModules.Drawings
local Chams     = loadedModules.Chams
local ESP       = loadedModules.ESP
local AntiAim   = loadedModules.AntiAim
local Rage      = loadedModules.Rage
local Aimbot    = loadedModules.Aimbot
local Movement = loadedModules.Movement
local SilentAim = loadedModules.SilentAim
local UIWindow  = loadedModules.UIWindow

-- ==========================================
-- INITIALIZE MOVEMENT
-- ==========================================
if Movement then
    pcall(function() Movement.Init() end)
end

-- ==========================================
-- LANGUAGE INIT
-- ==========================================
if i18n then
    i18n.SetLanguage("en")
end

-- ==========================================
-- HOT-RELOAD + LEGACY CLEANUP
-- ==========================================
SetProgress(splash, 0.96, "Cleaning up legacy instances...")
Lifecycle.HandleHotReload()
Lifecycle.CleanupLegacy()
task.wait(0.04)

-- ==========================================
-- SILENT AIM HOOK
-- ==========================================
if SilentAim then
    pcall(function() SilentAim.Install() end)
end

-- ==========================================
-- PLACEHOLDER LOG EVENT
-- Overwritten by UI after build
-- ==========================================
if Aimbot then
    Aimbot.SystemLogEvent = function(msg)
        -- No-op until UI is ready
    end
end

-- ==========================================
-- LIFECYCLE INIT (first pass, no UI yet)
-- ==========================================
SetProgress(splash, 0.97, "Starting engine systems...")

Lifecycle.Init({
    Aimbot    = Aimbot,
    Movement  = Movement,
    Chams     = Chams,
    ESP       = ESP,
    Drawings  = Drawings,
    Rage      = Rage,
    AntiAim   = AntiAim,
    SilentAim = SilentAim,
    UI        = nil,
})

Lifecycle.RegisterDestructor()
Lifecycle.BindInput()
Lifecycle.BindRenderLoop()

-- ==========================================
-- UI BUILD
-- ==========================================
SetProgress(splash, 0.98, "Building UI...")

local uiRef = nil

if UIWindow and UIWindow.Build then
    local uiOk, uiResult = pcall(UIWindow.Build, {
        State      = State,
        Services   = Services,
        Styles     = Styles,
        Utils      = Utils,
        i18n       = i18n,
        Aimbot     = Aimbot,
        Movement   = Movement,
        Lifecycle  = Lifecycle,
        Drawings   = Drawings,
        AntiAim    = AntiAim,
    })

    if uiOk and uiResult then
        uiRef = uiResult

        -- Patch UI ref back into Lifecycle
        Lifecycle.Init({
            Aimbot    = Aimbot,
            Movement  = Movement,
            Chams     = Chams,
            ESP       = ESP,
            Drawings  = Drawings,
            Rage      = Rage,
            AntiAim   = AntiAim,
            SilentAim = SilentAim,
            UI        = uiRef,
        })

        -- Wire log event
        if uiRef.LogEvent and Aimbot then
            Aimbot.SystemLogEvent = uiRef.LogEvent
        end
    else
        warn("[AimHubNext] UI build failed: " .. tostring(uiResult))
    end
end

-- ==========================================
-- STARTUP LOG MESSAGES
-- ==========================================
if Aimbot and Aimbot.SystemLogEvent then
    if i18n then
        Aimbot.SystemLogEvent(i18n.T("log_initialized"))
        Aimbot.SystemLogEvent(i18n.T("log_perf"))
        if SilentAim and SilentAim.Hooked then
            Aimbot.SystemLogEvent(i18n.T("log_silent"))
        end
        Aimbot.SystemLogEvent(i18n.T("log_all_ready"))
    else
        Aimbot.SystemLogEvent("Engine v39 initialized.")
        Aimbot.SystemLogEvent("All modules ready.")
    end
end

-- ==========================================
-- NON-CRITICAL ERROR REPORT
-- ==========================================
if #loadErrors > 0 then
    warn("[AimHubNext] Non-critical load errors:")
    for _, e in ipairs(loadErrors) do
        warn("  " .. e)
    end
    if Aimbot and Aimbot.SystemLogEvent then
        Aimbot.SystemLogEvent(
            "Warning: " .. #loadErrors .. " module(s) had errors."
        )
    end
end

-- ==========================================
-- DISMISS SPLASH
-- ==========================================
DismissSplash(splash, function()
    print("[AimHubNext] Boot complete. Engine live.")
end)