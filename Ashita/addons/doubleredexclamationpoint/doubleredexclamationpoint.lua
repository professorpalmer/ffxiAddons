addon.name = 'doubleredexclamationpoint'
addon.version = '0.2'
addon.author = 'Looney | Edits by Palmer (Zodiarchy @ Asura)'
addon.desc = 'give me the fucking doubleredexclamationpoint'
addon.link = 'https://github.com/loonsies/doubleredexclamationpoint'

-- Ashita dependencies
require 'common'
settings = require('settings')
chat = require('chat')
imgui = require('imgui')

-- Local dependencies
actionTypes = require('data/actionTypes')
mobStatus = require('data/mobStatus')

commands = require('src/commands')
config = require('src/config')
ui = require('src/ui')
utils = require('src/utils')

drep = {
    visible = { false },
    config = config.load(),
    prevTargetHP = -1,
    prevTargetID = -1,
}

ashita.events.register('command', 'command_cb', function (cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.id ~= 0x028 then return end

    local ap = utils.parseActionPacket(e)
    if not utils.isMonster(ap.UserIndex) then return end

    local targetEntity = utils.getTarget()
    if ap.UserIndex ~= targetEntity then return end

    if ap.Type == 7 or ap.Type == 8 then
        if ap.Type == 7 then
            targetStatus = mobStatus.weaponskill
        else
            targetStatus = mobStatus.casting
        end

        local mobId = ap.UserId
        utils.mobActionState[mobId] = os.clock() + 3
    end
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    ui.update()
    local currentTarget = utils.getTarget()
    if currentTarget then
        local target = GetEntity(currentTarget)
        if target then
            if target.HPPercent ~= drep.prevTargetHP then
                drep.prevTargetHP = target.HPPercent
            end
            if currentTarget ~= drep.prevTargetID then
                drep.prevTargetID = currentTarget
            end
        else
            drep.prevTargetHP = -1
            drep.prevTargetID = -1
        end
    end
end)
