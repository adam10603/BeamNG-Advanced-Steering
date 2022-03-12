# Configuration Guide

This page explains all the settings found in `better_steering_config.json`. You can edit the file in notepad, or any code editor.

___

### `enableCustomSteering`
> Value: `true` / `false`

Enables or disables the entire mod. If this is `false`, the stock input system is used. It's a good way to do quickly compare the two systems.

___

### `counterForce`

The values in this section control how the forces acting on the wheels can affect the steering rack. This is what's responsible for the car's natural countersteer tendency, and it simulates the effects of the car's caster angle.

___

### `counterForce.useSteeredWheels`
> Value: `true` / `false`

If `true`, the forces affecting the steering rack will be based on the forces experienced by the steered wheels (usually the front wheels).

If `false`, forces will be measured at the rear wheels (regardless if they are steered).

Since these are the forces that cause the car to naturally countersteer, this can have an effect on stability. Basing this on the steered wheels is more realistic (since those are the ones connected to the steering rack), however, this might make the car less stable at times. Taking the readings at the rear wheels is less realistic but can yield a more stable feel.

___

### `counterForce.response`
> Value: `0.0` - `1.0`

Adjusts how much horizontal wheel velocity is needed for the car's natural countersteer to reach its maximum cap ([`maxAngle`](#maxAngle)).

Higher values will cause the countersteer force to act more aggressively, and max out even from smaller slides. This will fight harder to keep the car straight.

Lower values will make the natural countersteer tendency more lazy and require more severe slides to reach [`maxAngle`](#maxAngle).

A higher value may require [`damping`](#damping) to be increased as well.

___

### `counterForce.maxAngle`
> Value: `0.0` - `20.0`
>
> Unit: degrees

The maximum steering angle that wheels are allowed to reach when deflected by the car's natural countersteer force.

A higher value may require [`damping`](#damping) to be increased as well.

___

### `counterForce.inputAuthority`
> Value: `0.0` - `1.0`

Only has an effect when turning inwards!

It determines how much your steering input can overrule the car's natural countersteer tendency (the force pushing back through the steering rack).

E.g. `0.2` would mean that even when you're fully turning inwards, 80% of the car's natural countersteer force is still in effect.

A lower value here will allow the car to resist your input more. This can result in better overall grip and stability, since it reduces the chance of the tires being overworked. GTA V's steering logic acts similarly to using a low value here. Since this can have the effect of reducing your maximum steering angle, a slight increase to [`slipTargetOffset`](#sliptargetoffset) might be needed when using low values.

A higher value will give you a bit more control, but at the risk of overworking the tires and reducing grip. This feels closer to the game's default input system, although not nearly that bad.

The effect is noticeable when trying to make a car slide just by turning inwards (not using weight shifting), or when trail braking into a turn with a car that tends to lose grip when doing so.

Since this setting controls how the car's natural countersteer force is mixed with your input, the difference it makes depends on the [`response`](#counterforceresponse) and [`maxAngle`](#counterforcemaxangle) settings. The stronger you make the countersteer force, the more difference you'll notice when adjusting how it's mixed with your input.

___

### `counterForce.damping`
> Value: `0.0` - `1.0`

How much damping force to apply to the car's natural countersteer force.

Damping force prevents the countersteer force from overcorrecting and oscillating left and right.

This is most noticeable when you stop giving steering input during a high-speed turn, and let the car straighten out on its own.

Increasing damping too much can lead to unwanted vibrations, so use this setting carefully.

![Damping](https://i.imgur.com/8HELKje.gif)

___

### `steeringSpeed`
> Value: `0.0` - `10.0`

How fast the steering is. Note that even `1.0` is faster than the default input system's sluggish steering speed.

![SteeringSpeed](https://i.imgur.com/jwTlKhm.gif)

___

### `relativeSteeringSpeed`
> Value: `true` / `false`

If `true`, the steering speed will be adjusted to each vehicle's steering wheel lock. Vehicles that have a lot of steering wheel travel will have slower steering as a result. The default input system also does this.

`false` gives all vehicles the same rate of input. Note that the steering hydro can still have a different speed cap in each vehicle, and that's not something the mod changes, so your mileage may still vary.

___

### `slipTargetOffset`
> Value: `-3.0` - `3.0`
>
> Unit: degrees

Adjusts the speed-related steering limit by offsetting the slip angle targeted by the steered wheels.

If you feel like the steering becomes too limited with speed, increasing this setting would help.

Values too low or too high can both cause understeer by giving you too little or too much steering. That said, it's usually better to be slightly over the ideal amount than under it.

If you mostly drive off-road vehicles, you might want to increase this a bit, since off-road tires and surfaces usually need a little more slip angle.

___

### `maxAdaptiveLimitAdjustment`
> Value: `0.0` - `3.0`
>
> Unit: degrees

The speed-related steering limit is continuously adjusted as the vehicle is turning, based on slip angle readings from the steered wheels. This ensures that the actual slip angle stays close to what the code wants to target.

The adjustment happens relatively slowly. This means that sudden things like bumps won't affect the steering limit much, but it will adapt to a corner for example.

This value limits how much this feedback loop is able to adjust the steering limit. E.g. a value of `2.0` would allow the steering cap to be dynamically adjusted by +/- 2° of steering.

The reason this needs to be capped is to make sure the feedback loop doesn't change the steering feel more than necessary, especially if it encounters abnormal readings in edge cases, or unusual vehicles.

___

### `logData`
> Value: `true` / `false`

If `true`, the mod prints steering-related information to the console as you drive.
You can bring up the console with the `~` key.