local config = {}

local default = T {
    daggerItem = { '' },
    swordItem = { '' },
    greatSwordItem = { '' },
    scytheItem = { '' },
    polearmItem = { '' },
    katanaItem = { '' },
    greatKatanaItem = { '' },
    clubItem = { '' },
    staffItem = { '' },
    mainItem = { '' },
    subItem = { '' },
    locked = { false },
    uiScale = { 1.0 }
}

config.load = function ()
    return settings.load(default)
end

return config
