# Day & Night

*They have never been awake at the same time. So they packed up the house and set off for the place where day and night meet.*

A side-view co-op game for two kids at one computer, made in Godot 4.7 (GDScript). The screen is split: Marta's day on
top, Giulio's night below, both showing the same world at the same time. Whatever one does appears in the other's half
straight away. [DESIGN.md](DESIGN.md) has the whole idea.

This is a prototype of one stop: the river.

## Play it

```bash
tools/run.sh
```

F11 toggles fullscreen, and Enter starts again once the house has crossed.

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

Whatever you're about to act on lights up. While Giulio holds the aim button, the direction keys move his target up to
3 blocks away.

## What's in the prototype

- **The two views:** one world and two cameras, with the night tone added by a shader.
- **Marta:** white and blue paint on rocks and blocks, a short reach, and washing paint off.
- **Giulio:** hammer and pick, wood planks that never run out, and stress colours.
- **The house:** it refuses a gap, breaks a bridge that can't hold it, and rolls back to safety.
- **The bell:** it puts the stop's rocks back where they started.

Not in yet: playing alone, her cloak, mixing, the easel, more tools and block kinds, caves, creatures, sound, saving,
and white paint on blocks, which looks right but doesn't hold anything up yet.

## What's in the box

```
scripts/core/  the game's rules: sim.gd has one tick(), and knows nothing about drawing
scripts/view/  draws the sim
scripts/main.gd  the split screen, the cameras, the input and the HUD
shaders/       night.gdshader, which leaves paint in colour
tools/         paints the art and runs the checks
tests/         bots that play the stop
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
tools/check.sh              # bots play the stop through the real tick(): the bare bridge must fail, the real solution must work
```

```bash
tools/run_shots.sh out_dir  # plays it in the real game under a virtual display and saves screenshots (needs xvfb)
```
