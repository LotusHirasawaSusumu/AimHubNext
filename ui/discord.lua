-- ui/discord.lua
-- AimHubNext Discord Prompt
-- Uses Rayfield:Notify() as a lightweight
-- replacement for the original custom modal.
-- Mod Author: CookieLee

local Discord = {}

local _ctx     = nil
local _Rayfield= nil

function Discord.Init(ctx, Rayfield)
    _ctx      = ctx
    _Rayfield = Rayfield

    Discord.ShowPrompt()
end

function Discord.ShowPrompt()
    local i18n = _ctx.i18n

    task.wait(1.5) -- slight delay after UI builds

    _Rayfield:Notify({
        Title    = i18n.T("discord_name"),
        Content  = i18n.T("discord_body") ..
                   "\n" .. i18n.T("discord_link"),
        Duration = 10,
        Image    = 6031071057,
        Actions  = {
            Accept = {
                Name     = i18n.T("discord_copy_btn"),
                Callback = function()
                    pcall(function()
                        local link = i18n.T("discord_link")
                        if setclipboard then
                            setclipboard(link)
                        elseif toclipboard then
                            toclipboard(link)
                        end
                    end)
                end,
            },
            Deny = {
                Name     = i18n.T("discord_later_btn"),
                Callback = function() end,
            },
        },
    })
end

return Discord