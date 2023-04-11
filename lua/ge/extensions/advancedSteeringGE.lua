local M = {}

local logTag              = "AdvancedSteeringGE"
local settingsFilePath    = "settings/advancedSteering/settings.json"
local oldSettingsFilePath = "settings/arcadeSteering/settings.json"
local oldSettingsDir      = "settings/arcadeSteering"

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
    ["steeringSpeed"]                 = 1.2,
    ["relativeSteeringSpeed"]         = true,
    ["steeringLimitOffset"]           = 0.0,
    ["countersteerLimitOffset"]       = 4.0,
    ["photoMode"]                     = false,
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
    execOnAllVehicles("advancedSteering.setConfig(" .. serialize(cfg) .. ")")
end

local function applyLegacySettingsToVehicles(cfg)
    execOnAllVehicles("arcadeSteering.setConfig(" .. serialize(cfg) .. ")")
end

local function saveSettings(jsonStr, silent)
    if jsonStr then
        -- If settings are passed in, save those
        local decoded = jsonDecode(jsonStr)
        if decoded then
            steeringCfg = mergeObjects(defaultConfig, decoded)
            local saved = jsonWriteFile(settingsFilePath, steeringCfg, true)
            if not silent then guihooks.trigger("advancedSteeringSettingsSaved", saved) end
        elseif not silent then
             guihooks.trigger("advancedSteeringSettingsSaved", false)
        end
    else
        -- If nothing is specified, save the current settings
        local saved = jsonWriteFile(settingsFilePath, mergeObjects(defaultConfig, steeringCfg), true)
        if not silent then guihooks.trigger("advancedSteeringSettingsSaved", saved) end
    end

    applySettingsToVehicles({["enableCustomSteering"] = steeringCfg["enableCustomSteering"]})
end

local function performConfigMigration(cfg)
    -- Sorting the the version numbers of migration functions so they are executed in order
    local versions = {}
    for version, _ in pairs(configMigration) do
        table.insert(versions, version)
    end
    table.sort(versions)

    -- Migrating the config through as many versions as needed
    for _, version in pairs(versions) do
        if cfg["_version"] < version then
            configMigration[version](cfg)
        end
    end
end

local function loadSettings(path)
    path = path or settingsFilePath

    local decoded = jsonReadFile(path)

    if not decoded then
        log("W", logTag, "Failed to load Advanced Steering settings. Creating config file with the default settings ...")
        steeringCfg = mergeObjects(defaultConfig, {})
        saveSettings(nil, true)
    else
        if not decoded["_version"] then
            decoded["_version"] = 0
        end

        steeringCfg = mergeObjects(defaultConfig, decoded)

        -- Checking if config migration is needed
        if steeringCfg["_version"] < defaultConfig["_version"] then
            performConfigMigration(steeringCfg)

            -- Saving the updated config
            saveSettings(nil, true)
        end
    end
end

local function displayDefaultSettings()
    guihooks.trigger("advancedSteeringSetDisplayedSettings", { ["settings"] = defaultConfig, ["isDefault"] = true })
end

local function displayCurrentSettings()
    guihooks.trigger("advancedSteeringSetDisplayedSettings", { ["settings"] = steeringCfg })
end

local function applySettings(jsonStr)
    local decoded = jsonDecode(jsonStr)
    if decoded then
        applySettingsToVehicles(mergeObjects(decoded, { ["enableCustomSteering"] = steeringCfg["enableCustomSteering"] }))
    end
    guihooks.trigger("advancedSteeringSettingsApplied", decoded and true or false)
end

M.displayDefaultSettings = displayDefaultSettings
M.displayCurrentSettings = displayCurrentSettings
M.applySettings          = applySettings
M.saveSettings           = saveSettings
-- M.onVehicleSpawned       = function()
-- end

local foundLegacyVersion = false

M.onVehicleSpawned = function ()
    applySettingsToVehicles(steeringCfg)

    -- Preparing for conflicts with the pre-rename version, just in case
    if foundLegacyVersion or arcadeSteeringGE then
        applyLegacySettingsToVehicles({["enableCustomSteering"] = false})
        guihooks.message("Please remove \"Arcade Steering\" from your mods folder and restart the game! \"Arcade Steering\" has been renamed to \"Advanced Steering\", but your game has both versions installed.", 30, logTag, "warning")
    end

    displayCurrentSettings()
end

M.onExtensionLoaded = function()
    -- Copying settings from the old config path to the new one, if necessary
    if FS:fileExists(oldSettingsFilePath) then
        loadSettings(oldSettingsFilePath)
        saveSettings(nil, true)
        FS:remove(oldSettingsDir)
    else
        loadSettings(settingsFilePath)
    end

    -- Preparing for conflicts with the pre-rename version, just in case
    if arcadeSteeringGE then
        foundLegacyVersion = true
        extensions.unload("arcadeSteeringGE")
    end
end

return M