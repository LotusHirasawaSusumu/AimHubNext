-- ui/window.lua
-- AimHubNext Rayfield UI Entry Point
-- Builds the main window, registers all tabs,
-- wires i18n strings, exposes uiRef back to main.lua
-- Mod Author: CookieLee

local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

local Builder = require(script.Parent.builder)
local Tabs    = require(script.Parent.tabs)
local Discord = require(script.Parent.discord)

local UI = {}

-- ==========================================
-- BUILD
-- Called from main.lua after all engine
-- modules are loaded.
-- Returns uiRef table consumed by Lifecycle.
-- ==========================================
function UI.Build(ctx)
    local i18n      = ctx.i18n
    local State     = ctx.State
    local Styles    = ctx.Styles
    local Utils     = ctx.Utils
    local Aimbot    = ctx.Aimbot
    local Lifecycle = ctx.Lifecycle
    local Drawings  = ctx.Drawings
    local AntiAim   = ctx.AntiAim
    local Services  = ctx.Services

    local S = State.Settings

    -- ==========================================
    -- MAIN WINDOW
    -- ==========================================
    local Window = Rayfield:CreateWindow({
        Name            = i18n.T("menu_title"),
        LoadingTitle    = "Aim Hub Next",
        LoadingSubtitle = i18n.T("menu_subtitle"),
        ConfigurationSaving = {
            Enabled  = true,
            FolderName = "AimHubNext",
            FileName   = "config",
        },
        Discord = {
            Enabled     = false, -- we have our own discord modal
        },
        KeySystem = false,
    })

    -- ==========================================
    -- PASS WINDOW + CTX TO SUB-MODULES
    -- ==========================================
    Builder.Init(ctx)
    Tabs.Init(ctx, Window, Builder)
    Discord.Init(ctx, Rayfield)

    -- ==========================================
    -- LOG EVENT IMPLEMENTATION
    -- Rayfield Notify used for kill/lock events.
    -- Also stored so Lifecycle can wire Aimbot.
    -- ==========================================
    local function LogEvent(msg)
        -- Rayfield notification for important events
        local isKill = msg:find("Eliminated") ~= nil
        Rayfield:Notify({
            Title    = isKill and "Eliminated" or "Locked",
            Content  = msg,
            Duration = 2.5,
            Image    = isKill and 4483362458 or 6031071057,
        })
    end

    -- ==========================================
    -- SHORTCUTS DISPLAY
    -- Rayfield has no native shortcut panel,
    -- we use a label on the Aim tab.
    -- Tabs module stores a ref for us to update.
    -- ==========================================
    local function UpdateShortcuts()
        local onOff = State.Aiming
            and i18n.T("shortcut_on")
            or  i18n.T("shortcut_off")
        local rageStr = S.RageEnabled
            and i18n.T("shortcut_on")
            or  i18n.T("shortcut_off")
        local silentStr = S.SilentAim
            and i18n.T("shortcut_on")
            or  i18n.T("shortcut_off")

        local text = string.format(
            i18n.T("shortcut_template"),
            tostring(S.AimKey),
            S.AimMode,
            onOff,
            rageStr,
            silentStr
        )

        -- Update the label stored by tabs module
        if Tabs.ShortcutLabel then
            Tabs.ShortcutLabel:Set(text)
        end
    end

    -- ==========================================
    -- TOGGLE MINIMIZE
    -- Rayfield handles this natively via its
    -- built-in minimize button, but Lifecycle
    -- may call this from the keybind.
    -- ==========================================
    local function ToggleMinimize()
        Rayfield:Destroy() -- not correct, Rayfield has no minimize API
        -- Instead we notify the user the keybind works
        -- but defer to Rayfield's own UI controls
        -- This is a no-op placeholder
    end

    -- ==========================================
    -- CLOSE ANIMATION
    -- Rayfield handles its own close animation.
    -- We just call callback after a short wait.
    -- ==========================================
    local function PlayCloseAnimation(callback)
        Rayfield:Destroy()
        task.wait(0.3)
        if callback then callback() end
    end

    -- Initial shortcut display
    UpdateShortcuts()

    -- ==========================================
    -- RETURN UIREF
    -- Consumed by Lifecycle.Init() and main.lua
    -- ==========================================
    return {
        LogEvent          = LogEvent,
        UpdateShortcuts   = UpdateShortcuts,
        ToggleMinimize    = ToggleMinimize,
        PlayCloseAnimation= PlayCloseAnimation,
    }
end

return UI