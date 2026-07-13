--[[
    Kotoba UI controls — language / channel cycling helpers (Wave 2)

    Shared constants and pure helpers used by panel.lua and kotoba.lua.
]]

local controls = {}

controls.LANG_CODES = { 'ja', 'en', 'es', 'fr', 'de', 'ko', 'zh' }

controls.LANG_NAMES = {
    ja = 'Japanese',
    en = 'English',
    es = 'Spanish',
    fr = 'French',
    de = 'German',
    ko = 'Korean',
    zh = 'Chinese',
}

-- Display order for //kb channel / Send-to cycling (Ashita parity labels → Windower keys)
controls.CHANNELS = { 'say', 'party', 'tell', 'ls', 'ls2', 'shout', 'yell' }

controls.CHANNEL_LABELS = {
    say = 'Say',
    party = 'Party',
    tell = 'Tell',
    ls = 'Linkshell',
    ls2 = 'Linkshell2',
    shout = 'Shout',
    yell = 'Yell',
}

local lang_set = {}
for _, code in ipairs(controls.LANG_CODES) do
    lang_set[code] = true
end

function controls.is_valid_lang(code)
    return code ~= nil and lang_set[code:lower()] == true
end

function controls.lang_name(code)
    if not code then
        return 'Unknown'
    end
    return controls.LANG_NAMES[code:lower()] or code
end

--[[
    Compose / outbound source language:
    - Target English → treat input as Japanese (incoming-style)
    - Any other target (ja/es/fr/de/ko/zh) → treat input as English
]]
function controls.source_lang_for(target_lang)
    if target_lang and target_lang:lower() == 'en' then
        return 'ja'
    end
    return 'en'
end

function controls.cycle_lang(current)
    local cur = (current or 'ja'):lower()
    local idx = 1
    for i, code in ipairs(controls.LANG_CODES) do
        if code == cur then
            idx = i
            break
        end
    end
    local next_idx = (idx % #controls.LANG_CODES) + 1
    return controls.LANG_CODES[next_idx]
end

function controls.cycle_channel(current)
    local cur = (current or 'say'):lower()
    local idx = 1
    for i, ch in ipairs(controls.CHANNELS) do
        if ch == cur then
            idx = i
            break
        end
    end
    local next_idx = (idx % #controls.CHANNELS) + 1
    return controls.CHANNELS[next_idx]
end

function controls.channel_label(key)
    if not key then
        return 'Say'
    end
    return controls.CHANNEL_LABELS[key:lower()] or key
end

return controls
