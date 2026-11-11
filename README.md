# Day & Night

*They have never been awake at the same time. So they packed up the house and set off for the place where day and night meet.*

A side-view co-op game for two kids at one computer, made in Godot 4.7 (GDScript). The screen is split: Marta's day on
top, Giulio's night below, both showing the same world at the same time. Whatever one does appears in the other's half
straight away. [DESIGN.md](DESIGN.md) has the whole idea.

This is a prototype of the first two lands: the Meadow (the Brook, the Gully, the River and the Cliff Lift) and the Old
Mines (the Mine Mouth, the Old Rails, the Sootling Hall and the Long Tunnel). It speaks English and Italian.

## Play it

Builds for Linux, Windows and Mac go to [itch.io](https://fourlastor.itch.io/day-and-night) on every push to `main`. To
play from the source:

```bash
tools/run.sh
```

The title offers to carry on, pick a stop already reached, see the controls, change the options or start a new journey.
Either kid can work the menus: arrows or WASD to choose, Enter, Space, E or K to pick, Esc to go back, or a gamepad's
stick, A and B. Esc or a gamepad's Start pauses the game.

The game saves as it goes: the stop in play, exactly as it is, every few seconds, on pause and when the window closes, so
it carries on mid-stop next time. Once the house is through, Enter (or A) goes on to the next stop. The language follows
the computer's until it's changed in the options. F11 toggles fullscreen and F5 starts the stop again. For testing, F6
and F7 jump back and forward between stops.

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
| Pause | Esc | Esc | Start |

Whatever you're about to act on lights up, with its key or button beside it. The keys for colours, tools and aiming sit
by the strips at the top left, and show gamepad buttons when that player has a gamepad. While Giulio holds the aim
button, the direction keys move his target up to 3 blocks away. The drive button works anywhere along the house, except
at the bell on its back end, where it rings. If the house can't go, it shudders and a crossed wheel appears on whatever
stopped it.

At the Cliff Lift Giulio's tools include a rope. Aim at one end and press his use key, then aim at the other end and press
it again. Pressing it on a rope's end unties it. In the mines Marta has yellow as well, and her yellow cloak lights her own
way, while Giulio's tools grow to hammer, stone, pick, rope and wheel. Any of his building tools takes out what it's aimed
at.

## What's in the prototype

- **The two views:** one world and two cameras, with the night tone added by a shader.
- **Marta:** white and blue paint on rocks and blocks, a short reach, and washing paint off. A group of his blocks
  rises once at least half of it is white, and strains a little before that.
- **Giulio:** hammer and pick, wood planks that never run out, and stress colours. At the Cliff Lift he gets rope: a
  block tied to something solid above it counts as held up, and things tied together move as one.
- **The house:** it refuses a gap, breaks a bridge that can't hold it, and rolls back to safety. What its wheels rest on
  can't be dug out. It weighs as much as 4 plain blocks, so a lift needs that much more white to carry it.
- **The bell:** it brings back lost rocks, and leaves any that are holding up a plank or that the house has reached.
- **The road:** eight stops, each a text map in `scripts/core/stops.gd`, played in order. Everything is saved in
  `user://progress.cfg`: the stop the road is on, the furthest one reached, the settings, and the stop in play. A saved
  stop whose map has changed since, after an update, starts afresh instead.
- **The menus:** title, pause, stops, controls and options, on a painted card over the frozen road, in English and
  Italian.
- **Caves:** in the mines, any open space with ground above it is dark. Daylight reaches a little way in at a mouth, and
  yellow rocks and blocks light the space around them, through open space only. Painted rocks show faintly in the dark.
- **Stone:** his second block kind. A run of it reaches 5 squares from a support, it sinks to the bottom of water and
  stands there, and it weighs double in a lift.
- **Carts:** a group of blocks with a wheel in it is a cart, and a yellow block in it is the engine, driving the way Marta
  faced when she painted it. Carts fall, carry what rides them, and wait when something is in the way.
- **Sootlings:** shy shadows in the mines' dark. They drift towards Giulio there and never go into light. One that
  touches him in the dark wakes him in the house.
- **Boulders:** three squares across, too heavy to shove even on blue, though white still lifts them.
- **Rock:** ground the pick can't dig, which holds up planks the way earth does. It makes the Gully's shelf and cliff.

Not in yet: the later lands, playing alone, choosing her cloak's colour, mixing, the easel, the mole and other helping
creatures, side goals and sound.

## What's in the box

```
scripts/core/  the game's rules: sim.gd has one tick() and knows nothing about drawing, and stops.gd has every stop
scripts/view/  draws the sim
scripts/main.gd  the split screen, the cameras, the input, the HUD and saving
scripts/menu.gd  the menus
scripts/progress.gd  the save file
data/lang/it.po  every line in Italian
assets/fonts/  Fredoka, the font
shaders/       night.gdshader, which leaves paint in colour
tools/         paints the art, runs the checks and exports the builds
tests/         bots that play every stop, one file per stop in tests/stops/
.github/       the workflow that checks, builds and publishes every push to main
DESIGN.md      the design
```

All art is original and generated. To change something, edit the painter rather than the output:

```bash
uv venv .venv && uv pip install --python .venv/bin/python pillow numpy scipy
```

```bash
.venv/bin/python tools/gen_sprites.py
```

```bash
tools/gen_splash.sh         # the boot splash, rendered by the game itself (needs xvfb)
```

## Tests

```bash
tools/check.sh              # bots play every stop through the real tick(): the obvious answer must fail, the real solution must work
```

It also saves every stop halfway and checks it plays on exactly the same once loaded, drives the real game and its menus
with key presses, and checks every line has an Italian version that fits where it's drawn.

```bash
tools/run_shots.sh out_dir  # plays every stop in the real game under a virtual display and saves screenshots (needs xvfb)
```

## Publishing

`.github/workflows/publish.yml` runs the check on every push to `main`, exports the three builds with `tools/export.sh`
and pushes them to itch.io with butler, using the `BUTLER_API_KEY` secret. The Mac build is signed ad hoc, not notarized,
so macOS asks before its first start. `.github/workflows/check-builds.yml`, started by hand, fetches the Mac and Windows
builds from the page and starts them on real Mac and Windows machines.

```bash
tools/export.sh linux       # or windows, or macos (which needs rcodesign): into build/
```

## Licence

The game is under the [Apache License 2.0](LICENSE). The font, Fredoka, is under the SIL Open Font License
([assets/fonts/OFL.txt](assets/fonts/OFL.txt)). Every build carries both, with the Godot Engine's notices.
