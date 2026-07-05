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
            or key == "SilentAim" or key == "AimMode" then
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

    -- Clamp current value into new range so Rayfield
    -- doesn't error on out-of-range CurrentValue
    local clamped   = math.clamp(S[key] or min, min, max)
    S[key]          = clamped

    local increment = (max - min) <= 2 and 0.01
                   or (max - min) <= 10 and 0.1
                   or 1

    local slider = tab:CreateSlider({
        Name         = i18n.T(titleKey),
        Range        = { min, max },
        Increment    = increment,
        Suffix       = "",
        CurrentValue = clamped,
        Flag         = "Slider_" .. key,
        Callback     = function(value)
            S[key] = value
            if callback then pcall(callback, value) end
        end,
    })
    table.insert(State.UIUpdaters, function()
        slider:Set(math.clamp(S[key] or min, min, max))
    end)
    return slider
end

function Builder.Dropdown(tab, key, titleKey, options, descKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings

    -- Validate current value exists in options
    local currentValid = false
    for _, opt in ipairs(options) do
        if tostring(opt) == tostring(S[key]) then
            currentValid = true
            break
        end
    end
    if not currentValid then S[key] = options[1] end

    local dropdown = tab:CreateDropdown({
        Name            = i18n.T(titleKey),
        Options         = options,
        CurrentOption   = { tostring(S[key]) },
        MultipleOptions = false,
        Flag            = "Dropdown_" .. key,
        Callback        = function(selected)
            local value = type(selected) == "table"
                and selected[1] or selected
            if value ~= nil then
                S[key] = value
            end
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
    local i18n = _ctx.i18n
    local text = i18n.T(titleKey)
    -- If key not found, i18n returns the key itself
    -- which is still better than an error
    tab:CreateSection(text)
end

-- ==========================================
-- SAFE KEYBIND
-- Replaces the old Keybind() that caused
-- callback errors on RightShift and similar.
-- Uses CreateButton instead of CreateKeybind
-- to avoid Rayfield's internal enum validation.
-- Displays current key and updates on click.
-- ==========================================
function Builder.SafeKeybind(tab, key, titleKey)
    local i18n  = _ctx.i18n
    local State = _ctx.State
    local S     = State.Settings

    local function KeyName()
        local raw = tostring(S[key])
        return raw:gsub("Enum.KeyCode.", "")
    end

    -- Display as a label showing current binding
    -- Real rebinding via UserInputService listener
    local label = tab:CreateLabel(
        i18n.T(titleKey) .. "  [ " .. KeyName() .. " ]"
    )

    -- Listen for next key press to rebind
    local listening = false
    local listenConn = nil

    tab:CreateButton({
        Name     = "Rebind " .. i18n.T(titleKey),
        Interact = "Press to rebind, then press new key",
        Callback = function()
            if listening then return end
            listening = true

            -- Update label to show waiting state
            label:Set(i18n.T(titleKey) .. "  [ ... ]")

            -- Listen for ONE key press
            listenConn = game:GetService("UserInputService").InputBegan:Connect(
                function(input, processed)
                    if processed then return end

                    -- Accept only keyboard keys
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then
                        return
                    end

                    -- Safely assign
                    pcall(function()
                        S[key] = input.KeyCode
                    end)

                    -- Update display
                    pcall(function()
                        label:Set(i18n.T(titleKey) .. "  [ " .. KeyName() .. " ]")
                    end)

                    listening = false
                    if listenConn then
                        listenConn:Disconnect()
                        listenConn = nil
                    end
                end
            )
        end,
    })

    -- Register updater
    table.insert(State.UIUpdaters, function()
        pcall(function()
            label:Set(i18n.T(titleKey) .. "  [ " .. KeyName() .. " ]")
        end)
    end)

    return label
end

return Builder