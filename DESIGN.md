# DAY & NIGHT — design notes

*They have never been awake at the same time. So they packed up the house and set off for the place where day and night meet.*

A side-view co-op adventure for two players at one computer: Marta, who loves drawing, and Giulio, who loves
building. They're kids of different ages and both are smart, so challenges must be real challenges: hard, but
never impossible.

Working title. This is a draft. The river stop exists as a prototype, and the rest is untested.

## The hook

1. **One world, two views.** The screen is split, with Marta's day on top and Giulio's night below, both showing
   the same world at the same time. Their characters never meet, but whatever one does appears in the other's
   half straight away.
2. **The house comes with them.** It's a house on wheels, parked at the current stop in both views. It's where
   they start, and getting it down the road is the goal they share.
3. **Giulio changes where things are, Marta changes what things are.** He digs and builds, and she paints
   properties onto objects.
4. **The eclipse.** The journey ends where day and night overlap. The line between the halves disappears and they
   share one screen for the first time.

## How it plays

**Together** is the main way to play. Both sit at the computer and each controls their own character, at their
own pace.

**Alone** still works. If only one of them is around, their half fills the screen and the other character sleeps
in the house. They can do their side of the current stop, and the rest waits.

The road is a series of stops. Each stop gives both players a job at the same time, and the two jobs connect at
least once, so neither is ever just watching. Who has the harder job alternates from stop to stop. When the way is
clear, the house drives on to the next stop.

There is no clock, because real puzzles need thinking time.

### Controls

There is no mouse or pen. Each player has a gamepad or a side of the keyboard, so there is no cursor to share. Two
gamepads work best. One gamepad plus the keyboard also works, and both on one keyboard is the fallback, though it's
cramped and cheap keyboards can drop keys when several are held.

Both use the same idea: whatever you're about to act on lights up.

### Day, night and caves

Night is a blue-toned version of the same world, and everything stays visible. The two views differ in colour,
plus a few things that exist on one side only, used sparingly: sunflowers that open by day, moonstones that only
show at night. Each player sees the other as a faint glow, so they can find each other.

Darkness is an event, not the default, because constant darkness would get old quickly. Only caves are dark. Her
yellow cloak lights her own way, but he has no light of his own, so he can only get through if she paints the
loose stones in the cave yellow.

### Fitting half the screen

- The split is top and bottom, because a road is wide. Each view shows about 50 blocks across and 15 high.
- **Every puzzle fits in one view,** so each player can see the whole problem without scrolling.
- Obstacles are wide rather than tall. Nothing essential needs a tall tower or a deep shaft.
- The camera follows sideways. The world is stacked in layers one view high: sky, surface and caves.
- Characters are about 2 blocks tall, and anything important is at least 2 blocks wide, so it stays readable at
  half size.

## Marta: paint

She picks a colour and paints whatever object is near her. The closest object within reach, in the direction she's
facing, lights up to show what she'll paint, and one button does it.

- **Her reach is short, about 3 blocks.** To paint anything further away, she needs Giulio to get her there.
- **Only objects take paint:** loose rocks, logs and crates, blocks Giulio placed, and his vehicles. The ground, cave
  walls and water don't, so it's always simple to see what can be painted.
- **A painted object affects what's around it.** Water isn't painted: a blue stone dropped in the river freezes the
  water around it.
- **One colour at a time.** A new colour replaces the old one, and she can wash paint off whenever she likes.
- **Colours never run out.** Once she has found one, it's hers for good.
- **Her cloak takes one colour too** and gives her a personal power. This is her own upgrade path.
- **Mixing is her crafting.** Nothing says what a mix does: she tries it and watches, and her colour book fills in.
- **The easel is for drawing.** In the house she can paint on a small pixel grid, one square at a time, like the
  pattern editor in Animal Crossing. Her pictures go on her cloak, the house's flag and the walls. They're only for
  looks, and no rule depends on them.

| Colour | Property | On objects | On her cloak |
|---|---|---|---|
| Cloud white | Floats | Rises until something stops it, and holds up what's resting on it. A connected group rises if it has at least as much white as plain | Glide |
| Fire red | Warm | Melts nearby ice and snow. A stone painted red is a furnace | Cross snow |
| Ice blue | Cold | Freezes nearby water, cools nearby lava into rock, and slides | Cross hot ground |
| Lightning yellow | Shines | Lights up dark caves, keeps sootlings away, powers machines | Carry a light |
| Leaf green (blue + yellow) | Grows | Saplings and vines grow slowly, towards light | To be decided |
| Bubblegum pink (red + white) | Bounces | Anything landing on it bounces | Higher jump |
| Storm purple (red + blue) | Heavy | Sinks, and weighs down whatever it's part of | Walk on the sea floor |

## Giulio: build

A simplified Terraria, tuned to be easy to pick up.

- **Tools unlock through the game,** the same way her colours do. Each does one clear thing.
- **Blocks never run out.** He collects kinds, not amounts: once he finds stone, he can place as much as he likes.
- **Digging is for getting through and finding things.** Underground is where the new tools, block kinds and old
  machine parts are.
- **Place anything.** Blocks go anywhere within reach if they touch something. There is no recipe for a bridge, just
  blocks and rules.
- **Vehicles.** Any connected group with wheels rolls, and drives itself with a yellow-painted block as its engine.
  The last vehicle is the house itself.
- **Reach.** The square he'd act on lights up, next to him in the direction he's facing, and holding a button lets
  him move it up to about 3 blocks away. Anything further needs a way to get closer, and a white rock can carry him
  up to places he can't build from.

| Tool | What it does | Found in |
|---|---|---|
| Hammer | Places and removes blocks | Start |
| Pick | Digs earth | Start |
| Rope | Ties objects together and hangs them from supports | The Meadow |
| Wheels | Turn a group of blocks into a cart | The Old Mines |
| Drill | Digs rock and ice | The Frozen Pass |
| Pump | Moves water | The Hot Springs |
| Sail, propeller | Move the house over water and through the air | The Sea, The Sky |

### Rules of building

- **Every block shows its stress**, from green to red, based on how far it is from a support. Wood spans about 3,
  stone 5 and iron 9. A pillar down to the ground resets the count.
- **The house is heavy.** Blocks never fall on their own, and a stretched bridge still holds the kids. Driving onto it
  adds load: if it can't hold, it breaks, the house rolls back to safety, and he rebuilds.
- **White objects are supports.** A white rock pressing up under a bridge holds it up.
- **Water has a current.** It carries away anything placed in it except stone. So wood can stand on a rock that
  breaks the surface but not on one under it, and that choice decides whether a river needs Marta.
- **Iron needs a furnace.** He finds ore, sets it beside a stone she painted red, and iron is his for good.

## What makes a challenge real

1. **Nothing says what to do.** The game shows the problem, never the solution. No arrows, no prompts.
2. **Learn, use, twist.** First the obvious answer works, so they learn the tool. Then the tool is used somewhere
   harder. Then the obvious answer fails, and they have to combine it with something they already know.
3. **Order matters.** Later solutions are chains of steps, and the wrong order means starting that chain again.
4. **Properties have physics.** A colour is never a key for a lock. It changes how something behaves, and the rest
   follows from that.
5. **Failing costs time, never progress.** If you fall or get caught, you wake up in the house.
6. **Any physical solution counts.** The game only checks that the house got through, so they can beat a puzzle in a
   way nobody planned.

### Never impossible

- **Each character is tuned to its player.** Each side has its own difficulty: how long the chains are, how many
  rules apply at once and how precise the movement is. Giulio's challenges come from trying, watching it fail and
  fixing it, with short chains and visible feedback. Long chains, planning ahead and fine control go to Marta.
- **Nothing runs out,** so there is nothing to recover.
- **Lost objects come back.** Ring the bell at the back of the house and loose objects at this stop return to where
  they started, so a rock floated out of reach can't block the game. Anything holding something up stays, and so
  does anything whose place the house has reached, so the bell never undoes a solution.
- **They have each other.** Marta can talk Giulio through a hard moment, and he can do the same for her. If both
  are stuck, a wordless sketch of the first step is available on request.
- **Hard extras are optional.** Each stop has a tough side goal with a house upgrade as its reward, so there's more
  to chew on without blocking anyone.

## Stops

- **Shape problems (Giulio):** gaps, walls, mountains, soft ground. Something is missing or in the way.
- **State problems (Marta):** too cold, too hot, too heavy, too dark, dead. Nothing needs building: the thing just has
  to be different.

Each land has 4 stops: one that teaches its new colour and tool, one that uses them, one that twists them, and the
land's end, which needs both players working closely together.

Examples at the intended difficulty:

- **White, in three beats.** Learn: a rock sits on the open road, and painting it white floats it away. Use: a ledge
  is too high to jump, so she rides a white rock up to it. Twist: a boulder sits under a rock shelf, and white just
  jams it against the shelf. Painted blue first, it freezes the stream and slides, so she can shove it past the shelf
  and then repaint it white.
- **The bridge, in three beats.** Learn: a narrow stream, and a line of planks works. Use: a wider river, where the
  middle turns red and the house won't cross until he adds a support. Twist: the current takes any wood placed in the
  water, so he needs a stone pillar, a white rock from Marta pressing up under the deck, or her ice to work from.
- **The cave (both).** She goes ahead in her yellow cloak and paints stones so he can follow. Rubble blocks her way
  and only he can dig it, so neither gets through alone.
- **The Snow Giant (both).** A gentle giant sits on the mountain pass and slowly walks towards the warmest thing
  nearby. She leaves red stones to lead it, and he builds walls and digs pits to steer it. It's a boss with no
  fighting.

## Needing each other

- **He needs her for** light in caves, heat for iron, lift for himself and heavy things, and engines for his vehicles.
- **She needs him for** getting within reach: ways up and across, tunnels through rubble, and boats to islands.
- **The house is shared.** She can paint his coat on its peg, so red keeps him warm in the snow. He can build her a
  long-handled brush at the workbench, which extends her reach.
- **Neither can destroy the other's work.** He can move painted blocks, which keep their paint, but he can't remove
  the paint. She can't remove blocks.
- **Progress is shared.** There are no scores.

## Creatures

There is no fighting and nothing to defeat. Every creature is a problem to think through or a friend to make.

- **Creatures to outwit.** Sootlings hide in dark caves and keep away from light. The Snow Giant walks towards
  warmth.
- **Creatures to help.** Giulio digs out a lost mole, and Marta thaws a frozen bird with a red stone. Once helped,
  they move into the house and lend a hand, like the mole marking buried finds.

## The road

| # | Land | Marta gains | Giulio gains | Ends with (both) |
|---|------|-------------|--------------|------------------|
| 1 | The Meadow | White and blue, from the start | Hammer, pick, wood, rope | **The Cliff Lift:** he hangs a platform from an old pulley, she paints enough of it white to raise the house |
| 2 | The Old Mines | Yellow | Stone, wheels | **The Long Tunnel:** he digs through the mountain, she lights the way with painted stones |
| 3 | The Frozen Pass | Red, warm cloak | Drill, iron | **The Snow Giant** |
| 4 | The Hot Springs | Mixing: green and pink | Pump | **The Geyser:** his platform, her heat and cold, and the house rides the steam up |
| 5 | The Sea | Purple | Hull, sail | **The Crossing:** he turns the house into a boat, she balances it with white and purple |
| 6 | The Sky | Nothing new: everything she has | Propeller | **The Flight:** the road ends at a cliff, so the house has to fly |
| 7 | The Eclipse | | | The final level, on one shared screen |

Lands 4 to 6 are rough. The first build is Lands 1 and 2.

## Art

Cut paper and crayon, shown on the [art style canvas](https://claude.ai/artifact/Cv5FG85e6LQgQ1QNQoTLUF). The world is
soft, muted paper layers, and only Marta's paint is strong, waxy crayon, so anything painted stands out at half size
and by night. The two views meet at a torn paper edge. A sun and moon sit on it and move closer as the road goes on, so
the eclipse doubles as a progress marker.

`tools/paint.py` paints the mock-ups: `tools/paint.py <output folder> [river cave eclipse paint cast]`. It needs Pillow,
NumPy and SciPy.

## Technical shape

- Godot 4.7, GDScript. No server: one save file in `user://`.
- One world, simulated once, with two cameras on it. The night view adds the blue tone.
- One tile grid per land. Water, heat, cold and stress are simple grid rules.
- Paint is one colour stored on each object, so it never touches the tile grid.
- A deterministic tick, so tests can replay scripted solutions and prove every stop can be finished.
- A hand-painted look at a higher resolution than Bellwater, with painted objects that stand out at half size.
- Very little text, in English and Italian.
