local M = {}
M.state = {}
local logTag = "arcadeSteering"

-- =================== Helpers

-- Returns the sum of all elements in the array `t`, and the number of elements that were summed.
-- The returned sum can be `nil` if it can't be calculated.
-- If `extractor` is provided, the return value of `extractor(element)` will be used in place of each array element.
-- If `extractor(element)` returns `nil`, the element is skipped and the returned sum and count will reflect this.
local function sum(t, extractor)
    extractor = extractor or function(val) return val end

    if #t == 0 then
        return nil
    end

    local acc = nil
    local count = 0

    for _, tVal in ipairs(t) do
        local transformed = extractor(tVal)
        if transformed ~= nil then
            count = count + 1
            if acc == nil then
                acc = transformed
            else
                acc = acc + transformed
            end
        end
    end

    return acc, count
end

-- Returns the average of all elements in the array `t`, or `nil` if the value can't be calculated.
-- If `extractor` is provided, the return value of `extractor(element)` will be used in place of each array element.
-- If `extractor(element)` returns `nil`, the element is skipped.
local function average(t, extractor)
    local dataSum, sumCount = sum(t, extractor)
    return (dataSum ~= nil and sumCount > 0) and (dataSum / sumCount) or nil
end

-- Determines if the array `t` contains the value `val`.
local function contains(t, val)
    for i, tVal in ipairs(t) do
        if tVal == val then
            return true
        end
    end
    return false
end

-- Returns an array with only the elements of the array `t` that satisfy `pred(element)`.
local function filter(t, pred)
    local ret = {}
    for _, tVal in ipairs(t) do
        if pred(tVal) then
            table.insert(ret, tVal)
        end
    end
    return ret
end

-- Returns an array such that each element is equal to `fn(element)` of the corresponding element in the array `t`.
local function transform(t, fn)
    local ret = {}
    for i, tVal in ipairs(t) do
        ret[i] = fn(tVal)
    end
    return ret
end

-- Counts how many elements of the array `t` satisfy `pred(element)`.
local function countIf(t, pred)
    local ret = 0
    if not t then
        return ret
    end
    for _, tVal in ipairs(t) do
        if pred(tVal) then
            ret = ret + 1
        end
    end
    return ret
end

-- Indicates if any element of the array `t` satisfies `pred(element)`.
local function any(t, pred)
    if not t then
        return false
    end
    for _, tVal in ipairs(t) do
        if pred(tVal) then
            return true
        end
    end
    return false
end

-- Determines if `val` is between `A` and `B` (inclusive), regardless if `A` or `B` are larger.
local function isBetween(val, A, B)
    return (val >= math.min(A, B)) and (val <= math.max(A, B))
end

local function inverseLerpClamped(from, to, val, outMin, outMax)
    return clamp(inverseLerp(from, to, val), outMin, outMax)
end

local function subtractTowardsZero(val, sub, dontFlipSign)
    if dontFlipSign and math.abs(val) <= sub then
        return 0
    end
    return val - sub * sign(val)
end

local function roundToDecimals(val, decimals)
    local scale = math.pow(10, decimals)
    return round(val * scale) / scale
end

local function clamp01(val)
    return clamp(val, 0, 1)
end

-- Returns the angle between two vectors in radians. The lengths are optional, you can pass them in if you already have them.
local function angleBetween(vecA, vecB, vecALen, vecBLen)
    vecALen = vecALen or vecA:length()
    vecBLen = vecBLen or vecB:length()
    return math.acos((vecA.x * vecB.x + vecA.y * vecB.y + vecA.z * vecB.z) / (vecALen * vecBLen))
end

-- Returns the value if the sign of it matches the reference, or 0 otherwise
local function signClampValue(val, signRef)
    return (sign(val) == sign(guardZero(signRef))) and val or 0
end

-- SmoothTowards class

local SmoothTowards = {}

-- `speed` is automatically normalized to the range given by `minValue` and `maxValue`.
-- Linearity: https://i.imgur.com/rXnDJuh.png
function SmoothTowards:new(speed, linearity, minValue, maxValue, startingValue)
    startingValue = startingValue or 0
    self.__index = self
    return setmetatable({
        speed         = speed,
        linearity     = linearity,
        range         = maxValue - minValue,
        state         = startingValue,
        startingValue = startingValue
    }, self)
end

function SmoothTowards:get(val, dt)
    local linearitySq       = self.linearity * self.linearity
    local speed             = self.speed / (1.0 - (1.0 / (linearitySq + (1.0 / 0.75)))) * 0.5
    local diffAbsNormalized = math.abs((val - self.state) / self.range)
    local diffSign          = sign(val - self.state)
    local adjustedSpeed     = (diffAbsNormalized * (1 - linearitySq) + linearitySq) * speed
    self.state              = self.state + diffSign * math.min(diffAbsNormalized, dt * adjustedSpeed) * self.range

    return self.state
end

function SmoothTowards:getWithSpeed(val, dt, speed)
    local originalSpeed = self.speed
    self.speed          = speed
    local ret           = self:get(val, dt)
    self.speed          = originalSpeed

    return ret
end

function SmoothTowards:getWithSpeedMult(val, dt, speedMult)
    return self:getWithSpeed(val, dt, self.speed * speedMult)
end

function SmoothTowards:value()
    return self.state
end

function SmoothTowards:reset()
    self.state = self.startingValue
end

-- RunningAverage class

local RunningAverage = {}

function RunningAverage:new(length)
    self.__index = self
    return setmetatable({
        length = length or 3,
        values = {}
    }, self)
end

function RunningAverage:add(val)
    if #self.values >= self.length then
        table.remove(self.values, 1)
    end
    table.insert(self.values, val)
end

function RunningAverage:get()
    if #self.values == 0 then
        return nil
    end
    return average(self.values)
end

function RunningAverage:reset()
    self.values = {}
end

function RunningAverage:count()
    return #self.values
end

-- Transform class
-- Holds information about an object's position and orientation. Can be used to translate vectors and points between world space and object space.
local Transform = {}

function Transform:new(_fwd, _up, _pos, _quat, _invQuat)
  self.__index  = self
  _fwd          = _fwd or vec3(0,1,0)
  _up           = _up or vec3(0,0,1)
  _pos          = _pos or vec3(0,0,0)
  _quat         = _quat or quatFromDir(_fwd, _up)
  _invQuat      = _invQuat or _quat:inversed()
  return setmetatable({
    fwdVec  = _fwd,
    upVec   = _up,
    pos     = _pos,
    quat    = _quat,
    invQuat = _invQuat
  }, self)
end

function Transform:pointToWorld(localPoint)
  return (self.quat * localPoint) + self.pos
end

function Transform:pointToLocal(worldPoint)
  return self.invQuat * (worldPoint - self.pos)
end

function Transform:vecToWorld(localVec)
  return self.quat * localVec
end

function Transform:vecToLocal(worldVec)
  return self.invQuat * worldVec
end

function Transform:transformToLocal(worldTransform)
  return Transform:new(self:vecToLocal(worldTransform.fwdVec), self:vecToLocal(worldTransform.upVec), self:pointToLocal(worldTransform.pos))
end

function Transform:transformToWorld(localTransform)
  return Transform:new(self:vecToWorld(localTransform.fwdVec), self:vecToWorld(localTransform.upVec), self:pointToWorld(localTransform.pos))
end

-- =================== Variables and config

local steeringCfg               = nil
local physicsSmoothingWindow    = 60 -- Number of physics updates
local counterFadeMinSpeed       = 5.0  -- km/h
local counterFadeMaxSpeed       = 15.0 -- km/h
local dampingFadeMinSpeed       = 20.0 -- km/h
local dampingFadeMaxSpeed       = 50.0 -- km/h
local steeredWheels             = {} -- Indicies of steered wheel(s)
local rearWheels                = {} -- Indicies of the rearmost wheel(s) by position
local allWheels                 = {} -- Indicies of all wheels
local steeringHydroIndex        = -1
local calibrationStage          = 0 -- Used during calibration
local steeringCurveExp          = 0.9 -- Default fallback value
local steeringLockRad           = math.rad(35) -- Default fallback value
local steeringLockDeg           = 35 -- Default fallback value
local wheelbase                 = 3.0
local hardSurfaceTypes          = { METAL=1,PLASTIC=1,RUBBER=1,GLASS=1,WOOD=1,ASPHALT=1,ROCK=1,RUMBLE_STRIP=1,COBBLESTONE=1 } -- taken from game\lua\common\particles.json
local hardSurfaceCache          = nil
local offroadCapIncreaseDeg     = 14 -- How much extra steering to give on offroad surfaces
local offroadCounterMult        = 0.5 -- Multiplies the strength of the automatic countersteer offroad. Helps with rally-style driving like throwing cars into a turn.

-- =================== State (things that need to be reset)

local steeringSmoother          = SmoothTowards:new(3.5, 0.15, -1, 1, 0)
-- local counterSmoother           = SmoothTowards:new(3.5, 0.15, -1, 1, 0) -- For manual countersteer input
local counterAssistSmoother     = SmoothTowards:new(7, 0.15, -1, 1, 0) -- Only for the assist
local isGroundedSpeedCap        = newTemporalSmoothing(4.0, 4.0, 4.0, 1)
local inputDirectionSpeedCap    = newTemporalSmoothing(6.0, 6.0, 6.0, 0)
local surfaceChangeSpeedCap     = newTemporalSmoothing(1.5, 1.5, 1.5, 1)
local radiusAccelSpeedCap       = newTemporalSmoothing(15, 15, 15, 10)
local calibrationHydroCap       = newTemporalSmoothing(2.5, 2.5, 2.5, 0) -- Hydros already have their own speed cap, but some are too fast for reliable calibration
local lastSolidSurfaceVal       = 1 -- 0 if all steered wheels are offroad, otherwise 1. Only updated if all steered wheels are grounded

local stablePhysicsData = {
    yawAngularVel   = RunningAverage:new(physicsSmoothingWindow),
    vehVelocity     = RunningAverage:new(physicsSmoothingWindow),
    wheelVelocities = {}
}

-- ===================

-- Other helpers

local function getHardSurfacesById()
    if not hardSurfaceCache then
        hardSurfaceCache = {}
        for k, v in pairs(particles.getMaterialsParticlesTable()) do
            hardSurfaceCache[k] = hardSurfaceTypes[v.name]
        end
    end
    return hardSurfaceCache
end


local function isWheelBroken(i)
    return wheels.wheels[i].isBroken
end

-- Returns the vehicle's current `Transform`.
local function getVehicleTransform()
    -- local pos = obj:getPosition()
    -- local rot = quat(obj:getRotation())
    -- local forward = rot * vec3(0,1,0)
    -- local up      = rot * vec3(0,0,1)
    -- return Transform:new(forward, up, pos)
    return Transform:new(-obj:getDirectionVector(), obj:getDirectionVectorUp(), obj:getPosition())
end

local function fWheelSmoothDownforce(wheelData)
    return wheelData.downForce
end

local function fWheelDownforce(wheelData)
    return wheelData.rawDownforce
end

local function fWheelPressure(wheelData)
    return wheelData.pressure
end

local function fWheelDownforceIfOnSolidSurface(wheelData)
    if wheelData.isOnSolidSurface then
        return wheelData.rawDownforce
    else
        return nil
    end
end

-- local function fWheelDownforceIfGrounded(wheelData)
--     if wheelData.isGrounded then
--         return wheelData.rawDownforce
--     else
--         return nil
--     end
-- end

-- local function fWheelWorldVel(wheelData)
--     return wheelData.velocityWorld
-- end

-- local function fWheelSlipAngle(wheelData)
--     return wheelData.slipAngle
-- end

local function fWheelSlipAngleIfGrounded(wheelData)
    if wheelData.isGrounded then
        return wheelData.slipAngle
    else
        return nil
    end
end

local function fWheelSlipAngle(wheelData)
    return wheelData.slipAngle
end

-- local function fWheelVehXVelIfGrounded(wheelData)
--     if wheelData.isGrounded then
--         return wheelData.velocityVehSpc.x
--     else
--         return nil
--     end
-- end

local function fWheelVehXVel(wheelData)
    return wheelData.velocityVehSpc.x
end

-- Returns data about a specific wheel
local function getWheelData(wheelIndex, vehTransform, ignoreAirborne)
    local mat, mat2 = wheels.wheels[wheelIndex].contactMaterialID1, wheels.wheels[wheelIndex].contactMaterialID2
    if mat == 4 then
      mat, mat2 = mat2, mat
    end

    local grounded = mat >= 0

    if ignoreAirborne and not grounded then
        return nil
    end

    local node1Pos        = obj:getNodePositionRelative(wheels.wheels[wheelIndex].node1)
    local node2Pos        = obj:getNodePositionRelative(wheels.wheels[wheelIndex].node2)
    local normal          = (node2Pos - node1Pos):normalized()
    local wFwdVec         = vehTransform:vecToWorld(normal:cross(vec3(0, 0, 1)):normalized() * wheels.wheels[wheelIndex].wheelDir)
    local transform       = Transform:new(wFwdVec, vehTransform.upVec, vehTransform:pointToWorld(node1Pos * 0.5 + node2Pos * 0.5))
    local velWorld        = stablePhysicsData.wheelVelocities[wheelIndex]:get() or vec3()
    local velWheelSpc     = transform:vecToLocal(velWorld)
    local velVehSpc       = vehTransform:vecToLocal(velWorld)
    local hardSurfaceIDs  = getHardSurfacesById()
    -- local pressureGroupID = wheels.wheels[wheelIndex].pressureGroup

    return {
        index            = wheelIndex,
        isSteered        = contains(steeredWheels, wheelIndex),
        isRear           = contains(rearWheels, wheelIndex),
        isGrounded       = grounded,
        transformWorld   = transform,
        velocityWorld    = velWorld,
        velocityVehSpc   = velVehSpc,
        velocityWheelSpc = velWheelSpc,
        slipAngle        = math.atan(velWheelSpc.x / guardZero(velWheelSpc.y)),
        rawDownforce     = wheels.wheels[wheelIndex].downForceRaw,
        downForce        = wheels.wheels[wheelIndex].downForce,
        isOnSolidSurface = hardSurfaceIDs[mat] and true or false
        -- pressure         = pressureGroupID and (obj:getGroupPressure(v.data.pressureGroups[pressureGroupID]) / 10000.0) or 0.0,
        -- contactDepth     = wheels.wheels[wheelIndex].contactDepth,
        -- rimRadius        = wheels.wheels[wheelIndex].hubRadius,
        -- tireRadius       = wheels.wheels[wheelIndex].radius,
        -- sidewall         = wheels.wheels[wheelIndex].radius - wheels.wheels[wheelIndex].hubRadius
        -- tireWidth        = wheels.wheels[wheelIndex].tireWidth
    }
end

-- Returns an array of wheel data objects for an array of wheel indicies
local function getWheelDataMultiple(wheelIndicies, vehTransform, ignoreBroken, ignoreAirborne)
    local ret = {}

    for _, i in ipairs(wheelIndicies) do
        if (ignoreBroken and not isWheelBroken(i)) or not ignoreBroken then
            local data = getWheelData(i, vehTransform, ignoreAirborne)
            if data ~= nil then
                table.insert(ret, data)
            end
        end
    end

    return ret
end

local function getSteeringCurveExponent(Vx, Vy)
    Vy = clamp(Vy, 0.001, 0.999) -- Otherwise the function might do dumb shit
    return math.log(1.0 - Vy, 10) / math.log(1.0 - Vx, 10)
end

local function getSteeringHydroStateNormalized()
    if steeringHydroIndex ~= -1 then
        local state       = hydros.hydros[steeringHydroIndex].state
        local center      = hydros.hydros[steeringHydroIndex].center
        local lowerLimit  = math.min(hydros.hydros[steeringHydroIndex].inLimit,
            hydros.hydros[steeringHydroIndex].outLimit)
        local higherLimit = math.max(hydros.hydros[steeringHydroIndex].inLimit,
            hydros.hydros[steeringHydroIndex].outLimit)
        if higherLimit <= center or lowerLimit >= center then
            return nil
        end
        if state <= center then
            return inverseLerp(lowerLimit, center, state) - 1
        else
            return inverseLerp(center, higherLimit, state)
        end
    end
    return nil
end

local function inputToNormalizedSteering(input)
    return sign(input) * (1.0 - math.pow(1.0 - math.abs(input), steeringCurveExp))
end

local function normalizedSteeringToInput(steeringAngleNormalized)
    return sign(steeringAngleNormalized) * (1.0 - math.pow(1.0 - math.abs(steeringAngleNormalized), 1.0 / steeringCurveExp))
end

local function getCurrentSteeringAngle(steeredWheelData, vehicleTransform)
    return average(steeredWheelData, function(wheelData)
        return angleBetween(vec3(0, -1, 0), vehicleTransform:vecToLocal(wheelData.transformWorld.fwdVec):z0())
    end)
end

-- Calibration stuff
local prevAngle             = 0
local hydroSignAtXY         = 0
local hydroSignAtLock       = 0
local calibrationDelay      = 0 -- Delays measuring the steering lock by 1 "frame"
local calibrationExpXY      = {0,0} -- X,Y point for determining the exponent for the function that converts between input and steering angle
local calibratedLockRad     = 0 -- Measured steering lock
local calibrationDuration   = 0 -- For abandoning calibration if it takes too long

local function customPhysicsStep(dtPhys)
    stablePhysicsData.vehVelocity:add(obj:getVelocity())
    stablePhysicsData.yawAngularVel:add(obj:getYawAngularVelocity())

    for i = 0, wheels.wheelCount - 1, 1 do
        stablePhysicsData.wheelVelocities[i]:add((obj:getNodeVelocityVector(wheels.wheels[i].node1) + obj:getNodeVelocityVector(wheels.wheels[i].node2)) * 0.5)
    end

    if steeringHydroIndex == -1 then
        -- Skip calibration
        calibrationStage = 3
        return
    end

    if calibrationStage < 2 then
        calibrationDuration = calibrationDuration + dtPhys

        if calibrationDuration > 2 then
            log("W", logTag, "Steering calibration was canceled because it took longer than expected. Try reloading the vehicle (Ctrl+R) on a flat surface!")
            calibrationStage = 3
            return
        end

        local hydroState = getSteeringHydroStateNormalized()

        if hydroState == nil then
            -- Hydro state can't be read, skipping calibration
            calibrationStage = 3
            return
        end

        local hydroSign     = sign(hydroState)
        local hydroStateAbs = math.abs(hydroState)
        local vehTransform  = getVehicleTransform()
        local wheelData     = getWheelDataMultiple(steeredWheels, vehTransform, true, false)
        local currentAngle  = getCurrentSteeringAngle(wheelData, vehTransform)

        if currentAngle == nil then
            -- In case steered wheels are somehow broken right after spawning, skip calibration
            calibrationStage = 3
            return
        end

        if math.abs(currentAngle - prevAngle) > 1e-6 then -- Only do the math if the angle changes (doesn't change on every physics step)
            prevAngle = currentAngle

            if hydroStateAbs > 0.5 and hydroSign ~= hydroSignAtXY then
                hydroSignAtXY       = hydroSign
                calibrationExpXY[1] = calibrationExpXY[1] + hydroStateAbs * 0.5
                calibrationExpXY[2] = calibrationExpXY[2] + currentAngle * 0.5
            end

            if hydroStateAbs > 0.999 then
                if calibrationDelay == 0 then
                    calibrationDelay = 1 -- Waits for the next value before taking the reading
                else
                    if hydroSignAtLock ~= hydroSign then
                        hydroSignAtLock   = hydroSign
                        calibrationStage  = calibrationStage + 1
                        calibrationDelay  = 0
                        calibratedLockRad = calibratedLockRad + currentAngle * 0.5
                    end
                end
            end

        end
    end

    if calibrationStage == 2 then
        calibrationStage    = 3
        calibratedLockRad   = calibratedLockRad * 1.03
        calibrationExpXY[2] = calibrationExpXY[2] * 1.03 -- The angles usually measure slightly low
        calibrationExpXY[2] = calibrationExpXY[2] / calibratedLockRad + 0.01 -- The curve usually ends up slightly low too
        local exponent      = getSteeringCurveExponent(calibrationExpXY[1], calibrationExpXY[2])

        if exponent < 0.7 or exponent > 1.3 then
            log("W", logTag, "Steering calibration readings seem abnormal. Try reloading the vehicle (Ctrl+R) on a flat surface!")
        end

        steeringCurveExp = clamp(exponent, 0.7, 1.3)
        steeringLockRad  = calibratedLockRad
        steeringLockDeg  = math.deg(calibratedLockRad)

        if steeringCfg["logData"] then
            print("======== Steering calibration results ========")
            print(string.format("Steering lock:           %8.3f°", steeringLockDeg))
            print(string.format("Steering curve exponent: %8.3f", steeringCurveExp))
        end
    end
end

local function reset()
    steeringSmoother:reset()
    counterAssistSmoother:reset()
    isGroundedSpeedCap:reset()
    inputDirectionSpeedCap:reset()
    surfaceChangeSpeedCap:reset()
    radiusAccelSpeedCap:reset()
    calibrationHydroCap:reset()
    lastSolidSurfaceVal = 1

    stablePhysicsData.yawAngularVel:reset()
    stablePhysicsData.vehVelocity:reset()

    -- Create or reset wheel velocity averages
    for i = 0, wheels.wheelCount - 1, 1 do
        if stablePhysicsData.wheelVelocities[i] ~= nil then
            stablePhysicsData.wheelVelocities[i]:reset()
        else
            stablePhysicsData.wheelVelocities[i] = RunningAverage:new(physicsSmoothingWindow)
        end
    end
end

local function initSecondStage()

    steeredWheels = {}
    rearWheels    = {}

    if wheels.wheelCount == 0 then
        return
    end

    reset()

    local tmpAllWheels = {}

    -- Helper function to find steered wheels. Could be improved, but so far this is the only way I found to detect them.
    local function isWheelSteered(index)
        return (v.data.wheels[index].steerAxisUp ~= nil or v.data.wheels[index].steerAxisDown ~= nil)
    end

    local foundSteeredWheels = 0

    for i = 0, wheels.wheelCount - 1 do
        table.insert(allWheels, i)

        local isSteered = isWheelSteered(i)
        if isSteered then foundSteeredWheels = foundSteeredWheels + 1 end
        local _pos = average({ obj:getNodePositionRelative(wheels.wheels[i].node1), obj:getNodePositionRelative(wheels.wheels[i].node2) }) or vec3()
        _pos.y = -_pos.y
        table.insert(tmpAllWheels, {
            index   = i,
            pos     = _pos,
            steered = isSteered
        })
    end

    -- Sorting by local Y position ([1] and [2] will be the rear wheels on a 4-wheel car)
    table.sort(tmpAllWheels, function(a, b)
        return a.pos.y < b.pos.y
    end)

    local frontmostY = tmpAllWheels[#tmpAllWheels].pos.y
    local rearmostY  = tmpAllWheels[1].pos.y

    wheelbase = frontmostY - rearmostY

    if foundSteeredWheels == 0 then
        -- In case `isWheelSteered()` couldn't detect the steered wheels, we'll use the front wheels (by position).
        for i = #tmpAllWheels, 1, -1 do
            if tmpAllWheels[i].pos.y >= (frontmostY - 0.1) then
                tmpAllWheels[i].steered = true
            else
                break
            end
        end
    elseif foundSteeredWheels > 2 then
        -- If more than 2 steered wheels were detected, only keep the frontmost 2. Keeping track of more might mess with some cars.
        local steeredCount = 0
        for i = #tmpAllWheels, 1, -1 do
            if steeredCount >= 2 then tmpAllWheels[i].steered = false
            elseif tmpAllWheels[i].steered then steeredCount = steeredCount + 1 end
        end
    end

    -- Saving steered wheel and rear wheel indicies to global arrays
    for _, wheel in ipairs(tmpAllWheels) do
        if wheel.steered then
            table.insert(steeredWheels, wheel.index)
        end

        if wheel.pos.y <= (rearmostY + 0.1) then
            table.insert(rearWheels, wheel.index)
        end
    end
end

local function initialize()
    -- Finding steering hydro
    if hydros then
        for i, h in pairs(hydros.hydros) do
            if h.inputSource == "steering_input" then
                steeringHydroIndex = i
                break
            end
        end
    end

    if steeringHydroIndex == -1 then
        log("W", logTag, "Steering hydro could not be found.")
    end

    initSecondStage()
end

-- ================ Copied over from the original, but modified

-- return vehicle mass at spawn time (will not change e.g. after losing a bumper)
local vehicleMassCache
local function vehicleMass()
    if not vehicleMassCache then
        vehicleMassCache = 0
        for _, n in pairs(v.data.nodes) do
            vehicleMassCache = vehicleMassCache + n.nodeWeight
        end
    end
    return vehicleMassCache
end

local lastDownforceFactor = 10
-- Freezes the value if less than `minGroundedWheels` are grounded
local function getDownforceFactor(wheelData, minGroundedWheels)
    if countIf(wheelData, function(w) return w.isGrounded end) < minGroundedWheels then
        return lastDownforceFactor
    end
    lastDownforceFactor = (sum(wheelData, fWheelSmoothDownforce) or 0.0) / vehicleMass()
    return lastDownforceFactor
end

local function getBestTurnRadius(vel, allWheelData, dt)
    local accel  = obj:getStaticFrictionCoef() * getDownforceFactor(allWheelData, math.ceil(#allWheelData * 0.501))
    accel        = radiusAccelSpeedCap:getUncapped(accel, dt)
    local radius = square(vel) / accel * 1.35
    return clamp(radius, 0, 100000)
end

-- ================

-- local function getMinTurnRadius()
--     local c = wheelbase / math.cos((math.pi * 0.5) - steeringLockRad)
--     return math.sqrt(c * c - wheelbase * wheelbase) -- Just return c for front wheels, this is for rear
-- end

-- Draws a bar above the vehicle for debugging a scalar value
local function debugBar(vehicleTransform, val, max, slot, colorArr)
    local colorMult = sign(guardZero(val)) * 0.25 + 0.75
    obj.debugDrawProxy:drawCylinder(
        vehicleTransform:pointToWorld(vec3(0, 0, 1.8 + slot * 0.2)),
        vehicleTransform:pointToWorld(vec3(0, 0, 1.8 + slot * 0.2) + vec3(-4, 0, 0) * (val / max)),
        0.1,
        color(colorArr[1] * colorMult, colorArr[2] * colorMult, colorArr[3] * colorMult)
    )
end

-- Gets the baseline steering speed multiplier based on the relative steering speed setting
local function getBaseSteeringSpeedMult()
    return steeringCfg["relativeSteeringSpeed"] and (580 / v.data.input.steeringWheelLock) or 1
end

-- Calculates the fiunal steering speed multiplier based on speed, input method, and settings
local function getSteeringSpeedMult(filter, baseSteeringSpeedMult)
    local ret = steeringCfg["steeringSpeed"] * ((electrics.values.airspeed / 150.0) + 1.0) -- // TODO add a config value for this or something
    ret       = ret * baseSteeringSpeedMult
    if filter == FILTER_KBD then
        ret = ret * 0.6
    end
    return ret
end

-- 0 if all the wheels are off road, 1 if all on solid surface, in-between if mixed. Weighted by the downforce on each wheel.
-- local function getRatioOnSolidSurface(wheels)
--     return (sum(wheels, fWheelDownforceIfOnSolidSurface) or 0) / ((sum(wheels, fWheelDownforce)) + 1e-10)
-- end

-- Returns true if all the specified wheels are on an offroad surface
local function checkAllWheelsOffroad(wheels)
    return not any(wheels, function(wheel) return wheel.isOnSolidSurface end)
end

-- Returns true if all the specified wheels are grounded
local function checkAllWheelsGrounded(wheels)
    return not any(wheels, function(wheel) return not wheel.isGrounded end)
end

-- Unused
-- 0 if all the wheels are in the air, 1 if all grounded, in-between if mixed. Weighted by the downforce on each wheel.
-- local function getRatioOnGround(wheels)
--     return (sum(wheels, fWheelDownforceIfGrounded) or 0) / ((sum(wheels, fWheelDownforce)) + 1e-10)
-- end

-- Returns the steering limit as an input value (0-1)
local function getSteeringLimit(velLen, allWheelData, dt)
    --  Top down view, car is going "up" on the screen, turning right
    --
    --  o---o
    --  |car|
    --  |   |      best turning radius
    --  o---o ------------------------------X center of turning circle

    --   |\
    --   |β\
    --   |  \
    -- a |   \ c
    --   |    \
    --   |_____\
    --      b

    local a                   = wheelbase
    local b                   = getBestTurnRadius(velLen, allWheelData, dt)
    local c                   = math.sqrt(a * a + b * b) -- // FIXME use steered wheel pos or something instead of entire wheelbase // FIXME remove fixme because its probably fine
    local beta                = math.asin(b / c)
    local desiredLimitRad     = (math.pi * 0.5) - beta -- Steering angle at which the wheels' normal would point to the center of the turning circle
    local authorityCorrection = (1 - steeringCfg["counterForce.inputAuthority"]) * clamp(steeringCfg["counterForce.response"] * (steeringCfg["counterForce.useSteeredWheels"] and 5 or 5.5), 0, steeringCfg["counterForce.maxAngle"]) -- // FIXME experimental, not sure about this
    desiredLimitRad           = desiredLimitRad + math.rad(5) + math.rad(authorityCorrection) + math.rad(steeringCfg["steeringLimitOffset"])

    return normalizedSteeringToInput(clamp01(desiredLimitRad / steeringLockRad))
end

-- Lowers the input authority setting for keyboard
local function getEffectiveInputAuthority(filter)
    return (filter == FILTER_KBD) and (steeringCfg["counterForce.inputAuthority"] * 0.6) or steeringCfg["counterForce.inputAuthority"]
end

local function processInput(e, dt)

    -- Don't do anything if calibration hasn't finished
    if calibrationStage < 3 then
        electrics.values.steeringUnassisted = 0.0
        return 0.0, 0.0
    end

    -- Initial steering smoothing / speed cap
    local baseSteeringSpeedMult = getBaseSteeringSpeedMult()
    local steeringSpeedMult     = getSteeringSpeedMult(e.filter, baseSteeringSpeedMult)
    local ival = clamp(steeringSmoother:getWithSpeedMult(e.val, dt, steeringSpeedMult), e.minLimit, e.maxLimit) -- Adjust speed inside get() if needed

    -- ======================== Gathering measurements, assembling data

    local originalInput        = ival
    local originalInputAbs     = math.abs(ival)
    local vehicleTransform     = getVehicleTransform()
    local worldVel             = stablePhysicsData.vehVelocity:get() or vec3()
    local localVel             = vehicleTransform:vecToLocal(worldVel)
    localVel.y                 = -localVel.y -- Why is the Y axis backwards on vehicles??
    local localHVel            = localVel:z0():length()
    local localHVelKmh         = localHVel * 3.6
    local localFwdVelClamped   = math.max(0, localVel.y)

    -- Used for fading in/out all the input adjustments at low speed.
    local fadeIn               = smoothstep(clamp01(inverseLerp(counterFadeMinSpeed, counterFadeMaxSpeed, localHVelKmh)))
    -- Fades in/out the damping force at low to moderate speeds.
    local dampingFade          = smoothstep(clamp01(inverseLerp(dampingFadeMinSpeed, dampingFadeMaxSpeed, localHVelKmh)))

    local allWheelData         = getWheelDataMultiple(allWheels, vehicleTransform, true, false)
    local steeredWheelData     = filter(allWheelData, function(wheel) return wheel.isSteered end)
    local rearWheelData        = filter(allWheelData, function(wheel) return wheel.isRear end)

    local travelDirectionRad   = math.atan2(localVel.x, localVel.y)
    local yawAngularVel        = stablePhysicsData.yawAngularVel:get() or 0.0

    local avgRearWheelXVel     = average(rearWheelData, fWheelVehXVel) or 0.0

    local steeredSlipAngle     = math.deg(average(steeredWheelData, fWheelSlipAngle) or 0)
    local steeredSlipAngleAbs  = math.abs(steeredSlipAngle)
    local rearSlipAngle        = math.deg((average(rearWheelData, fWheelSlipAngle) or 0))
    local rearSlipAngleAbs     = math.abs(rearSlipAngle)

    -- 1 if at least one of the steered wheels is grounded, 0 otherwise. Basically a boolean with smoothing to prevent an instant transition.
    local groundedSmooth = 0.0

    if any(steeredWheelData, function(wheel) return wheel.isGrounded end) then
        groundedSmooth = smoothstep(isGroundedSpeedCap:get(1, dt))
    else
        groundedSmooth = smoothstep(isGroundedSpeedCap:get(0, dt))
    end

    -- ======================== Countersteer assist

    -- Wheel data that the countersteer force will be based on
    local sourceWheelData       = steeringCfg["counterForce.useSteeredWheels"] and steeredWheelData or rearWheelData

    -- 1 when trying to countersteer, 0 otherwise. Basically a boolean with smoothing to prevent an instant transition.
    local isCountersteering     = smoothstep(inputDirectionSpeedCap:getWithRate((sign(originalInput) ~= sign(guardZero(avgRearWheelXVel)) and originalInputAbs > 1e-10) and inverseLerpClamped(3, 8, rearSlipAngleAbs, 0, 1) or 0.0, dt, 5))

    -- 0 if all steered wheels are offroad, otherwise 1. Only updated if all steered wheels are grounded
    local solidSurfaceVal       = checkAllWheelsGrounded(steeredWheelData) and (checkAllWheelsOffroad(steeredWheelData) and 0 or 1) or lastSolidSurfaceVal
    lastSolidSurfaceVal         = solidSurfaceVal
    local smoothSolidSurfaceVal = smoothstep(surfaceChangeSpeedCap:get(solidSurfaceVal, dt))

    local carCorrection         = 31.5 / steeringLockDeg -- Correction factor for the max steering lock
    local referenceWVel         = 50 - (40 * steeringCfg["counterForce.response"]) -- Scales the countersteer force based on the response setting
    local avgWheelVelocity      = average(sourceWheelData, function(w) return w.velocityVehSpc:z0() end) or vec3() -- Average horizontal velocity of the source wheels in the car's coordinate space
    local avgWheelVelFwd        = vec3(avgWheelVelocity.x, -math.abs(avgWheelVelocity.y), avgWheelVelocity.z) -- Corrects the direction in reverse
    local avgWheelVelFwdLen     = avgWheelVelFwd:length()
    local avgWheelVelocityAngle = math.deg(angleBetween(avgWheelVelFwd, vec3(0, -1, 0), avgWheelVelFwdLen, 1)) -- Average angle of the horizontal wheel velocity vectors in the car's coordinate space
    local correctionBase        = (sign(guardZero(-avgWheelVelFwd.x)) * avgWheelVelocityAngle) * avgWheelVelFwdLen / referenceWVel * carCorrection * 0.0171 -- The magic number is to get the same magnitude as the old method I was using
    local counterForce          = counterAssistSmoother:getWithSpeedMult(clamp(correctionBase, -1, 1), dt, baseSteeringSpeedMult)
    local counterCap            = clamp(steeringCfg["counterForce.maxAngle"], 0, steeringLockDeg) / steeringLockDeg

    local dampingStrength       = (1.0 - originalInputAbs) * 0.8 + 0.2 -- Lessens the damping force as more steering input is applied. Damping is much more important when the automatic countersteer force is acting alone with no user input.
    local dampingForce          = subtractTowardsZero(-yawAngularVel, 0.012, true) * steeringCfg["counterForce.damping"] * 0.25 * dampingStrength * dampingFade -- The damping force is based on the negative yaw angular velocity. A small amount is subtracted towards 0 to filter out some noise.

    counterForce                = clamp(counterForce + dampingForce, -counterCap, counterCap) * groundedSmooth
    counterForce                = counterForce * lerp(offroadCounterMult, 1, smoothSolidSurfaceVal)

    -- ======================== Calculating the steering limit and final countersteer force

    local steeringLimit       = getSteeringLimit(localFwdVelClamped, allWheelData, dt)
    local effectiveAuthority  = getEffectiveInputAuthority(e.filter)

    -- Returns the steering limit and countersteer force that would be in effect if the player was turning inward
    local function processInputInward()
        local counterStrength = clamp01((1.0 - originalInputAbs) * effectiveAuthority + (1.0 - effectiveAuthority))
        local _counterForce   = normalizedSteeringToInput(counterForce * counterStrength)
        local limit           = clamp01(steeringLimit + (1 - smoothSolidSurfaceVal) * normalizedSteeringToInput(clamp01(offroadCapIncreaseDeg / steeringLockDeg)))
        return limit, _counterForce
    end

    -- Returns the steering limit and countersteer force that would be in effect if the player was countersteering
    local function processInputCounter()
        local _counterForce    = normalizedSteeringToInput(counterForce)
        local manualCounterCap = inverseLerpClamped(0, math.max(steeringLockRad, math.rad(5)), math.abs(travelDirectionRad) + math.rad(5), 0, 1) -- // FIXME travel direction??
        manualCounterCap       = normalizedSteeringToInput(manualCounterCap)
        manualCounterCap       = clamp01(manualCounterCap - (sign(ival) * _counterForce))
        return manualCounterCap, _counterForce
    end

    -- Calculating the limit and countersteer force both as if the player was turning in or coutersteering. We'll lerp between them as needed.
    local capInward, counterForceInward   = processInputInward()
    local capOutward, counterForceOutward = processInputCounter()

    -- Final steering limit that will be applied
    local effectiveCap = lerp(capInward, capOutward, isCountersteering)

    -- Final countersteer force that will be applied
    local effectiveCounterForce = lerp(counterForceInward, counterForceOutward, isCountersteering)

    -- Final processed input
    local finalAssistedInput = clamp(ival * effectiveCap + effectiveCounterForce, e.minLimit, e.maxLimit)
    ival = lerp(ival, finalAssistedInput, fadeIn)

    -- How to do debug draw shit
    -- obj.debugDrawProxy:drawNodeSphere(NODE, RADIUS, color(R, G, B))
    -- obj.debugDrawProxy:drawCylinder(FROM, TO, RADIUS, color(R, G, B))

    if steeringCfg["logData"] and localHVelKmh > 2 then
        print("====================================")
        print(string.format("Estimated steering lock:   %8.3f°", steeringLockDeg))
        -- print(string.format("Target steering limit:     %8.3f°", inputToNormalizedSteering(steeringLimit) * steeringLockDeg))
        -- print(string.format("Predicted steering angle:  %8.3f°", inputToNormalizedSteering(ival) * steeringLockDeg))
        print(string.format("Current steering angle:    %8.3f°", math.deg(getCurrentSteeringAngle(steeredWheelData, vehicleTransform) or 0)))
        print(string.format("Avg steered wheel slip:    %8.3f°", steeredSlipAngleAbs))
        print(string.format("Avg rear wheel slip:       %8.3f°", rearSlipAngleAbs))
        print(string.format("Travel Direction:          %8.3f°", math.deg(travelDirectionRad)))
        -- print(string.format("Countersteer cap:          %8.3f°", inputToNormalizedSteering(manualCounterCap) * steeringLockDeg))
        -- print(string.format("Manual counter force:      %8.3f°", inputToNormalizedSteering(finalCounterForce - counterForce) * steeringLockDeg))
        print(string.format("Countersteering:           %8.3f", isCountersteering))
        -- print(string.format("Current turning radius:    %8.3f", clamp(math.abs(localHVel / yawAngularVel), 0, 9999.99)))
        -- print(string.format("Best turning radius est.:  %8.3f", getBestTurnRadius(localHVel, allWheelData, dt)))

        -- print(string.format("Limit:                     %8.3f°", inputToNormalizedSteering(getSteeringLimit(localFwdVelClamped, allWheelData, dt)) * steeringLockDeg))
        -- print(string.format("ival:                      %8.3f°", inputToNormalizedSteering(ival) * steeringLockDeg))
        -- print(string.format("Auto counter angle:        %8.3f°", inputToNormalizedSteering(counterForceInward) * steeringLockDeg))
        -- print(string.format("Mass:                      %8.3f", vehicleMass()))
        -- print(string.format("Friction:                  %8.3f", obj:getStaticFrictionCoef()))
        -- print(string.format("Depth:                     %8.3f", steeredWheelData[1].contactDepth))
        -- print(string.format("Steered:                   %8.3f", #steeredWheelData))
        -- print(string.format("GRIP:                      %8.3f", obj:getStaticFrictionCoef()))
        -- print(string.format("Sidewall:                  %8.3f", steeredWheelData[1].sidewall))
        -- print(string.format("Softness:                  %8.3f", wheels.wheels[steeredWheelData[1].index].softnessCoef))
        -- print(string.format("Pressure:                  %8.3f", steeredWheelData[1].pressure))
    end

    return ival, originalInput
end

local function calibrationInterject(e, dt, k, filter)
    -- Conditions for not doing calibration
    if calibrationStage >= 3 or steeringHydroIndex == -1 or filter == FILTER_AI then
        calibrationStage = 3
        return e.val
    end

    -- Preventing the player from moving the vehicle during calibration
    if k == "throttle" then
        return 0
    elseif k == "parkingbrake" then
        return 1
    elseif k == "brake" then
        return 0
    elseif k == "steering" then
        if calibrationStage == 0 then
            input.state[k].filter   = FILTER_DIRECT
            input.state[k].angle    = 0
            input.state[k].lockType = 0
            return calibrationHydroCap:get(-1, dt)
        elseif calibrationStage == 1 then
            input.state[k].filter   = FILTER_DIRECT
            input.state[k].angle    = 0
            input.state[k].lockType = 0
            return calibrationHydroCap:get(1, dt)
        end
    end

    return e.val
end

-- Copied from original
local function getDefaultState(itype)
    return { val = 0, filter = 0,
        smootherKBD = newTemporalSmoothing(10, 10, nil, 0),
        smootherPAD = newTemporalSmoothing(10, 10, nil, 0),
        minLimit = -1, maxLimit = 1 }
end

-- Copied from original
-- keyboard (multi-key) compatibility
local kbdSteerLeft = 0
local kbdSteerRight = 0
local function kbdSteer(isRight, val, filter)
  if isRight then kbdSteerRight = val
  else            kbdSteerLeft  = val end
  input.event('steering', kbdSteerRight-kbdSteerLeft, filter)
end

-- Copied from original
-- gamepad( (mono-axis) compatibility
local function padAccelerateBrake(val, filter)
  if val > 0 then
    input.event('throttle',  val, filter)
    input.event('brake',    0, filter)
  else
    input.event('throttle',    0, filter)
    input.event('brake', -val, filter)
  end
end

-- ======================== Settings, GUI calls

local defaultConfig = {
    ["enableCustomSteering"]          = true,
    ["logData"]                       = false,
    ["steeringSpeed"]                 = 1.2,
    ["relativeSteeringSpeed"]         = true,
    ["steeringLimitOffset"]           = 0.0,
    ["counterForce.useSteeredWheels"] = true,
    ["counterForce.response"]         = 0.3,
    ["counterForce.maxAngle"]         = 8.0,
    ["counterForce.inputAuthority"]   = 0.4,
    ["counterForce.damping"]          = 0.65,
}

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

local function saveSettings(jsonStr, silent)
    if jsonStr then
        -- If settings are passed in, save those
        local decoded = jsonDecode(jsonStr)
        if decoded then
            local saved = jsonWriteFile(settingsFilePath, mergeObjects(defaultConfig, decoded), true)
            if not silent then guihooks.trigger("arcadeSteeringSettingsSaved", saved) end
        elseif not silent then
             guihooks.trigger("arcadeSteeringSettingsSaved", false)
        end
    else
        -- If nothing is specified, save the current settings
        local saved = jsonWriteFile(settingsFilePath, mergeObjects(defaultConfig, steeringCfg), true)
        if not silent then guihooks.trigger("arcadeSteeringSettingsSaved", saved) end
    end
end

local function loadSettings()
    local decoded = jsonReadFile(settingsFilePath)

    if not decoded then
        log("W", logTag, "Failed to load Arcade Steering settings. Creating config file with the default settings ...")
        steeringCfg = defaultConfig
        saveSettings(nil, true)
    else
        steeringCfg = mergeObjects(defaultConfig, decoded)
    end
end

local function reloadVehicle()
    obj:queueGameEngineLua("scenetree.findObjectById(" .. tostring(obj:getID()) .. "):reload()")
end

local function displayDefaultSettings()
    guihooks.trigger("arcadeSteeringSetDisplayedSettings", { ["settings"] = defaultConfig, ["isDefault"] = true })
end

local function displayCurrentSettings()
    guihooks.trigger("arcadeSteeringSetDisplayedSettings", { ["settings"] = steeringCfg })
end

local function applySettings(jsonStr)
    local decoded = jsonDecode(jsonStr)
    if decoded then steeringCfg = decoded end
    guihooks.trigger("arcadeSteeringSettingsApplied", decoded and true or false)
end

-- ======================== Hijacking original functions, injecting custom input processing

local ogPhysicsStep      = onPhysicsStep
local ogInputEvent       = input.event
local ogInputToggleEvent = input.toggleEvent
local ogInputUpdate      = input.updateGFX

M.onExtensionLoaded = function()

    loadSettings()
    displayCurrentSettings()

    if not steeringCfg["enableCustomSteering"] or not v.data.input then return end

    initialize()

    M.state["steering"] = getDefaultState("steering")

    input.event = function(itype, ivalue, filter, angle, lockType)
        if itype == "steering" then
            M.state[itype].val      = ivalue
            M.state[itype].filter   = filter
            M.state[itype].angle    = angle
            M.state[itype].lockType = lockType
        else
            ogInputEvent(itype, ivalue, filter, angle, lockType)
        end
    end
    
    input.toggleEvent = function(itype)
        if itype == "steering" then
            if M.state[itype].val > 0.5 then
                M.state[itype].val = 0
            else
                M.state[itype].val = 1
            end
            M.state[itype].filter = 0
        else
            ogInputToggleEvent(itype)
        end
    end

    -- Using modified copies of these here because the originals call event() instead of input.event() so the redirected versions above won't get called because they only change the public interface of input
    input.kbdSteer           = kbdSteer
    input.padAccelerateBrake = padAccelerateBrake

    onPhysicsStep = function(dtPhys)
        ogPhysicsStep(dtPhys)
        customPhysicsStep(dtPhys)
    end

    input.updateGFX = function(dt)

        -- Processing the input *before* the original input script, then passing it on with FILTER_DIRECT so that the original input system will use it as-is.

        local unassistedInput = 0.0

        for k, e in pairs(M.state) do
            local angle = e.angle or 0
            if angle > 0 and k == "steering" then e.filter = FILTER_DIRECT end -- enforce direct filter if user has chosen an angle for steering binding

            if k == "steering" then
                if not (e.filter == FILTER_PAD or e.filter == FILTER_KBD or e.filter == FILTER_KBD2) then
                    input.state[k].val = M.state[k].val
                else
                    input.state[k].val, unassistedInput = processInput(M.state[k], dt)
                    input.state[k].filter               = FILTER_DIRECT
                    input.state[k].angle                = 0
                    input.state[k].lockType             = 0
                end
            end
        end

        for k, e in pairs(input.state) do
            input.state[k].val = calibrationInterject(input.state[k], dt, k, e.filter)
        end

        ogInputUpdate(dt)

        electrics.values.steeringUnassisted = unassistedInput -- Setting this here to overwrite what the original script set this to (the assisted value)
    end
end

M.onReset = reset

M.displayDefaultSettings = displayDefaultSettings
M.displayCurrentSettings = displayCurrentSettings
M.applySettings          = applySettings
M.saveSettings           = saveSettings
M.reloadVehicle          = reloadVehicle

return M