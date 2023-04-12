# Configuration Guide

The default settings should be fine for most people, so you can just enjoy the mod without changing anything.
But if you want to fine tune the steering feel, you can do so in the included UI app. This page explains all the settings in the UI app.

![UI App](https://i.imgur.com/IRgihn0.png)

# General

### Enable Advanced Steering

Enables or disables the entire mod. When disabled, the stock input system is used. It's a good way to quickly compare the two systems.

Changing this will only take effect if you save your settings and reload the car with <kbd>Ctrl</kbd>+<kbd>R</kbd>.

___

### Log data

If enabled, the mod prints steering-related information to the console as you're driving.
You can bring up the console with the <kbd>~</kbd> key.

I suggest enabling force-scrolling with the <kbd>⤓</kbd> button in the top left of the console if you're using this.

# Steering input
Settings related to steering input from the player.

### Relative steering speed

If enabled, the [Steering speed](#steering-speed) setting is applied to the steering wheel itself. This means that different ratio steering racks will change the rate of steering down at the wheels, and vehicles with more steering wheel rotation will have a slower steering feel as a result (like trucks or buses). The default input system also does this for added realism.

If disabled, the [Steering speed](#steering-speed) setting is applied to the steered wheels on the ground instead of the steering wheel. This means that different ratio steering racks will NOT change the rate of steering down at the wheels, they will only make the steering wheel rotate faster or slower. This is less realistic but it provides a much more consistent steering response across different vehicles.

Personally I prefer this disabled, but I left it enabled in the deafult config to make different steering ratios have a more realistic effect.

___

### Steering speed
> Range: `0.0` - `10.0`

How fast the steering is.

When using the ***Key (smooth)*** input filter, this setting is reduced internally to 70% of its value.

![SteeringSpeed](https://i.imgur.com/oYO88Cq.gif)

___

### Steering limit offset
> Range: `-5.0` - `5.0` degrees

Changes the steering angle cap for turning inward. For example a value of `2.0` would let you steer 2° more than normal.

The default cap (`0.0`) is already pretty accurate with keeping the steered wheels near their peak grip in a turn, so I'd recommend sticking to it. I only left this setting in for experimentation or edge cases. You can ignore this basically.

___

### Countersteer limit offset
> Range: `0.0` - `10.0` degrees

Changes the steering angle cap for countersteering. This only applies to manual countersteer input, not the car's self-steer tendency.

This cap is relative to the angle of the slide. For example if the car is in a 20° slide, a value of `0.0` would let you countersteer up to 20° while a value of `5.0` would let you countersteer up to 25°.

Higher values make countersteering more responsive and vice versa.

I'd recommend using at least a few degrees here, as `0.0` can feel a bit limiting when countersteering.

___

### Photo mode

This only applies to keyboard input! When enabled, it turns off auto-centering when the car is stationary. This means you can leave the wheels turned with no input required. It's useful for taking screenshots for example.

___

# Self-steer tendency
These settings affect how the car's natural self-steer tendency behaves. Manual countersteering is not affected by these.


### Use steered wheels

If enabled, the car's self-steer force will be based on the forces at the steered wheels (usually the front wheels). This is more realistic, but can feel less stable at times.

If disabled, forces will be measured at the rear wheels (regardless if they are steered). This is not realistic but it yields a more stable feel. If you disable this setting, I recommend decreasing [Response](#response) and [Damping](#damping) slightly, since this mode will inherently start countersteering a bit sooner and also won't overcorrect as much.

A side-effect of having this enabled is that you'll get an increased steering limit at low speeds (below 40km/h-ish) if you use an [Input authority](#input-authority) setting less than `1.0`. It's a minor detail, you can ignore it.

___

### Response
> Range: `0.0` - `1.0`

Adjusts how aggressively the car's self-steer force ramps up (before it caps out at [Max angle](#max-angle)). This does not affect manual countersteering.

Higher values will make the car feel tighter, causing its self-steer force to fight harder to go straight.

Lower values will make the car more loose, as the car's self-steer tendency won't be as aggressive.

When driving on off-road surfaces, this value is internally decreased to allow for a looser "rally-style" driving utilizing the car's claw grip.

Increasing this value might require [Damping](#damping) to be increased as well.

___

### Max angle
> Range: `0.0` - `90.0` degrees

The maximum steering angle that the car's self-steer force is allowed to reach. You can always countersteer more than this manually, but this will cap the car's own self-steer tendency.

When driving on off-road surfaces, this value is internally decreased to allow for a looser "rally-style" driving utilizing the car's claw grip.

Increasing this value might require [Damping](#damping) to be increased as well.

![Max angle](https://i.imgur.com/zxtFXWu.gif)

___

### Input authority
> Range: `0.0` - `1.0`

It determines how much your steering input can overrule the car's self-steer force when you turn inwards while the car is oversteering.

A lower value will allow the car to resist your input more if you're trying to turn inwards while the car oversteers. A higher value will give you more direct control, but it makes oversteering easier.

Think of a lower setting like having a looser grip on the steering wheel and letting it pull back if it wants to. A higher setting is more like holding the steering wheel firmly at a certain position.

The difference this setting makes depends on the [Response](#response) and [Max angle](#max-angle) settings. The stronger you make the car's self-steer force, the more difference you'll notice when you allow it to resist your input.

When using the ***Key (smooth)*** input filter, this setting is reduced internally to 70% of its value.

In the GIF below, the car starts to gently oversteer after the turn begins. Low input authority allows the car to correct the slide to an extent despite the player fully turning inwards.

![Input authority](https://i.imgur.com/bQANw6m.gif)

___

### Damping
> Range: `0.0` - `1.0`

How much damping force to apply to the car's self-steer force.

Without damping, the car's self-steer force might overshoot and oscillate left and right when trying to straighten out. Damping helps it to settle down.

This is most noticeable in high-grip cars when you stop giving steering input during a high-speed turn and let the car try to straighten out on its own.

In general, the stronger you make the car's self-steer tendency with the [Response](#response) and [Max angle](#max-angle) settings, the more damping you'll need. You'll also need more damping if the [Use steered wheels](#use-steered-wheels) setting is enabled, as that's naturally a bit less stable.

I wouldn't recommend using more damping than necessary as too much can cause unwanted vibrations in some cars. If you notice the steering unnaturally spazzing out (especially while braking on uneven roads), you might want to decrease damping.

![Damping](https://i.imgur.com/SdnhUcA.gif)
