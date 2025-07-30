addon.name      = 'ScriptedExtender'
addon.author    = 'Scripted'
addon.version   = '1.0'
addon.desc      = 'INDI packet extender for Scripted'
addon.link      = 'https://ashitaxi.com/'

require('common')

last_sent = 0

if windower then
    windower.register_event('incoming chunk', function (id, data, modified, injected, blocked)
        local sendstr = "Scripted extravariables "
        local updatescripted = false
        if id == 0x028 then
            local indi = data:byte(0x59)
            if last_sent ~= indi then
                sendstr = sendstr.."INDI:"..indi
                last_sent = indi
                updatescripted = true
            end
        end
        if updatescripted then
            windower.send_command(sendstr)
        end
    end)
end

if ashita then
    ashita.events.register('packet_in', 'scripted_extender_cb', function(e)
        local sendstr = "//Scripted extravariables "
        local updatescripted = false
        if e.id == 0x028 then
            local indi = struct.unpack('B', e.data, 0x59 + 1)
            if last_sent ~= indi then
                sendstr = sendstr.."INDI:"..indi
                last_sent = indi
                updatescripted = true
            end
        end
        if updatescripted then
            AshitaCore:GetChatManager():QueueCommand(-1, sendstr)
        end
        return false
    end)
end 