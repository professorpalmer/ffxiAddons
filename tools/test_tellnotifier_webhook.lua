-- Regression for GitHub issue #3: ping uses webhook_url, tells used webhook_tell
-- even when webhook_tell was the shipped placeholder INSERT_WEBHOOK_URL_HERE.

package.path = './Windower/addons/tellnotifier/?.lua;' .. package.path
local Webhook = require('lib/webhook')

local failures = 0

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        failures = failures + 1
        io.stderr:write(string.format('FAIL %s\n  expected: %q\n  actual:   %q\n', label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(actual, label)
    if actual ~= true then
        failures = failures + 1
        io.stderr:write(string.format('FAIL %s\n  expected true, got %s\n', label, tostring(actual)))
    end
end

local function assert_false(actual, label)
    if actual ~= false then
        failures = failures + 1
        io.stderr:write(string.format('FAIL %s\n  expected false, got %s\n', label, tostring(actual)))
    end
end

local real_url = 'https://discord.com/api/webhooks/123/abc'
local other_url = 'https://discord.com/api/webhooks/456/def'

assert_false(Webhook.is_usable(nil), 'nil is not usable')
assert_false(Webhook.is_usable(''), 'empty is not usable')
assert_false(Webhook.is_usable('   '), 'whitespace is not usable')
assert_false(Webhook.is_usable('INSERT_WEBHOOK_URL_HERE'), 'shipped placeholder is not usable')
assert_false(Webhook.is_usable('PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE'), 'README placeholder is not usable')
assert_false(Webhook.is_usable('not-a-url'), 'bare text is not usable')
assert_true(Webhook.is_usable(real_url), 'discord https URL is usable')

-- Issue #3 repro: user followed README and only replaced webhook_url.
local readme_only = {
    webhook_url = real_url,
    webhook_tell = 'INSERT_WEBHOOK_URL_HERE',
    webhook_party = 'INSERT_WEBHOOK_URL_HERE',
    webhook_linkshell1 = '',
    webhook_linkshell2 = '',
    webhook_say = '',
    webhook_shout = '',
    webhook_yell = '',
    webhook_unity = '',
}
assert_eq(Webhook.resolve(readme_only, 'Tell'), real_url, 'Tell falls back to webhook_url when webhook_tell is a placeholder')
assert_eq(Webhook.resolve(readme_only, 'Party'), real_url, 'Party falls back to webhook_url when webhook_party is a placeholder')
assert_eq(Webhook.resolve(readme_only, 'Test'), real_url, 'unknown chat type uses webhook_url')

-- Reporter workaround: only webhook_tell is a real URL.
local tell_only = {
    webhook_url = 'INSERT_WEBHOOK_URL_HERE',
    webhook_tell = other_url,
    webhook_party = '',
    webhook_linkshell1 = '',
    webhook_linkshell2 = '',
    webhook_say = '',
    webhook_shout = '',
    webhook_yell = '',
    webhook_unity = '',
}
assert_eq(Webhook.resolve(tell_only, 'Tell'), other_url, 'usable webhook_tell wins')
assert_eq(Webhook.resolve(tell_only, 'Party'), '', 'no usable fallback when webhook_url is a placeholder')

-- Dedicated channel still wins over the main URL.
local split = {
    webhook_url = real_url,
    webhook_tell = other_url,
    webhook_party = '',
    webhook_linkshell1 = '',
    webhook_linkshell2 = '',
    webhook_say = '',
    webhook_shout = '',
    webhook_yell = '',
    webhook_unity = '',
}
assert_eq(Webhook.resolve(split, 'Tell'), other_url, 'usable per-channel URL is not overwritten by webhook_url')
assert_eq(Webhook.resolve(split, 'Party'), real_url, 'empty per-channel URL falls back to webhook_url')

if failures > 0 then
    io.stderr:write(string.format('%d assertion(s) failed\n', failures))
    os.exit(1)
end

io.write('ok\n')
