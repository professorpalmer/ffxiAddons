--[[
* TellNotifier Configuration Module
* Handles settings, defaults, and configuration management
--]]

local config = require('config')

local Config = {}

-- Default Settings
Config.defaults = {
    webhook_url = '', -- Main/fallback webhook URL
    enabled = true,
    discord_enabled = true,
    cooldown = 1,
    debug_mode = false,

    -- Chat monitoring settings
    monitor_tells = true,
    monitor_party = false,
    monitor_linkshell1 = false,
    monitor_linkshell2 = false,
    monitor_say = false,
    monitor_shout = false,
    monitor_yell = false,
    monitor_unity = false,
    monitor_outgoing = false,

    -- Batching settings
    enable_batching = true,
    batch_interval = 2,

    -- Per-channel cooldowns (optional, uses global cooldown if not set)
    cooldown_tell = nil,
    cooldown_party = nil,
    cooldown_linkshell1 = nil,
    cooldown_linkshell2 = nil,
    cooldown_say = nil,
    cooldown_shout = nil,
    cooldown_yell = nil,
    cooldown_unity = nil,

    -- Per-chat-type webhook URLs
    webhook_tell = '',
    webhook_party = '',
    webhook_linkshell1 = '',
    webhook_linkshell2 = '',
    webhook_say = '',
    webhook_shout = '',
    webhook_yell = '',
    webhook_unity = '',
}

-- Chat mode lookup table
Config.chat_modes = {
    [0] = { name = 'Say', setting = 'monitor_say' },
    [1] = { name = 'Shout', setting = 'monitor_shout' },
    [2] = { name = 'Linkshell1', setting = 'monitor_linkshell1' },
    [3] = { name = 'Tell', setting = 'monitor_tells' },
    [4] = { name = 'Party', setting = 'monitor_party' },
    [5] = { name = 'Linkshell1', setting = 'monitor_linkshell1' },
    [26] = { name = 'Yell', setting = 'monitor_yell' },
    [27] = { name = 'Linkshell2', setting = 'monitor_linkshell2' },
    [33] = { name = 'Unity', setting = 'monitor_unity' },
}

-- Chat type to setting name mapping
Config.chat_type_map = {
    tells = 'monitor_tells',
    tell = 'monitor_tells',
    party = 'monitor_party',
    linkshell1 = 'monitor_linkshell1',
    ls1 = 'monitor_linkshell1',
    ls = 'monitor_linkshell1',
    linkshell = 'monitor_linkshell1',
    linkshell2 = 'monitor_linkshell2',
    ls2 = 'monitor_linkshell2',
    say = 'monitor_say',
    shout = 'monitor_shout',
    yell = 'monitor_yell',
    unity = 'monitor_unity',
    outgoing = 'monitor_outgoing',
}

function Config.load()
    return config.load(Config.defaults)
end

function Config.save(settings)
    config.save(settings)
end

function Config.reload(settings)
    config.reload(settings)
end

function Config.get_webhook_for_chat_type(settings, chat_type)
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

    if specific_webhook and specific_webhook ~= '' then
        return specific_webhook
    else
        return settings.webhook_url
    end
end

function Config.get_cooldown_for_chat_type(settings, chat_type)
    local cooldown_map = {
        Tell = settings.cooldown_tell,
        Party = settings.cooldown_party,
        Linkshell1 = settings.cooldown_linkshell1,
        Linkshell2 = settings.cooldown_linkshell2,
        Say = settings.cooldown_say,
        Shout = settings.cooldown_shout,
        Yell = settings.cooldown_yell,
        Unity = settings.cooldown_unity,
    }

    local specific_cooldown = cooldown_map[chat_type]

    if specific_cooldown and specific_cooldown > 0 then
        return specific_cooldown
    else
        return settings.cooldown  -- Use global cooldown as fallback
    end
end

return Config
