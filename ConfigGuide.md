# Configuration Guide

The mod has a UI app you can use to tweak things. This page explains all the settings in the UI app.

![UI App](https://i.imgur.com/9QktZO0.png)

# General

### Enable Arcade Steering

Enables or disables the entire mod. When disabled, the stock input system is used. It's a good way to quickly compare the two systems.

Changing this will only take effect if you save your settings and reload the car with <kbd>Ctrl</kbd>+<kbd>R</kbd>.

___

### Log data

If enabled, the mod prints steering-related information to the console as you're driving.
You can bring up the console with the <kbd>~</kbd> key.

I suggest enabling force-scrolling with the <kbd>⤓</kbd> button in the top left of the console if you're using this.

# Steering
Settings related to regular steering input.

### Steering speed
> Range: `0.0` - `10.0`

How fast the steering is. This isn't related to the default input system's steering speed, as the mod completely changes how input is processed.

When using the ***Key (smooth)*** input filter, this setting is reduced internally to 60% of its value.

![SteeringSpeed](https://i.imgur.com/oYO88Cq.gif)

___

### Steering limit offset
> Range: `-5.0` - `5.0` degrees

Changes the steering angle cap. For example a value of `2.0` would let you steer 2° more than normal.

The default cap (`0.0`) is already very accurate with keeping the steered wheels near their peak grip in a turn, so I don't see a need to change this. I only left this setting here just in case someone runs into a weird edge case or something. You can ignore this basically.

___

### Relative steering speed

If enabled, the steering speed will be adjusted to each vehicle's steering wheel lock. Vehicles that have a lot of steering wheel travel will have slower steering as a result. The default input system also does this.

If disabled, all vehicles will have the same rate of input. Note that the steering hydro has a different speed cap in each vehicle, and this isn't change by the mod, so your mileage may still vary.

___

# Countersteer force
These settings affect how the car's natural countersteer tendency behaves. Manual countersteering is not affected by these.


### Use steered wheels

If enabled, the car's own countersteer force will be based on the forces experienced by the steered wheels (usually the front wheels).

If disabled, forces will be measured at the rear wheels (regardless if they are steered).

Changing this can have an effect on stability. Basing the countersteer force on the steered wheels is more realistic (since those wheels are connected to the steering rack), however, this might make the car less stable at times. Taking the readings at the rear wheels is less realistic but can yield a more stable feel.

___

### Response
> Range: `0.0` - `1.0`

Adjusts how easily the natural countersteer force can reach it's maximum ([Max angle](#max-angle)). This does not affect manual countersteering.

Higher values will cause the car to countersteer more aggressively by itself and fight harder to go straight.

Lower values will make the countersteer tendency more lazy and require bigger slides for the car to countersteer at [Max angle](#max-angle).

A higher value may require [Damping](#damping) to be increased as well.

___

### Max angle
> Range: `0.0` - `90.0` degrees

The maximum allowed steering angle when the car is countersteering only by itself. You can always countersteer more than this manually, but this will cap the car's own countersteer tendency.

A higher value may require [Damping](#damping) to be increased as well.

___

### Relative angle

If enabled, [Max angle](#max-angle) will be scaled based on the car's maximum steering angle. This means that cars with a low steering lock will countersteer less, and vice versa.

___

### Input authority
> Range: `0.0` - `1.0`

Only has an effect when turning inwards!

It determines how much your steering input can overrule the car's own countersteer tendency. E.g. `0.2` would mean that even when you're fully turning inwards, 80% of the car's own countersteer force is still in effect.

A lower value here will allow the car to resist your input more. This can result in better overall grip and stability, since it reduces the chance of the tires being overworked. GTA V's steering logic acts similarly to using a low value here.

A higher value will give you more control, but at the risk of overworking the tires and reducing grip. This feels closer to not using any assists, although not nearly that bad.

The effect is noticeable when trying to make a car slide just by turning inwards (not using weight shifting), or when trail braking into a turn with a car that tends to lose grip when doing so.

Since this setting controls how the car's own countersteer force is mixed with your input, the difference it makes depends on the [Response](#response) and [Max angle](#max-angle) settings. The stronger you make the countersteer force, the more difference you'll notice when you change how it's mixed with your input.

When using the ***Key (smooth)*** input filter, this setting is reduced internally to 60% of its value.

___

### Damping
> Range: `0.0` - `1.0`

How much damping force to apply to the car's own countersteer force.

Without damping, the car's countersteering might overshoot and oscillate left and right, or even whip the car around in the opposite direction in bad cases. Damping helps the countersteer force to settle down and prevents it from overshooting.

This is most noticeable when you stop giving steering input during a high-speed turn and let the car try to straighten out on its own.

In general, the stronger you make the car's countersteer tendency with the [Response](#response) and [Max angle](#max-angle) settings, the more damping you'll need. You'll also need more damping if the [Use steered wheels](#use-steered-wheels) setting is enabled, as that's naturally less stable.

Increasing damping too much can lead to unwanted vibrations in some cars though, so use this setting carefully.

![Damping](https://i.imgur.com/SdnhUcA.gif)
