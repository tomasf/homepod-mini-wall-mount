# HomePod mini Wall Mount

A two-part wall mount for the HomePod mini, made with [Cadova](https://github.com/tomasf/Cadova). It holds the speaker
120 mm out from the wall, hides the excess cable inside, and lets the cable leave upward toward an outlet above the
mount. Both parts print without supports. It fits both the first and the second generation of the HomePod mini.

## How it works

The **shell** is screwed to the wall. The speaker's foot stands in a 2 mm recess at its tip, with the rest of the
speaker free all round. Between the speaker and the wall, the shell is hollow.

The **lid** sits inside a rim on top of the shell, a fraction of a millimetre below its edge, so the seam can't be seen
from below. Its underside carries a
spool for the excess cable.

The cable runs down through a hole in the lid just behind the speaker, around the spool, and back up through a notch at
the wall end. The lid is held by a single screw under the speaker, where the speaker covers it. At the wall end, a 45°
edge on the lid hooks under a matching lip on the shell. The lid also covers the wall screws.

## What you need

| Part | Count | Notes |
| --- | --- | --- |
| DIN 7982 countersunk tapping screw, 4.2 mm | 2 | Wall screws. 4.2 × 25 reaches about 20 mm into the wood; use 4.2 × 32 for thin panelling. |
| DIN 7982 countersunk tapping screw, 3.5 × 13 mm | 1 | Lid screw. 3.5 × 9.5 also works. Nothing longer than 13 mm. |

The wall screws are meant for wood. Use suitable plugs for other walls.

## Printing

| Model | Orientation |
| --- | --- |
| `Models/Print plate.3mf` | Both parts, laid out side by side in their print orientations |

The shell is set to print with three walls, which fill its sides completely and give them an even surface. Slicers
read this setting from the file. No supports are needed. The few horizontal spans, at the top of the speaker's recess and in the lid screw's pilot hole,
are short bridges. Turn on elephant foot compensation if your printer needs it, so that the lid drops into the shell.
On Bambu Lab printers, record timelapses in smooth mode or not at all: the traditional mode pauses on the shell's
side every layer and leaves a line of blobs.

`Models/Assembly.3mf` shows everything in place. Each piece is a separate part that you can show or hide.

## Assembly

1. Screw the shell to the wall with the outlet 15–20 cm above it. The screws are 50 mm apart and go in at a slight
   upward angle.
2. Thread the cable's USB-C plug down through the hole in the lid, from the top.
3. Wind the excess cable around the spool, under the barbs. It holds about 1.5 m.
4. Lay the cable into the notch at the wall end, so that it runs up to the outlet.
5. Hold the lid tilted 5–10° with the speaker end up, slide the wall end in under the lip, and lower the other end.
6. Fasten the lid screw, then stand the speaker in its recess.

To take the lid off, do the same in reverse.

## Building

The models are generated from Swift source. With a Swift 6.3 toolchain:

```bash
swift run
```

This writes the assembly and print plate models to `Models/`. The model is described only as assembled, and
[Prepress](https://github.com/tomasf/Prepress) lays the shell and the lid out on the print plate from there.

```bash
swift test
```

This checks that the parts fit each other, the speaker, the coil and the cable.

Clearances come from the tolerance in `Sources/main.swift`, 0.2 mm by default. Raise it if parts fit too tightly on
your printer. The speaker's distance from the wall is `HomePodMini.wallDistance`.

## Assumptions

Some dimensions are estimates rather than measurements:

- The cable is taken to be 6 ft (1.83 m) long.
- The USB-C plug is taken to be at most 12 × 8 mm.
- The cable is taken to leave the speaker about 8 mm above the bottom of the foot.
- The speaker's foot is taken to be 2 mm thick.
