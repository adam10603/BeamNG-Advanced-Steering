# BeamNG.drive: Arcade Steering
![Version](https://img.shields.io/badge/Version-2.0.2-blue.svg) ![Compatibility](https://img.shields.io/badge/Game_compatibility-v26.2.0-green.svg)

## Intro 🖊️

This is an extensive modification of BeamNG.drive's steering input system for controller and keyboard. It provides a steering system that's more aware of the vehicle's underlying physics and results in an improved steering feel.

With version 0.26 BeamNG added an ***Oversteer reduction assistant*** and ***Understeer reduction assistant*** which behave pretty similarly to this mod. In the past Arcade Steering used to add these mechanics because the stock game was completely lacking them, but since 0.26 the mod now exists more as a refinement. The stock assists are a big improvement over the pre-0.26 situation, however, this mod still seeks to improve the steering feel further.

The main features of the mod include:

 - Accurate steering limit to utilize the steered wheels' peak grip
   - This is similar to the ***Understeer reduction assistant*** in 0.26+
 - Natural countersteer tendency, simulating the effects of the car's caster angle
   - This is similar to the ***Oversteer reduction assistant*** in 0.26+
 - More refined steering feel compared to the stock assists
 - Highly customizable settings

Despite the "arcade" name, you shouldn't think of this as some kind of artificial driver-aid or somehow less realistic. This is a common way of processing steering input in racing games (both arcade and sim), and it mimics real-life driving mechanics.

## Installation 🖥️

If you're using the 1.0 version of the mod you should delete it and verify your game files in Steam. Starting with 2.0 the mod is a standard zip package that doesn't replace any existing game files.

 1. [Download the latest release](https://github.com/adam10603/BeamNG-Arcade-Steering/releases).
 2. Copy `arcadeSteering.zip` to your `mods` folder ([follow this guide](https://documentation.beamng.com/tutorials/mods/installing-mods/#manual-installation) if you don't know where it is).
 3. The mod should now appear in the in-game mod manager.

## Setup 🛠

Go to ***Options*** ➡ ***Controls*** ➡ ***Bindings*** ➡ ***Vehicle***, and click on the bind(s) for steering. Make sure that the ***Filter*** is set correctly (or use ***Automatic*** if unsure), and set the ***1:1 steering angle*** to 0 if you're using a controller.

The mod will not do anything with the ***Wheel (direct)*** filter, as it's only meant for keyboard and controller. But for steering input specifically, it does modify the behavior of the other filter types.

The ***Key (smooth)*** filter will lower the [Steering speed](ConfigGuide.md#steering-speed) and [Input authority](ConfigGuide.md#input-authority) settings to 60% of their original value when you drive. This gives a smoother feel that's easier to control on keyboard. The ***Key (fast)*** and ***Gamepad*** filters are identical, and both use the config values as-is.

Any steering-related option in the game such as ***Understeer reduction assistant***, ***Oversteer reduction assistant***, ***Slower steering at high speed*** or ***Limit steering at high speed*** will not work as long as you're driving with this mod enabled. This is because the mod completely bypasses the default steering system and uses its own logic for everything.

## Usage 🎮

When you first spawn a vehicle, an automatic steering calibration takes place. You won't be able to drive until it's over, but it only lasts about 1 second.

That's pretty much it. Keep driving and you should notice a change in steering feel, and that cars feel more well-behaved and predictable. Things like drifting will also feel different.

## [Config Guide 📝](ConfigGuide.md)

The default settings will work just fine for most people, but you can use the included UI app to tweak the settings to your taste.

Go to ***UI Apps*** in the top menu in-game, click ***Add app*** and look for ***Arcade Steering Config***. This widget will let you tweak the settings on the fly.

Click the link above for a full breakdown of each setting in the app.

## Version History 📃

* v1.0
  * Initial release
* v2.0
  * Big chungus of an update
  * Works with 0.26 and up
  * No longer requires modifying game files, it's packaged like a standard mod
  * Added a UI app for tweaking settings on the fly
  * Major changes to the steering limit logic
  * Offroad steering has been improved (wasn't even considered previously)
  * Numerous improvements and tweaks to basically everything
* v2.0.2
  * Fixed a small bug in the steering logic when switching directions
  * Fixed a small bug in the UI app