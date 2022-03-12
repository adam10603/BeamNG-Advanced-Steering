-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt




-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- CUSTOM STEERING DATA AND HELPERS <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<




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

  for _,tVal in ipairs(t) do
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
  return (dataSum ~= nil) and (dataSum / sumCount) or nil
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

-- Custom steering variables

local steeringCfg               = jsonReadFile("lua/vehicle/better_steering_config.json")
local originalPhysicsStep       = onPhysicsStep -- hijacking that bitch for stable physics readings
local physicsSmoothingWindow    = 40
local counterFadeMinSpeed       = 5.0  -- km/h
local counterFadeMaxSpeed       = 15.0 -- km/h
local dampingFadeMinSpeed       = 20.0 -- km/h
local dampingFadeMaxSpeed       = 50.0 -- km/h
local steeredWheels             = {} -- Indicies of steered wheel(s)
local rearWheels                = {} -- Indicies of the rearmost wheel(s) by position
local allWheels                 = {} -- Indicies of all wheels
local steeringHydroIndex        = -1
local customPhysicsStep         -- Forward declaration
local calibrationStage          = 0 -- Used during calibration
local steeringCurveExp          = 0.9 -- Default fallback value
local steeringLockRad           = math.rad(35) -- Default fallback value
local steeringLockDeg           = 35 -- Default fallback value
local calibrationHydroCap       = newTemporalSmoothing(3, 3, 3, 0) -- Hydros already have their own speed cap, but some are too fast for reliable calibration

local defaultConfig             = {
  ["enableCustomSteering"] = true,

  ["counterForce"] = {
      ["useSteeredWheels"] = true,
      ["response"] = 0.375,
      ["maxAngle"] = 8.0,
      ["inputAuthority"] = 0.35,
      ["damping"] = 0.6
  },

  ["steeringSpeed"] = 1.0,
  ["relativeSteeringSpeed"] = true,
  ["slipTargetOffset"] = 1.5,
  ["maxAdaptiveLimitAdjustment"] = 1.0,
  ["logData"] = false
}

-- Clamping config values or using default values if they can't be read
if not steeringCfg then
  steeringCfg = defaultConfig
else
  if not steeringCfg.counterForce then
    steeringCfg.counterForce = defaultConfig.counterForce
  else
    steeringCfg.counterForce.response        = clamp01(steeringCfg.counterForce.response or defaultConfig.counterForce.response)
    steeringCfg.counterForce.maxAngle        = clamp(steeringCfg.counterForce.maxAngle or defaultConfig.counterForce.maxAngle, 0, 20)
    steeringCfg.counterForce.inputAuthority  = clamp01(steeringCfg.counterForce.inputAuthority or defaultConfig.counterForce.inputAuthority)
    steeringCfg.counterForce.damping         = clamp01(steeringCfg.counterForce.damping or defaultConfig.counterForce.damping)
  end
  steeringCfg.steeringSpeed               = clamp(steeringCfg.steeringSpeed or defaultConfig.steeringSpeed, 0, 10)
  steeringCfg.slipTargetOffset            = clamp(steeringCfg.slipTargetOffset or defaultConfig.slipTargetOffset, -3, 3)
  steeringCfg.maxAdaptiveLimitAdjustment  = clamp(steeringCfg.maxAdaptiveLimitAdjustment or defaultConfig.maxAdaptiveLimitAdjustment, 0, 3)
end

-- =================== Custom steering state (things that (might) need to be reset)

local steeringSmoother          = SmoothTowards:new(3.5, 0.15, -1, 1, 0)
local counterSmoother           = SmoothTowards:new(7, 0.15, -1, 1, 0) -- Only for the assist
local limitBlendOffsetSpeedCap  = newTemporalSmoothing(0.2, 0.2, 0.2, 0) -- 0.2
local isGroundedSpeedCap        = newTemporalSmoothing(4.0, 4.0, 4.0, 1)
local inputDirectionSpeedCap    = newTemporalSmoothing(4.0, 4.0, 4.0, 0)
local limitBlendOffset          = 0

local stablePhysicsData = {
  yawAngularVel   = RunningAverage:new(physicsSmoothingWindow),
  vehVelocity     = RunningAverage:new(physicsSmoothingWindow),
  wheelVelocities = {}
}

-- ===================

local function resetCustomSteering()
  steeringSmoother:reset()
  counterSmoother:reset()
  limitBlendOffsetSpeedCap:reset()
  isGroundedSpeedCap:reset()
  inputDirectionSpeedCap:reset()

  limitBlendOffset = 0

  stablePhysicsData.yawAngularVel:reset()
  stablePhysicsData.vehVelocity:reset()

  for i = 0, wheels.wheelCount - 1, 1 do
    if stablePhysicsData.wheelVelocities[i] ~= nil then
      stablePhysicsData.wheelVelocities[i]:reset()
    else
      stablePhysicsData.wheelVelocities[i] = RunningAverage:new(physicsSmoothingWindow)
    end
  end
end

local function initCustomSteering()

  steeredWheels = {}
  rearWheels    = {}

  if wheels.wheelCount == 0 then
    return
  end

  resetCustomSteering()

  local tmpAllWheels = {}

  local foundSteeredWheels = false

  -- Helper function to find steered wheels. Could be improved, but so far this is the only way I found to detect them.
  local function isWheelSteered(index)
    return (v.data.wheels[index].steerAxisUp ~= nil or v.data.wheels[index].steerAxisDown ~= nil)
  end

  for i = 0, wheels.wheelCount - 1 do
    table.insert(allWheels, i)

    local isSteered = isWheelSteered(i)
    foundSteeredWheels = foundSteeredWheels or isSteered
    local _pos = average({ obj:getNodePositionRelative(wheels.wheels[i].node1), obj:getNodePositionRelative(wheels.wheels[i].node2) })
    _pos.y = -_pos.y
    table.insert(tmpAllWheels, {
      index = i,
      pos = _pos,
      steered = isSteered
    })
  end

  -- Sorting by local Y position ([1] and [2] will be the rear wheels on a 4-wheel car)
  table.sort(tmpAllWheels, function (a, b)
    return a.pos.y < b.pos.y
  end)

  local frontmostY  = tmpAllWheels[#tmpAllWheels].pos.y
  local rearmostY   = tmpAllWheels[1].pos.y

  -- In case `isWheelSteered()` couldn't detect the steered wheels, we'll use the front wheels.
  if not foundSteeredWheels then
    for i=#tmpAllWheels, 1, -1 do
      if tmpAllWheels[i].pos.y >= (frontmostY - 0.1) then
        tmpAllWheels[i].steered = true
      else
        break
      end
    end
  end

  -- Saving steered wheel and rear wheel indicies to global arrays
  for _,wheel in ipairs(tmpAllWheels) do
    if wheel.steered then
      table.insert(steeredWheels, wheel.index)
    end

    if wheel.pos.y <= (rearmostY + 0.1) then
      table.insert(rearWheels, wheel.index)
    end
  end

  onPhysicsStep = customPhysicsStep
end

-- Other helpers

-- Determines if `val` is between `A` and `B` (inclusive), regardless if `A` or `B` are larger.
local function isBetween(val, A, B)
  return (val >= math.min(A, B)) and (val <= math.max(A, B))
end

-- Returns the angle between two vectors in radians.
local function angleBetween(vecA, vecB)
  return math.acos((vecA.x * vecB.x + vecA.y * vecB.y + vecA.z * vecB.z) / (vecA:length() * vecB:length()))
end

-- Determines if the array `t` contains the value `val`.
local function contains(t, val)
  for i,tVal in ipairs(t) do
    if tVal == val then
      return true
    end
  end
  return false
end

-- Returns an array with only the elements of the array `t` that satisfy `pred(element)`.
local function filter(t, pred)
  local ret = {}
  for _,tVal in ipairs(t) do
    if pred(tVal) then
      table.insert(ret, tVal)
    end
  end
  return ret
end

-- Returns an array such that each element is equal to `fn(element)` of the corresponding element in the array `t`.
local function transform(t, fn)
  local ret = {}
  for i,tVal in ipairs(t) do
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
  for _,tVal in ipairs(t) do
    if pred(tVal) then
      ret = ret + 1
    end
  end
  return ret
end

-- 4PL coefficients for a speed (km/h) vs. input curve, for an estimated 6° slip angle on the steered wheels.
local lowSlipInputCoeffs = {
  target = 6, -- Just to keep track of things
  a = 1.220429,
  b = 2.885174,
  c = 29.89848,
  d = 0.1235478
}

-- 4PL coefficients for a speed (km/h) vs. input curve, for an estimated 12° slip angle on the steered wheels.
local highSlipInputCoeffs = {
  target = 12, -- Just to keep track of things
  a = 1.234133,
  b = 3.257421,
  c = 32.0843,
  d = 0.3285247
}

-- 4PL coefficients for a speed (km/h) vs. target slip angle estimate curve.
-- Used as an initial approximation before further adjustments are made based on slip angle readings.
local targetSlipCoeffs = {
  a = 10.30405,
  b = 2.578546,
  c = 63.97519,
  d = 6.728409
}

local function eval4PL(x, coefficients)
  return coefficients.d + (coefficients.a - coefficients.d) / (1 + math.pow(x / coefficients.c, coefficients.b))
end

-- local function eval2ndOrderPolynomial(x, coefficients)
--   return coefficients.a + (coefficients.b * x) + (coefficients.c * x * x)
-- end

-- -- Positive result only
-- local function evalInverse2ndOrderPolynomial(y, coefficients)
--   if coefficients.c == 0 then
--     return (y - coefficients.a) / coefficients.b
--   else
--     return (math.sqrt(4 * coefficients.c * (y - coefficients.a) + (coefficients.b * coefficients.b)) - coefficients.b) / (2 * coefficients.c)
--   end
-- end

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

-- Returns the vehicle's current `Transform`.
local function getVehicleTransform()
  -- local pos = obj:getPosition()
  -- local rot = quat(obj:getRotation())
  -- local forward = rot * vec3(0,1,0)
  -- local up      = rot * vec3(0,0,1)
  -- return Transform:new(forward, up, pos)
  return Transform:new(-obj:getDirectionVector(), obj:getDirectionVectorUp(), obj:getPosition())
end

-- Returns the target blend between the low slip input estimate and high slip input estimate.
-- This blend can be used to achieve a certain target slip angle.
local function getInputTargetBlend(kmh, slipCoeffs, lowSlipTarget, highSlipTarget)
  local targetSlipAngle = eval4PL(kmh, slipCoeffs) + 0.25 + steeringCfg.slipTargetOffset
  return clamp(inverseLerp(lowSlipTarget, highSlipTarget, targetSlipAngle), -0.5, 1.5)
end

-- Indicates if the target slip angle should be adjusted based on the current driving conditions.
local function shouldAdjustLimitBlendOffset(originalInput, blendOffsetRaw, steeredSlipAbs, originalTargetSlip, rearSlip, localHVelKmh)
  return  (math.abs(originalInput) >= 0.99 or blendOffsetRaw < -0.1) and
          (steeredSlipAbs <= originalTargetSlip * 3) and
          (sign(originalInput) ~= sign(rearSlip) and math.abs(rearSlip) > 2 and math.abs(rearSlip) < 30) and
          (localHVelKmh > 20.0)
end

local function isWheelBroken(i)
  return wheels.wheels[i].isBroken
end

local function fWheelWorldVel(wheelData)
  return wheelData.velocityWorld
end

local function fWheelSlipAngle(wheelData)
  return wheelData.slipAngle
end

local function fWheelSlipAngleIfGrounded(wheelData)
  if wheelData.isGrounded then
    return wheelData.slipAngle
  else
    return nil
  end
end

local function fWheelVehXVelIfGrounded(wheelData)
  if wheelData.isGrounded then
    return wheelData.velocityVehSpc.x
  else
    return nil
  end
end

local function fWheelVehXVel(wheelData)
  return wheelData.velocityVehSpc.x
end

-- Returns data about a specific wheel
local function getWheelData(wheelIndex, vehTransform, ignoreAirborne)
  local grounded = wheels.wheels[wheelIndex].contactMaterialID1 >= 0 or wheels.wheels[wheelIndex].contactMaterialID2 >= 0

  if ignoreAirborne and not grounded then
    return nil
  end

  local node1Pos    = obj:getNodePositionRelative(wheels.wheels[wheelIndex].node1)
  local node2Pos    = obj:getNodePositionRelative(wheels.wheels[wheelIndex].node2)
  local normal      = (node2Pos - node1Pos):normalized()
  local wFwdVec     = vehTransform:vecToWorld(normal:cross(vec3(0,0,1)):normalized() * wheels.wheels[wheelIndex].wheelDir)
  local transform   = Transform:new(wFwdVec, vehTransform.upVec, vehTransform:pointToWorld(node1Pos * 0.5 + node2Pos * 0.5))
  local velWorld    = stablePhysicsData.wheelVelocities[wheelIndex]:get() or vec3()
  local velWheelSpc = transform:vecToLocal(velWorld)
  local velVehSpc   = vehTransform:vecToLocal(velWorld)

  return {
    index             = wheelIndex,
    isSteered         = contains(steeredWheels, wheelIndex),
    isRear            = contains(rearWheels, wheelIndex),
    isGrounded        = grounded,
    transformWorld    = transform,
    velocityWorld     = velWorld,
    velocityVehSpc    = velVehSpc,
    velocityWheelSpc  = velWheelSpc,
    slipAngle         = math.atan(velWheelSpc.x / velWheelSpc.y)
    -- rimRadius         = wheels.wheels[wheelIndex].hubRadius,
    -- tireRadius        = wheels.wheels[wheelIndex].radius,
    -- sidewall          = wheels.wheels[wheelIndex].radius - wheels.wheels[wheelIndex].hubRadius,
    -- tireWidth         = wheels.wheels[wheelIndex].tireWidth
  }
end

-- Returns an array of wheel data objects for an array of wheel indicies
local function getWheelDataMultiple(wheelIndicies, vehTransform, ignoreBroken, ignoreAirborne)
  local ret = {}

  for _,i in ipairs(wheelIndicies) do
    if (ignoreBroken and not isWheelBroken(i)) or not ignoreBroken then
      local data = getWheelData(i, vehTransform, ignoreAirborne)
      if data ~= nil then
        table.insert(ret, data)
      end
    end
  end

  return ret
end

-- Adjusts the blend offset used to determine the target slip angle, based on the current driving conditions.
local function adjustLimitBlendOffset(steeredWheelData, steeredSlipAngleAbs, inputLimitBlend, originalInput, originalTargetSlip, rearSlipAngle, localHVelKmh, dt)
  if #steeredWheelData == 0 then
    limitBlendOffset = limitBlendOffsetSpeedCap:get(0, dt)
  else
    local blendFeedback       = inverseLerp(lowSlipInputCoeffs.target, highSlipInputCoeffs.target, steeredSlipAngleAbs)
    local maxBlendAdjustment  = steeringCfg.maxAdaptiveLimitAdjustment / (highSlipInputCoeffs.target - lowSlipInputCoeffs.target)
    local blendOffsetRaw      = clamp(inputLimitBlend - blendFeedback, -maxBlendAdjustment, maxBlendAdjustment)

    if shouldAdjustLimitBlendOffset(originalInput, blendOffsetRaw, steeredSlipAngleAbs, originalTargetSlip, rearSlipAngle, localHVelKmh) then
      limitBlendOffset = limitBlendOffsetSpeedCap:get(blendOffsetRaw, dt)
    end
  end
end

local function getSteeringCurveExponent(Vx, Vy)
  Vy = clamp(Vy, 0.001, 0.999) -- Otherwise the function might do dumb shit
  return math.log(1.0 - Vy, 10) / math.log(1.0 - Vx, 10)
end

local function getSteeringHydroStateNormalized()
  if steeringHydroIndex ~= -1 then
    local state       = hydros.hydros[steeringHydroIndex].state
    local center      = hydros.hydros[steeringHydroIndex].center
    local lowerLimit  = math.min(hydros.hydros[steeringHydroIndex].inLimit, hydros.hydros[steeringHydroIndex].outLimit)
    local higherLimit = math.max(hydros.hydros[steeringHydroIndex].inLimit, hydros.hydros[steeringHydroIndex].outLimit)
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
  return 1.0 - math.pow(1.0 - input, steeringCurveExp)
end

local function normalizedSteeringToInput(steeringAngleNormalized)
  return 1.0 - math.pow(1.0 - steeringAngleNormalized, 1.0 / steeringCurveExp)
end

local function getCurrentSteeringAngle(steeredWheelData, vehicleTransform)
  return average(steeredWheelData, function(wheelData)
    return angleBetween(vec3(0,-1,0), vehicleTransform:vecToLocal(wheelData.transformWorld.fwdVec):z0())
  end)
end

local prevAngle             = 0
local hydroSignAtXY         = 0
local hydroSignAtLock       = 0
local calibrationDelay      = 0 -- Delays measuring the steering lock by 1 "frame"
local calibrationExpXY      = {0,0} -- X,Y point for determining the exponent for the function that converts between input and steering angle
local calibratedLockRad     = 0 -- Measured steering lock
local calibrationDuration   = 0 -- For abandoning calibration if it takes too long

customPhysicsStep = function(dtSim)
  originalPhysicsStep(dtSim)

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
    calibrationDuration = calibrationDuration + dtSim
    
    if calibrationDuration > 2 then
      print("WARNING: Steering calibration was canceled because it took longer than expected. Try reloading the vehicle (Ctrl+R) on a relatively flat surface!")
      calibrationStage = 3
      return
    end

    local hydroState    = getSteeringHydroStateNormalized()

    if hydroState == nil then
      -- Hydro state can't be read, skipping calibration
      calibrationStage = 3
      return
    end

    local hydroSign     = sign(hydroState)
    local hydroStateAbs = math.abs(hydroState)
    local vehTransform  = getVehicleTransform()
    local wheelData     = getWheelDataMultiple(steeredWheels, vehTransform, true, false) -- // TODO steered or front whatever, all wheel steering
    local currentAngle  = getCurrentSteeringAngle(wheelData, vehTransform)

    if currentAngle == nil then
      -- In case steered wheels are somehow broken right after spawning, skip calibration
      calibrationStage = 3
      return
    end

    if math.abs(currentAngle - prevAngle) > 1e-6 then -- Only do the math if the angle changes (doesn't change on every physics step)
      prevAngle = currentAngle

      if hydroStateAbs > 0.5 and hydroSign ~= hydroSignAtXY then
        hydroSignAtXY         = hydroSign
        calibrationExpXY[1]   = calibrationExpXY[1] + hydroStateAbs * 0.5
        calibrationExpXY[2]   = calibrationExpXY[2] + currentAngle * 0.5
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
    calibrationExpXY[2] = calibrationExpXY[2] / calibratedLockRad + 0.012 -- The curve usually ends up slightly low too
    local exponent      = getSteeringCurveExponent(calibrationExpXY[1], calibrationExpXY[2])

    if exponent < 0.7 or exponent > 1.3 then
      print("WARNING: Steering calibration readings seem abnormal. Try reloading the vehicle (Ctrl+R) on a relatively flat surface!")
    end
  
    steeringCurveExp  = clamp(exponent, 0.7, 1.3)
    steeringLockRad   = calibratedLockRad
    steeringLockDeg   = math.deg(calibratedLockRad)

    if steeringCfg.logData then
      print("======== Steering calibration results ========")
      print(string.format("Steering lock:            %.4f°", steeringLockDeg))
      print(string.format("Steering curve exponent:  %.4f", steeringCurveExp))
    end
  end
end




-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- END OF CUSTOM STEERING DATA AND HELPERS >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>




local M = {}

M.keys = {} -- Backwards compatibility
local MT = {} -- metatable
local keysDeprecatedWarned
MT.__index = function(tbl, key)
  if not keysDeprecatedWarned then
    log("E", "", "Vehicle "..dumps(vehiclePath).." is using input.keys["..dumps(key).."]. This may be removed in the next update; the creator of that vehicle should instead use \"vehicle-specific bindings\".")
    keysDeprecatedWarned = true
  end
  return rawget(M.keys, key)
end
setmetatable(M.keys, MT)
M.state = {}
M.filterSettings = {}
M.lastFilterType = -1

local filterTypes = {[FILTER_KBD] = "Keyboard", [FILTER_PAD] = "Gamepad", [FILTER_DIRECT] = "Direct", [FILTER_KBD2] = "KeyboardDrift"}

--set kbd initial rates (derive these from the menu options eventually)
local kbdInRate = 2.2
local kbdOutRate = 1.6

--set kbd understeer limiting effect (A value of 1 will achieve min steering speed of 0*kbdOutRate)
local kbdUndersteerMult = 0.7
--set kbd oversteer help effect (A value of 1 will achieve max steering speed of 2*kbdOutRate)
local kbdOversteerMult = 0.7

local rateMult = nil
local kbdOutRateMult = 0
local kbdInRateMult = 0
local padSmoother = nil
local kbdSmoother = nil
local vehicleSteeringWheelLock = 450
local handbrakeSoundEngaging    = nil
local handbrakeSoundDisengaging = nil
local handbrakeSoundDisengaged  = nil
local inputNameCache = {}

local gxSmoothMax = 0
local gx_Smoother = newTemporalSmoothing(4) -- it acts like a timer

local min, max, abs = math.min, math.max, math.abs

local function init()
  --inRate (towards the center), outRate (away from the center), autoCenterRate, startingValue
  M.state = {
    steering = { val = 0, filter = 0,
      smootherKBD = newTemporalSmoothing(),
      smootherPAD = newTemporalSmoothing(),
      minLimit = -1, maxLimit = 1 },
    throttle = { val = 0, filter = 0,
      smootherKBD = newTemporalSmoothing(3, 3, 1000, 0),
      smootherPAD = newTemporalSmoothing(100, 100, nil, 0),
      minLimit =  0, maxLimit = 1 },
    brake = { val = 0, filter = 0,
      smootherKBD = newTemporalSmoothing(3, 3, 1000, 0),
      smootherPAD = newTemporalSmoothing(100, 100, nil, 0),
      minLimit =  0, maxLimit = 1 },
    parkingbrake = { val = 0, filter = 0,
      smootherKBD = newTemporalSmoothing(10, 10, nil, 0),
      smootherPAD = newTemporalSmoothing(10, 10, nil, 0),
      minLimit =  0, maxLimit = 1 },
    clutch = { val = 0, filter = 0,
      smootherKBD = newTemporalSmoothing(10, 20, 20, 0),
      smootherPAD = newTemporalSmoothing(10, 10, nil, 0),
      minLimit =  0, maxLimit = 1 },
  }
end
local function initSecondStage()
  --scale rates based on steering wheel degrees
  local foundSteeringHydro = false

  if hydros then
    for i, h in pairs(hydros.hydros) do
      --check if it's a steering hydro
      if h.inputSource == "steering_input" then


        steeringHydroIndex = i


        foundSteeringHydro = true
        --if the value is present, scale the values
        if h.steeringWheelLock then
          vehicleSteeringWheelLock = abs(h.steeringWheelLock)
          break
        end
      end
    end
  end

  if v.data.input and v.data.input.steeringWheelLock ~= nil then
    vehicleSteeringWheelLock = v.data.input.steeringWheelLock
  elseif foundSteeringHydro then
    if v.data.input == nil then v.data.input = {} end
    v.data.input.steeringWheelLock = vehicleSteeringWheelLock
  end

  for wi,wd in pairs(wheels.wheels) do
    if wd.parkingTorque and wd.parkingTorque > 0 then
      handbrakeSoundEngaging    = handbrakeSoundEngaging or sounds.createSoundscapeSound('handbrakeEngaging')
      handbrakeSoundDisengaging = handbrakeSoundDisengaging or sounds.createSoundscapeSound('handbrakeDisengaging')
      handbrakeSoundDisengaged  = handbrakeSoundDisengaged or sounds.createSoundscapeSound('handbrakeDisengaged')
      break
    end
  end

  rateMult = 5 / 8
  if vehicleSteeringWheelLock ~= 1 then
    rateMult = 450 / vehicleSteeringWheelLock
  end

  kbdOutRateMult = min(kbdOutRate * rateMult, 2.68)
  kbdInRateMult = min(kbdInRate * rateMult, 3.68)
  padSmoother = newTemporalSmoothing()
  kbdSmoother = newTemporalSmoothing()

  M.reset()

  if steeringCfg.enableCustomSteering then
    initCustomSteering()
  end

end

local function dynamicInputRateKbd(v, dt, curx)
  local signv = sign(v)
  local signx = sign(curx)
  local gx = sensors.gx
  local signgx = sign(gx)
  local absgx = abs(gx)

  local gs = kbdSmoother:getWithRateUncapped(0, dt, 3)
  if absgx > gs then
    gs = absgx
    kbdSmoother:set(gs)
  end

  -- centering by lifting key:
  if v == 0 then
    return kbdInRateMult
  end

  local g = abs(obj:getGravity())
  --reduce steering speed only when steered into turn and pressing key into direction of turn (help limit the understeer)
  if signx == -signgx and signv == -signgx then
    kbdSmoother:set(0)
    local gLateral = min(absgx, g) / (g + 1e-30)
    return kbdOutRateMult - (kbdOutRateMult * kbdUndersteerMult * gLateral)
  end

  --increase steering speed when pressing key out of direction of turn (help save the car from oversteer)
  if signv == signgx then
    local gLateralSmooth = min(gs, g) / (g + 1e-30)
    return kbdOutRateMult + (kbdOutRateMult * kbdOversteerMult * gLateralSmooth)
  end

  return kbdOutRateMult
end

local function dynamicInputRateKbd2(v, curx)
  local signv = sign(v)
  local signx = sign(curx)
  local gx = sensors.gx
  local signgx = sign(gx)
  local mov = v-curx
  local signmov = sign(mov)
  local speed = electrics.values['wheelspeed']

  -- centering by lifting key:
  if v == 0 then return kbdInRateMult end

  -- centering by pressing opposite key:
  if signmov ~= signx then return kbdInRateMult * 1.5 end

  -- recovering from oversteer:
  if signv == signgx or signmov == signgx or signx == signgx then return kbdInRateMult * 1.8 end

  -- not enough data, fallback case
  if speed == nil then return kbdInRateMult end

  -- regular steering:
  speed = abs(speed)
  local g = abs(obj:getGravity())
  return kbdOutRateMult * (1.4 - min(speed / 12, 1) * min(gxSmoothMax, g) / (g + 1e-30)) / 1.4
end

local function dynamicInputRatePad(v, dt, curx)
  local ps = padSmoother:getWithRateUncapped(0, dt, 0.2)
  local diff = v - curx
  local absdiff = abs(diff) * 0.9
  if absdiff > ps then
    ps = absdiff
    padSmoother:set(ps)
  end

  local baserate = (min(absdiff * 1.7, 3) + ps + 0.35)
  if diff * sign(curx) < 0 then
    return min(baserate * 2, 5) * rateMult
  else
    return baserate * rateMult
  end
end

local lockTypeWarned
local function updateGFX(dt)
  gxSmoothMax = gx_Smoother:getUncapped(0, dt)
  local absgx = abs(sensors.gx)
  if absgx > gxSmoothMax then
    gx_Smoother:set(absgx)
    gxSmoothMax = absgx
  end

  -- map the values
  for k, e in pairs(M.state) do
    local ival = 0
    if e.filter == FILTER_DIRECT then
      e.angle = e.angle or 0
      e.lockType = e.angle <= 0 and 0 or e.lockType or 0
      if e.lockType == 0 then
        -- 1:N relation in the whole range
        ival = e.val
      else
        local vehicleAngle = vehicleSteeringWheelLock * 2 -- convert from jbeam scale (half range) to input scale (full range)
        local relation = e.angle / vehicleAngle
        if e.lockType == 2 then
          -- 1:1 relation in the first half
          ival = e.val * relation + sign(e.val) * square(2*max(0.5,abs(e.val))-1) * max(0, 1 - relation) -- ival = linear + nonlinear
        elseif e.lockType == 1 then
          -- 1:1 relation in the whole range
          ival = clamp(e.val * relation, -1, 1)
        else
          if not lockTypeWarned then
            lockTypeWarned = true
            log("E", "", "Unsupported steering lock type: "..dumps(e.lockType))
          end
        end
      end
    else
      if steeringCfg.enableCustomSteering and k == "steering" and (e.filter ~= FILTER_DIRECT) then
        local speedMult = steeringCfg.steeringSpeed * ((electrics.values.airspeed / 150) + 1) -- airspeed thing is temporary
        if steeringCfg.relativeSteeringSpeed then
          speedMult = speedMult * 580 / vehicleSteeringWheelLock
        end
        if e.filter == FILTER_KBD then
          speedMult = speedMult * 0.5
        end
        steeringSmoother.range = e.maxLimit - e.minLimit -- Should be correct anyway, but just in case
        ival = steeringSmoother:getWithSpeedMult(e.val, dt, speedMult)
      else
        ival = min(max(e.val, -1), 1)
        if e.filter == FILTER_PAD then -- joystick / game controller - smoothing without autocentering
          if k == 'steering' then
            ival = e.smootherPAD:getWithRate(ival, dt, dynamicInputRatePad(ival, dt, e.smootherPAD:value()))
          else
            ival = e.smootherPAD:get(ival, dt)
          end
        elseif e.filter == FILTER_KBD then
          if k == 'steering' then
            ival = e.smootherKBD:getWithRate(ival, dt, dynamicInputRateKbd(ival, dt, e.smootherKBD:value()))
          else
            ival = e.smootherKBD:get(ival, dt)
          end
        elseif e.filter == FILTER_KBD2 then
          if k == 'steering' then
            ival = e.smootherKBD:getWithRate(ival, dt, dynamicInputRateKbd2(ival, e.smootherKBD:value()))
          else
            ival = e.smootherKBD:get(ival, dt)
          end
        end
      end
    end

    if not steeringCfg.enableCustomSteering and k == "steering" then
      local f = M.filterSettings[e.filter] -- speed-sensitive steering limit
      if playerInfo.anyPlayerSeated and not ai.isDriving() then
        if e.filter ~= M.lastFilterType then
          obj:queueGameEngineLua(string.format('extensions.hook("startTracking", {Name = "ControlsUsed", Method = "%s"})', filterTypes[e.filter]))
          M.lastFilterType = e.filter
        end
      end
      ival = ival * min(1, max(f.limitMultiplier, f.limitM * electrics.values.airspeed + f.limitB ))
    end

    ival = min(max(ival, e.minLimit), e.maxLimit)




    -- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    -- CUSTOM STEERING MAIN LOGIC <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    -- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<




    -- Preventing the player from moving the vehicle during calibration
    if steeringCfg.enableCustomSteering and calibrationStage < 3 then
      if k == "throttle" then
        ival = 0
      elseif k == "parkingbrake" then
        ival = 1
      elseif k == "brake" then
        ival = 0
      elseif k == "steering" and e.filter == FILTER_DIRECT then
        calibrationStage = 3
      end
    end

    if steeringCfg.enableCustomSteering and wheels.wheelCount > 0 and k == "steering" and (e.filter ~= FILTER_DIRECT) then

      if calibrationStage < 3 then

        -- Calibration
        if steeringHydroIndex ~= -1 then
          if calibrationStage == 0 then
            ival = calibrationHydroCap:get(-1, dt)
          elseif calibrationStage == 1 then
            ival = calibrationHydroCap:get(1, dt)
          end
        end

      else

        -- ======================== Gathering measurements, assembling data

        local originalInput         = ival
        local originalInputAbs      = math.abs(ival)
        local vehicleTransform      = getVehicleTransform()
        local worldVel              = stablePhysicsData.vehVelocity:get() or vec3()
        local localVel              = vehicleTransform:vecToLocal(worldVel)
        localVel.y                  = -localVel.y -- Why is the Y axis backwards on vehicles??
        local localHVelKmh          = localVel:z0():length() * 3.6

        -- Used for fading in/out all the input adjustments at low speed.
        local fadeIn                = smoothstep(clamp01(inverseLerp(counterFadeMinSpeed, counterFadeMaxSpeed, localHVelKmh)))
        -- Fades in/out the damping force at low to moderate speeds.
        local dampingFade           = smoothstep(clamp01(inverseLerp(dampingFadeMinSpeed, dampingFadeMaxSpeed, localHVelKmh)))

        local clampedForwardKmh     = math.max(0, localVel.y * 3.6)

        local allWheelData          = getWheelDataMultiple(allWheels, vehicleTransform, true, false)
        local steeredWheelData      = filter(allWheelData, function(wheel) return wheel.isSteered end)
        local rearWheelData         = filter(allWheelData, function(wheel) return wheel.isRear end)

        local steeredSlipAngle      = math.deg(average(steeredWheelData, fWheelSlipAngleIfGrounded) or 0)
        local steeredSlipAngleAbs   = math.abs(steeredSlipAngle)

        local rearSlipAngle         = math.deg((average(rearWheelData, fWheelSlipAngleIfGrounded) or 0))
        local rearSlipAngleAbs      = math.abs(rearSlipAngle)

        local travelDirectionRad    = math.atan2(localVel.x, localVel.y)
        local yawAngularVel         = stablePhysicsData.yawAngularVel:get() or 0.0

        local avgRearWheelXVelRaw   = average(rearWheelData, fWheelVehXVel)
        local avgRearWheelXVel      = avgRearWheelXVelRaw or 0.0

        -- 1 when trying to turn inwards, 0 otherwise. Basically a boolean with smoothing to prevent an instant transition.
        local inputDirectionSmooth  = smoothstep(inputDirectionSpeedCap:get((sign(originalInput) == sign(avgRearWheelXVel) and originalInputAbs > 0.1) and 1.0 or 0.0, dt))

        -- ======================== Limiting steering with speed

        -- Baseline input limit estimate
        local inputLimitLow       = eval4PL(clampedForwardKmh, lowSlipInputCoeffs)
        local inputLimitHigh      = eval4PL(clampedForwardKmh, highSlipInputCoeffs)
        local inputLimitBlend     = getInputTargetBlend(clampedForwardKmh,
                                                        targetSlipCoeffs,
                                                        lowSlipInputCoeffs.target,
                                                        highSlipInputCoeffs.target)
        local originalTargetSlip  = lerp(lowSlipInputCoeffs.target, highSlipInputCoeffs.target, inputLimitBlend)

        -- Adjusting the limit based on slip angle readings
        if steeringCfg.maxAdaptiveLimitAdjustment > 0 then
          adjustLimitBlendOffset(steeredWheelData, steeredSlipAngleAbs, inputLimitBlend, originalInput, originalTargetSlip, rearSlipAngle, localHVelKmh, dt)
        end

        local inputLimitFinal = clamp01(lerp(inputLimitLow, inputLimitHigh, inputLimitBlend + limitBlendOffset)) -- lerp() * carCorrection ?

        -- Applying the steering limit.
        ival = lerp(ival, ival * inputLimitFinal, fadeIn)

        -- ======================== Countersteer assist

        local wheelData           = steeringCfg.counterForce.useSteeredWheels and steeredWheelData or rearWheelData
        local avgSourceWheelXVel  = steeringCfg.counterForce.useSteeredWheels and (average(wheelData, fWheelVehXVel) or localVel.x) or (avgRearWheelXVelRaw or localVel.x)

        -- 1 if at least one of the front wheels is grounded, 0 otherwise. Basically a boolean with smoothing to prevent an instant transition.
        local groundedSmooth      = 0.0

        if countIf(steeredWheelData, function(wheel) return not wheel.isGrounded end) == #steeredWheelData then
          groundedSmooth = isGroundedSpeedCap:get(0, dt)
        else
          groundedSmooth = isGroundedSpeedCap:get(1, dt)
        end

        local carCorrection       = 31.5 / steeringLockDeg -- // TODO maybe not use this?
        local referenceXVel       = 50 - (40 * steeringCfg.counterForce.response)
        local correctionBase      = clamp(-avgSourceWheelXVel / referenceXVel * carCorrection, -1, 1)

        local dampingStrength     = 1.0 - originalInputAbs
        local counterForce        = counterSmoother:getWithSpeedMult(correctionBase, dt, steeringCfg.relativeSteeringSpeed and (580 / vehicleSteeringWheelLock) or 1)
        local dampingForce        = subtractTowardsZero(-yawAngularVel, 0.012, true) * steeringCfg.counterForce.damping * 0.25 * dampingStrength * dampingFade
        local counterInputCap     = normalizedSteeringToInput(steeringCfg.counterForce.maxAngle / steeringLockDeg)

        local effectiveAuthority  = (e.filter == FILTER_KBD) and (steeringCfg.counterForce.inputAuthority * 0.6) or steeringCfg.counterForce.inputAuthority
        counterForce              = clamp(counterForce + dampingForce, -counterInputCap, counterInputCap)
        local counterStrength     = clamp01((1.0 - originalInputAbs) * effectiveAuthority + (1.0 - effectiveAuthority))
        counterStrength           = lerp(1, counterStrength, inputDirectionSmooth)
        counterForce              = counterForce * counterStrength * groundedSmooth

        -- Caps countersteering at the angle of the slide + 5°.
        -- Only applies to manual countersteering, the assist has a separate cap.
        -- The cap on manual countersteering is this value minus what the assist is already doing.
        -- E.g. if the assist is already countersteering at 20% of this cap, the player's countersteer input will mapped to the remaining 80%.
        local manualCounterCap    = inverseLerpClamped(math.rad(2), math.max(steeringLockRad, math.rad(5)), math.abs(travelDirectionRad) + math.rad(5), 0, 1)
        manualCounterCap          = normalizedSteeringToInput(manualCounterCap)

        -- Countersteer input from the player, if any.
        -- Technically it will ramp up briefly even if turning inwards, but the cap applied below suppresses that.
        local manualCounterInput  = originalInput * (1.0 - inputDirectionSmooth)

        local finalCounterForce   = counterForce + (manualCounterInput * clamp01(manualCounterCap - math.abs(counterForce) - math.abs(ival)))

        -- Adding countersteer force and manual countersteer input.
        ival = lerp(ival, clamp(ival + finalCounterForce, e.minLimit, e.maxLimit), fadeIn)

        if steeringCfg.logData and localHVelKmh > 2 then
          print("====================================")
          print(string.format("Estimated steering lock:    %.4f°", steeringLockDeg))
          print(string.format("Current steering angle:     %.4f°", math.deg(getCurrentSteeringAngle(steeredWheelData, vehicleTransform) or 0)))
          print(string.format("Target steered wheel slip:  %.4f°", originalTargetSlip))
          print(string.format("Avg steered wheel slip:     %.4f°", steeredSlipAngleAbs))
          print(string.format("Avg rear wheel slip:        %.4f°", rearSlipAngleAbs))
        end

        -- print(limitBlendOffset)

      end
    end



    -- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    -- END OF CUSTOM STEERING MAIN LOGIC >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    -- >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



    if k == "parkingbrake" then
      local prev = M[k] or e.minLimit
      if handbrakeSoundEngaging    and prev == e.minLimit and ival > prev then sounds.playSoundSkipAI(handbrakeSoundEngaging   ) end
      if handbrakeSoundDisengaging and prev == e.maxLimit and ival < prev then sounds.playSoundSkipAI(handbrakeSoundDisengaging) end
      if handbrakeSoundDisengaged  and ival == e.minLimit and ival < prev then sounds.playSoundSkipAI(handbrakeSoundDisengaged ) end
    end

    M[k] = ival

    inputNameCache[k] = inputNameCache[k] or k..'_input'
    electrics.values[inputNameCache[k]] = ival
  end
end

local function reset()
  if steeringCfg.enableCustomSteering then
    resetCustomSteering()
  end

  gxSmoothMax = 0
  gx_Smoother:reset()

  for k, e in pairs(M.state) do
    e.smootherKBD:reset()
    e.smootherPAD:reset()
  end
  M:settingsChanged()
end

local function getDefaultState(itype)
  return { val = 0, filter = 0,
    smootherKBD = newTemporalSmoothing(10, 10, nil, 0),
    smootherPAD = newTemporalSmoothing(10, 10, nil, 0),
    minLimit = -1, maxLimit = 1 }
end

local function event(itype, ivalue, filter, angle, lockType)
  if M.state[itype] == nil then -- probably a vehicle-specific input
    log("W", "", "Creating vehicle-specific input event type '"..dumps(itype).."' using default values")
    M.state[itype] = getDefaultState(itype)
  end
  M.state[itype].val = ivalue
  M.state[itype].filter = filter
  M.state[itype].angle = angle
  M.state[itype].lockType = lockType
end

local function toggleEvent(itype)
  if M.state[itype] == nil then return end
  if M.state[itype].val > 0.5 then
    M.state[itype].val = 0
  else
    M.state[itype].val = 1
  end
  M.state[itype].filter = 0
end

-- keyboard (multi-key) compatibility
local kbdSteerLeft = 0
local kbdSteerRight = 0
local function kbdSteer(isRight, val, filter)
  if isRight then kbdSteerRight = val
  else            kbdSteerLeft  = val end
  event('steering', kbdSteerRight-kbdSteerLeft, filter)
end

-- gamepad( (mono-axis) compatibility
local function padAccelerateBrake(val, filter)
  if val > 0 then
    event('throttle',  val, filter)
    event('brake',    0, filter)
  else
    event('throttle',    0, filter)
    event('brake', -val, filter)
  end
end

local function settingsChanged()
  M.filterSettings = {}
  for i,v in ipairs({ FILTER_KBD, FILTER_PAD, FILTER_DIRECT, FILTER_KBD2 }) do
    local f = {}
    local limitEnabled = settings.getValue("inputFilter"..tostring(v).."_limitEnabled"   , false)
    if limitEnabled then
      local startSpeed = clamp(settings.getValue("inputFilter"..tostring(v).."_limitStartSpeed"), 0, 100) -- 0..100 m/s
      local endSpeed   = clamp(settings.getValue("inputFilter"..tostring(v).."_limitEndSpeed"  ), 0, 100) -- 0..100 m/s
      f.limitMultiplier= clamp(settings.getValue("inputFilter"..tostring(v).."_limitMultiplier"), 0,   1) -- 0..1 multi
      if startSpeed > endSpeed then
        log("W", "", "Invalid speeds for speed sensitive filter #"..dumps(v)..", sanitizing by swapping: ["..dumps(startSpeed)..".."..dumps(endSpeed).."]")
        startSpeed, endSpeed = endSpeed, startSpeed
      end

      f.limitM = (f.limitMultiplier - 1) / (endSpeed - startSpeed)
      f.limitB = 1 - f.limitM * startSpeed
    else
      f.limitMultiplier = 1
      f.limitM = 0
      f.limitB = 1
    end
    M.filterSettings[v] = f
  end
end

-- public interface
M.updateGFX = updateGFX
M.init = init
M.initSecondStage = initSecondStage
M.reset = reset
M.event = event
M.toggleEvent = toggleEvent
M.kbdSteer = kbdSteer
M.padAccelerateBrake = padAccelerateBrake
M.settingsChanged = settingsChanged

return M
























-- ඞ