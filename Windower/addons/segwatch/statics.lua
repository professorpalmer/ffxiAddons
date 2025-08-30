--Copyright (c) 2024, SegWatch Developer
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of <addon name> nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

--Default settings file:
default_settings = {
    strings = {
        default =
        "string.format('Segments: %d | Rate: %.1f/hr | Run: %d | Run Rate: %.1f/30min', segments.current, segments.rate/1000, segments.run_segments, segments.run_rate/1000)",
        odyssey =
        "string.format('Segments: %d | Rate: %.1f/hr | Run: %d | Run Rate: %.1f/30min | Duration: %s', segments.current, segments.rate/1000, segments.run_segments, segments.run_rate/1000, segments.run_duration and string.format('%02d:%02d:%02d', math.floor(segments.run_duration/3600), math.floor((segments.run_duration%3600)/60), math.floor(segments.run_duration%60)) or '00:00:00')",
    },
    text_box_settings = {
        pos = {
            x = 100,
            y = 100,
        },
        bg = {
            alpha = 255,
            red = 0,
            green = 0,
            blue = 0,
            visible = true
        },
        flags = {
            right = false,
            bottom = false,
            bold = false,
            italic = false,
            draggable = true
        },
        padding = 0,
        text = {
            size = 12,
            font = 'Consolas',
            fonts = {},
            alpha = 255,
            red = 255,
            green = 255,
            blue = 255,
            stroke = {
                alpha = 255,
                red = 0,
                green = 0,
                blue = 0,
                width = 1
            }
        }
    },
    show_gain_messages = true
}

-- Approved textbox commands:
approved_commands = {
    show = { n = 0 },
    hide = { n = 0 },
    pos = { n = 2, t = 'number' },
    pos_x = { n = 1, t = 'number' },
    pos_y = { n = 1, t = 'number' },
    font = { n = 1, t = 'string' },
    size = { n = 1, t = 'number' },
    pad = { n = 1, t = 'number' },
    color = { n = 3, t = 'number' },
    alpha = { n = 1, t = 'number' },
    transparency = { n = 1, t = 'number' },
    bg_color = { n = 3, t = 'number' },
    bg_alpha = { n = 1, t = 'number' },
    bg_transparency = { n = 1, t = 'number' }
}

-- Not technically static, but sets the initial values for all features:
function initialize()
    segments = {
        registry = {},
        run_registry = {},
        current = 0,
        rate = 0,
        run_rate = 0,
        run_segments = 0,
        run_start_time = os.clock(),
        run_duration = 0,
        in_odyssey = false,

    }

    local info = windower.ffxi.get_info()

    frame_count = 0

    -- Check if we're in an Odyssey zone on load
    if info.logged_in then
        local zone_name = res.zones[info.zone].english
        if string.find(zone_name, 'Odyssey') or string.find(zone_name, 'Segments') then
            segments.in_odyssey = true
            cur_func = loadstring("current_string = " .. settings.strings.odyssey)
        else
            cur_func = loadstring("current_string = " .. settings.strings.default)
        end
        setfenv(cur_func, _G)
    end
end
