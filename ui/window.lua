-- ui/window.lua
-- AimHubNext Rayfield UI Entry Point
-- Mod Author: CookieLee

local require = ...

local UI = {}

function UI.Build(ctx)
    local Rayfield = loadstring(game:HttpGet(
        "https://sirius.menu/rayfield"
    ))()

    local i18n      = ctx.i18n
    local State     = ctx.State
    local Styles    = ctx.Styles
    local Utils     = ctx.Utils
    local Aimbot    = ctx.Aimbot
    local Lifecycle = ctx.Lifecycle
    local Drawings  = ctx.Drawings
    local AntiAim   = ctx.AntiAim

    -- Lazy-load UI sub-modules via RemoteRequire
    -- They don't need require() themselves —
    -- everything is passed through ctx.
    local BuilderMod = require("ui/builder.lua")
    local TabsMod    = require("ui/tabs.lua")
    local DiscordMod = require("ui/discord.lua")

    local Window = Rayfield:CreateWindow({
        Name            = i18n.T("menu_title"),
        LoadingTitle    = "Aim Hub Next",
        LoadingSubtitle = i18n.T("menu_subtitle"),
        ConfigurationSaving = {
            Enabled    = true,
            FolderName = "AimHubNext",
            FileName   = "config",
        },
        Discord  = { Enabled = false },
        KeySystem= false,
    })

    BuilderMod.Init(ctx)
    TabsMod.Init(ctx, Window, BuilderMod)
    DiscordMod.Init(ctx, Rayfield)

    local function LogEvent(msg)
        local isKill = msg:find("Eliminated") ~= nil
        Rayfield:Notify({
            Title    = isKill and "Eliminated" or "Locked",
            Content  = msg,
            Duration = 2.5,
            Image    = isKill and 4483362458 or 6031071057,
        })
    end

    local function UpdateShortcuts()
        local S      = State.Settings
        local onOff  = State.Aiming
            and i18n.T("shortcut_on") or i18n.T("shortcut_off")
        local rageStr = S.RageEnabled
            and i18n.T("shortcut_on") or i18n.T("shortcut_off")
        local silentStr = S.SilentAim
            and i18n.T("shortcut_on") or i18n.T("shortcut_off")
        local text = string.format(
            i18n.T("shortcut_template"),
            tostring(S.AimKey):gsub("Enum.KeyCode.", ""),
            S.AimMode, onOff, rageStr, silentStr
        )
        if TabsMod.ShortcutLabel then
            TabsMod.ShortcutLabel:Set(text)
        end
    end

    local function PlayCloseAnimation(callback)
        Rayfield:Destroy()
        task.wait(0.3)
        if callback then callback() end
    end

    UpdateShortcuts()

    return {
        LogEvent           = LogEvent,
        UpdateShortcuts    = UpdateShortcuts,
        ToggleMinimize     = function() end,
        PlayCloseAnimation = PlayCloseAnimation,
    }
end

return UI