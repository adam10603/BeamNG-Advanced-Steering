# Configuration Guide

The default settings should be fine for most people, so you can just enjoy the mod without changing anything.
But if you want to fine tune the steering feel, you can do so in the included UI app. This page explains all the settings in the UI app.

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

How fast the steering is.

When using the ***Key (smooth)*** input filter, this setting is reduced internally to 60% of its value.

![SteeringSpeed](https://i.imgur.com/oYO88Cq.gif)

___

### Steering limit offset
> Range: `-5.0` - `5.0` degrees

Changes the steering angle cap. For example a value of `2.0` would let you steer 2° more than normal.

The default cap (`0.0`) is already very accurate with keeping the steered wheels near their peak grip in a turn, so I don't see a need to change this. I only left this setting here just in case someone runs into a weird edge case or something. You can ignore this basically.

___

### Relative steering speed

If enabled, the steering speed will be adjusted to each vehicle's steering wheel lock. Vehicles that have a lot of steering wheel travel will have slower steering as a result (like trucks or buses). The default input system also does this.

If disabled, all vehicles will have a similar-ish steering speed at the wheels. Note that the steering hydro will still have a different speed cap in each vehicle, so your mileage may still vary.

___

# Countersteer force
These settings affect how the car's natural countersteer tendency behaves. Manual countersteering is not affected by these.


### Use steered wheels

If enabled, the car's own countersteer force will be based on the forces at the steered wheels (usually the front wheels). This is more realistic, but can feel less stable at times.

If disabled, forces will be measured at the rear wheels (regardless if they are steered). This is not realistic but it can yield are more stable feel.

A side-effect of having this enabled is that you'll get an increased steering limit at low speeds (below 40km/h-ish) if you use an [Input authority](#input-authority) setting less than 1. It's a minor detail, you can ignore it.

___

### Response
> Range: `0.0` - `1.0`

Adjusts how easily the car's natural countersteer force can reach it's maximum ([Max angle](#max-angle)). This does not affect manual countersteering.

Higher values will make the car feel tighter, causing its natural countersteer force to fight harder to go straight.

Lower values will make the car more loose, as the car's countersteer tendency will be more lazy and won't reach [Max angle](#max-angle) as easily.

I don't recommend using values over 0.5 or so.

When driving on off-road surfaces, this value is internally decreased to allow for a looser "rally-style" driving style utilizing the car's claw grip.

Increasing this value might require [Damping](#damping) to be increased as well.

___

### Max angle
> Range: `0.0` - `90.0` degrees

The maximum allowed steering angle when the car is countersteering only by itself. You can always countersteer more than this manually, but this will cap the car's own countersteer tendency.

When driving on off-road surfaces, this value is internally decreased to allow for a looser "rally-style" driving style utilizing the car's claw grip.

Increasing this value might require [Damping](#damping) to be increased as well.

___

### Input authority
> Range: `0.0` - `1.0`

Only has an effect when turning inwards!

It determines how much your steering input can overrule the car's own countersteer tendency. E.g. `0.4` would mean that even when you're fully turning inwards, 60% of the car's own countersteer force is still in effect.

A lower value here will allow the car to resist your input more, taking it more as a "suggestion". This can result in better overall grip and stability, since it reduces the chance of the tires being overworked. GTA V's steering logic acts similarly to using a low value here.

A higher value will give you more direct control over the steering, but you might risk overworking the tires and reducing grip. This feels closer to not using any assists, although not nearly that bad.

The effect is more noticeable in cars that easily lose front grip (like under braking).

Since this setting controls how the car's own countersteer force is mixed with your input, the difference it makes depends on the [Response](#response) and [Max angle](#max-angle) settings. The stronger you make the countersteer force, the more difference you'll notice when it's mixed with your input.

Starting with version 2.1 lowering this setting will internally increase the [Steering limit offset](#steering-limit-offset) setting slightly. This roughly compensates for the steering angle you lose when using low values here.

When using the ***Key (smooth)*** input filter, this setting is reduced internally to 60% of its value.

___

### Damping
> Range: `0.0` - `1.0`

How much damping force to apply to the car's own countersteer force.

Without damping, the car's countersteering might overshoot and oscillate left and right when trying to straighten out. Damping helps the countersteer force to settle down and prevents it from overcorrecting.

This is most noticeable when you stop giving steering input during a high-speed turn and let the car try to straighten out on its own.

In general, the stronger you make the car's countersteer tendency with the [Response](#response) and [Max angle](#max-angle) settings, the more damping you'll need. You'll also need more damping if the [Use steered wheels](#use-steered-wheels) setting is enabled, as that's naturally less stable.

I wouldn't recommend using more damping than necessary. Increasing damping too much can lead to unwanted vibrations in some cars. If you notice the steering spazzing out, you might want to decrease damping.

![Damping](https://i.imgur.com/SdnhUcA.gif)