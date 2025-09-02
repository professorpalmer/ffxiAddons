--[[
* Sendoria Configuration Module
* Handles settings, defaults, and configuration management
--]]

local config = require('config')

local Config = {}

-- Default Settings
Config.defaults = {
    enabled = true,
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

    -- Webhook settings removed - Discord bot handles all communication

    -- Relay settings for bidirectional Discord communication
    relay_enabled = false,
    relay_file_path = 'chat_relay.txt',
    response_file_path = 'discord_responses.txt',
    relay_interval = 0.5,
    relay_log_all_chat = true,

    -- Auto-start Discord bot settings
    auto_start_bot = false,
    bot_executable_path = 'SendoriaBot_Silent.exe', -- Use silent version by default
    bot_process_name = 'SendoriaBot_Silent.exe',
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

-- Webhook functions removed - Discord bot handles all communication

function Config.get_cooldown_for_chat_type(settings, chat_type)
    -- Ensure settings exists and has a cooldown value
    if not settings then
        return 1
    end

    local cooldown_map = {
        Tell = settings.cooldown_tell or nil,
        Party = settings.cooldown_party or nil,
        Linkshell1 = settings.cooldown_linkshell1 or nil,
        Linkshell2 = settings.cooldown_linkshell2 or nil,
        Say = settings.cooldown_say or nil,
        Shout = settings.cooldown_shout or nil,
        Yell = settings.cooldown_yell or nil,
        Unity = settings.cooldown_unity or nil,
    }

    local specific_cooldown = cooldown_map[chat_type]

    if specific_cooldown and type(specific_cooldown) == 'number' and specific_cooldown > 0 then
        return specific_cooldown
    else
        return settings.cooldown or 1 -- Use global cooldown as fallback
    end
end

return Config
