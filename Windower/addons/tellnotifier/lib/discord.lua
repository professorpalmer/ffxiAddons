--[[
* TellNotifier Discord Module
* Handles Discord webhook communication and notifications
--]]

local https = require('ssl.https')
local ltn12 = require('ltn12')

local Discord = {}

function Discord.send_notification(webhook_url, sender, message, chat_type, debug_mode)
    if not webhook_url or webhook_url == '' then
        if debug_mode then
            windower.add_to_chat(123, string.format('TellNotifier: No webhook URL configured for %s', chat_type))
        end
        return false
    end

    -- Create the notification content
    local notification_text = string.format('FFXI %s from %s: %s', chat_type, sender or 'Unknown',
        message or 'Empty message')

    -- Escape text for JSON
    local json_safe_text = notification_text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
    :gsub('\t', '\\t')

    -- Create JSON payload
    local payload = string.format('{"content":"%s"}', json_safe_text)

    -- Send request
    local response_body = {}
    local request_result, response_code = https.request {
        url = webhook_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#payload)
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_body),
        protocol = "tlsv1_2",
        verify = "none",
        options = "all"
    }

    if not request_result then
        if debug_mode then
            windower.add_to_chat(123,
                string.format('TellNotifier: HTTPS failed (%s), trying curl fallback...', tostring(response_code)))
        end

        -- Fallback to curl
        local curl_text = notification_text:gsub('"', '\\"')
        local command = string.format(
            'curl -s -X POST -H "Content-Type: application/json" -d "{\\"content\\":\\"%s\\"}" "%s"',
            curl_text, webhook_url)

        local handle = io.popen(command)
        if handle then
            handle:read("*a")
            handle:close()
            if debug_mode then
                windower.add_to_chat(123,
                    string.format('TellNotifier: Sent via curl fallback for %s from %s', chat_type, sender))
            end
            return true
        end
        return false
    elseif response_code ~= 204 then
        if debug_mode then
            windower.add_to_chat(123,
                string.format('TellNotifier: Discord returned code %s (expected 204)', tostring(response_code)))
        end
        return false
    else
        if debug_mode then
            windower.add_to_chat(123,
                string.format('TellNotifier: Discord notification sent for %s from %s', chat_type, sender))
        end
        return true
    end
end

function Discord.test_webhook(webhook_url)
    if not webhook_url or webhook_url == '' then
        return false, "No webhook URL configured"
    end

    local payload = '{"content":"Ping test from TellNotifier addon"}'
    local response_body = {}

    local request_result, response_code = https.request {
        url = webhook_url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#payload)
        },
        source = ltn12.source.string(payload),
        sink = ltn12.sink.table(response_body),
        protocol = "tlsv1_2",
        verify = "none",
        options = "all"
    }

    if not request_result then
        return false, string.format("Request failed: %s", tostring(response_code))
    elseif response_code == 204 then
        return true, "Success"
    else
        return false, string.format("Response code: %s", tostring(response_code))
    end
end

return Discord
