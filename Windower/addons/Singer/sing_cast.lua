local cast = {}

function cast.JA(str)
    windower.send_command(str)
    del = 1.2
end

function cast.MA(str,ta)
    windower.send_command('input /ma "%s" %s':format(str,ta))
    del = 1.2
end

function cast.check_song(song_list,targ,buffs,spell_recasts,recasts,JA_WS_lock,recast)
    local maxsongs = get.maxsongs(targ,buffs)
    local currsongs = timers[targ] and table.length(timers[targ]) or 0
    local basesongs = get.base_songs
    local ta = targ == 'AoE' and '<me>' or targ

    if basesongs > 2 and currsongs < maxsongs and #song_list > currsongs then
        for i = 1, #setting.dummy do
            local song = setting.dummy[i]

            if basesongs - i >= 0 and currsongs == maxsongs - i and spell_recasts[get.song_by_name(song).id] <= 0 then
                cast.MA(song, ta)
                return true
            end
        end
    end

    for i = 1, math.min(#song_list, maxsongs) do
        local song = get.song_by_name(song_list[i])

        if song and spell_recasts[song.id] <= 0 and
            (not timers[targ] or not timers[targ][song.enl] or
            os.time() - timers[targ][song.enl].ts + recast > 0 or
            (buffs.troubadour and not timers[targ][song.enl].nt) or
            (buffs['soul voice'] and not timers[targ][song.enl].sv) or
            (troubadour_sync_mode and buffs.troubadour and ta == '<me>')) then

            if ta == '<me>' and settings.clarion and not JA_WS_lock and not buffs['clarion call'] and recasts[111] <= 0 and 
               currsongs >= basesongs and #song_list > currsongs and
               -- Smart timing: Only use Clarion when we can stack it with NiTro for maximum benefit
               -- OR when immediate mode is enabled (manual override)
               (settings.clarion_immediate or 
                ((not settings.troubadour or buffs.troubadour or recasts[110] > 0) and
                 (not settings.nightingale or buffs.nightingale or recasts[109] > 0))) then
                cast.JA('input /ja "Clarion Call" <me>')
            elseif ta == '<me>' and settings.nightingale and not JA_WS_lock and not buffs.nightingale and recasts[109] <= 0 and recasts[110] <= 0 then
                cast.JA('input /ja "Nightingale" <me>')
            elseif ta == '<me>' and settings.troubadour and not JA_WS_lock and not buffs.troubadour and recasts[110] <= 0 then
                troubadour_sync_mode = true  -- Activate sync mode to force all songs into Troubadour window
                troubadour_sync_timeout = os.time() + 30  -- 30 second timeout for safety
                cast.JA('input /ja "Troubadour" <me>')
            elseif ta == '<me>' and not JA_WS_lock and song.enl == settings.marcato and not buffs.marcato and not buffs['soul voice'] and recasts[48] <= 0 then
                cast.JA('input /ja "Marcato" <me>')
            elseif ta ~= '<me>' and not buffs.pianissimo then 
                if not JA_WS_lock and recasts[112] <= 0 then
                    cast.JA('input /ja "Pianissimo" <me>')
                end
            else
                cast.MA(song.enl, ta)
            end
            return true
        end
    end
end

return cast
