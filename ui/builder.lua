-- ui/builder.lua
-- AimHubNext Rayfield Component Builder
-- Mod Author: CookieLee

local require = ...

local Builder = {}
local _ctx    = nil

function Builder.Init(ctx)
    _ctx = ctx
end

function Builder.Toggle(tab, key, titleKey, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings
    local toggle = tab:CreateToggle({
        Name         = i18n.T(titleKey),
        CurrentValue = S[key],
        Flag         = "Toggle_" .. key,
        Callback     = function(value)
            S[key] = value
            if key == "Enabled" or key == "RageEnabled"
            or key == "SilentAim" then
                if _ctx.UIRef and _ctx.UIRef.UpdateShortcuts then
                    _ctx.UIRef.UpdateShortcuts()
                end
            end
        end,
    })
    table.insert(State.UIUpdaters, function()
        toggle:Set(S[key])
    end)
    return toggle
end

function Builder.Slider(tab, key, titleKey, min, max, descKey, callback)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings
    local increment = (max - min) <= 10 and 0.1 or 1
    local slider = tab:CreateSlider({
        Name         = i18n.T(titleKey),
        Range        = { min, max },
        Increment    = increment,
        Suffix       = "",
        CurrentValue = S[key],
        Flag         = "Slider_" .. key,
        Callback     = function(value)
            S[key] = value
            if callback then pcall(callback, value) end
        end,
    })
    table.insert(State.UIUpdaters, function()
        slider:Set(S[key])
    end)
    return slider
end

function Builder.Dropdown(tab, key, titleKey, options, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings
    local dropdown = tab:CreateDropdown({
        Name            = i18n.T(titleKey),
        Options         = options,
        CurrentOption   = { tostring(S[key]) },
        MultipleOptions = false,
        Flag            = "Dropdown_" .. key,
        Callback        = function(selected)
            local value = type(selected) == "table"
                and selected[1] or selected
            S[key] = value
            if _ctx.UIRef and _ctx.UIRef.UpdateShortcuts then
                _ctx.UIRef.UpdateShortcuts()
            end
        end,
    })
    table.insert(State.UIUpdaters, function()
        dropdown:Set(tostring(S[key]))
    end)
    return dropdown
end

function Builder.Button(tab, titleKey, descKey, callback)
    local i18n = _ctx.i18n
    return tab:CreateButton({
        Name     = i18n.T(titleKey),
        Interact = descKey and i18n.T(descKey) or nil,
        Callback = function()
            if callback then pcall(callback) end
        end,
    })
end

function Builder.Label(tab, text)
    return tab:CreateLabel(text)
end

function Builder.Section(tab, titleKey)
    tab:CreateSection(_ctx.i18n.T(titleKey))
end

function Builder.Keybind(tab, key, titleKey, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings
    local bind = tab:CreateKeybind({
        Name           = i18n.T(titleKey),
        CurrentKeybind = tostring(S[key]):gsub("Enum.KeyCode.", ""),
        HoldToInteract = false,
        Flag           = "Keybind_" .. key,
        Callback       = function(newKey)
            local enumKey = Enum.KeyCode[newKey]
            if enumKey then S[key] = enumKey end
        end,
    })
    table.insert(State.UIUpdaters, function()
        bind:Set(tostring(S[key]):gsub("Enum.KeyCode.", ""))
    end)
    return bind
end

return Builder