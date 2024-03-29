local M = {}
M.state = {}
local logTag = "AdvancedSteeringVE"

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

-- Indicates if at least `n` elements of the array `t` satisfy `pred(element)`.
local function atLeast(t, n, pred)
    local matches = 0
    if not t then
        return false
    end
    for _, tVal in ipairs(t) do
        if pred(tVal) then
            matches = matches + 1
            if matches >= n then return true end
        end
    end
    return matches >= n
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

-- Indicates if all elements of the array `t` satisfy `pred(element)`.
local function all(t, pred)
    if not t then
        return false
    end
    for _, tVal in ipairs(t) do
        if not pred(tVal) then
            return false
        end
    end
    return true
end

-- Determines if `val` is between `A` and `B` (inclusive), regardless if `A` or `B` are larger.
local function isBetween(val, A, B)
    return (val >= math.min(A, B)) and (val <= math.max(A, B))
end

-- Like a clamp, but the output has a smooth transition (parabolic easing) to the min and max values instead of a sudden cutoff.
-- `easingWindow` should be between `0.0` - `1.0`, it's normalized to the range given by `minVal` - `maxVal`.
-- Example graph of `clampEased(x, 0.0, 10.0, 0.4)` : https://i.imgur.com/WY9zYHK.png
local function clampEased(val, minVal, maxVal, easingWindow)
    local windowScaled     = easingWindow * (maxVal - minVal)
    local halfWindowScaled = windowScaled * 0.5
    local minLow           = minVal - halfWindowScaled
    local minHigh          = minVal + halfWindowScaled
    local maxLow           = maxVal - halfWindowScaled
    local maxHigh          = maxVal + halfWindowScaled

    if val < minLow  then return minVal end
    if val > maxHigh then return maxVal end

    if val < minHigh then
        local t = (val - minLow) / windowScaled -- inverseLerp(val, minLow, minHigh)
        return minVal + t * t * halfWindowScaled
    end
    if val > maxLow then
        local t = (val - maxLow - windowScaled) / windowScaled -- inverseLerp(val - windowScaled, maxLow, maxHigh)
        return maxVal - t * t * halfWindowScaled
    end

    return val
end

local function inverseLerpClamped(from, to, val, outMin, outMax)
    return clamp(inverseLerp(from, to, val), outMin, outMax)
end

local function inverseLerpClampedEased(from, to, val, outMin, outMax, transitionWindow)
    return clampEased(inverseLerp(from, to, val), outMin, outMax, transitionWindow)
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

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- Returns the angle between two vectors in radians. The lengths are optional, you can pass them in to avoid re-calculating them if you already have them.
local function angleBetween(vecA, vecB, vecALen, vecBLen)
    vecALen = vecALen or vecA:length()
    vecBLen = vecBLen or vecB:length()
    if vecALen * vecBLen == 0 then return 0 end
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
        length   = length or 3,
        elements = {},
        sum      = nil
    }, self)
end

function RunningAverage:add(element)
    if #self.elements >= self.length then
        self.sum = self.sum - table.remove(self.elements, 1)
    end
    table.insert(self.elements, element)
    if self.sum then self.sum = self.sum + element else self.sum = element end
end

function RunningAverage:get()
    if #self.elements == 0 then
        return nil
    end
    return self.sum and (self.sum / #self.elements) or nil
end

function RunningAverage:reset()
    self.elements = {}
    self.sum      = nil
end

function RunningAverage:count()
    return #self.elements
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
local physicsSmoothingWindow    = 80 -- Number of physics updates
local assistFadeMinSpeed        = 1.8  -- km/h
local assistFadeMaxSpeed        = 15.0 -- km/h
local counterFadeRefSpeed       = 40.0 -- km/h
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
local offroadCapIncreaseDeg     = 16 -- How much extra steering to give on offroad surfaces
local offroadSelfSteerMult      = 0.5 -- Multiplies the strength of the self-steer tendency offroad. Helps with rally-style driving like throwing cars into a turn.
local wheelsMidPoint            = vec3(0, 0, 0) -- The average position of all the wheels (car coordinate space)
local avgPressureAtStart        = -1 -- The average tire pressure when the vehicle is first spawned, used as a fallback
local disableMod                = false -- If true, the mod will restore all the original input functionality and disable itself on the next frame (for this vehicle only)
local initialToggleSetting      = nil
local isVehicleActive           = false
local maxTorqueSteer            = 1.0 -- Deg
local customFilterType          = "ADVANCED_STEERING"

-- =================== State (things that need to be reset)

local steeringSmoother          = SmoothTowards:new(3.5, 0.15, -1, 1, 0)
local steeringSmootherAbs       = SmoothTowards:new(3.5, 0.15, -1, 1, 0)
local selfSteerSmoother         = SmoothTowards:new(6, 0.15, -1, 1, 0)
local selfSteerSmoother2        = SmoothTowards:new(6, 0.15, -1, 1, 0)
local isGroundedSpeedCap        = newTemporalSmoothing(4.0, 4.0, 4.0, 1)
local surfaceSmoother           = newTemporalSmoothingNonLinear(1.5, 1.5, 0.5)
local radiusGripSmoother        = newTemporalSmoothingNonLinear(5, 5, 12) --newTemporalSmoothing(15, 15, 15, 10)
local radiusGripSmootherOLD     = newTemporalSmoothingNonLinear(5, 5, 12) --newTemporalSmoothing(15, 15, 15, 10)
local calibrationHydroCap       = newTemporalSmoothing(2.5, 2.5, 2.5, 0) -- Hydros already have their own speed cap, but some are too fast for reliable calibration
local lastHardSurfaceVal        = 1 -- 0 if driving offroad, 1 on hard surfaces. Only changed if more than half the wheels change surface type, frozen if at least half the wheels are airborne.
local selfSteerLPF              = newTemporalSmoothingNonLinear(30, 30, 0) -- Low pass filters for the self-steer force. These are used to let small vibrations through even when the force is otherwise meant to be suppressed.
local selfSteer2LPF             = newTemporalSmoothingNonLinear(30, 30, 0)
local counterBlendSpeedCap      = newTemporalSmoothing(6.0, 6.0, 6.0, 0)
local manualCounterBlendCap     = newTemporalSmoothingNonLinear(20.0, 20.0, 0)
local steeredTorqueSmoother     = newTemporalSmoothingNonLinear(8, 8, 0)
local steeredGripSmoother       = newTemporalSmoothingNonLinear(8, 8, 0)

local stablePhysicsData = {
    yawAngularVel   = RunningAverage:new(physicsSmoothingWindow),
    vehVelocity     = RunningAverage:new(physicsSmoothingWindow),
    wheelVelocities = {}
}

-- ===================

-- Other helpers

-- Draws a bar above the vehicle for debugging a scalar value
local function debugBar(vehicleTransform, val, max, colorArr, slot)
    if math.abs(val / max) < 0.001 then val = 0 end
    local colorMult = sign(guardZero(val)) * 0.25 + 0.75
    local baseYOffset = 1.8
    -- Main bar
    obj.debugDrawProxy:drawCylinder(
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2)),
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2) + vec3(-2, 0, 0) * (val / max)),
        0.08,
        color(colorArr[1] * colorMult, colorArr[2] * colorMult, colorArr[3] * colorMult)
    )
    -- Bottom edge
    obj.debugDrawProxy:drawCylinder(
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2 - 0.1) - vec3(-2, 0, 0)),
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2 - 0.1) + vec3(-2, 0, 0)),
        0.02,
        color(0, 0, 0)
    )
    -- Top edge
    obj.debugDrawProxy:drawCylinder(
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2 + 0.1) - vec3(-2, 0, 0)),
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2 + 0.1) + vec3(-2, 0, 0)),
        0.02,
        color(0, 0, 0)
    )
    -- 0 line
    obj.debugDrawProxy:drawCylinder(
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2 - 0.1)),
        vehicleTransform:pointToWorld(wheelsMidPoint + vec3(0, 0, baseYOffset + slot * 0.2 + 0.1)),
        0.02,
        color(0, 0, 0)
    )
end

local function debugWheels(allWheelData)
    for i,w in ipairs(allWheelData) do
        local posOffset = w.transformWorld.upVec:cross(w.transformWorld.fwdVec) * 0.5 * -w.wheelDir
        obj.debugDrawProxy:drawCylinder(
            w.transformWorld.pos + posOffset,
            w.transformWorld.pos + posOffset + w.transformWorld.fwdVec,
            0.02,
            color(255, 255, 0)
        )

        obj.debugDrawProxy:drawCylinder(
            w.transformWorld.pos + posOffset,
            w.transformWorld.pos + posOffset + w.velocityWorld:normalized(),
            0.02,
            color(0, 255, 255)
        )
    end
end

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

local function fWheelDownforceIfOnHardSurface(wheelData)
    if wheelData.isOnHardSurface then
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

local function fWheelSlipAngleAbs(wheelData)
    return math.abs(wheelData.slipAngle)
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

local function fWheelTireVolume(wheelData)
    return wheelData.tireVolume
end

local function fWheelTireSoftness(wheelData)
    return wheelData.tireSoftness
end

local function fWheelTirePressureIfNotDeflated(wheelData)
    if wheelData.deflated then
        return nil
    else
        return wheelData.pressure
    end
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
    local pressureGroupID = wheels.wheels[wheelIndex].pressureGroup

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
        isOnHardSurface  = hardSurfaceIDs[mat] and true or false,
        contactMatID     = mat,
        pressure         = v.data.pressureGroups[pressureGroupID] and (obj:getGroupPressure(v.data.pressureGroups[pressureGroupID]) / 10000.0) or 0.0,
        deflated         = wheels.wheels[wheelIndex].isTireDeflated,
        -- contactDepth     = wheels.wheels[wheelIndex].contactDepth,
        -- rimRadius        = wheels.wheels[wheelIndex].hubRadius,
        -- tireRadius       = wheels.wheels[wheelIndex].radius,
        sidewall         = wheels.wheels[wheelIndex].radius - wheels.wheels[wheelIndex].hubRadius,
        tireVolume       = wheels.wheels[wheelIndex].tireVolume,
        tireSoftness     = wheels.wheels[wheelIndex].softnessCoef,
        isPropulsed      = wheels.wheels[wheelIndex].isPropulsed,
        propulsionTorque = wheels.wheels[wheelIndex].propulsionTorque * wheels.wheels[wheelIndex].wheelDir,
        wheelDir         = wheels.wheels[wheelIndex].wheelDir
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
    local avgDir = average(steeredWheelData, function(wheelData)
        return vehicleTransform:vecToLocal(wheelData.transformWorld.fwdVec):z0()
    end)
    return sign(avgDir.x) * angleBetween(vec3(0, -1, 0), avgDir)
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
    -- Measuring average tire pressure at spawn. Kinda expensive doing it this way but whatever it only runs once.
    if avgPressureAtStart == -1 then
        avgPressureAtStart = average(getWheelDataMultiple(allWheels, getVehicleTransform(), true, false), fWheelTirePressureIfNotDeflated) or 28.0
    end

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

        if calibrationDuration > 3 then
            guihooks.message("Steering calibration aborted. Advanced Steering will be disabled for this vehicle. Try reloading the vehicle (Ctr+R) on a flat surface!", 10, logTag, "warning")
            log("W", logTag, "Steering calibration aborted. Advanced Steering will be disabled for this vehicle. Try reloading the vehicle (Ctr+R) on a flat surface!")
            disableMod = true
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
        local currentAngle  = math.abs(getCurrentSteeringAngle(wheelData, vehTransform))

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
        calibratedLockRad   = calibratedLockRad * 1.02
        calibrationExpXY[2] = calibrationExpXY[2] * 1.02 -- The angles usually measure slightly low
        calibrationExpXY[2] = calibrationExpXY[2] / calibratedLockRad + 0.001 -- A small correction is needed to the curve because of the angle adjustments
        local exponent      = getSteeringCurveExponent(calibrationExpXY[1], calibrationExpXY[2])

        steeringCurveExp = clamp(exponent, 0.7, 1.3)
        steeringLockRad  = calibratedLockRad
        steeringLockDeg  = math.deg(calibratedLockRad)

        if steeringLockDeg < 3 then
            guihooks.message("Failed to detect the steering mechanism. Advanced Steering will be disabled for this vehicle.", 8, logTag, "warning")
            log("W", logTag, "Failed to detect the steering mechanism. Advanced Steering will be disabled for this vehicle.")
            disableMod = true
        elseif exponent < 0.7 or exponent > 1.3 then
            guihooks.message("Advanced Steering calibration seems abnormal. Try reloading the vehicle (Ctr+R) on a flat surface!", 8, logTag, "warning")
            log("W", logTag, "Advanced Steering calibration seems abnormal. Try reloading the vehicle (Ctr+R) on a flat surface!")
        end

        if steeringCfg["logData"] and not disableMod then
            print("======== Advanced Steering calibration results ========")
            print(string.format("Steering lock:           %8.3f°", steeringLockDeg))
            print(string.format("Steering curve exponent: %8.3f", steeringCurveExp))
        end
    end
end

local function reset()
    steeringSmoother:reset()
    steeringSmootherAbs:reset()
    selfSteerSmoother:reset()
    selfSteerSmoother2:reset()
    isGroundedSpeedCap:reset()
    surfaceSmoother:reset()
    radiusGripSmoother:reset()
    radiusGripSmoother:set(12)
    calibrationHydroCap:reset()
    lastHardSurfaceVal = 1
    selfSteerLPF:reset()
    selfSteer2LPF:reset()
    counterBlendSpeedCap:reset()
    manualCounterBlendCap:reset()
    steeredTorqueSmoother:reset()
    steeredGripSmoother:reset()

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

    wheelsMidPoint = average(tmpAllWheels, function(w) return w.pos end) or vec3()
    wheelsMidPoint.y = -wheelsMidPoint.y

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
        guihooks.message("Failed to detect the steering hydro. Advanced Steering will be disabled for this vehicle.", 8, logTag, "warning")
        log("W", logTag, "Failed to detect the steering hydro. Advanced Steering will be disabled for this vehicle.")
        disableMod = true
        return
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
    if not atLeast(wheelData, minGroundedWheels, function(w) return w.isGrounded end) then
        return lastDownforceFactor
    end
    lastDownforceFactor = (sum(wheelData, fWheelSmoothDownforce) or 0.0) / vehicleMass()
    return lastDownforceFactor
end

local function getGripFactor(wheelData)
    return obj:getStaticFrictionCoef() * getDownforceFactor(wheelData, math.floor(#wheelData * 0.5) + 1)
end

-- Returns a correction factor for the best turning radius based on variables like grip and tire properties.
local function getRadiusCorrection(grip, allWheelData)
    local avgTireVolume = average(allWheelData, fWheelTireVolume) or 0.035
    local avgTireSoftness = average(allWheelData, fWheelTireSoftness) or 0.8
    local correction = (grip * avgTireVolume / avgTireSoftness * 0.918 - 0.473) * 0.8
    return 1.27 * (1 + clamp(correction, -0.1, 0.155))
end

local function getBestTurnRadius(vel, allWheelData, dt)
    local grip   = getGripFactor(allWheelData)
    grip         = radiusGripSmoother:get(grip, dt)
    local radius = (vel * vel) / grip * getRadiusCorrection(grip, allWheelData)
    return clamp(radius, 0, 100000)
end

local function getBestTurnRadiusOLD(vel, allWheelData, dt)
    local grip   = getGripFactor(allWheelData)
    grip         = radiusGripSmootherOLD:get(grip, dt)
    local radius = (vel * vel) / grip * 1.35
    return clamp(radius, 0, 100000)
end

-- ================

-- Gets the baseline steering speed multiplier based on the relative steering speed setting
local function getBaseSteeringSpeedMult(e)
    if steeringCfg["photoMode"] and (e.filter == FILTER_KBD or e.filter == FILTER_KBD2) then
        if e.val == 0 and math.max(math.abs(electrics.values['wheelspeed']), vec3(obj:getSmoothRefVelocityXYZ()):length()) < 0.5 then
            return 0.0
        end
    end
    return steeringCfg["relativeSteeringSpeed"] and (540 / v.data.input.steeringWheelLock) or 1
end

-- Calculates the final steering speed multiplier based on speed, input method, and settings
local function getSteeringSpeedMult(filter, baseSteeringSpeedMult)
    local ret = steeringCfg["steeringSpeed"] * ((electrics.values.airspeed / 200.0) + 1.0) -- // TODO add a config value for this or something
    ret       = ret * baseSteeringSpeedMult
    if filter == FILTER_KBD then
        ret = ret * 0.7
    end
    return ret
end

-- 0 if all the wheels are off road, 1 if all on hard surface, in-between if mixed. Weighted by the downforce on each wheel.
local function getRatioOnHardSurface(wheels)
    return (sum(wheels, fWheelDownforceIfOnHardSurface) or 0) / guardZero(sum(wheels, fWheelDownforce) or 0)
end

-- Returns true if all the specified wheels are on an offroad surface
-- local function checkAllWheelsOffroad(wheels)
--     return not any(wheels, function(wheel) return wheel.isOnHardSurface end)
-- end

-- Returns true if all the specified wheels are on a hard surface
-- local function checkAllWheelsOnHardSurface(wheels)
--     return all(wheels, function(wheel) return wheel.isOnHardSurface end)
-- end

-- Returns true if all the specified wheels are grounded
-- local function checkAllWheelsGrounded(wheels)
--     return not any(wheels, function(wheel) return not wheel.isGrounded end)
-- end

-- Unused
-- 0 if all the wheels are in the air, 1 if all grounded, in-between if mixed. Weighted by the downforce on each wheel.
-- local function getRatioOnGround(wheels)
--     return (sum(wheels, fWheelDownforceIfGrounded) or 0) / ((sum(wheels, fWheelDownforce)) + 1e-10)
-- end

-- Calculates a correction (steering degrees) to add to the base calculation of the steering limit
local function getLimitCorrection(allWheelData)
    local avgPressure = average(allWheelData, fWheelTirePressureIfNotDeflated) or avgPressureAtStart
    local pressureFactor = (math.sqrt((avgPressure - 10) / 365) + 0.885) / 1.2
    local correction = (5.0 / pressureFactor * (wheelbase / 2.5)) * 2.02 - 6
    return clamp(correction, 3, 6)
end

-- Returns the steering limit normalized to the steering lock (0-1)
local function getSteeringLimit(allWheelData, velLen, effectiveAuthority, dt)
    --  Top down view, car is going north, turning right
    --
    --  o---o
    --  |car|
    --  |   |    best turning radius est.
    --  o---o ------------------------------X center of turning circle

    --   |\
    --   |β\     β = baseline steering angle, adjusted further based on other variables
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
    local authorityCorrection = (1.0 - effectiveAuthority) * 0.2 * steeringCfg["counterForce.response"] * inverseLerpClamped(0, 0.5, steeringCfg["counterForce.maxAngle"], 0, 1) -- Depends on how the input authority is processed. Changing the self-steer force behavior will require a change to this.
    desiredLimitRad           = desiredLimitRad + math.rad(getLimitCorrection(allWheelData)) + math.rad(authorityCorrection) + math.rad(steeringCfg["steeringLimitOffset"])

    -- print(b)
    -- print(math.deg(desiredLimitRad))
    -- print(string.format("Authority correction: %8.3f", authorityCorrection))
    -- print(string.format("Limit correction: %8.3f", getLimitCorrection(allWheelData)))

    return clamp01((desiredLimitRad + math.rad(0.4)) / steeringLockRad)
end

local function getHardSurfaceVal(allWheelData, minGroundedWheels, lastVal)
    if not atLeast(allWheelData, minGroundedWheels, function(w) return w.isGrounded end) then
        return lastVal
    end

    local ratio = getRatioOnHardSurface(allWheelData)

    if ratio < 0.2 then return 0
    elseif ratio > 0.8 then return 1
    else return ratio end
end

-- Returns the increase to the steering limit due to torque steer (typically FWD or AWD cars under acceleration)
local function getTorqueSteerAmount(steeredWheelData, dt)

    if not any(steeredWheelData, function (w) return w.isPropulsed end) then
        return 0
    end

    -- Average drive torque on the steered wheels, normalized and smoothed
    local smoothSteeredTorqueFactor = steeredTorqueSmoother:get(clamp01((average(steeredWheelData, function(w) return w.propulsionTorque end) or 0.0) / 600), dt)

    -- Average total grip factor of the front wheels, normalized and smoothed
    local smoothSteeredGripFactor   = steeredGripSmoother:get(clamp01(getGripFactor(steeredWheelData) / 12.0), dt)

    return (maxTorqueSteer / steeringLockDeg) * smoothSteeredTorqueFactor * smoothSteeredGripFactor
end

-- Returns a smooth 0-1 value that indicates if any steered wheels are grounded
local function getSteeredWheelGroundedFactor(steeredWheelData, dt)
    local groundedSmooth = 0.0

    if any(steeredWheelData, function(w) return w.isGrounded end) then
        groundedSmooth = smoothstep(isGroundedSpeedCap:get(1, dt))
    else
        groundedSmooth = smoothstep(isGroundedSpeedCap:get(0, dt))
    end

    return groundedSmooth
end

local function signedPow(x, y)
    return sign(x) * math.pow(math.abs(x), y)
end

-- Returns the automatic self-steer force for two scenarios: no player input or countersteering, and the player turning inward. The force is normalized steering amount.
local function getBaseSelfSteerForce(sourceWheelData, localHVelKmh, baseSteeringSpeedMult, smoothHardSurfaceVal, yawAngularVel, originalInputAbs, dt)
    local avgWheelVel       = average(sourceWheelData, function(w) return w.velocityVehSpc:z0() end) or vec3() -- Average horizontal velocity vector of the source wheels in the car's coordinate space
    local avgWheelVelFwd         = vec3(avgWheelVel.x, -math.abs(avgWheelVel.y), avgWheelVel.z) -- Corrects the direction in reverse
    local avgWheelVelLen         = avgWheelVel:length()
    local avgWheelVelocityAngle  = math.deg(angleBetween(avgWheelVelFwd, vec3(0.0, -1.0, 0.0), avgWheelVelLen, 1)) -- Average angle of the horizontal wheel velocity vectors in the car's coordinate space
    local inwardAngleSub         = steeringCfg["counterForce.useSteeredWheels"] and 3.0 or 4.1 -- How much angle (deg) to subtract from the average wheel velocity angle to leave an "inner deadzone" for the self-steer force when turning inward
    local avgWheelVelocityAngle2 = clampEased(avgWheelVelocityAngle - inwardAngleSub, 0.0, 180.0, 2.0 / 180.0) * (90.0 / (90.0 - inwardAngleSub)) -- The "2" versions are for turning inwards
    local avgWheelVelXSign       = sign(guardZero(-avgWheelVelFwd.x))
    local correctionExponent     = 1.0 + (1.0 - math.log10(10.0 * (steeringCfg["counterForce.response"] * 0.9 + 0.1))) -- This exponent is for adjusting the responsiveness of the self-steer force based on the setting for it
    local correctionBase         = signedPow(avgWheelVelXSign * clamp01(avgWheelVelocityAngle  / 72.0), correctionExponent) * 72.0 / steeringLockDeg -- Base self-steer force
    local correctionBase2        = signedPow(avgWheelVelXSign * clamp01(avgWheelVelocityAngle2 / 72.0), correctionExponent) * 72.0 / steeringLockDeg -- Same but when turning inward
    local selfSteerCap           = clamp01(steeringCfg["counterForce.maxAngle"] / steeringLockDeg) -- Max self-steer amount

    local offroadCorrection      = lerp(offroadSelfSteerMult, 1.0, smoothHardSurfaceVal)
    local selfSteerStrength      = math.sqrt(clamp01(avgWheelVelLen / (counterFadeRefSpeed / 3.6)))

    local dampingStrength        = (1.0 - originalInputAbs) -- Lessens the damping force as more steering input is applied. Damping is much more important when the self-steer force is acting alone with no user input.
    dampingStrength              = dampingStrength * selfSteerStrength -- Also decrease damping at lower speeds, but since the whole thing will be multiplied by `selfSteerStrength` again, I don't quite want it to scale with V^2
    local dampingForce           = subtractTowardsZero(-yawAngularVel, 0.012, true) * steeringCfg["counterForce.damping"] * 0.25 * 0.85 * dampingStrength -- The damping force is based on the negative yaw angular velocity. A small amount is subtracted towards 0 to filter out some noise.

    local selfSteerForce         = selfSteerSmoother:get(clamp(correctionBase, -1.0, 1.0), dt)
    local selfSteerForce2        = selfSteerSmoother2:get(clamp(correctionBase2, -1.0, 1.0), dt)

    selfSteerForce               = clampEased(selfSteerForce  + dampingForce, -selfSteerCap, selfSteerCap, 0.4) * selfSteerStrength * offroadCorrection
    selfSteerForce2              = clampEased(selfSteerForce2 + dampingForce, -selfSteerCap, selfSteerCap, 0.4) * selfSteerStrength * offroadCorrection

    return selfSteerForce, selfSteerForce2
end

-- Lowers the input authority setting for keyboard
local function getEffectiveInputAuthority(filter)
    return (filter == FILTER_KBD) and (steeringCfg["inputAuthority"] * 0.7) or steeringCfg["inputAuthority"]
end

-- local gxSmootherTest = RunningAverage:new(100)

local function processInput(e, dt)

    -- Don't do anything if calibration hasn't finished
    if calibrationStage < 3 then
        electrics.values.steeringUnassisted = 0.0
        return 0.0, 0.0
    end

    -- Initial steering smoothing / speed cap
    local baseSteeringSpeedMult = getBaseSteeringSpeedMult(e)
    local steeringSpeedMult     = getSteeringSpeedMult(e.filter, baseSteeringSpeedMult)
    local ival                  = clamp(steeringSmoother:getWithSpeedMult(e.val, dt, steeringSpeedMult), e.minLimit, e.maxLimit) -- Adjust speed inside get() if needed

    -- ======================== Gathering measurements, assembling data

    local originalInput        = ival
    local originalInputAbs     = clamp(steeringSmootherAbs:getWithSpeedMult(math.abs(e.val), dt, steeringSpeedMult), e.minLimit, e.maxLimit) -- Using a smooth version of the absolute value instead of the absolute of the smooth version. Needs an additional smoother but works better this way.
    local vehicleTransform     = getVehicleTransform()
    local worldVel             = stablePhysicsData.vehVelocity:get() or vec3()
    local localVel             = vehicleTransform:vecToLocal(worldVel)
    localVel.y                 = -localVel.y -- Why is the Y axis backwards on vehicles??
    local localHVel            = localVel:z0():length()
    local localHVelKmh         = localHVel * 3.6
    local localFwdVelClamped   = math.max(0, localVel.y)

    -- Used for fading in/out all the input adjustments at low speed.
    local fadeIn               = smoothstep(inverseLerpClamped(assistFadeMinSpeed, assistFadeMaxSpeed, localHVelKmh, 0, 1))

    local allWheelData         = getWheelDataMultiple(allWheels, vehicleTransform, true, false)
    local steeredWheelData     = filter(allWheelData, function(wheel) return wheel.isSteered end)
    local rearWheelData        = filter(allWheelData, function(wheel) return wheel.isRear end)

    local travelDirectionRad   = math.atan2(localVel.x, localVel.y)
    local yawAngularVel        = stablePhysicsData.yawAngularVel:get() or 0.0

    local avgRearWheelXVel     = average(rearWheelData, fWheelVehXVel) or 0.0
    local steeredSlipAngle     = math.deg(average(steeredWheelData, fWheelSlipAngle) or 0)
    local _rearSlipRaw         = average(rearWheelData, fWheelSlipAngle)
    local rearSlipAngle        = math.deg(_rearSlipRaw or 0)
    local steeredSlipAngleAbs  = math.abs(steeredSlipAngle)
    local rearSlipAngleAbs     = math.abs(rearSlipAngle)
    local rearSlipAngle2       = math.deg(_rearSlipRaw or (-travelDirectionRad)) -- Uses the travel direction as a backup in case the rear slip angle is not available
    local rearSlipAngleAbs2    = math.abs(rearSlipAngle2) -- Uses the travel direction as a backup in case the rear slip angle is not available

    -- 1 if at least one of the steered wheels is grounded, 0 otherwise. Basically a boolean with smoothing to prevent an instant transition.
    local groundedSmooth    = getSteeredWheelGroundedFactor(steeredWheelData, dt)

    -- true if steering outward
    local isCountersteering = (sign(originalInput) ~= sign(guardZero(avgRearWheelXVel)) and originalInputAbs > 1e-6)
    -- 1 when trying to countersteer, 0 otherwise, smooth. The car has to be sliding at a certain angle before steering outward is considered countersteering. This is used to blend between the inward and outward self-steer force.
    local selfSteerBlend    = counterBlendSpeedCap:get(isCountersteering and inverseLerpClampedEased(5, 12, rearSlipAngleAbs2, 0, 1, 0.5) or 0.0, dt)
    -- Same as the above, but starts rising at smaller angles of slide. This is used to blend between the inward and outward steering limit. This allows better manual countersteering in smaller slides compared to using the version above.
    local steeringCapBlend  = manualCounterBlendCap:get(isCountersteering and inverseLerpClampedEased(2, 5, rearSlipAngleAbs2, 0, 1, 1) or 0.0, dt)

    -- 0 if driving offroad, 1 on hard surfaces. Only changed if more than half the wheels change surface type, frozen if at least half the wheels are airborne.
    local hardSurfaceVal        = getHardSurfaceVal(allWheelData, math.floor(#allWheelData * 0.5) + 1, lastHardSurfaceVal)--getHardSurfaceVal(allWheelData, lastHardSurfaceVal)
    lastHardSurfaceVal          = hardSurfaceVal
    local smoothHardSurfaceVal  = surfaceSmoother:get(hardSurfaceVal, dt) -- Smooth version

    -- ======================== Self-steer tendency / countersteer force

    local selfSteerForce, selfSteerForceInward = getBaseSelfSteerForce(
        steeringCfg["counterForce.useSteeredWheels"] and steeredWheelData or rearWheelData,
        localHVelKmh,
        baseSteeringSpeedMult,
        smoothHardSurfaceVal,
        yawAngularVel,
        originalInputAbs,
        dt
    )

    selfSteerForce       = selfSteerForce * groundedSmooth
    selfSteerForceInward = selfSteerForceInward * groundedSmooth

    -- ======================== Calculating the steering limit and final self-steer force

    local effectiveAuthority = getEffectiveInputAuthority(e.filter)
    local steeringLimit      = getSteeringLimit(allWheelData, localFwdVelClamped, effectiveAuthority, dt)

    -- Returns the steering limit and self-steer force that would be in effect if the player was turning inward
    local function processInputInward()
        local selfSteerStrength = clamp01((1.0 - originalInputAbs) * effectiveAuthority + (1.0 - effectiveAuthority))
        local selfSteerLF       = selfSteerLPF:get(selfSteerForce, dt)
        local selfSteerHF       = selfSteerForce - selfSteerLF
        local selfSteer2LF      = selfSteer2LPF:get(selfSteerForceInward, dt)
        local _selfSteerForce   = lerp(selfSteerLF, selfSteer2LF, originalInputAbs) * selfSteerStrength + selfSteerHF

        local offroadOffset     = (1 - smoothHardSurfaceVal) * clamp01(offroadCapIncreaseDeg / steeringLockDeg)
        local limit             = clamp01(steeringLimit + offroadOffset)
        return limit, _selfSteerForce
    end

    -- Returns the steering limit and self-steer force that would be in effect if the player was countersteering
    local function processInputCounter()
        local counterLimitOffset = clamp(1 - rearSlipAngleAbs2 / 180.0, 0.5, 1.0) * steeringCfg["countersteerLimitOffset"]
        local manualCounterCap   = inverseLerpClamped(0, math.max(steeringLockDeg, 8), rearSlipAngleAbs2 + counterLimitOffset, 0, 1)
        manualCounterCap         = clamp01(manualCounterCap - (sign(originalInput) * selfSteerForce))
        return manualCounterCap, selfSteerForce
    end

    -- Calculating the limit and self-steer force both as if the player was turning inward or coutersteering. We'll lerp between them as needed.
    local capInward, selfSteerInward   = processInputInward()
    local capOutward, selfSteerOutward = processInputCounter()
    capOutward                         = math.max(capOutward, capInward)

    -- Final steering limit that will be applied
    local effectiveCap = lerp(capInward, capOutward, steeringCapBlend) + getTorqueSteerAmount(steeredWheelData, dt)

    -- Final self-steer force that will be applied
    local effectiveSelfSteerForce = lerp(selfSteerInward, selfSteerOutward, selfSteerBlend)

    -- Final processed input
    local finalProcessedInput = normalizedSteeringToInput(clamp(ival * effectiveCap + effectiveSelfSteerForce, -1, 1))
    ival = lerp(ival, finalProcessedInput, fadeIn)

    if isVehicleActive and steeringCfg["logData"] and localHVelKmh > 2 then
        print("====================================")
        print(string.format("Estimated steering lock:    %8.3f°", steeringLockDeg))
        print(string.format("Current steering angle:     %8.3f°", 0 - math.deg(getCurrentSteeringAngle(steeredWheelData, vehicleTransform) or 0)))
        print(string.format("Self-steer target:          %8.3f°", effectiveSelfSteerForce * steeringLockDeg))
        print(string.format("Travel Direction:           %8.3f°", 0 - math.deg(travelDirectionRad)))
        print(string.format("Avg steered wheel slip:     %8.3f°", steeredSlipAngle))
        print(string.format("Avg rear wheel slip:        %8.3f°", rearSlipAngle))
        -- print(string.format("Countersteering mode:       %8.1f%%", steeringCapBlend * 100))

        -- print(string.format("Mass:                       %8.3f", vehicleMass()))
        -- print(string.format("Sidewall:                   %8.3f", steeredWheelData[1].sidewall))
        -- print(string.format("Softness:                   %8.3f", wheels.wheels[steeredWheelData[1].index].softnessCoef))
        -- print(string.format("Pressure:                   %8.3f", average(allWheelData, fWheelTirePressureIfNotDeflated) or avgPressureAtStart))
        -- local wheelXPos = {}
        -- for _,w in ipairs(allWheelData) do
        --     table.insert(wheelXPos, vehicleTransform:pointToLocal(w.transformWorld.pos).x)
        -- end
        -- table.sort(wheelXPos, function (a, b)
        --     return a < b
        -- end)
        -- print(string.format("Track width:                %8.3f", wheelXPos[#wheelXPos] - wheelXPos[1]))

        -- print(string.format("Tire width:                 %8.3f", wheels.wheels[steeredWheels[1]].tireWidth))
        -- print(string.format("Tire volume:                %8.3f", wheels.wheels[steeredWheels[1]].tireVolume))

        -- print(string.format("Friction  = %8.3f", obj:getStaticFrictionCoef()))
        -- print(string.format("Wheelbase = %8.3f", wheelbase))
        -- print(string.format("Dfactor   = %8.3f", getDownforceFactor(allWheelData, 3)))
        print(string.format("Current turning radius:    %8.3fm", clamp(math.abs(localHVel / yawAngularVel), 0, 9999.99)))
        -- print(string.format("Best turning radius est.:   %8.3fm", getBestTurnRadius(localHVel, allWheelData, dt)))
        -- gxSmootherTest:add(sensors.gx2 / obj:getGravity())
        -- print(string.format("Gx        = %8.3f", gxSmootherTest:get()))
        -- print(string.format("SPEED: %8.3f", localHVelKmh))

        -- debugWheels(allWheelData)
    end

    -- obj.debugDrawProxy:drawSphere(0.2, vehicleTransform:pointToWorld(wheelsMidPoint), color(255, 0, 255, 255))

    return ival, originalInput
end

-- Performs calibration by setting the inputs to certain values during the calibration phase
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
            input.state[k].filter   = customFilterType
            input.state[k].angle    = 0
            input.state[k].lockType = 0
            return calibrationHydroCap:get(-1, dt)
        elseif calibrationStage == 1 then
            input.state[k].filter   = customFilterType
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

-- Copied from original, modified
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

local function reloadVehicle()
    obj:queueGameEngineLua("scenetree.findObjectById(" .. tostring(obj:getID()) .. "):reload()")
end

-- ======================== Hijacking original functions, injecting custom input processing

local ogPhysicsStep      = onPhysicsStep
local ogInputEvent       = input.event
local ogInputToggleEvent = input.toggleEvent
local ogInputUpdate      = input.updateGFX
local ogInputKbdSteer    = input.kbdSteer
local ogInputPadAccel    = input.padAccelerateBrake

local function restoreFunctionHooks()
    onPhysicsStep            = ogPhysicsStep
    input.event              = ogInputEvent
    input.toggleEvent        = ogInputToggleEvent
    input.updateGFX          = ogInputUpdate
    input.kbdSteer           = ogInputKbdSteer
    input.padAccelerateBrake = ogInputPadAccel
end

local function onEnabled()

    -- BeamMP remote vehicles and AI traffic
    if v.mpVehicleType == "R" or ai.mode ~= "disabled" or not v.data.controller or not v.data.controller[0] then
        disableMod = true
        return
    end

    initialToggleSetting = steeringCfg["enableCustomSteering"]

    if not steeringCfg["enableCustomSteering"] or not v.data.input then return end

    initialize()

    if disableMod then return end -- initialize() can set this to true

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

        -- BeamMP remote vehicles and AI traffic
        if v.mpVehicleType == "R" or ai.mode ~= "disabled" then
            disableMod = true
        end

        -- Processing the input *before* the original input script, then passing it on with FILTER_DIRECT so that the original input system will use it as-is.

        local unassistedInput = 0.0

        for k, e in pairs(M.state) do
            -- local angle = e.angle or 0
            -- if angle > 0 and k == "steering" then e.filter = FILTER_DIRECT end -- enforce direct filter if user has chosen an angle for steering binding

            if k == "steering" then
                if e.filter == FILTER_PAD or e.filter == FILTER_KBD or e.filter == FILTER_KBD2 then
                    input.state[k].val, unassistedInput = processInput(M.state[k], dt)
                else
                    input.state[k].val, unassistedInput = M.state[k].val, M.state[k].val
                end
                input.state[k].filter   = customFilterType
                input.state[k].angle    = 0
                input.state[k].lockType = 0
            end
        end

        for k, e in pairs(input.state) do
            input.state[k].val = calibrationInterject(input.state[k], dt, k, e.filter)
        end

        ogInputUpdate(dt)

        electrics.values.steeringUnassisted = unassistedInput -- Setting this here to overwrite what the original script set this to (the assisted value)

        if disableMod then
            restoreFunctionHooks() -- Disabling the mod completely if something goes wrong
        end
    end
end

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

local function setConfig(cfg)
    -- if disableMod then return end

    local firstCall = false
    local newConfig = nil

    if steeringCfg == nil then
        newConfig = cfg
        firstCall = true
    else
        newConfig = mergeObjects(steeringCfg, cfg)
    end

    steeringCfg = newConfig

    if firstCall then
        -- Initialize everything the first time the config is set
        onEnabled()
    end
end

local function onPlayersChanged(hasPlayer)
    isVehicleActive = hasPlayer
    if not steeringCfg then return end
    if hasPlayer then
        -- Has to be called from game engine lua because of a bug
        obj:queueGameEngineLua("guihooks.trigger('advancedSteeringSetDisplayedSettings', " .. serialize({ ["settings"] = steeringCfg, ["dirty"] = (initialToggleSetting ~= steeringCfg["enableCustomSteering"] and initialToggleSetting ~= nil) }) .. ")")
    end
end

M.onReset           = reset
M.onPlayersChanged  = onPlayersChanged

M.reloadVehicle     = reloadVehicle
M.setConfig         = setConfig

return M