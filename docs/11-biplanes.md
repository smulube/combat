# 11 — Biplanes

## Goal

Add a second mode where each player flies a biplane. Planes **never stop moving**, the stick
adjusts **throttle** instead of driving, everything **wraps** around the screen edges, and
**clouds** hide any plane flying through them. You'll also see how much of guide 10's design pays
off: this guide should touch the core very little.

## Concepts

### Same input, different meaning

The `Input` struct doesn't change. The *mode* interprets it:

| Input | Tank | Biplane |
|---|---|---|
| `left`/`right` | rotate | bank (rotate) |
| `forward` | drive | throttle up (towards max speed) |
| `back` | reverse | throttle down (towards min speed, **never zero**) |
| `fire` | shoot | shoot |

This is the payoff of sending *intentions* (keys held) rather than *actions* ("move left").
The server can reinterpret them per mode without changing the client.

### Velocity carried into shells

A plane moving at 40 u/s that fires a shell at 80 u/s relative to the air should send the shell
off at ~120 u/s over the ground. Otherwise a fast plane can overtake its own bullets. Physically
the shell's velocity is the plane's velocity plus the muzzle velocity. It's a one-line change,
but notice that it needs `Unit.speed`, which you added in guide 10.

### Clouds and server-side fog of war

A cloud is just a rectangle in the arena, like a wall that nothing collides with. A plane whose
centre is inside a cloud is **invisible**. `visible?/2` returns false, and the snapshot leaves the
plane out entirely (guide 10). The client draws the cloud on top anyway, so a well-behaved
client and a hacked client see exactly the same thing.

Decide on one rule: can planes **shoot** from inside clouds, and can they be **hit** there? In the
original, shooting into a cloud could still hit. Our hit detection is server-side and doesn't
consult `visible?/2`, so hits work by default. That's a nice tense mechanic.

## Steps

### 1. Arena support for clouds

- `Arena` gains `clouds: []`, a list of `%{x, y, w, h}`.
- `Arenas.from_ascii/1` learns a new character, `~` for cloud cells.
- `arena_info/1` includes `clouds`.
- Add `Arenas.sky/0`: **no walls at all**, a few cloud banks, and spawns at left and right, both
  heading roughly towards the centre.

There are no border walls, because units wrap.

### 2. `Combat.Game.Modes.Biplane`

`use Combat.Game.Mode`, then implement:

- `name/0` returns `"biplane"`.
- `arena/1` returns `Arenas.sky()`.
- `spawn_units/2`: one unit per side, with `speed` set to the cruise speed.
- `wrap?/0` returns `true`, and `shells_hit_walls?/0` returns `false` (there are no walls anyway).
- `weapon/0`: shells faster than tank shells and short-lived (`~0.8 s`), so you can't shoot
  across the whole wrapped sky.
- `visible?/2`: false when the unit's centre is inside any cloud (`Collision.contains_point?/2`).
- `move_unit/4`:
  1. cooldowns (reuse the shared helpers)
  2. if spinning: rotate continuously and **keep moving** (a hit plane tumbles forward). Ignore
     input
  3. rotation via `left`/`right`, at a slightly faster turn interval than tanks
  4. throttle: `forward` adds `accel × dt` to `speed`, `back` subtracts it, then clamp to
     `[min_speed, max_speed]`, e.g. `[20, 45]`
  5. `pos += from_dir(dir) × speed × dt`. There's no collision to resolve, and the core's
     `wrap_positions/1` handles the edges

Make the core's firing step add the shooter's velocity (`from_dir(dir) × speed`) to the shell's
velocity. For tanks, `speed` is 0, so tank behaviour doesn't change. Check that your tank tests
still pass.

### 3. Wrapping and hit detection near edges

With wrapping, a plane at `x = 159` and a shell at `x = 1` are 2 units apart, not 158. For this
game, **ignore it**: a near-miss across the seam is rare and invisible to players. Write a comment
explaining the simplification. (A stretch goal fixes it.)

### 4. Client

- Add a `biplane` drawer: a blocky plane shape (a long fuselage plus a crossbar for the wings)
  pointing along +x, rotated like tanks.
- Draw **clouds after units**, as soft white/grey blocks, so they cover planes visually too.
- Wrapping pops a plane from one edge to the other in a single snapshot. Guide 13's
  interpolation must **not** smooth across that jump, or the plane would visibly whizz across
  the whole screen for one frame. Note it now for later.

## Tests (`test/combat/game/modes/biplane_test.exs`)

- With no input, a plane's position changes every tick (it never stops).
- Holding `back` for a long time leaves `speed == min_speed`, not zero.
- A plane flying east past `x = 160` reappears near `x = 0` (this exercises the core `wrap?`
  path).
- A plane inside a cloud doesn't appear in `Game.snapshot/1`'s `units`. It reappears after
  leaving the cloud.
- A shell fired by a moving plane is faster than the base shell speed.
- A hit still scores even when the victim is inside a cloud.

## Checkpoint

Create a Biplane match from the lobby and play it in two windows. Dogfight! Hide in a cloud and
watch your opponent's screen: you vanish completely, and the WS frames in devtools confirm you
aren't there.

## Stretch goals

- **Correct wrapped distances:** compute the shortest dx/dy on a torus
  (`dx = dx - width * round(dx / width)`) inside the collision check when `wrap?` is on.
- **Engine sound:** after guide 13, map each plane's speed to the pitch of a WebAudio oscillator.
  To do that, add `speed` to the unit snapshot.
- Cloud drift: clouds move slowly across the sky. Now they're dynamic, so they must be in the
  snapshot rather than only in `arena_info`.

Next: [12 — Jets](12-jets.md)
