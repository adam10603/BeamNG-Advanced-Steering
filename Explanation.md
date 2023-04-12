# Why use a steering assist?

This page makes the case for why input processing like this is needed in driving games or simulators for keyboard or controller input.

The short version is that it basically emulates the effects of force-feedback. This makes the steering feel more intuitive and more realistic at the same time, and it makes it much more comparable to using a force-feedback steering wheel. The long version is below.

First we'll establish how the steering works in a real car, then how that translates to player input in a game or simulator. The explanations here are simplified because I didn't want to make this page too long, but it gets the basics through.

## 📈 Steering amount

Because of how tires work (both in real life and realistic enough games), there's always an optimal amount of steering (or rather an optimal slip angle) that results in the highest grip for the front wheels. Steering either less or more than this would reduce your front grip.

This is the reason you don't just go full-lock steering at high speed, because that's beyond the optimal steering angle, and therefore the car would understeer. Sounds a bit counterintuitive, but basically steering too much can make you turn less.

![The lateral force of a tire](https://i.imgur.com/meJGE7C.gif)

In the GIF above you can see how steering too much can decrease your grip, and that there's an optimal angle that gives you the best traction. The lateral force bar is basically your cornering grip. *Sidenote: this bar is just a hand-made animation and not the real force, but it gets the point across.*

In a real car you can intuitively tell what the best amount of steering is based on the resistance you feel through the steering wheel as well as the cornering forces on your body, so steering the optimal amount is usually not an issue.

## 🛒 Caster-effect

In a real car the front wheels will always try to turn towards the direction of travel, thanks to their caster angle. It's the same thing as the wheels of a shopping cart or office chair trying to align themselves with the direction they are going in. This is the reason that you can just loosen your grip on the steering wheel when coming out of a turn and the steering will re-center itself.

But it's not just simple self-centering, it's always relative to the direction of travel. This means a car will also countersteer by itself in a slide, if you let it. [🔗 Click here](https://www.youtube.com/embed/CrFcex7oRa0?start=57&end=117) for a minute-long part of a video talking about this self-steering tendency and how drifters take advantage of it by letting the car countersteer by itself.

The important part is that in a real car even if you don't touch the steering wheel, the front wheels will try to turn themselves towards the direction of travel. This greatly helps with car control and overall stability, the car is basically self-stabilizing.

## 🎮 Input devices

When it comes to driving games or simulators it's often said that a force-feedback steering wheel is the best way to play them. This is because FFB allows you to feel where the optimal amount of steering is, and also it allows the car to have a self-steering tendency which helps with stability and countersteering. By mimicking the steering feel of a real car, FFB allows for a much greater level of car control compared to not having it.

However, using a keyboard or controller is much more common than FFB steering wheels. The problem is that these devices lack FFB. This means you don't get those steering behaviors I mentioned, and your input is basically "blind". It might sound like a small detail but this has a huge effect on the driving feel and it can make or break the whole experience.

## 🛠️ Bridging the gap

If a driving game or simulator takes keyboard / controller input as-is, feeding it directly into the car's steering with no extra processing (or just basic smoothing), the result will not only be unrealistic but also unnecessarily difficult to control. This added difficulty simply wouldn't exist with FFB or in a real car.

This is why keyboard / controller input in a lot of games and sims has some extra processing applied which mimics the effects of FFB. The two major advantages are that the steering gets capped to the optimal amount, and the car will gain some natural self-steering ability which helps a lot with stability. This not only makes the car's steering behave more realistically, but it also allows players on keyboard / controller to have an experience that's closer to FFB steering wheels in terms of car control and performance.

## 📜 Philosophy

As far as terminology, I think the word "assist" is a bit tainted in most people's minds. Calling this an assist can give people the idea that it's along the lines of assisted braking for example, which is something meant more for beginners. This is why I often use terms like input processing or simulating the effects of FFB, because I feel like that avoids these misunderstandings.

I've seen many conversations online around steering assists / input processing, and there are a few points that often get repeated. I'll answer the most common ones here.

#### 🔵 *"If you want your steering to be good, just get a wheel"*

Why couldn't people without a wheel also have a good driving experience? This is basically just gatekeeping. Next.

#### 🔵 *"I'm a good driver, I don't need assists"*

This kind of input processing is not just for beginners. It doesn't really add any extra benefit that FFB steering wheels wouldn't have, so it's not some unfair advantage or artificial driver-aid. It's just about making keyboards / controllers better suited for steering a car, which by default they aren't the most optimal for. Without this, car control would be much harder compared to FFB steering wheels, and for no good reason. I guess you can drive without it if you like the challenge, but personally I'd be happy if I'm allowed similar levels of car control to FFB wheel users despite not having one.

#### 🔵 *"I want realism, so I won't use any assists"*

Realism is basically the point of it. Without this, keyboard / controller input would result in pretty unrealistic steering. Like I said earlier, in a real car you would feel what the right amount of steering is, and you would also rely on the car's self-steer tendency for stability and countersteering. By default you don't get any of that on keyboard / controller. If you want the steering in a game or sim to behave more like a real car, that's all the more reason to use something that allows it to do just that. I'd understand this argument for things like arcade ABS, but this is different. Of course I'm not here to deny anyone's preferences for input methods, but the realism argument doesn't quite work for this.

Also, I think we can all agree that FFB steering wheels are the most realistic input method. Now think about what FFB does: it allows the car to steer itself and correct itself for you. Does that not sound like an assist? This is why it's a bit strange to me when some people are against the idea of an assist while using FFB themselves.

If the assistance that FFB provides is accepted as a good thing (which it is), then allowing the same behavior on a controller shouldn't be looked at too differently if you ask me. With FFB steering wheels the tire forces are sent to an FFB motor which feeds them into your input, and with keyboard / controller the forces are fed into the input by some code since you don't have an FFB motor to do it. Although the two methods aren't quite identical due to the different nature of those input devices, but they are both trying to achieve the same concept, and both will make the steering act in a more realistic way which improves car control.

#### 🔵 *"But this makes driving easier, that can't be realistic"*

Difficulty does not equal realism. For example you could play using smoke signals and a smoke detector as your input. Would it be difficult? Yes. Does that mean it's more realistic? No, it's just a bad system. Similarly, keyboard / controller input with no extra processing (or just basic smoothing) is not the best suited system for steering a car. Yes, it's difficult, but no, it's not realistic. You would just get punished for things you could get away with in a real car or by using FFB. Of course you could drive with that kind of raw input if that's what you prefer, but I wouldn't call that added difficulty realistic.

#### 🔵 *"But I want to be in control, I don't want an assist to decide what happens"*

I can't speak for other implementations of this idea, but at least with my version I kept it a big priority to translate player intent as well to the car as possible. It's about overcoming the limitations of an input device, and not about interfering with what the player is doing or creating some kind of dumbed-down experience. If anything, I find that cars obey my inputs in a way that makes much more sense when I'm driving with my mod enabled in BeamNG.

## 🚗 Advanced Steering

Advanced Steering is my own implementation of everything described above, in the form of a mod for BeamNG. The two main things it achieves are a fairly accurate steering limit which keeps the steered wheels near their optimal angle for cornering, and also self-steer tendency which helps with stability and countersteering. It bypasses the default input processing of BeamNG to do this.

BeamNG does have two options called ***Oversteer reduction assistant*** and ***Understeer reduction assistant***, and they were likely inspired by the first version of my mod. Those two assists together are trying to implement the same concepts that I talked about as well, but the steering feel they provide still misses the mark for me. They are better than nothing, but I much prefer the feel of my own implementation in many ways.

Of course I don't expect everyone to agree with my points or to like this mod, but I think for most players on keyboard / controller it's worth a try. It's highly customizable through the UI app, so everyone can dial in the driving feel to their liking. But even if some don't end up liking this mod, at the very least it can give people an idea of how significantly this kind of thing can affect the driving experience in general.