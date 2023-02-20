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
    ["enableCustomSteering"]          = true,
    ["logData"]                       = false,
    ["steeringSpeed"]                 = 1.0,
    ["relativeSteeringSpeed"]         = true,
    ["steeringLimitOffset"]           = 0.0,
    ["countersteerLimitOffset"]       = 5.0,
    ["counterForce.useSteeredWheels"] = true,
    ["counterForce.response"]         = 0.2,
    ["counterForce.maxAngle"]         = 8.0,
    ["counterForce.inputAuthority"]   = 0.7,
    ["counterForce.damping"]          = 0.7,
}

local steeringCfg = mergeObjects(defaultConfig, {})

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
        steeringCfg = mergeObjects(defaultConfig, decoded)
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