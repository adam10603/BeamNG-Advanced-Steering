local M = {}

local logTag              = "AdvancedSteeringGE"
local settingsFilePath    = "settings/advancedSteering/settings.json"
local presetsDir          = "settings/advancedSteering/presets"
local shippedPresetsDir   = "/lua/ge/extensions/advancedSteeringPresetsShipped"
local oldSettingsFilePath = "settings/arcadeSteering/settings.json"
local oldSettingsDir      = "settings/arcadeSteering"

local presetList  = {} -- This is the list of presets that is sent to the UI app. It's an array where each entry contains a preset's name, ID, and read-only status.
local presetFiles = {} -- Stores the file names of each preset, mapped by preset IDs.

local referenceConfig = {
    ["_version"]                      = 260, -- This is used for detecting and migrating saved configs from older versions. This doesn't necessarily match the mod version, it's only updated when config compatibility is changed.
    ["enableCustomSteering"]          = true,
    ["logData"]                       = false,
    ["steeringSpeed"]                 = 1.2,
    ["inputAuthority"]                = 0.7,
    ["relativeSteeringSpeed"]         = true,
    ["steeringLimitOffset"]           = 0.0,
    ["countersteerLimitOffset"]       = 4.0,
    ["photoMode"]                     = false,
    ["counterForce.useSteeredWheels"] = true,
    ["counterForce.response"]         = 0.35,
    ["counterForce.maxAngle"]         = 8.0,
    ["counterForce.damping"]          = 0.5,
}

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

local steeringCfg = mergeObjects(referenceConfig, {})

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function round(x)
    return ((x < 0) and -1 or 1) * math.floor(math.abs(x) + 0.5)
end

-- These functions are responsible for migrating saved configs from older versions to be compatible with the current version
local configMigration = {
    [250] = function(cfg)
        local newResponse = cfg["counterForce.response"] * 2.0
        cfg["counterForce.response"] = clamp01(round(newResponse * 100.0) / 100.0)

        cfg["_version"] = 250
    end,

    [260] = function(cfg)
        local newResponse = cfg["counterForce.response"] * math.pow(cfg["counterForce.response"] * 0.9 + 0.1, 0.175) * 1.05 - 0.05
        cfg["counterForce.response"] = clamp01(round(newResponse * 100.0) / 100.0)

        cfg["inputAuthority"] = cfg["counterForce.inputAuthority"]
        cfg["counterForce.inputAuthority"] = nil

        cfg["_version"] = 260
    end
}

local function execOnAllVehicles(command)
    local vehicles = getAllVehicles()
    for k,v in pairs(vehicles) do
        vehicles[k]:queueLuaCommand(command)
    end
end

local function execOnVehicle(command, vehicle)
    vehicle:queueLuaCommand(command)
end

local function applySettingsToAllVehicles(cfg)
    execOnAllVehicles("advancedSteering.setConfig(" .. serialize(cfg) .. ")")
end

local function applySettingsToVehicle(cfg, vehicle)
    execOnVehicle("advancedSteering.setConfig(" .. serialize(cfg) .. ")", vehicle)
end

local function applyLegacySettingsToAllVehicles(cfg)
    execOnAllVehicles("arcadeSteering.setConfig(" .. serialize(cfg) .. ")")
end

local function saveSettingsInternal(obj, silent, path, preset)
    path = path or settingsFilePath

    if obj then
        -- If settings are passed in, save those
        local output = mergeObjects(referenceConfig, obj)
        local saved = jsonWriteFile(path, output, true)
        if not silent then
            guihooks.trigger(preset and "advancedSteeringPresetSaved" or "advancedSteeringSettingsSaved", saved)
        end
        if not preset then steeringCfg = output end
    end

    if not preset then applySettingsToAllVehicles({["enableCustomSteering"] = steeringCfg["enableCustomSteering"]}) end
end

local function getFileName(path)
    local name = path:match("^.+[\\/](.+)$")
    return name
end

local function getPresetName(fileName)
    local name = fileName:match("^(.+)%..+$"):gsub("^%d*_?", ""):gsub("[%s+_]", " ")
    return name
end

local function getPresetID(presetName)
    local id = presetName:lower():gsub("[^%w%s_]", ""):gsub("[%s+_]", "-")
    return id
end

local function isPresetReadOnly(fileName)
    local _, subCount = fileName:gsub("^%d*_", "")
    return subCount > 0
end

local function getFullPresetPath(fileName)
    return presetsDir .. "/" .. fileName
end

local function saveSettings(jsonStr, silent)
    if jsonStr then
        local decoded = jsonDecode(jsonStr)
        if decoded then
            saveSettingsInternal(decoded, silent)
        elseif not silent then
            guihooks.trigger("advancedSteeringSettingsSaved", false)
        end
    else
        saveSettingsInternal(steeringCfg, silent)
    end
end

local function savePreset(jsonStr, presetID, silent)
    local presetFileEntry = presetFiles[presetID]

    if not presetFileEntry or presetFileEntry.readOnly then
        if not silent then guihooks.trigger("advancedSteeringPresetSaved", false) end
        return
    end

    local decoded = jsonDecode(jsonStr)
    if decoded then
        saveSettingsInternal(decoded, silent, getFullPresetPath(presetFileEntry), true)
        return
    end

    if not silent then guihooks.trigger("advancedSteeringPresetSaved", false) end
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

local function loadSettings(path, dontCreateNew)
    path = (path or settingsFilePath)

    local decoded = jsonReadFile(path)

    local ret = nil

    if not decoded then
        if not dontCreateNew then
            ret = mergeObjects(referenceConfig, {})
            log("W", logTag, "Failed to load Advanced Steering settings. Creating config file with the default settings ...")
            saveSettingsInternal(ret, true, path)
        else
            log("W", logTag, "Failed to load the requested Advanced Steering config file: " .. path)
        end
    else
        if not decoded["_version"] then
            decoded["_version"] = 0
        end

        local saveRequired = false

        -- Checking if config migration is needed
        if decoded["_version"] < referenceConfig["_version"] then
            performConfigMigration(decoded)

            saveRequired = true
        end

        ret = mergeObjects(referenceConfig, decoded)

        if saveRequired then saveSettingsInternal(ret, true, path) end
    end

    return ret
end

local function ensurePresetsDir()
    if not FS:directoryExists(presetsDir) then
        FS:directoryCreate(presetsDir)
    end

    local paths = FS:findFiles(shippedPresetsDir, "*.json", 0)
    if type(paths) == "table" and #paths > 0 then
        for _, filePath in ipairs(paths) do
            local fileName = getFileName(filePath)
            local presetPath = getFullPresetPath(fileName)
            if not FS:fileExists(presetPath) or isPresetReadOnly(fileName) then
                FS:copyFile(filePath, presetPath)
            end
        end
    else
        log("E", logTag, "Failed to load the default set of presets")
    end
end

local function migrateAllPresets()
    for k, v in pairs(presetFiles) do
        loadSettings(getFullPresetPath(v), true) -- Loading each preset will perform migration
    end
end

local function refreshPresetList()
    local paths = FS:findFiles(presetsDir, "*.json", 0)
    if type(paths) == "table" and #paths > 0 then
        local tmpList  = {}
        local tmpFiles = {}

        for _, filePath in ipairs(paths) do
            local fileName   = getFileName(filePath)
            local presetName = getPresetName(fileName)
            local readOnly   = isPresetReadOnly(fileName)
            local presetID   = getPresetID(presetName)

            table.insert(tmpList, {
                ["ID"]       = presetID,
                ["name"]     = presetName,
                ["readOnly"] = readOnly
            })

            tmpFiles[presetID] = fileName
        end

        presetFiles = tmpFiles
        presetList  = tmpList
    else
        log("E", logTag, "Failed to load the default set of presets")
    end
end

local function applySettings(jsonStr)
    local decoded = jsonDecode(jsonStr)
    if decoded then
        applySettingsToAllVehicles(mergeObjects(decoded, { ["enableCustomSteering"] = steeringCfg["enableCustomSteering"] }))
    end
    guihooks.trigger("advancedSteeringSettingsApplied", decoded and true or false)
end

local function displayCurrentSettings()
    guihooks.trigger("advancedSteeringSetDisplayedSettings", { ["settings"] = steeringCfg, ["saved"] = true })
end

local function displayPresetList()
    guihooks.trigger("advancedSteeringDisplayPresetList", presetList)
end

local function displayPreset(presetID)
    local presetCfg = loadSettings(getFullPresetPath(presetFiles[presetID]), true)
    guihooks.trigger("advancedSteeringSetDisplayedSettings", { ["settings"] = presetCfg, ["preset"] = true })
end

M.displayCurrentSettings = displayCurrentSettings
M.applySettings          = applySettings
M.saveSettings           = saveSettings
M.displayPresetList      = displayPresetList
M.displayPreset          = displayPreset
M.refreshPresetList      = refreshPresetList
M.savePreset             = savePreset

local foundLegacyVersion = false

M.onVehicleSpawned = function (vehicleID)
    applySettingsToVehicle(steeringCfg, be:getObjectByID(vehicleID))

    -- Preparing for conflicts with the pre-rename version, just in case
    if foundLegacyVersion or arcadeSteeringGE then
        if arcadeSteeringGE and arcadeSteeringGE.onVehicleSpawned then
            arcadeSteeringGE.onVehicleSpawned = function() end
        end
        applyLegacySettingsToAllVehicles({["enableCustomSteering"] = false})
        guihooks.message("Please remove \"Arcade Steering\" from your mods folder (if present) and restart the game! \"Arcade Steering\" has been renamed to \"Advanced Steering\", but your game currently has both versions loaded.", 30, logTag, "warning")
    end

    displayCurrentSettings()

    -- refreshPresetList()
    displayPresetList()
end

M.onExtensionLoaded = function()
    -- Copying settings from the old config path to the new one, if necessary
    if FS:fileExists(oldSettingsFilePath) then
        steeringCfg = loadSettings(oldSettingsFilePath)
        saveSettingsInternal(steeringCfg, true)
        FS:remove(oldSettingsDir)
    else
        steeringCfg = loadSettings(settingsFilePath)
    end

    ensurePresetsDir()
    refreshPresetList()
    migrateAllPresets()

    -- Preparing for conflicts with the pre-rename version, just in case
    if arcadeSteeringGE then
        foundLegacyVersion = true
        extensions.unload("arcadeSteeringGE")
    end
end

return M