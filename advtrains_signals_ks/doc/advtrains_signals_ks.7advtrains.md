% advtrains_signals_ks(7advtrains) | Advtrains User Guide

# NAME
`advtrains_signals_ks` - Ks signals for advtrains

# DESCRIPTION

This mod includes a modified subset of German rail signals. This page documents the signals implemented by this mod and some differences between this mod and German signals used in real life. The TODO section is currently included as there are notable modifications to this mod by the current `new-ks` branch, but it will be removed when the branch is ready for review.

# SIGNAL ASPECTS

This section mainly describes the different signal aspects. Please note that the meaning of some signal aspects may differ from their RL counterparts, and that the differences documented in the following section are not comprehensive.

Due to historical reasons, "ex-DB" and "ex-DR" are used to refer to the former Deutsche Bundesbahn (West Germany) and the former Deutsche Reichsbahn (East Germany), respectively.

## Ks signals
The Ks signals are used like most other signals in advtrains. It has the following aspects:

* Hp 0 (red light): Stop
* Ks 1 (green light): Proceed at maximum speed or with the speed limit shown on the Zs 3 indicator directly above the signal (if present) and expect to proceed the next main signal at maximum speed or, if the green light is flashing, with the speed limit shown on the Zs 3v indicator directly below the signal
* Ks 2 (yellow light): Proceed at maximum speed or with the speed limit shown on the Zs 3 indicator directly above the signal (if present) and expect to stop in front of the next main signal.

In addition, Sh 1 (see below) may also appear with Hp 0, in which case the train continues in shunt mode.

## Shunt signals
Shunt signals are labeled "Ks Shunting signal" in-game. It has the following aspects:

* Sh 0 (two horizontally aligned red lights): Stop
* Sh 1/(ex-DR) Ra 12 (two white lights aligned on a slanted line): shunting allowed

## Signal signs
There are a few signal signs provided by this mod:

* Lf 7 (black number on a white background): Proceed with the permanent speed limit shown on the sign
* Lf 1/2 (black number on a yellow background): Proceed with the temporary speed limit shown on the sign
* Lf 3 (black letter "E" on a yellow background): The temporary speed limit previously set by Lf 1/2 is lifted
* "E" signal (**not** Lf 3) (black letter "E" on a white background): Proceed at maximum speed
* Ra 10 (the black text "Halt für Rangierfahrten" on a white semicircle): Do not proceed if in shunt mode
* Proceed as main ("PAM", in-game only) ("S" below a green arrow): Proceed without shunt mode

# DIFFERENCES FROM REAL-LIFE SIGNALS

[This document](https://www.bahnstatistik.de/Signale_pdf/SB-DBAG.pdf) is used for reference,

* The speed is indicated in m/s instead of multiples of 10km/h.
* Due to the potentially large number of nodes, only certain hard-coded values are allowed.
* Certain visual effects, such as making signal signs reflective or lit at night, are not implemented.
* The "E" sign, unlike Lf 3, lifts the main speed restriction as if by Hp 1.
* The actual Lf 3 has an orange background.
* Signal signs operate independently from other signals.
* Distant signaling is not yet implemented.
* The location of most signals are not checked. The location of Zs 3 and Zs 3v are only checked relative to the location of the main (Ks) signal.
* The "shunt signals" in this mod are actually known as "Schutzsignale". The word "Rangiersignale" refers to a different set of signals (including acoustic signals) given by the person specifically responsible for train shunting.
* The ex-DB definition of Sh 1 ("Fahrverbot aufgehoben") is that the track section ahead is clear and does not imply that the driver is allowed to proceed.
* @orwell noted on the Minetest forum that the function of Lf 7 in the mod should normally be done with Zs 3.

# TODO
* Implement warning speed for temporary slow zones ("vorübergehende Langsamfahrstellen") with Lf 1/Lf 2 and Lf 3.
* Use Zs 3 instead of Lf 7 for the main speed restriction; use Lf 7 for line speed restriction.
* Change the "E" sign to Zs 10.
