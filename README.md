# Day & Night

*They have never been awake at the same time. So they packed up the house and set off for the place where day and night meet.*

A side-view co-op game for two kids at one computer, made in Godot 4.7 (GDScript). The screen is split: Marta's day on
top, Giulio's night below, both showing the same world at the same time. Whatever one does appears in the other's half
straight away. [DESIGN.md](DESIGN.md) has the whole idea.

This is a prototype of the Meadow's first three stops: the Brook, the Gully and the River.

## Play it

```bash
tools/run.sh
```

F11 toggles fullscreen. F5 starts the stop again at any time. Once the house is through, Enter goes on to the next
stop, and the game remembers which stop you're on. For testing, F6 and F7 jump back and forward between stops.

## Controls

With two gamepads, the first is Marta's. With one, it's Giulio's and Marta takes the keyboard.

| Action | Marta's keys | Giulio's keys | Gamepad |
|---|---|---|---|
| Move | A, D | Left, Right | D-pad or left stick |
| Jump | W | Up | A |
| Paint, or use tool | E | K | X |
| Wash (Marta), hold to aim (Giulio) | R | L | B |
| Next colour or tool | Q | J | LB or RB |
| Drive the house, ring its bell | F | I | Y |

Whatever you're about to act on lights up, with its key or button beside it. The keys for colours, tools and aiming sit
by the strips at the top left, and show gamepad buttons when that player has a gamepad. While Giulio holds the aim
button, the direction keys move his target up to 3 blocks away. The drive button works anywhere along the house, except
at the bell on its back end, where it rings. If the house can't go, it shudders and a crossed wheel appears on whatever
stopped it.

## What's in the prototype

- **The two views:** one world and two cameras, with the night tone added by a shader.
- **Marta:** white and blue paint on rocks and blocks, a short reach, and washing paint off.
- **Giulio:** hammer and pick, wood planks that never run out, and stress colours.
- **The house:** it refuses a gap, breaks a bridge that can't hold it, and rolls back to safety. What its wheels rest on
  can't be dug out.
- **The bell:** it brings back lost rocks, and leaves any that are holding up a plank or that the house has reached.
- **The road:** three stops, each a text map in `scripts/core/stops.gd`, played in order. Progress is saved in
  `user://progress.cfg`.
- **Rock:** ground the pick can't dig, which holds up planks the way earth does. It makes the Gully's shelf and cliff.

Not in yet: the Cliff Lift and the Old Mines, playing alone, her cloak, mixing, the easel, more tools and block kinds,
caves, creatures, sound, and white paint on blocks, which looks right but doesn't hold anything up yet.

## What's in the box

```
scripts/core/  the game's rules: sim.gd has one tick() and knows nothing about drawing, and stops.gd has every stop
scripts/view/  draws the sim
scripts/main.gd  the split screen, the cameras, the input and the HUD
shaders/       night.gdshader, which leaves paint in colour
tools/         paints the art and runs the checks
tests/         bots that play every stop, one file per stop in tests/stops/
DESIGN.md      the design
```

All art is original and generated. To change something, edit the painter rather than the output:

```bash
uv venv .venv && uv pip install --python .venv/bin/python pillow numpy scipy
```

```bash
.venv/bin/python tools/gen_sprites.py
```

## Tests

```bash
tools/check.sh              # bots play every stop through the real tick(): the obvious answer must fail, the real solution must work
```

```bash
tools/run_shots.sh out_dir  # plays every stop in the real game under a virtual display and saves screenshots (needs xvfb)
```
