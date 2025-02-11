local utils, config, language
local lightBowgun, heavyBowgun, bow
local data = {
    title = "miscellaneous",
    consumables = {
        items = false,
        endemic_life = false
    },
    sharpness_level = -1,
    old_sharpness_level = -1,
    ammo_and_coatings = {
        unlimited_ammo = false,
        unlimited_coatings = false,
        auto_reload = false, -- Drawn here, but no hook
        no_deviation = false
    },
    wirebugs = {
        unlimited_ooc = false,
        unlimited = false,
        give_3 = false,
        unlimited_powerup = false
    },
    canteen = {
        dango_100_no_ticket = false,
        dango_100_ticket = false,
        managed_dango_100 = nil,
        level_4 = false
    },
    data = {
        sharpness_level_old = -1,
        level_4_was_enabled = false
    }
}

function data.init()
    utils = require("Buffer.Misc.Utils")
    config = require("Buffer.Misc.Config")
    language = require("Buffer.Misc.Language")
    lightBowgun = require("Buffer.Modules.LightBowgun")
    heavyBowgun = require("Buffer.Modules.HeavyBowgun")
    bow = require("Buffer.Modules.Bow")

    data.init_hooks()
end

function data.init_hooks()
    sdk.hook(sdk.find_type_definition("snow.data.ItemSlider"):get_method("notifyConsumeItem(snow.data.ContentsIdSystem.ItemId, System.Boolean)"), function(args)
        local item_id = sdk.to_int64(args[3])
        -- Marionette Spider = 69206037
        -- Ec Item = 69206016 - 69206040
        if data.consumables.endemic_life and ((item_id >= 69206016 and item_id <= 69206040) or (item_id == 69206037)) then
            if item_id == 69206037 then -- Needs to be reset otherwise it will be stuck in the "consumed" state
                local creature_manager = sdk.get_managed_singleton("snow.envCreature.EnvironmentCreatureManager")
                local playerBase = utils.getPlayerBase()
                creature_manager:call("setEc057UseCount", playerBase:get_field("_PlayerIndex"), 0)
            end
            return sdk.PreHookResult.SKIP_ORIGINAL
        elseif data.consumables.items and not ((item_id >= 69206016 and item_id <= 69206040) or (item_id == 69206037)) then
            return sdk.PreHookResult.SKIP_ORIGINAL
        end

    end, utils.nothing())

    sdk.hook(sdk.find_type_definition("snow.player.PlayerManager"):get_method("update"), function(args)
        local playerBase = utils.getPlayerBase()
        if not playerBase then return end

        if data.sharpness_level > -1 then
            if data.data.sharpness_level_old == -1 then data.data.sharpness_level_old = playerBase:get_field("<SharpnessLv>k__BackingField") end
            -- | 0=Red | 1=Orange | 2=Yellow | 3=Green | 4=Blue | 5=White | 6=Purple |
            playerBase:set_field("<SharpnessLv>k__BackingField", data.sharpness_level) -- Sharpness Level of Purple
            -- playerBase:set_field("<SharpnessGauge>k__BackingField", 400) -- Sharpness Value
            -- playerBase:set_field("<SharpnessGaugeMax>k__BackingField", 400) -- Max Sharpness
        elseif data.sharpness_level == -1 and data.data.sharpness_level_old > -1 then
            playerBase:set_field("<SharpnessLv>k__BackingField", data.data.sharpness_level_old)
            data.data.sharpness_level_old = -1
        end

        if data.wirebugs.give_3 then
            playerBase:set_field("<HunterWireWildNum>k__BackingField", 1)
            playerBase:set_field("_HunterWireNumAddTime", 7000)
        end

        if data.wirebugs.unlimited_powerup then
            local playerData = utils.getPlayerData()
            if not playerData then return end
            playerData:set_field("_WireBugPowerUpTimer", 10700)
        end

    end, utils.nothing())

    sdk.hook(sdk.find_type_definition("snow.data.bulletSlider.BottleSliderFunc"):get_method("consumeItem"), function(args)
        if data.ammo_and_coatings.unlimited_coatings then return sdk.PreHookResult.SKIP_ORIGINAL end
    end, utils.nothing())

    sdk.hook(sdk.find_type_definition("snow.data.bulletSlider.BulletSliderFunc"):get_method("consumeItem"), function(args)
        if data.ammo_and_coatings.unlimited_ammo then return sdk.PreHookResult.SKIP_ORIGINAL end
    end, utils.nothing())

    local managed_fluctuation = nil
    sdk.hook(sdk.find_type_definition("snow.data.BulletWeaponData"):get_method("get_Fluctuation"), function(args)
        local managed = sdk.to_managed_object(args[2])
        if not managed then return end
        if not managed:get_type_definition():is_a("snow.data.BulletWeaponData") then return end
        managed_fluctuation = true
    end, function(retval)
        if managed_fluctuation ~= nil then
            managed_fluctuation = nil
            if data.ammo_and_coatings.no_deviation then return 0 end
        end
        return retval
    end)

    sdk.hook(sdk.find_type_definition("snow.player.fsm.PlayerFsm2ActionHunterWire"):get_method("start"), utils.nothing(), function(retval)
        if (data.wirebugs.unlimited_ooc and not utils.checkIfInBattle()) or data.wirebugs.unlimited then
            local playerBase = utils.getPlayerBase()
            if not playerBase then return end

            local wireGuages = playerBase:get_field("_HunterWireGauge")
            if not wireGuages then return end

            wireGuages = wireGuages:get_elements()
            for i, gauge in ipairs(wireGuages) do
                gauge:set_field("_RecastTimer", 0)
                gauge:set_field("_RecoverWaitTimer", 0)
            end
        end
    end)

    local managed_dango, managed_dango_chance = nil, nil
    sdk.hook(sdk.find_type_definition("snow.data.DangoData"):get_method("get_SkillActiveRate"), function(args)
        if data.canteen.dango_100_no_ticket or data.canteen.dango_100_ticket then
            local managed = sdk.to_managed_object(args[2])
            if not managed then return end
            if not managed:get_type_definition():is_a("snow.data.DangoData") then return end

            local isUsingTicket = utils.getMealFunc():call("getMealTicketFlag")

            if isUsingTicket or data.canteen.dango_100_no_ticket then
                managed_dango = managed
                managed_dango_chance = managed:get_field("_Param"):get_field("_SkillActiveRate")
                managed:get_field("_Param"):set_field("_SkillActiveRate", 200)
                return sdk.PreHookResult.SKIP_ORIGINAL
            end
        end
    end, function(retval)
        -- Restore the original value
        if (data.canteen.dango_100_no_ticket or data.canteen.dango_100_ticket) and managed_dango then
            managed_dango:get_field("_Param"):set_field("_SkillActiveRate", managed_dango_chance)
            managed_dango = nil
            managed_dango_chance = nil
        end
        return retval
    end)

    sdk.hook(sdk.find_type_definition("snow.facility.kitchen.MealFunc"):get_method("updateList"), function(args)
        if data.canteen.level_4 and not data.data.level_4_wasEnabled then
            data.data.level_4_wasEnabled = true
            local dangoLevels = utils.getMealFunc():get_field("SpecialSkewerDangoLv")
            local level4 = sdk.create_instance("System.UInt32")
            level4:set_field("mValue", 4)
            for i = 0, 2 do dangoLevels[i] = level4 end

        elseif not data.canteen.level_4 and data.data.level_4_wasEnabled then
            data.data.level_4_wasEnabled = false
            local dangoLevels = utils.getMealFunc():get_field("SpecialSkewerDangoLv")

            for i = 0, 2 do
                local level = sdk.create_instance("System.UInt32")
                level:set_field("mValue", i == 0 and 4 or i == 1 and 3 or 1) -- lua version of i == 0 ? 4 : i == 1 ? 3 : 1
                dangoLevels[i] = level
            end
        end
    end, utils.nothing())

end

function data.draw()

    local changed, any_changed = false, false
    local languagePrefix = data.title .. "."

    if imgui.collapsing_header(language.get(languagePrefix .. "title")) then
        imgui.indent(10)

        languagePrefix = data.title .. ".sharpness_levels."
        local sharpness_display = {language.get(languagePrefix .. "disabled"), language.get(languagePrefix .. "red"), language.get(languagePrefix .. "orange"),
                                   language.get(languagePrefix .. "yellow"), language.get(languagePrefix .. "green"), language.get(languagePrefix .. "blue"),
                                   language.get(languagePrefix .. "white"), language.get(languagePrefix .. "purple")}

        local languagePrefix = data.title .. "."
        changed, data.sharpness_level =
            imgui.slider_int(language.get(languagePrefix .. "sharpness_level"), data.sharpness_level, -1, 6, sharpness_display[data.sharpness_level + 2])
        utils.tooltip(language.get(languagePrefix .. "sharpness_level_tooltip"))
        any_changed = any_changed or changed
        languagePrefix = data.title .. ".consumables."
        if imgui.tree_node(language.get(languagePrefix .. "title")) then
            changed, data.consumables.items = imgui.checkbox(language.get(languagePrefix .. "items"), data.consumables.items)
            any_changed = any_changed or changed
            changed, data.consumables.endemic_life = imgui.checkbox(language.get(languagePrefix .. "endemic_life"), data.consumables.endemic_life)
            any_changed = any_changed or changed
            imgui.tree_pop()
        end
        languagePrefix = data.title .. ".ammo_and_coatings."
        if imgui.tree_node(language.get(languagePrefix .. "title")) then
            changed, data.ammo_and_coatings.unlimited_coatings = imgui.checkbox(language.get(languagePrefix .. "unlimited_coatings"), data.ammo_and_coatings.unlimited_coatings)
            any_changed = any_changed or changed
            changed, data.ammo_and_coatings.unlimited_ammo = imgui.checkbox(language.get(languagePrefix .. "unlimited_ammo"), data.ammo_and_coatings.unlimited_ammo)
            any_changed = any_changed or changed
            changed, data.ammo_and_coatings.auto_reload = imgui.checkbox(language.get(languagePrefix .. "auto_reload"), data.ammo_and_coatings.auto_reload)
            any_changed = any_changed or changed
            changed, data.ammo_and_coatings.no_deviation = imgui.checkbox(language.get(languagePrefix .. "no_deviation"), data.ammo_and_coatings.no_deviation)
            any_changed = any_changed or changed
            imgui.tree_pop()
        end
        languagePrefix = data.title .. ".wirebugs."
        if imgui.tree_node(language.get(languagePrefix .. "title")) then
            changed, data.wirebugs.unlimited_ooc = imgui.checkbox(language.get(languagePrefix .. "unlimited_ooc"), data.wirebugs.unlimited_ooc)
            any_changed = any_changed or changed
            changed, data.wirebugs.unlimited = imgui.checkbox(language.get(languagePrefix .. "unlimited"), data.wirebugs.unlimited)
            any_changed = any_changed or changed
            changed, data.wirebugs.give_3 = imgui.checkbox(language.get(languagePrefix .. "give_3"), data.wirebugs.give_3)
            any_changed = any_changed or changed
            changed, data.wirebugs.unlimited_powerup = imgui.checkbox(language.get(languagePrefix .. "unlimited_powerup"), data.wirebugs.unlimited_powerup)
            utils.tooltip(language.get(languagePrefix .. "unlimited_powerup_tooltip"))
            any_changed = any_changed or changed
            imgui.tree_pop()
        end
        languagePrefix = data.title .. ".canteen."
        if imgui.tree_node(language.get(languagePrefix .. "title")) then
            changed, data.canteen.dango_100_no_ticket = imgui.checkbox(language.get(languagePrefix .. "dango_100_no_ticket"), data.canteen.dango_100_no_ticket)
            any_changed = any_changed or changed
            changed, data.canteen.dango_100_ticket = imgui.checkbox(language.get(languagePrefix .. "dango_100_ticket"), data.canteen.dango_100_ticket)
            any_changed = any_changed or changed
            changed, data.canteen.level_4 = imgui.checkbox(language.get(languagePrefix .. "level_4"), data.canteen.level_4)
            utils.tooltip(language.get(languagePrefix .. "level_4_tooltip"))
            any_changed = any_changed or changed
            imgui.tree_pop()
        end

        if any_changed then config.save_section(data.create_config_section()) end
        imgui.unindent(10)
        imgui.separator()
        imgui.spacing()
    end
end

function data.create_config_section()
    return {
        [data.title] = {
            consumables = data.consumables,
            sharpness_level = data.sharpness_level,
            ammo_and_coatings = data.ammo_and_coatings,
            wirebugs = data.wirebugs,
            canteen = data.canteen
        }
    }
end

function data.load_from_config(config_section)
    if not config_section then return end

    data.consumables = config_section.consumables or data.consumables
    data.sharpness_level = config_section.sharpness_level or data.sharpness_level
    data.ammo_and_coatings = config_section.ammo_and_coatings or data.ammo_and_coatings
    data.wirebugs = config_section.wirebugs or data.wirebugs
    data.canteen = config_section.canteen or data.canteen

    -- Old config format helper
    if config_section.unlimited_consumables then
        data.consumables.items = config_section.unlimited_consumables
        data.consumables.endemic_life = config_section.unlimited_consumables
    end

end

return data
