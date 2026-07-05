-- ui/tabs.lua
-- AimHubNext Rayfield Tab Population
-- Builds all tab pages using Builder helpers.
-- Mod Author: CookieLee

local Tabs = {}
Tabs.ShortcutLabel = nil

local _ctx     = nil
local _Window  = nil
local _Builder = nil

function Tabs.Init(ctx, Window, Builder)
    _ctx     = ctx
    _Window  = Window
    _Builder = Builder

    Tabs._BuildAimTab()
    Tabs._BuildRageTab()
    Tabs._BuildVisualsTab()
    Tabs._BuildCustomTab()
    Tabs._BuildSettingsTab()
    Tabs._BuildLogsTab()
end

-- ==========================================
-- AIM LOCK TAB
-- ==========================================
function Tabs._BuildAimTab()
    local i18n = _ctx.i18n
    local tab  = _Window:CreateTab(i18n.T("tab_aimlock"), 4483362458)

    -- Status shortcut label at top
    Tabs.ShortcutLabel = _Builder.Label(tab,
        "[ Shortcuts will appear here ]"
    )

    _Builder.Section(tab, "tab_aimlock")

    _Builder.Toggle(tab, "Enabled",         "aim_master_title",    "aim_master_desc")
    _Builder.Toggle(tab, "WallCheck",       "aim_wallcheck_title", "aim_wallcheck_desc")
    _Builder.Toggle(tab, "AutoShoot",       "aim_autoshoot_title", "aim_autoshoot_desc")
    _Builder.Toggle(tab, "SilentAim",       "aim_silent_title",    "aim_silent_desc")
    _Builder.Toggle(tab, "FOVCheckEnabled", "aim_fovfilter_title", "aim_fovfilter_desc")
    _Builder.Toggle(tab, "TargetIndicator", "aim_indicator_title", "aim_indicator_desc")
    _Builder.Toggle(tab, "FOVPulse",        "aim_fovpulse_title",  "aim_fovpulse_desc")
    _Builder.Toggle(tab, "AutoSwitch",      "aim_autoswitch_title","aim_autoswitch_desc")

    _Builder.Section(tab, "aim_mode_title")

    _Builder.Dropdown(tab, "AimMode",
        "aim_mode_title",
        { "Toggle", "Hold" },
        "aim_mode_desc"
    )
    _Builder.Dropdown(tab, "TargetPriority",
        "aim_priority_title",
        { "Distance", "Health", "FOV" },
        "aim_priority_desc"
    )
    _Builder.Dropdown(tab, "ShootMode",
        "aim_firerate_title",
        { "Normal", "Fast", "Uzi" },
        "aim_firerate_desc"
    )
    _Builder.Dropdown(tab, "TargetPart",
        "aim_mode_title",
        { "Head", "HumanoidRootPart" },
        "aim_mode_desc"
    )

    _Builder.Section(tab, "aim_smooth_title")

    _Builder.Slider(tab, "Smoothness",  "aim_smooth_title",  1,    100,  "aim_smooth_desc")
    _Builder.Slider(tab, "FOVRadius",   "aim_fovrad_title",  20,   500,  "aim_fovrad_desc")
    _Builder.Slider(tab, "MaxDistance", "aim_maxdist_title", 50,   5000, "aim_maxdist_desc")
    _Builder.Slider(tab, "Prediction",  "aim_predict_title", 0,    10,   "aim_predict_desc")

    _Builder.Section(tab, "tab_settings")

    _Builder.Keybind(tab, "AimKey",      "aim_mode_title",   "aim_mode_desc")
    _Builder.Keybind(tab, "ToggleUiKey", "aim_fovpulse_title","aim_fovpulse_desc")
end

-- ==========================================
-- RAGE TAB
-- ==========================================
function Tabs._BuildRageTab()
    local i18n   = _ctx.i18n
    local AntiAim= _ctx.AntiAim
    local tab    = _Window:CreateTab(i18n.T("tab_rage"), 6031071057)

    _Builder.Section(tab, "tab_rage")

    _Builder.Toggle(tab, "RageEnabled",    "rage_master_title",   "rage_master_desc")
    _Builder.Toggle(tab, "SnapAim",        "rage_snap_title",     "rage_snap_desc")
    _Builder.Toggle(tab, "HitboxExpander", "rage_hitbox_title",   "rage_hitbox_desc")
    _Builder.Toggle(tab, "KillAura",       "rage_aura_title",     "rage_aura_desc")
    _Builder.Toggle(tab, "AntiAimEnabled", "rage_antiaim_title",  "rage_antiaim_desc")
    _Builder.Toggle(tab, "ResolverEnabled","rage_resolver_title",  "rage_resolver_desc")

    _Builder.Section(tab, "rage_antiaim_style")

    _Builder.Dropdown(tab, "AutoHitbox",
        "rage_hitbox_cycle",
        { "Head", "Torso", "Random" },
        "rage_hitbox_cycledesc"
    )

    local aaModesOptions = AntiAim and AntiAim.GetModes()
        or { "Spin","Jitter","SideWays","BackWards",
             "HalfSideWays","FakeDown","FakeUp","Random" }

    _Builder.Dropdown(tab, "AntiAimMode",
        "rage_antiaim_style",
        aaModesOptions,
        "rage_antiaim_styledesc"
    )

    _Builder.Section(tab, "rage_aaspeed_title")

    _Builder.Slider(tab, "HitboxSize",    "rage_hitboxsize_title", 1,   20,  "rage_hitboxsize_desc")
    _Builder.Slider(tab, "KillAuraRange", "rage_aurarange_title",  5,   50,  "rage_aurarange_desc")
    _Builder.Slider(tab, "AntiAimSpeed",  "rage_aaspeed_title",    1,   50,  "rage_aaspeed_desc")
    _Builder.Slider(tab, "AntiAimPitch",  "rage_aapitch_title",    -89, 89,  "rage_aapitch_desc")
end

-- ==========================================
-- VISUALS TAB
-- ==========================================
function Tabs._BuildVisualsTab()
    local i18n = _ctx.i18n
    local tab  = _Window:CreateTab(i18n.T("tab_visuals"), 4483362458)

    _Builder.Section(tab, "tab_visuals")

    _Builder.Toggle(tab, "ChamsEnabled", "vis_chams_title", "vis_chams_desc")
    _Builder.Toggle(tab, "ESPEnabled",   "vis_esp_title",   "vis_esp_desc")
    _Builder.Toggle(tab, "ShowFOV",      "vis_fov_title",   "vis_fov_desc")

    _Builder.Section(tab, "vis_visible_opacity")

    _Builder.Slider(tab, "ChamsVisibleTransparency",  "vis_visible_opacity",  0, 1, "vis_visible_desc")
    _Builder.Slider(tab, "ChamsOccludedTransparency", "vis_occluded_opacity", 0, 1, "vis_occluded_desc")
    _Builder.Slider(tab, "ESPTransparency",           "vis_esp_opacity",      0, 1, "vis_esp_desc2")

    _Builder.Section(tab, "vis_chams_title")

    _Builder.Label(tab, "GREEN = Visible  |  RED = Wall / Blocked")
end

-- ==========================================
-- CUSTOMIZATION TAB
-- ==========================================
function Tabs._BuildCustomTab()
    local i18n     = _ctx.i18n
    local State    = _ctx.State
    local Styles   = _ctx.Styles
    local Drawings = _ctx.Drawings
    local Utils    = _ctx.Utils
    local tab      = _Window:CreateTab(i18n.T("tab_customization"), 4483362458)

    _Builder.Section(tab, "tab_customization")

    -- Accent color cycle button
    _Builder.Button(tab, "cust_swapcolor", nil, function()
        local S = State.Settings
        S.AccentColorIndex = S.AccentColorIndex + 1
        if S.AccentColorIndex > #State.AccentPresets then
            S.AccentColorIndex = 1
        end
        Styles.RefreshAccent()
        if Drawings then
            Drawings.RefreshAccent()
        end
    end)

    _Builder.Section(tab, "cust_ui_trans_title")

    _Builder.Slider(tab, "MenuTransparency", "cust_ui_trans_title", 0, 100, "cust_ui_trans_desc")
    _Builder.Slider(tab, "BorderThickness",  "cust_border_title",   1, 5,   "cust_border_desc")

    _Builder.Label(tab, i18n.T("cust_chams_legend"))
    _Builder.Label(tab, i18n.T("cust_chams_desc"))
end

-- ==========================================
-- SETTINGS TAB
-- ==========================================
function Tabs._BuildSettingsTab()
    local i18n     = _ctx.i18n
    local State    = _ctx.State
    local Styles   = _ctx.Styles
    local Drawings = _ctx.Drawings
    local Utils    = _ctx.Utils
    local Lifecycle= _ctx.Lifecycle
    local tab      = _Window:CreateTab(i18n.T("tab_settings"), 4483362458)

    _Builder.Section(tab, "tab_settings")

    -- Save config
    _Builder.Button(tab, "sett_save", nil, function()
        -- Rayfield handles config saving via its own system
        -- (ConfigurationSaving flag in CreateWindow)
        -- We trigger it manually here too
        Rayfield:Notify({
            Title    = i18n.T("sett_saved"),
            Content  = i18n.T("log_saved"),
            Duration = 2,
            Image    = 4483362458,
        })
    end)

    -- Reset defaults
    _Builder.Button(tab, "sett_reset", nil, function()
        for key, value in pairs(State.DefaultSettings) do
            State.Settings[key] = value
        end
        Utils.RunAllUpdaters()
        Styles.RefreshAccent()
        if Drawings then Drawings.RefreshAccent() end
        Utils.ResetHitboxes()
    end)

    -- Copy Discord
    _Builder.Button(tab, "sett_discord", nil, function()
        pcall(function()
            local link = "https://discord.gg/8jSF8vSvbJ"
            if setclipboard then
                setclipboard(link)
            elseif toclipboard then
                toclipboard(link)
            end
        end)
    end)

    -- Unload engine
    _Builder.Button(tab, "sett_unload", nil, function()
        Lifecycle.CinematicClose()
    end)

    _Builder.Section(tab, "tab_settings")

    -- Language switcher
    local i18nRef = _ctx.i18n
    _Builder.Button(tab, "tab_settings", nil, function()
        local current = "en"
        local langs   = i18nRef.GetAvailableLanguages()
        local nextIdx = 1
        for i, code in ipairs(langs) do
            if code == current then
                nextIdx = (i % #langs) + 1
                break
            end
        end
        i18nRef.SetLanguage(langs[nextIdx])
    end)

    _Builder.Label(tab,
        "Aim Hub Next  |  Mod by CookieLee\n" ..
        "Original by @Rakamo82"
    )
end

-- ==========================================
-- LOGS TAB
-- ==========================================
function Tabs._BuildLogsTab()
    local i18n = _ctx.i18n
    local tab  = _Window:CreateTab(i18n.T("tab_logs"), 4483362458)

    _Builder.Section(tab, "tab_logs")

    -- Static info label
    _Builder.Label(tab,
        "Kill and lock events appear as\n" ..
        "notifications in the top-right corner."
    )

    _Builder.Label(tab,
        "Engine: v39  |  Aim Hub Next\n" ..
        "Mod Author: CookieLee"
    )
end

return Tabs