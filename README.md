BSM
===

Bit Shifter's Monitor for the MEGA65.

![Monitor](https://github.com/MEGA65/mega65-rom-monitor/blob/main/pictures/monitor.png)

This monitor is an open source replacement for the C65 monitor.

You can either load the monitor from disk(image) or patch it into the C65 ROM.

Load
====
```
1) select disk image with "BSM", e.g. bsmon.d81 from this repository.
2) DLOAD "BSM"
3) RUN
```

Patch
=====
```
1) download "911001.mon" from this repository
2) rename current file on SD-card from "MEGA65.ROM" to "MEGA65.OLD"
3) rename "911001.mon" to "MEGA65.ROM"
```

The "Load" method is temporary.

The "Patch" method is permanent (you can go back by renaming again).

The new monitor supports many features of the 45GS02 CPU and the linear address modes,
which enables access to the full 28 bit space of ROM, RAM and I/O.

A full documentation is in progress as chapter in the MEGA65 User's Guide.

The source code can be assembled with the BSA assembler
https://github.com/Edilbert/BSA

Credits
=======

I dedicate this monitor program to Jim Butterfield the 6502 guru.

This work was motivated by and written for the MEGA65 team.

Special thanks go to:

Gábor for the excellent emulator xemu

Anton, who built and lent me a MEGA65 prototype

Paul and Deft, for permanent motivation

