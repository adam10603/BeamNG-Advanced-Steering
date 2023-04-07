local M = {}

local logTag           = "arcadeSteeringGE"
local settingsFilePath = "settings/arcadeSteering/settings.json"

-- Returns a new object by merging `obj` into `ref`
local function mergeObjects(ref, obj)
    local ret = {}
    for i,v in pairs(ref) do
        if obj[i] ~= nil then
            ret[i] = obj[i]
        else
            ret[i] = ref[i]
        end
    end
    return ret
end

local defaultConfig = {
    ["_version"]                      = 250, -- This is used for detecting and migrating saved configs from older versions. This doesn't necessarily match the mod version, it's only updated when config compatibility is changed.
    ["enableCustomSteering"]          = true,
    ["logData"]                       = false,
    ["steeringSpeed"]                 = 1.0,
    ["relativeSteeringSpeed"]         = true,
    ["steeringLimitOffset"]           = 0.0,
    ["countersteerLimitOffset"]       = 5.0,
    ["counterForce.useSteeredWheels"] = true,
    ["counterForce.response"]         = 0.4,
    ["counterForce.maxAngle"]         = 8.0,
    ["counterForce.inputAuthority"]   = 0.7,
    ["counterForce.damping"]          = 0.7,
}

local steeringCfg = mergeObjects(defaultConfig, {})

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- These functions are responsible for migrating saved configs from older versions to be compatible with the current version
local configMigration = {
    [250] = function(cfg)
        cfg["counterForce.response"] = clamp01(math.floor(cfg["counterForce.response"] * 2.0 * 100.0 + 0.5) / 100.0)
        -- cfg["counterForce.damping"]  = clamp01(math.floor(cfg["counterForce.damping"] * 0.85 * 100.0 + 0.5) / 100.0)

        cfg["_version"] = 250
    end
}

local function execOnAllVehicles(command)
    local vehicles = getAllVehicles()
    for k,v in pairs(vehicles) do
        vehicles[k]:queueLuaCommand(command)
    end
end

local function applySettingsToVehicles(cfg)
    execOnAllVehicles('arcadeSteering.setConfig(' .. serialize(cfg) .. ')')
end

local function saveSettings(jsonStr, silent)
    -- if M.disableArcadeSteering then return end

    if jsonStr then
        -- If settings are passed in, save those
        local decoded = jsonDecode(jsonStr)
        if decoded then
            steeringCfg = mergeObjects(defaultConfig, decoded)
            local saved = jsonWriteFile(settingsFilePath, steeringCfg, true)
            if not silent then guihooks.trigger("arcadeSteeringSettingsSaved", saved) end
        elseif not silent then
             guihooks.trigger("arcadeSteeringSettingsSaved", false)
        end
    else
        -- If nothing is specified, save the current settings
        local saved = jsonWriteFile(settingsFilePath, mergeObjects(defaultConfig, steeringCfg), true)
        if not silent then guihooks.trigger("arcadeSteeringSettingsSaved", saved) end
    end

    applySettingsToVehicles({["enableCustomSteering"] = steeringCfg["enableCustomSteering"]})
end

local function loadSettings()
    -- if M.disableArcadeSteering then return end

    local decoded = jsonReadFile(settingsFilePath)

    if not decoded then
        log("W", logTag, "Failed to load Arcade Steering settings. Creating config file with the default settings ...")
        steeringCfg = mergeObjects(defaultConfig, {})
        saveSettings(nil, true)
    else
        if not decoded["_version"] then
            decoded["_version"] = 0
        end

        steeringCfg = mergeObjects(defaultConfig, decoded)

        -- Checking if config migration is needed
        if steeringCfg["_version"] < defaultConfig["_version"] then
            -- Sorting the the version numbers of migration functions so they are executed in order
            local versions = {}
            for version, _ in pairs(configMigration) do
                table.insert(versions, version)
            end
            table.sort(versions)

            -- Migrating the config through as many versions as needed
            for _, version in pairs(versions) do
                if steeringCfg["_version"] < version then
                    configMigration[version](steeringCfg)
                end
            end

            -- Saving the config with the updated version number
            saveSettings(nil, true)
        end
    end
end

local function displayDefaultSettings()
    -- if M.disableArcadeSteering then return end
    guihooks.trigger("arcadeSteeringSetDisplayedSettings", { ["settings"] = defaultConfig, ["isDefault"] = true })
end

local function displayCurrentSettings()
    -- if M.disableArcadeSteering then return end
    guihooks.trigger("arcadeSteeringSetDisplayedSettings", { ["settings"] = steeringCfg })
end

local function applySettings(jsonStr)
    -- if M.disableArcadeSteering then return end
    local decoded = jsonDecode(jsonStr)
    if decoded then
        -- steeringCfg = decoded
        applySettingsToVehicles(mergeObjects(decoded, { ["enableCustomSteering"] = steeringCfg["enableCustomSteering"] }))
    end
    guihooks.trigger("arcadeSteeringSettingsApplied", decoded and true or false)
end

M.displayDefaultSettings = displayDefaultSettings
M.displayCurrentSettings = displayCurrentSettings
M.applySettings          = applySettings
M.saveSettings           = saveSettings
-- M.onVehicleSpawned       = function()
-- end

M.onVehicleSpawned = function ()
    applySettingsToVehicles(steeringCfg)
    displayCurrentSettings()
end
M.onExtensionLoaded = loadSettings

return M