# BeamNG.drive: Arcade Steering
![Version](https://img.shields.io/badge/Version-1.0-blue.svg) ![Compatibility](https://img.shields.io/badge/Game_compatibility-v24.1.2-green.svg)


## Intro 🖊️


This is an extensive modification of BeamNG.drive's steering input system for controller and keyboard. Unfortunately the default system is very simplistic and falls short of the level of input processing seen in other driving games. This mod provides a steering system that's more aware of the vehicle's underlying physics.

This mod is work-in-progress, so it may be subject to changes and improvements in the near future.

Concerns around the game's default steering system aren't new. [There have been discussions](https://www.beamng.com/threads/steering-assist-for-over-under-steerers.59477/) about it for a long time, as well as attempts to improve it such as the ["Forza" Steerig Mod](https://www.beamng.com/threads/forza-steering-for-keyboard-and-gamepad.77578/), or [IKT's script](https://gist.github.com/E66666666/207027cc29f1869a43f6ccef054e3845) that uses his GTA-style steering logic.

After seeing that others are just as frustrated with BeamNG.drive's input handling as I was, I made a more well-rounded mod to overhaul it. The main features of this mod include:

 - Dynamic, slip angle-based steering limit
 - Ability to properly countersteer in a slide or drift
 - Forces acting on the steered wheels can feed back into the steering rack
 - Cars naturally countersteer to an extent, simulating the effect of their caster angle
 - Highly customizable config file

Despite what it might sound like, you shouldn't think of this mod as some kind of artificial driver-aid. This is a pretty common way in which driving games (both arcade and sim) handle player input, and it reflects how driving in real life works too.

Here are two quick videos comparing the stock input system to the modified one:

https://user-images.githubusercontent.com/8660105/157807873-c8ed5bed-7ffe-406f-b707-58be0ca18f0b.mp4

https://user-images.githubusercontent.com/8660105/157831670-15eeaae5-520b-49ec-8ff7-4be9d4e4ffb7.mp4


## Installation 🖥️

 1. [Download the latest release.](https://github.com/adam10603/BeamNG-Arcade-Steering/releases)
 2. Navigate to the game's main directory, then go to `lua\vehicle`.
 3. Rename `input.lua` to something else. This will be a backup of the original file, if you ever want to restore it.
 4. Copy the downloaded `input.lua` and `arcade_steering_config.json` files to the `vehicle` directory.

Since this mod replaces game files instead of using the game's modding API, updating the game may remove these files.


## Setup 🛠


Go to ***Options*** ➡ ***Controls*** ➡ ***Bindings*** ➡ ***Vehicle***, and click on the bind for ***Steering***. Make sure that the steering lock type is ***1:N***, and that the filter type matches the input device of the bind.

The mod will not work with the ***Wheel (direct)*** filter, as it's only meant for keyboard and controller. But for steering input specifically, it does modify the behavior of the other filter types.

The ***Key (smooth)*** filter will lower the [`steeringSpeed`](ConfigGuide.md#steeringspeed) and [`inputAuthority`](ConfigGuide.md#counterforceinputauthority) settings internally. The ***Key (fast)*** and ***Gamepad*** filters are identical, and both use the config values as-is.

The ***Limit steering at speed*** option on the ***Filters*** tab will be ignored when the mod is active, as the mod uses its own logic to limit steering.


## Usage 🎮


When you first spawn a vehicle, an automatic steering calibration takes place. You won't be able to control the vehicle until it's over, but it only lasts about 1 second.

If you use a controller, don't be afraid to give 100% stick input to turn. You won't be grinding down the front tires like before, since the mod will ensure that the steering angle is appropriate. The same applies to keyboard input.

There's not much else to it. Keep driving and you should notice that cars feel more well-behaved and predictable. Now that the input system is more tied-in with the driving physics, it will be easier to get a feel for what your car is doing.


## [Config Guide 📝](ConfigGuide.md)


The default values in the config file work just fine, but if you want to customize the experience, a full guide is linked above.

If you make changes to the config file, press `Ctrl+R` in-game to reload your current vehicle. This applies your changes without having to restart the game.


## Version History 📃


* v1.0
  * Initial release
