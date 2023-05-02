# BeamNG.drive: Advanced Steering
*Formerly known as Arcade Steering*

![Version](https://img.shields.io/badge/Version-2.6-blue.svg) ![Compatibility](https://img.shields.io/badge/Game_compatibility-28.1.0-green.svg)

![Thumbnail](https://i.imgur.com/yeQaquE.png)

![Thumbnail](https://i.imgur.com/yeQaquE.png)

## 🖊️ Intro

This mod is an overhaul of BeamNG.drive's steering input system for controller and keyboard. It provides a steering system that's more aware of the vehicle's underlying physics and results in an improved steering feel that's more intuitive and closer to how real cars behave. It's a useful mod for anyone without a steering wheel, regardless of skill level. It also includes customizable settings, letting people adjust the steering feel to their liking.

BeamNG version 0.26+ has two options called ***Oversteer reduction assistant*** and ***Understeer reduction assistant*** which behave similarly to this mod. These options are an improvement over not having them at all (like in older versions of the game), however, the steering feel they provide still leaves room for improvement. This is where Advanced Steering comes in.

The main features of the mod include:

 - Accurate steering limit to utilize the steered wheels' peak grip
   - This is similar to the ***Understeer reduction assistant*** in 0.26+
 - Natural self-steer tendency, simulating the effects of the car's caster angle
   - This is similar to the ***Oversteer reduction assistant*** in 0.26+
 - More refined steering feel compared to the stock input system
 - Highly customizable settings

## [📖 Reasoning](Explanation.md)

The principles implemented by this mod are a common way of processing steering input in racing games (both arcade and sim), and they mimic real-life driving mechanics. The goal is to make the steering behave in a more intuitive way that you otherwise wouldn't get if your input device lacks force-feedback. Click the link above for a longer breakdown of why input processing like this is recommended for keyboard and controller input.

## 🖥️ Installation

You can easily get the mod from the in-game mod repository. Just search "Advanced Steering" and subscribe to it!

In case you want the zip version, you can get that from the [BeamNG website](https://www.beamng.com/resources/advanced-steering.24284/) or the [Releases](https://github.com/adam10603/BeamNG-Advanced-Steering/releases) section.

## 🛠 Setup

Go to ***Options*** ➡ ***Controls*** ➡ ***Bindings*** ➡ ***Vehicle***, and click on the bind(s) for ***Steering***. Make sure the ***Filter*** is set correctly (or just ***Automatic***), and set the ***1:1 steering angle*** to 0 for controller. For a controller I'd also decrease ***Linearity*** to somewhere between 1.0 - 2.0 as well (the default is higher).

The mod will not do anything if you use the ***Wheel (direct)*** filter, as it's only meant for keyboard and controller. But for steering input specifically, it does modify the behavior of the other filter types.

The ***Key (smooth)*** filter will lower the [Steering speed](ConfigGuide.md#steering-speed) and [Input authority](ConfigGuide.md#input-authority) settings to 70% of their original value when you drive. This gives a smoother feel that's easier to control on keyboard. The ***Key (fast)*** and ***Gamepad*** filters are identical, and both use the config values as-is.

Any steering-related option in the game such as ***Understeer reduction assistant***, ***Oversteer reduction assistant***, ***Slower steering at high speed*** or ***Limit steering at high speed*** will not work as long as you're driving with this mod enabled. This is because the mod bypasses the default input system and uses its own logic for everything.

## 🎮 Usage

When you first spawn a vehicle, a quick steering calibration will take place. You won't be able to drive until it's over, but it only lasts about 1 second.

That's pretty much it. Keep driving and you should notice a change in steering feel, and that cars feel more well-behaved and predictable.

## [📝 Config Guide](ConfigGuide.md)

The default settings will work just fine for most people, but you can use the included UI app to tweak the settings to your taste.

Go to ***UI Apps*** in the top menu in-game, click ***Add app*** and look for ***Advanced Steering Config***. This widget will let you tweak the settings on the fly.

Click the link above for a full breakdown of every setting.