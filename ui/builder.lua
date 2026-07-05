-- ui/builder.lua
-- AimHubNext Rayfield Component Builder
-- Wraps Rayfield Tab methods with i18n,
-- State wiring, and UIUpdater registration.
-- Mod Author: CookieLee

local Builder = {}

local _ctx = nil

function Builder.Init(ctx)
    _ctx = ctx
end

-- ==========================================
-- TOGGLE
-- Wraps Tab:CreateToggle()
-- Reads/writes State.Settings[key]
-- ==========================================
function Builder.Toggle(tab, key, titleKey, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings

    local toggle = tab:CreateToggle({
        Name        = i18n.T(titleKey),
        CurrentValue= S[key],
        Flag        = "Toggle_" .. key,
        Callback    = function(value)
            S[key] = value
            if _ctx.Utils then
                -- refresh shortcut display on relevant toggles
                if key == "Enabled" or key == "RageEnabled"
                or key == "SilentAim" then
                    if _ctx.UIRef and _ctx.UIRef.UpdateShortcuts then
                        _ctx.UIRef.UpdateShortcuts()
                    end
                end
            end
        end,
    })

    -- Register updater so Reset can sync UI state
    if State.UIUpdaters then
        table.insert(State.UIUpdaters, function()
            toggle:Set(S[key])
        end)
    end

    return toggle
end

-- ==========================================
-- SLIDER
-- Wraps Tab:CreateSlider()
-- ==========================================
function Builder.Slider(tab, key, titleKey, min, max, descKey, callback)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings

    local slider = tab:CreateSlider({
        Name         = i18n.T(titleKey),
        Range        = {min, max},
        Increment    = (max - min) <= 10 and 0.1 or 1,
        Suffix       = "",
        CurrentValue = S[key],
        Flag         = "Slider_" .. key,
        Callback     = function(value)
            S[key] = value
            if callback then
                pcall(callback, value)
            end
        end,
    })

    if State.UIUpdaters then
        table.insert(State.UIUpdaters, function()
            slider:Set(S[key])
        end)
    end

    return slider
end

-- ==========================================
-- DROPDOWN (replaces CycleButton)
-- Wraps Tab:CreateDropdown()
-- options = plain array of strings
-- ==========================================
function Builder.Dropdown(tab, key, titleKey, options, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings

    local dropdown = tab:CreateDropdown({
        Name         = i18n.T(titleKey),
        Options      = options,
        CurrentOption= { tostring(S[key]) },
        MultipleOptions = false,
        Flag         = "Dropdown_" .. key,
        Callback     = function(selected)
            -- Rayfield returns a table for dropdown
            local value = type(selected) == "table"
                and selected[1] or selected
            S[key] = value
            if _ctx.UIRef and _ctx.UIRef.UpdateShortcuts then
                _ctx.UIRef.UpdateShortcuts()
            end
        end,
    })

    if State.UIUpdaters then
        table.insert(State.UIUpdaters, function()
            dropdown:Set(tostring(S[key]))
        end)
    end

    return dropdown
end

-- ==========================================
-- BUTTON
-- Wraps Tab:CreateButton()
-- ==========================================
function Builder.Button(tab, titleKey, descKey, callback)
    local i18n = _ctx.i18n

    return tab:CreateButton({
        Name     = i18n.T(titleKey),
        Interact = descKey and i18n.T(descKey) or nil,
        Callback = function()
            if callback then
                pcall(callback)
            end
        end,
    })
end

-- ==========================================
-- LABEL
-- Wraps Tab:CreateLabel()
-- Returns the label so caller can call :Set()
-- ==========================================
function Builder.Label(tab, text)
    return tab:CreateLabel(text)
end

-- ==========================================
-- SECTION DIVIDER
-- Wraps Tab:CreateSection()
-- ==========================================
function Builder.Section(tab, titleKey)
    local i18n = _ctx.i18n
    tab:CreateSection(i18n.T(titleKey))
end

-- ==========================================
-- KEYBIND
-- Wraps Tab:CreateKeybind()
-- ==========================================
function Builder.Keybind(tab, key, titleKey, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings

    local bind = tab:CreateKeybind({
        Name         = i18n.T(titleKey),
        CurrentKeybind = tostring(S[key]):gsub("Enum.KeyCode.", ""),
        HoldToInteract = false,
        Flag         = "Keybind_" .. key,
        Callback     = function(newKey)
            local enumKey = Enum.KeyCode[newKey]
            if enumKey then
                S[key] = enumKey
            end
        end,
    })

    if State.UIUpdaters then
        table.insert(State.UIUpdaters, function()
            local name = tostring(S[key]):gsub("Enum.KeyCode.", "")
            bind:Set(name)
        end)
    end

    return bind
end

return Builder