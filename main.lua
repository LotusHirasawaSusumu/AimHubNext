-- main.lua
-- AimHubNext Entry Point
-- Wires all modules together, shows boot splash,
-- then hands off to Lifecycle.
-- Mod Author: CookieLee

-- ==========================================
-- BOOT SPLASH UI
-- Simple elegant loading screen shown while
-- modules initialize. Pure Instance-based,
-- no dependencies, self-contained.
-- ==========================================
local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local LocalPlayer     = Players.LocalPlayer
local PlayerGui       = LocalPlayer:WaitForChild("PlayerGui")

local function CreateBootSplash()
    -- Remove any leftover splash from previous inject
    local existing = PlayerGui:FindFirstChild("AimHubNext_Boot")
    if existing then existing:Destroy() end

    local BootGui = Instance.new("ScreenGui")
    BootGui.Name            = "AimHubNext_Boot"
    BootGui.ResetOnSpawn    = false
    BootGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    BootGui.DisplayOrder    = 999
    BootGui.Parent          = PlayerGui

    -- Dim overlay
    local Overlay = Instance.new("Frame", BootGui)
    Overlay.Size                  = UDim2.new(1, 0, 1, 0)
    Overlay.BackgroundColor3      = Color3.fromRGB(8, 9, 12)
    Overlay.BackgroundTransparency= 0
    Overlay.BorderSizePixel       = 0
    Overlay.ZIndex                = 1

    -- Center card
    local Card = Instance.new("Frame", BootGui)
    Card.Name                   = "BootCard"
    Card.AnchorPoint            = Vector2.new(0.5, 0.5)
    Card.Size                   = UDim2.new(0, 320, 0, 160)
    Card.Position               = UDim2.new(0.5, 0, 0.5, 0)
    Card.BackgroundColor3       = Color3.fromRGB(14, 15, 20)
    Card.BackgroundTransparency = 0
    Card.BorderSizePixel        = 0
    Card.ZIndex                 = 2
    Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 12)

    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Thickness = 1.2
    CardStroke.Color     = Color3.fromRGB(35, 37, 45)

    -- Accent top bar
    local AccentBar = Instance.new("Frame", Card)
    AccentBar.Size             = UDim2.new(1, 0, 0, 2)
    AccentBar.Position         = UDim2.new(0, 0, 0, 0)
    AccentBar.BackgroundColor3 = Color3.fromRGB(0, 230, 115)
    AccentBar.BorderSizePixel  = 0
    AccentBar.ZIndex           = 3
    local AccentBarCorner = Instance.new("UICorner", AccentBar)
    AccentBarCorner.CornerRadius = UDim.new(0, 12)

    -- Logo / Title
    local Title = Instance.new("TextLabel", Card)
    Title.Size               = UDim2.new(1, 0, 0, 28)
    Title.Position           = UDim2.new(0, 0, 0, 18)
    Title.BackgroundTransparency = 1
    Title.Text               = "Aim Hub Next"
    Title.Font               = Enum.Font.GothamBold
    Title.TextSize           = 20
    Title.TextColor3         = Color3.fromRGB(255, 255, 255)
    Title.TextXAlignment     = Enum.TextXAlignment.Center
    Title.ZIndex             = 3

    -- Subtitle / author line
    local Sub = Instance.new("TextLabel", Card)
    Sub.Size                 = UDim2.new(1, 0, 0, 14)
    Sub.Position             = UDim2.new(0, 0, 0, 48)
    Sub.BackgroundTransparency = 1
    Sub.Text                 = "Mod by CookieLee"
    Sub.Font                 = Enum.Font.GothamSemibold
    Sub.TextSize             = 11
    Sub.TextColor3           = Color3.fromRGB(0, 230, 115)
    Sub.TextXAlignment       = Enum.TextXAlignment.Center
    Sub.ZIndex               = 3

    -- Status label (dynamic text)
    local StatusLabel = Instance.new("TextLabel", Card)
    StatusLabel.Name             = "StatusLabel"
    StatusLabel.Size             = UDim2.new(1, -24, 0, 14)
    StatusLabel.Position         = UDim2.new(0, 12, 0, 78)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text             = "Initializing..."
    StatusLabel.Font             = Enum.Font.Gotham
    StatusLabel.TextSize         = 10
    StatusLabel.TextColor3       = Color3.fromRGB(120, 125, 140)
    StatusLabel.TextXAlignment   = Enum.TextXAlignment.Left
    StatusLabel.ZIndex           = 3

    -- Progress bar track
    local BarTrack = Instance.new("Frame", Card)
    BarTrack.Size             = UDim2.new(1, -24, 0, 4)
    BarTrack.Position         = UDim2.new(0, 12, 0, 96)
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
    PctLabel.Size               = UDim2.new(1, -24, 0, 14)
    PctLabel.Position           = UDim2.new(0, 12, 0, 104)
    PctLabel.BackgroundTransparency = 1
    PctLabel.Text               = "0%"
    PctLabel.Font               = Enum.Font.GothamBold
    PctLabel.TextSize           = 9
    PctLabel.TextColor3         = Color3.fromRGB(0, 230, 115)
    PctLabel.TextXAlignment     = Enum.TextXAlignment.Right
    PctLabel.ZIndex             = 3

    -- Version watermark
    local Ver = Instance.new("TextLabel", Card)
    Ver.Size                 = UDim2.new(1, 0, 0, 12)
    Ver.Position             = UDim2.new(0, 0, 1, -20)
    Ver.BackgroundTransparency = 1
    Ver.Text                 = "v39  |  github.com/CookieLee/AimHubNext"
    Ver.Font                 = Enum.Font.Gotham
    Ver.TextSize             = 8
    Ver.TextColor3           = Color3.fromRGB(55, 58, 70)
    Ver.TextXAlignment       = Enum.TextXAlignment.Center
    Ver.ZIndex               = 3

    -- Animate card in
    Card.Position = UDim2.new(0.5, 0, 0.6, 0)
    Card.BackgroundTransparency = 1
    CardStroke.Transparency = 1

    local tweenIn = TweenService:Create(Card,
        TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {
            Position               = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 0,
        }
    )
    TweenService:Create(CardStroke,
        TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Transparency = 0 }
    ):Play()
    tweenIn:Play()

    -- Return references needed by SetProgress / Dismiss
    return {
        Gui         = BootGui,
        Card        = Card,
        CardStroke  = CardStroke,
        Overlay     = Overlay,
        BarFill     = BarFill,
        StatusLabel = StatusLabel,
        PctLabel    = PctLabel,
    }
end

-- ==========================================
-- PROGRESS UPDATER
-- Call SetProgress(splash, 0..1, "message")
-- to animate the bar and update status text.
-- ==========================================
local function SetProgress(splash, fraction, message)
    fraction = math.clamp(fraction, 0, 1)
    local pct = math.floor(fraction * 100)

    -- Tween the bar fill width
    TweenService:Create(splash.BarFill,
        TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.new(fraction, 0, 1, 0) }
    ):Play()

    splash.PctLabel.Text    = pct .. "%"
    splash.StatusLabel.Text = message or ""
end

-- ==========================================
-- DISMISS SPLASH
-- Fades out card + overlay, then destroys.
-- Calls optional callback when done.
-- ==========================================
local function DismissSplash(splash, callback)
    -- Fill bar to 100% first
    TweenService:Create(splash.BarFill,
        TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.new(1, 0, 1, 0) }
    ):Play()
    splash.PctLabel.Text    = "100%"
    splash.StatusLabel.Text = "Done."

    task.wait(0.35)

    -- Slide card out + fade
    TweenService:Create(splash.Card,
        TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {
            Position               = UDim2.new(0.5, 0, 0.42, 0),
            BackgroundTransparency = 1,
        }
    ):Play()
    TweenService:Create(splash.CardStroke,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Transparency = 1 }
    ):Play()
    TweenService:Create(splash.Overlay,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 1 }
    ):Play()

    task.wait(0.5)
    pcall(function() splash.Gui:Destroy() end)

    if callback then
        callback()
    end
end

-- ==========================================
-- BOOT SEQUENCE
-- Shows splash, loads modules step by step
-- with progress updates, then hands off.
-- ==========================================
local splash = CreateBootSplash()

-- Small initial pause so card animation plays
task.wait(0.2)

-- ==========================================
-- STEP-BY-STEP MODULE LOADING
-- Each require() call is wrapped in pcall
-- so a single bad module doesn't kill boot.
-- Progress is reported honestly per step.
-- ==========================================
local loadedModules = {}
local loadErrors    = {}

local function Load(name, path, progress, message)
    SetProgress(splash, progress, message)
    local ok, result = pcall(require, path)
    if ok then
        loadedModules[name] = result
    else
        table.insert(loadErrors, name .. ": " .. tostring(result))
        warn("[AimHubNext] Failed to load module: " .. name)
        warn(tostring(result))
    end
    task.wait(0.08) -- small breath between steps for UI smoothness
end

-- Resolve module root path
-- In a real executor loadstring context, modules are
-- loaded via loadstring(game:HttpGet(url))() pattern.
-- For ModuleScript-based setups, swap these paths
-- to the actual ModuleScript references.
local Root = script -- adjust if using a different container

Load("i18n",       Root.core.i18n,           0.08,  "Loading language pack...")
Load("State",      Root.core.state,           0.16,  "Loading state manager...")
Load("Services",   Root.core.services,        0.22,  "Acquiring Roblox services...")
Load("Styles",     Root.core.styles,          0.28,  "Loading style definitions...")
Load("Utils",      Root.core.utils,           0.34,  "Loading utilities...")
Load("Lifecycle",  Root.core.lifecycle,       0.42,  "Loading lifecycle manager...")
Load("Drawings",   Root.engine.drawings,      0.50,  "Initializing drawing objects...")
Load("Chams",      Root.engine.chams,         0.57,  "Loading CHAMS system...")
Load("ESP",        Root.engine.esp,           0.63,  "Loading ESP system...")
Load("AntiAim",    Root.engine.antiaim,       0.69,  "Loading Anti-Aim engine...")
Load("Rage",       Root.engine.rage,          0.75,  "Loading Rage systems...")
Load("Aimbot",     Root.engine.aimbot,        0.82,  "Loading Aimbot core...")
Load("SilentAim",  Root.hooks.silentaim,      0.88,  "Installing Silent Aim hook...")

SetProgress(splash, 0.93, "Running lifecycle setup...")
task.wait(0.08)

-- ==========================================
-- ABORT IF CRITICAL MODULES MISSING
-- ==========================================
local criticalModules = {
    "State", "Services", "Utils",
    "Lifecycle", "Aimbot", "Drawings"
}
local aborted = false

for _, name in ipairs(criticalModules) do
    if not loadedModules[name] then
        aborted = true
        SetProgress(splash, 1, "CRITICAL ERROR: " .. name .. " failed to load.")
        warn("[AimHubNext] Critical module missing: " .. name)
        task.wait(3)
        pcall(function() splash.Gui:Destroy() end)
        return
    end
end

-- ==========================================
-- WIRE MODULES TOGETHER
-- ==========================================
local State      = loadedModules.State
local Services   = loadedModules.Services
local Utils      = loadedModules.Utils
local Lifecycle  = loadedModules.Lifecycle
local Styles     = loadedModules.Styles
local i18n       = loadedModules.i18n
local Drawings   = loadedModules.Drawings
local Chams      = loadedModules.Chams
local ESP        = loadedModules.ESP
local AntiAim    = loadedModules.AntiAim
local Rage       = loadedModules.Rage
local Aimbot     = loadedModules.Aimbot
local SilentAim  = loadedModules.SilentAim

-- Default language (can be changed by user via settings later)
if i18n then
    i18n.SetLanguage("en")
end

-- ==========================================
-- HOT-RELOAD + LEGACY CLEANUP
-- Must happen before any new UI or systems
-- are created to avoid duplicate GUI frames.
-- ==========================================
SetProgress(splash, 0.95, "Cleaning up legacy instances...")
Lifecycle.HandleHotReload()
Lifecycle.CleanupLegacy()
task.wait(0.05)

-- ==========================================
-- SILENT AIM HOOK INSTALL
-- Best-effort, non-blocking.
-- ==========================================
if SilentAim then
    pcall(function() SilentAim.Install() end)
end

-- ==========================================
-- WIRE AIMBOT LOG EVENT
-- Aimbot calls this when it locks/eliminates.
-- UI log module will override this reference
-- once the UI is built.
-- ==========================================
if Aimbot then
    Aimbot.SystemLogEvent = function(msg)
        -- Placeholder until UI log is ready
        -- UI module will overwrite this after build
    end
end

-- ==========================================
-- LIFECYCLE INIT
-- Pass all module references so Lifecycle
-- can call Tick / Cleanup on each without
-- circular require chains.
-- ==========================================
SetProgress(splash, 0.97, "Starting engine systems...")

Lifecycle.Init({
    Aimbot    = Aimbot,
    Chams     = Chams,
    ESP       = ESP,
    Drawings  = Drawings,
    Rage      = Rage,
    AntiAim   = AntiAim,
    SilentAim = SilentAim,
    -- UI ref will be patched in after UI builds
    UI        = nil,
})

-- Register destructor so next inject can cleanly kill this one
Lifecycle.RegisterDestructor()

-- Bind keyboard input (aim key, UI toggle)
Lifecycle.BindInput()

-- Start the main render loop
Lifecycle.BindRenderLoop()

SetProgress(splash, 0.99, "Building UI...")
task.wait(0.1)

-- ==========================================
-- UI LOAD
-- UI is loaded last so all engine systems
-- are ready before any UI callbacks fire.
-- Rayfield-based UI will be built here.
-- For now a placeholder is used so the
-- engine runs even before UI step is done.
-- ==========================================
local UIModule = nil
local uiOk, uiResult = pcall(require, Root.ui.main)
if uiOk then
    UIModule = uiResult

    -- UI builds itself and returns a reference table
    local uiRef = UIModule.Build({
        State      = State,
        Services   = Services,
        Styles     = Styles,
        Utils      = Utils,
        i18n       = i18n,
        Aimbot     = Aimbot,
        Lifecycle  = Lifecycle,
        Drawings   = Drawings,
        AntiAim    = AntiAim,
    })

    -- Patch UI reference into Lifecycle so
    -- input handler can call ToggleMinimize etc.
    if uiRef then
        Lifecycle.Init({
            Aimbot    = Aimbot,
            Chams     = Chams,
            ESP       = ESP,
            Drawings  = Drawings,
            Rage      = Rage,
            AntiAim   = AntiAim,
            SilentAim = SilentAim,
            UI        = uiRef,
        })

        -- Wire log event to UI log system
        if uiRef.LogEvent and Aimbot then
            Aimbot.SystemLogEvent = uiRef.LogEvent
        end
    end
else
    warn("[AimHubNext] UI module failed to load: " .. tostring(uiResult))
end

-- ==========================================
-- LOG STARTUP MESSAGES
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
        Aimbot.SystemLogEvent("Engine v39 Initialized.")
        Aimbot.SystemLogEvent("All modules ready.")
    end
end

-- ==========================================
-- REPORT ANY NON-CRITICAL LOAD ERRORS
-- ==========================================
if #loadErrors > 0 then
    warn("[AimHubNext] Non-critical module errors:")
    for _, err in ipairs(loadErrors) do
        warn("  " .. err)
    end
    if Aimbot and Aimbot.SystemLogEvent then
        Aimbot.SystemLogEvent("Warning: " .. #loadErrors .. " module(s) had errors. Check console.")
    end
end

-- ==========================================
-- DISMISS SPLASH AND HAND OFF
-- ==========================================
DismissSplash(splash, function()
    -- Everything is running. Splash is gone.
    -- Engine loop, input, and UI are all live.
    print("[AimHubNext] Boot complete.")
end)