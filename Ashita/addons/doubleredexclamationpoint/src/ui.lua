ui = {}
currentWeapon = 'Unknown'
lastWeaponSkill = 'None'
targetStatus = mobStatus.normal

ui.maxLabelWidth = 0

function ui.drawUI()
    -- Apply UI scaling
    local scale = drep.config.uiScale[1] or 1.0
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 4 * scale, 4 * scale })
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4 * scale, 4 * scale })
    
    if imgui.Begin('doubleredexclamationpoint', drep.visible, ImGuiWindowFlags_AlwaysAutoResize) then
        imgui.Text(string.format('Target status: %s', mobStatus[targetStatus]))
        imgui.Text(string.format('Weapon: %s', currentWeapon))
        imgui.Text(string.format('Last WS used: %s', lastWeaponSkill))
        imgui.Text(string.format('Claimed by: %s', utils.getPartyClaimerName(utils.getTarget())))

        local tp = utils.getTP()
        if tp < 1000 then
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 0.0, 0.0, 1.0 }) -- red
        else
            imgui.PushStyleColor(ImGuiCol_Text, { 0.0, 1.0, 0.0, 1.0 }) -- green
        end

        imgui.Text(string.format('TP: %i', tp))
        imgui.PopStyleColor()

        if imgui.Button('Reset') then
            currentWeapon = 'Unknown'
            lastWeaponSkill = 'None'
            targetStatus = mobStatus.normal
            utils.resetClickedButtons()
        end
        imgui.SameLine()
        if imgui.Checkbox('Lock weapon names', drep.config.locked) then
            settings.save()
        end
        imgui.SameLine()
        imgui.Text('UI Scale:')
        imgui.SameLine()
        imgui.SetNextItemWidth(40)
        if imgui.InputFloat('##UIScale', drep.config.uiScale, 0.1, 0.1, '%.1f') then
            -- Clamp the value between 0.5 and 2.0
            if drep.config.uiScale[1] < 0.5 then
                drep.config.uiScale[1] = 0.5
            elseif drep.config.uiScale[1] > 2.0 then
                drep.config.uiScale[1] = 2.0
            end
            settings.save()
        end
        imgui.Separator()

        -- Dagger
        utils.labeledInput('Dagger', '##Dagger', drep.config.daggerItem)
        if utils.coloredButton('Equip', 'EquipDagger') then
            utils.weapon(drep.config.daggerItem[1], 'Dagger', 'EquipDagger')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Cyclone', 'Cyclone') then
            utils.weaponskill('Cyclone', 'Cyclone')
        end
        imgui.SameLine()
        if utils.coloredButton('Energy Drain', 'EnergyDrain') then
            utils.weaponskill('Energy Drain', 'EnergyDrain')
        end

        imgui.Separator()

        -- Sword
        utils.labeledInput('Sword', '##Sword', drep.config.swordItem)
        if utils.coloredButton('Equip', 'EquipSword') then
            utils.weapon(drep.config.swordItem[1], 'Sword', 'EquipSword')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Red Lotus Blade', 'RedLotusBlade') then
            utils.weaponskill('Red Lotus Blade', 'RedLotusBlade')
        end
        imgui.SameLine()
        if utils.coloredButton('Seraph Blade', 'SeraphBlade') then
            utils.weaponskill('Seraph Blade', 'SeraphBlade')
        end

        imgui.Separator()

        -- Great Sword
        utils.labeledInput('Great Sword', '##GreatSword', drep.config.greatSwordItem)
        if utils.coloredButton('Equip', 'EquipGreatSword') then
            utils.weapon(drep.config.greatSwordItem[1], 'Great Sword', 'EquipGreatSword')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Freezebite', 'Freezebite') then
            utils.weaponskill('Freezebite', 'Freezebite')
        end

        imgui.Separator()

        -- Scythe
        utils.labeledInput('Scythe', '##Scythe', drep.config.scytheItem)
        if utils.coloredButton('Equip', 'EquipScythe') then
            utils.weapon(drep.config.scytheItem[1], 'Scythe', 'EquipScythe')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Shadow of Death', 'ShadowOfDeath') then
            utils.weaponskill('Shadow of Death', 'ShadowOfDeath')
        end

        imgui.Separator()

        -- Polearm
        utils.labeledInput('Polearm', '##Polearm', drep.config.polearmItem)
        if utils.coloredButton('Equip', 'EquipPolearm') then
            utils.weapon(drep.config.polearmItem[1], 'Polearm', 'EquipPolearm')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Raiden Thrust', 'RaidenThrust') then
            utils.weaponskill('Raiden Thrust', 'RaidenThrust')
        end

        imgui.Separator()

        -- Katana
        utils.labeledInput('Katana', '##Katana', drep.config.katanaItem)
        if utils.coloredButton('Equip', 'EquipKatana') then
            utils.weapon(drep.config.katanaItem[1], 'Katana', 'EquipKatana')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Blade: Ei', 'BladeEi') then
            utils.weaponskill('Blade: Ei', 'BladeEi')
        end

        imgui.Separator()

        -- Great Katana
        utils.labeledInput('Great Katana', '##GreatKatana', drep.config.greatKatanaItem)
        if utils.coloredButton('Equip', 'EquipGreatKatana') then
            utils.weapon(drep.config.greatKatanaItem[1], 'Great Katana', 'EquipGreatKatana')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Tachi: Jinpu', 'TachiJinpu') then
            utils.weaponskill('Tachi: Jinpu', 'TachiJinpu')
        end
        imgui.SameLine()
        if utils.coloredButton('Tachi: Koki', 'TachiKoki') then
            utils.weaponskill('Tachi: Koki', 'TachiKoki')
        end

        imgui.Separator()

        -- Club
        utils.labeledInput('Club', '##Club', drep.config.clubItem)
        if utils.coloredButton('Equip', 'EquipClub') then
            utils.weapon(drep.config.clubItem[1], 'Club', 'EquipClub')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Seraph Strike', 'SeraphStrike') then
            utils.weaponskill('Seraph Strike', 'SeraphStrike')
        end

        imgui.Separator()

        -- Staff
        utils.labeledInput('Staff', '##Staff', drep.config.staffItem)
        if utils.coloredButton('Equip', 'EquipStaff') then
            utils.weapon(drep.config.staffItem[1], 'Staff', 'EquipStaff')
        end
        imgui.SameLine()
        imgui.Dummy({ 0, 0 })
        imgui.SameLine()
        if utils.coloredButton('Earth Crusher', 'EarthCrusher') then
            utils.weaponskill('Earth Crusher', 'EarthCrusher')
        end
        imgui.SameLine()
        if utils.coloredButton('Sunburst', 'Sunburst') then
            utils.weaponskill('Sunburst', 'Sunburst')
        end

        imgui.Separator()

        -- Main Equipment
        utils.labeledInput('Main', '##MainItem', drep.config.mainItem)
        
        -- Sub Equipment  
        utils.labeledInput('Sub', '##SubItem', drep.config.subItem)
        
        -- Equip button for Main/Sub
        if utils.coloredButton('Equip', 'EquipMainSub') then
            if drep.config.mainItem[1] and drep.config.mainItem[1] ~= '' then
                utils.equipMain(drep.config.mainItem[1], 'EquipMain')
            end
            if drep.config.subItem[1] and drep.config.subItem[1] ~= '' then
                -- Add a small delay for sub equip to avoid conflicts
                ashita.tasks.once(0.5, function()
                    utils.equipSub(drep.config.subItem[1], 'EquipSub')
                end)
            end
        end

        imgui.End()
    end
    
    -- Reset style vars
    imgui.PopStyleVar(2)
end

function ui.update()
    local now = os.clock()

    for mobId, busyUntil in pairs(utils.mobActionState) do
        if busyUntil <= now then
            utils.mobActionState[mobId] = nil
            targetStatus = mobStatus.normal
        end
    end

    local targetId = utils.getTarget()
    if not targetId or targetId == 0 then
        targetStatus = mobStatus.normal
    end

    if utils.mobActionState[targetId] and utils.mobActionState[targetId] < now then
        targetStatus = mobStatus.normal
    end

    if drep.prevTargetHP == -1 or drep.prevTargetID == -1 or utils.getTarget() ~= drep.prevTargetID then
        currentWeapon = 'Unknown'
        lastWeaponSkill = 'None'
        utils.resetClickedButtons()
    end

    -- Safely get equipped weapon with error handling for zoning
    local itemId, bag = utils.getEquippedItemId(0)

    if itemId ~= nil and itemId ~= 0 then
        local resMgr = AshitaCore:GetResourceManager()
        if resMgr then
            local item = resMgr:GetItemById(itemId)
            if item ~= nil and item.Name ~= nil and item.Name[1] ~= nil then
                currentWeapon = item.Name[1]
            end
        end
    end

    if not drep.visible[1] then
        return
    end

    ui.drawUI()
end

return ui
