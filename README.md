Astro Attack
======
##### A Gameboy Game written in assembly

Assembling
---
There is currently no makefile, so you have to assemble the ROM manually. To do this, you will need the [rgbds](https://github.com/rednex/rgbds) Toolset. Furthermore, the files for the EasterEgg aren't included in this repository, which leads to an Error when assembling. To fix this, you need to change the USEEASTEREGG constant at the top of the [Main File](src/astroattack.asm) to 0. The Files schould then assembler without an error, at the cost of loosing the EasterEgg ingame.

Tools
---
The following Tools were used in the process of developing this Game:
- [rgbds](https://github.com/rednex/rgbds) - Assembling the code
- [BGB](http://bgb.bircd.org/) - Testing and debugging the ROM
- [GBTD](http://www.devrs.com/gb/hmgd/gbtd.html) - Designing all the Tilesets
- [GBMB](http://www.devrs.com/gb/hmgd/gbmb.html) - Mapping them on a Background

About
---
I wanted to make a Gameboy for quite some Time, but never had the time for it. When my a friend of me got into Old consoles, I used the opportunity and made this Game for him.
