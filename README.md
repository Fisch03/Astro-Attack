Astro Attack
======
###### A Gameboy Game written in Z80 assembly

###### WARNING: This is my first-ever assembly Program. Because of that, most of the Code is way too over-commented and probably very Resource-Intensitive

How to Play
---
#### Goal
- The Asteroids are falling from the Sky. You can see their Shadows before they hit the Ground. If you fail to avoid them, you loose a Life
- Rockets are coming from the Edges of the Screen. If they hit you, you will also loose a Life.
- Every Asteroid and Rocket you avoided gives you Points
- Try to survive as Long as you can!

#### Controls
- Move with the Joypad
- Press A while moving to Dash
- Press B to use a Bomb and Clear the whole Screen
- Press Start to Pause the Game

Assembling
---
There is currently no makefile, so you have to assemble the ROM manually. To do this, you will need the [rgbds](https://github.com/rednex/rgbds) Toolset. Furthermore, the files for the Easter Egg aren't included in this repository, which leads to an Error when assembling. To fix this, you need to change the USEEASTEREGG constant at the top of the [Main File](src/astroattack.asm) to 0. The Files should then assemble without an error, at the cost of loosing the EasterEgg ingame.

Tools
---
The following Tools were used in the process of developing this Game:
- [rgbds](https://github.com/rednex/rgbds) - Assembling the code
- [BGB](http://bgb.bircd.org/) - Testing and debugging the ROM
- [GBTD](http://www.devrs.com/gb/hmgd/gbtd.html) - Designing all the Tilesets
- [GBMB](http://www.devrs.com/gb/hmgd/gbmb.html) - Mapping them on a Background

About
---
I wanted to make a Gameboy Game for quite some Time, but never really got start programming. When my a friend of me got into Old consoles, I used the opportunity and made this Game for him.
