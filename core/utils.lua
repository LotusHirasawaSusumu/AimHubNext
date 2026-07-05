-- core/utils.lua
-- AimHubNext Shared Utility Functions
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local Utils = {}

function Utils.SafeConnect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(State.GlobalConnections, connection)
    return connection
end

function Utils.TweenObj(obj, goal, duration, style, dir)
    local info = TweenInfo.new(
        duration or 0.25,
        style    or Enum.EasingStyle.Quad,
        dir      or Enum.EasingDirection.Out
    )
    local tween = Services.TweenService:Create(obj, info, goal)
    tween:Play()
    return tween
end

function Utils.HookButtonAnimations(btn, baseColor, hoverColor)
    local uiScale = btn:FindFirstChildOfClass("UIScale")
                 or Instance.new("UIScale", btn)
    uiScale.Scale = 1
    btn.MouseEnter:Connect(function()
        Utils.TweenObj(btn, { BackgroundColor3 = hoverColor }, 0.2)
    end)
    btn.MouseLeave:Connect(function()
        Utils.TweenObj(btn, { BackgroundColor3 = baseColor }, 0.2)
        Utils.TweenObj(uiScale, { Scale = 1 }, 0.2)
    end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            Utils.TweenObj(uiScale, { Scale = 0.94 }, 0.1,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            Utils.TweenObj(uiScale, { Scale = 1 }, 0.15,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end)
end

function Utils.ControlClick(press)
    if press then
        if mouse1press then
            mouse1press()
        else
            local char = Services.LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then tool:Activate() end
            end
        end
    else
        if mouse1release then
            mouse1release()
        else
            local char = Services.LocalPlayer.Character
            if char then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then tool:Deactivate() end
            end
        end
    end
end

function Utils.ResetHitboxes()
    for part, size in pairs(State.OriginalSizes) do
        if part and part.Parent then
            pcall(function()
                part.Size = size
                if part.Name == "Head" then
                    part.Transparency = 0
                elseif part.Name == "HumanoidRootPart" then
                    part.Transparency = 1
                end
            end)
        end
    end
    State.OriginalSizes = {}
end

function Utils.WipeAllESPRemnants()
    for _, p in ipairs(Services.Players:GetPlayers()) do
        if p.Character then
            for _, name in ipairs({
                "Ligia_Premium_ESP",
                "TestESP_Highlight",
                "Ligia_DualChams",
                "AimHubNext_DualChams",
                "AimHubNext_ESP",
            }) do
                local obj = p.Character:FindFirstChild(name)
                if obj then pcall(function() obj:Destroy() end) end
            end
        end
    end
    State.ChamsVisibilityCache = {}
end

function Utils.GetScreenFOVDistance(player)
    local Camera = Services.Camera
    local UIS    = Services.UserInputService
    if not player.Character
    or not player.Character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    local pos, onScreen = Camera:WorldToViewportPoint(
        player.Character.HumanoidRootPart.Position
    )
    if not onScreen then return math.huge end
    local mousePos = UIS:GetMouseLocation()
    return (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
end

function Utils.IsTeammate(player)
    local lp = Services.LocalPlayer
    if player.Team ~= nil and lp.Team ~= nil then
        if player.Team == lp.Team
        or player.TeamColor == lp.TeamColor then
            return true
        end
    end
    return false
end

function Utils.RegisterUpdater(fn)
    table.insert(State.UIUpdaters, fn)
end

function Utils.RunAllUpdaters()
    for _, fn in ipairs(State.UIUpdaters) do
        pcall(fn)
    end
end

return Utils