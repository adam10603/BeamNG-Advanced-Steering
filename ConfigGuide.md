# Configuration Guide

This page explains all the settings found in `better_steering_config.json`. You can edit the file in notepad, or any text or code editor.

___

### `enableCustomSteering`
> Type: Boolean (true / false)

Enables or disables the entire mod. If this is `false`, the stock input system is used. It's a good way to do quickly compare the two.

___

### `counterAssist.useSteeredWheels`
> Type: Boolean (true / false)

If this is `true`, the forces affecting the steering rack will be based on the forces experienced by the steered wheels (usually the front wheels).

If `false`, the forces will be based on those at the rear wheels (regardless if they are steered).

Since these forces are responsible for the car's natural countersteering tendency, this can have an effect on stability. Basing this on the steered wheels is more realistic (since those are the ones connected to the steering rack), however, this might make the car less stable at times. Using the rear wheels is less realistic but can yield a more stable feel.

___

### `counterAssist.response`
> Type: Number (0.0 - 1.0)

Adjusts how much horizontal wheel velocity is needed for the car's natural countersteer to reach its maximum cap (`maxAngle`).

Higher values will cause the countersteer force to ramp up sooner and max out from smaller slides. Lower values will make the natural countersteer more lazy.

A higher value may require `damping` to be increased as well.

___

### `counterAssist.maxAngle`
> Type: Number (0.0 - 20.0)

> Unit: degrees

The maximum steering angle that the car's natural countersteer can reach.

A higher value may require `damping` to be increased as well.

___

### `counterAssist.inputAuthority`
> Type: Number (0.0 - 1.0)

Only has an effect when turning inwards. It determines how much your input can overrule the car's natural countersteer tendency (the force pushing back through the steering rack).

A lower value here will allow the car to resist your input more. This can result in better overall grip and stability, since it reduces the chance of the tires being overworked. GTA V's steering logic is similar to using low value here.

A higher value will give you a bit more control, but at the risk of overworking the tires and reducing grip. This feels closer to the game's default input system, although not nearly that bad.

___

### `counterAssist.damping`
> Type: Number (0.0 - 1.0)

How much damping force to apply to the car's natural countersteer force.

Damping force prevents the countersteer force from overcorrecting and oscillating left and right.

Most noticeable at higher speed, when you stop giving input mid-turn and let the car straighten out on its own using its countersteer tendency.

___

### `steeringSpeed`
> Type: Number (0.0 - 10.0)

How fast the steering is. Note that even `1.0` is faster than the default input system's sluggish steering speed.

___

### `relativeSteeringSpeed`
> Type: Boolean (true / false)

If `true`, the steering speed will be adjusted to each vehicle's steering wheel lock. Vehicles that have a lot of steering wheel travel will have slower steering as a result. The default input system also does this.

`false` gives all vehicles the same rate of input. Note that the steering hydro can still have a different speed cap in each vehicle, and that's not something the mod changes, so your mileage may still vary.

___

### `slipTargetOffset`
> Type: Number (-3.0 - 3.0)

> Unit: degrees

Adjusts the speed-related steering limit by offsetting the slip angle targeted by the steered wheels.

If you feel like the steering becomes too limited with speed, you can increase this to target a higher slip angle.

Increasing this too high will risk turning the wheels too much and losing grip.

If you mostly drive off-road vehicles, you might want to increase this a bit, since off-road tires and surfaces usually need a little more slip angle. Maybe this will be automated in the future.

___

### `maxAdaptiveLimitAdjustment`
> Type: Number (0.0 - 3.0)

> Unit: degrees

The speed-related steering limit is continuously adjusted as the vehicle is turning, based on slip angle readings from the steered wheels. This ensures that the real slip angle is actually close to what the code wants to target.

This value limits how much this feedback loop is able to adjust the steering limit. E.g. a value of `2.0` would allow the feedback loop to adjust the steering cap by +/- 2°.

The reason this needs to be capped is to make sure the feedback loop can't mess things up too much, even if it encounters weird slip angle readings in some edge cases or with unexpected types of vehicles.

___

### `logData`
> Type: Boolean (true / false)

If `true`, the mod prints steering-related information to the console as you drive.
You can bring up the console with the `~` key.