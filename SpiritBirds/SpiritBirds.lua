-- Sprit Bird types w/ index for EnvironmentCreatureManager#_EcPrefabList.mItems
local SPIRIT_BIRDS = {
    atk = 11,
    def = 12,
    hp = 13,
    spd = 14,
    all = 15,
    gold = 31
}
local autospawn = {
    enabled = true,
    spawned = false
}
local isWindowOpen, wasOpen = false, false

local spawnedBirds = {}

local configPath = "SpiritBirds.json"

-- Load the config
local function loadConfig()
    if json ~= nil then
        local file = json.load_file(configPath)
        if file then
            autospawn.enabled = file.autospawn
            isWindowOpen = file.isWindowOpen
        end
    end
end
loadConfig()

-- Save the config
local function saveConfig()
    json.dump_file(configPath, {
        autospawn = autospawn.enabled,
        isWindowOpen = isWindowOpen
    })
end

-- Get the player
local function getPlayer()
    local player = sdk.get_managed_singleton("snow.player.PlayerManager"):call("findMasterPlayer")
    if not player then return end
    player = player:call("get_GameObject")
    return player
end

-- Get the player's location
local function getPlayerLocation()
    local player = getPlayer()
    if not player then return end
    local location = player:call("get_Transform"):call("get_Position")
    if not location then return end
    return location
end

-- Get Creature Manager
local function getEnvCreatureManager()
    local envCreature = sdk.get_managed_singleton("snow.envCreature.EnvironmentCreatureManager")
    if not envCreature then return end
    return envCreature
end

-- Get Quest State [ 0 = Lobby, 1 = Ready/Loading, 2 = Quest, 3 = End, 5 = Abandoned, 7 = Returned ]
local function getQuestStatus()
    local questManager = sdk.get_managed_singleton("snow.QuestManager")
    if not questManager then return end
    return questManager:get_field("_QuestStatus")
end

-- Function to get length of table
local function getLength(obj)
    local count = 0
    for _ in pairs(obj) do count = count + 1 end
    return count
end

-- Spawn the bird
local function spawnBird(type)
    local envCreature = getEnvCreatureManager()
    local location = getPlayerLocation()

    -- Create the bird
    local ecList = envCreature:get_field("_EcPrefabList"):get_field("mItems"):get_elements()
    local ecBird = ecList[SPIRIT_BIRDS[type]]
    if not ecBird:call("get_Standby") then ecBird:call("set_Standby", true) end

    -- Set the bird as active
    local bird = ecBird:call("instantiate(via.vec3)", location)

    -- If the bird isn't managed, try spawning another (This prevents the having to spawn twice if bird doesn't exist in level)
    if not sdk.is_managed_object(bird) then
        spawnBird(type)
    else
        table.insert(spawnedBirds, bird)
    end
end

-- Watch for Auto-Spawn of Prism and clear spawned birds after quest ends
re.on_pre_application_entry("UpdateBehavior", function()
    -- If Auto spawn is enabled and quest status says it's active
    if getQuestStatus() == 2 and autospawn.enabled and not autospawn.spawned then
        if not autospawn.spawned then
            spawnBird("all")
            -- If you want to change the the mod to spawn in 5 birds of a different type, just replace the line above with one of the following
            -- for i = 0, 5 do     spawnBird("hp")       end
            -- for i = 0, 5 do     spawnBird("atk")      end
            -- for i = 0, 5 do     spawnBird("def")      end
            -- I have no plans to add this as a feature so you can change it if you want
            autospawn.spawned = true
        end

        -- If the quest status is not active, clear the spawned birds, and set autospawned.spawned to false
    elseif getQuestStatus() ~= 2 and getLength(spawnedBirds) > 0 then
        autospawn.spawned = false
        for i, bird in pairs(spawnedBirds) do bird:call("destroy", bird) end
        spawnedBirds = {}
    end
end)

-- Remove any spawned birds on on script reset
re.on_script_reset(function()
    for i, bird in pairs(spawnedBirds) do bird:call("destroy", bird) end
    spawnedBirds = {}
end)

-- Draw a window to the REFramework Script Generated UI
re.on_draw_ui(function()
    if imgui.button("Toggle SpiritBird GUI") then
        isWindowOpen = not isWindowOpen
        saveConfig()
    end
    if isWindowOpen then
        wasOpen = true
        isWindowOpen = imgui.begin_window("Spawn SpiritBirds", isWindowOpen, 64)
        if imgui.button("   « Attack »    ") then spawnBird("atk") end
        imgui.same_line()
        if imgui.button("   « Defense »   ") then spawnBird("def") end
        if imgui.button("   « Health »    ") then spawnBird("hp") end
        imgui.same_line()
        if imgui.button("   « Stamina »   ") then spawnBird("spd") end
        if imgui.button("                 « Rainbow »                  ") then spawnBird("all") end
        if imgui.button("                  « Golden »                    ") then spawnBird("gold") end
        local changed = false
        changed, autospawn.enabled = imgui.checkbox("Auto-Spawn Prism", autospawn.enabled)
        if changed then saveConfig() end
        imgui.end_window()
    elseif wasOpen then
        wasOpen = false
        saveConfig()
    end
end)
