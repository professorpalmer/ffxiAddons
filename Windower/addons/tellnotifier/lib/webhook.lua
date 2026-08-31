--[[
* TellNotifier webhook URL resolution
* Pure Lua so tools/test_tellnotifier_webhook.lua can run outside Windower.
--]]

local Webhook = {}

local PLACEHOLDERS = {
    INSERT_WEBHOOK_URL_HERE = true,
    PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE = true,
}

function Webhook.is_usable(url)
    if type(url) ~= 'string' then
        return false
    end
    local trimmed = url:match('^%s*(.-)%s*$') or ''
    if trimmed == '' or PLACEHOLDERS[trimmed] then
        return false
    end
    local host = trimmed:match('^https://([^/?#]+)')
    return host ~= nil and host ~= ''
end

function Webhook.resolve(settings, chat_type)
    local webhook_map = {
        Tell = settings.webhook_tell,
        Party = settings.webhook_party,
        Linkshell1 = settings.webhook_linkshell1,
        Linkshell2 = settings.webhook_linkshell2,
        Say = settings.webhook_say,
        Shout = settings.webhook_shout,
        Yell = settings.webhook_yell,
        Unity = settings.webhook_unity,
    }

    local specific_webhook = webhook_map[chat_type]
    if Webhook.is_usable(specific_webhook) then
        return specific_webhook
    end
    if Webhook.is_usable(settings.webhook_url) then
        return settings.webhook_url
    end
    return ''
end

return Webhook
