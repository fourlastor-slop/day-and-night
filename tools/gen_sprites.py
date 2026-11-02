#!/usr/bin/env python
"""Paints every sprite the game uses into assets/gfx, with the painter in paint.py.

usage: python tools/gen_sprites.py
"""
import math
import os

import numpy as np
from PIL import Image

from paint import (BLUE, GREEN, GRASS, ORANGE, P, RED, STONE, U, WHITE, WOOD, WOOD_D, YELLOW, Multi, cloud, ell, giulio, grass_strip,
                   house, marta, painted_rock, plain_rock, rbox, rgb, ridge, rock, sparkle, tree, wheel)

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'gfx')
EARTH = ('#b39877', '#a98f70', '#9e866a', '#937c63', '#88725b')


def cutout(W, H, draw):
    """Paints on white and on black, and recovers the sprite's colour and alpha from the difference."""
    hi = P(W, H)
    hi.c[:] = 1
    draw(hi)
    lo = P(W, H)
    lo.c[:] = 0
    draw(lo)
    a = np.clip(1 - (hi.c - lo.c).mean(axis=2), 0, 1)
    col = lo.c / np.maximum(a[..., None], 1e-3)
    col = np.clip(col * (1 + .02 * hi.t['f'])[..., None], 0, 1)
    return np.dstack([col, a])


def write(name, arr, size=None):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255 + .5).astype(np.uint8))
    if size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    im.save(os.path.join(OUT, name + '.png'))


def backdrop(night):
    W, H = 2720, 720
    p = P(W, H, night)
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, low = (rgb('#17214c'), rgb('#44598f')) if night else (rgb('#bfd9e0'), rgb('#f5ecd9'))
    p.c[:] = top * (1 - y) + low * y
    p.c *= (1 + .008 * np.tanh(p.t['c1']) + .016 * p.t['m'])[..., None]
    sx, sy = 38 * U, 2.6 * U
    if night:
        p.glow(sx, sy, 2.2 * U, '#c9d6f5', a=.34)
        outer = [(sx + 1.25 * U * math.cos(a), sy + 1.25 * U * math.sin(a)) for a in np.linspace(.9, 5.4, 26)]
        inner = [(sx + .5 * U + .98 * U * math.cos(a), sy - .1 * U + .98 * U * math.sin(a)) for a in np.linspace(5.0, 1.3, 20)]
        p.shape(np.array(outer + inner), '#eef1f8', line=.2, shadow=.1, rim=.2, painted=True, step=9)
        rs = np.random.RandomState(4)
        for k in range(120):
            x, yy = rs.rand() * W, rs.rand() * 6.8 * U
            r = 2 + rs.rand() * 5
            if r > 5.2:
                sparkle(p, x, yy, r * 1.5, '#e9edf9')
            else:
                p.dot(x, yy, r * .34, '#dfe6f7')
    else:
        p.glow(sx, sy, 2.4 * U, '#fff0c4', a=.4)
        p.shape(ell(sx, sy, 1.25 * U, 1.25 * U), '#fbe6ad', line=.2, shadow=.08, rim=.25, step=14)
    for cx, cy, sc in ((7, 2.2, .9), (21, 3.6, .7), (31, 1.7, 1.0), (47, 3.0, .85), (54, 1.5, .7)):
        cloud(p, cx * U, cy * U, sc, '#f5f0e3' if not night else '#8fa0c8')
    peaks = [(26, 15), (33, 7.4), (37, 8.9), (41, 5.9), (45, 8.1), (50, 6.4), (58, 15)]
    p.shape(np.array([(x * U, yy * U) for x, yy in peaks]), '#c6cfcf', line=.1, shadow=.05, rim=.2, step=26, amp=3)
    for x, yy, w in ((41, 5.9, .9), (50, 6.4, .8), (33, 7.4, .6)):
        p.shape(np.array([((x - w) * U, (yy + 1.15) * U), (x * U, yy * U), ((x + w) * U, (yy + 1.15) * U), ((x + .25) * U, (yy + .9) * U),
                          ((x - .2) * U, (yy + 1.2) * U)]), '#ecebe4', line=.05, shadow=0, rim=.1, amp=1.2)
    p.shape(ridge(W, 8.3 * U, ((26, 170), (14, 70)), 2, H), '#c3d0b4', line=.12, shadow=.12, rim=.2, step=20, amp=2, hatch=1)
    for x in (3.5, 6, 18, 21, 26, 33.5, 49):
        tree(p, x, 8.8, .5, '#a8b995', seed=int(x * 3))
    p.shape(ridge(W, 9.25 * U, ((18, 120), (9, 45)), 5, H), '#b2c19b', line=.14, shadow=.16, rim=.18, step=18, amp=2, hatch=2)
    return p.finish()


def earth_sheet(p):
    for r, col in enumerate(EARTH):
        for v in range(3):
            px, py = v * 64 + 8, r * 64 + 8
            c = rgb(col) * (.98 + v * .03)
            p.shape(rbox(px, py, px + 48, py + 48, 6), c, line=.17, lw=1.3, shadow=.07, rim=.07, amp=.7, hatch=(r + v) % 3, step=9)
            if v == 2:
                p.shape(rock(px + 26, py + 28, 13, 10, r + 3), STONE, line=.35, lw=1.3, shadow=.12, amp=.6, step=6)


def grass_sheet(p):
    for v in range(3):
        grass_strip(p, v * 72 + 2, v * 72 + 70, 18)


def wood(p, px, py):
    p.shape(rbox(px, py, px + U, py + U, 4), WOOD, line=.6, lw=1.8, shadow=.2, rim=.14, amp=.8, hatch=2, step=9)
    p.line([[px + 4, py + U * .36], [px + U - 4, py + U * .36]], WOOD_D, w=1.6, a=.55)
    p.line([[px + 4, py + U * .68], [px + U - 4, py + U * .68]], WOOD_D, w=1.6, a=.55)
    for ny in (.18, .84):
        p.dot(px + 7, py + U * ny, 1.8, WOOD_D, painted=False)
        p.dot(px + U - 7, py + U * ny, 1.8, WOOD_D, painted=False)


def block_sheet(p):
    for v, col in enumerate((None, WHITE, BLUE)):
        px, py = v * 64 + 8, 8
        wood(p, px, py)
        if col:
            p.shape(rbox(px + 1, py + 1, px + U - 1, py + U - 1, 4), col, kind='crayon', line=.6, lw=1.6, shadow=0, rim=.08, amp=.6, step=8, hatch=v)


def stress_sheet(p):
    for v, col in enumerate((GREEN, YELLOW, ORANGE, RED)):
        p.shape(rbox(v * 48 + 5, 3, v * 48 + 43, 13, 3), col, kind='crayon', line=.4, lw=1.2, shadow=0, rim=0, amp=.4, step=6, hatch=v)


def river(p):
    W, H = p.W, p.H
    p.shape(rbox(-12, 8, W + 12, H + 20, 6), '#9cc1c4', line=.35, shadow=.1, rim=.3, hatch=1, step=18, amp=1.6)
    for k, yy in enumerate((30, 58, 86, 112, 132)):
        for x0 in np.arange(k * 34.0, W, 150):
            xs = np.linspace(x0, x0 + 72, 10)
            p.line(np.c_[xs, yy + 3 * np.sin(xs / 16)], '#c9dddc', w=2.1, a=.7, amp=.3, step=6)


def ice(p):
    p.shape(rbox(2, 4, 62, 30, 8), '#dff1f7', line=.5, shadow=.14, rim=.4, step=12, hatch=1, painted=True, amp=1)
    p.line([(12, 14), (30, 12), (44, 18)], '#a9d4e6', w=2.2, a=.9, amp=.4, painted=True)


def wisp(p):
    parts = Multi([ell(85 + dx, 34 + dy, r, r * .68, 18) for dx, dy, r in ((-42, 2, 26), (0, 8, 34), (42, 0, 24))])
    p.shape(parts, '#f8f6ee', line=.2, shadow=.1, rim=.2, painted=True, amp=1)


def glow():
    yy, xx = np.mgrid[-1:1:128j, -1:1:128j]
    a = np.exp(-(xx ** 2 + yy ** 2) * 4)
    return np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a - a.min()])


def ring(p):
    q = ell(100, 100, 84, 84, 40)
    p.glow_shape(q, '#ffefa8', spread=8, a=.1)
    p.dashes(q, '#fff3b4', w=5, dash=19, gap=13)


def target(p):
    q = np.array([(12.0, 12.0), (68.0, 12.0), (68.0, 68.0), (12.0, 68.0)])
    p.dashes(q, '#fff3d0', w=4, dash=13, gap=8)


def window(p):
    p.glow(60, 60, 34, '#ffb44a', a=.5)
    p.shape(ell(60, 60, 34, 34), '#ffd070', line=.4, shadow=0, rim=0, painted=True)
    p.line([[26, 60], [94, 60]], WOOD_D, w=3, a=.9, amp=.4, painted=True)
    p.line([[60, 26], [60, 94]], WOOD_D, w=3, a=.9, amp=.4, painted=True)


def colours_strip(p):
    p.shape(rbox(10, 8, 186, 92, 12), '#f3ecdd', line=.5, shadow=.3, rim=.2, painted=True, hatch=1)
    for k, col in enumerate((WHITE, BLUE)):
        q = ell(58 + k * 80, 50, 25, 25, 22)
        p.shape(q, '#d9d2c2' if col == WHITE else '#efe6d4', line=0, shadow=.12, rim=0, painted=True, amp=1)
        p.shape(q, col, kind='crayon', line=.7, lw=1.8, shadow=0, rim=.08, amp=1, step=7, hatch=k)


def tools_strip(p):
    p.shape(rbox(10, 8, 186, 92, 12), '#e5e0d4', line=.5, shadow=.3, rim=.2, painted=True, hatch=2)
    cx, cy = 58, 50
    p.line([(cx - 14, cy + 20), (cx + 8, cy - 8)], WOOD_D, w=6, a=1, amp=.3, grain=False, painted=True)
    p.shape(rbox(cx - 8, cy - 22, cx + 24, cy - 4, 3), '#7f8892', line=.7, lw=1.6, shadow=.1, rim=.2, painted=True, step=6)
    cx += 80
    p.line([(cx - 14, cy + 20), (cx + 8, cy - 10)], WOOD_D, w=6, a=1, amp=.3, grain=False, painted=True)
    arc = [(cx + 4 + 26 * math.cos(a), cy + 2 + 22 * math.sin(a)) for a in np.linspace(-2.7, -.3, 10)]
    p.line(arc, '#7f8892', w=7, a=1, amp=.3, grain=False, painted=True)


def selected(p):
    p.line(ell(42, 42, 34, 34, 28), '#a98f5c', w=4.5, a=1, closed=True, amp=.6, painted=True)


def join(p):
    W = p.W
    xs = np.arange(-20, W + 21, 14.0)
    rs = np.random.RandomState(9)
    from scipy import ndimage as ndi
    edge = ndi.gaussian_filter1d(rs.randn(len(xs)), 1.2) * 9
    torn = np.vstack([np.c_[xs, 14 + edge * .5], [W + 20, -20], [-20, -20]])
    p.shape(torn, '#f4eee0', line=.3, lw=1.5, shadow=.5, rim=.1, amp=1, step=10, painted=True, hatch=1)


def disc(p, col):
    p.shape(ell(60, 60, 48, 48, 30), col, line=.6, shadow=.3, rim=.2, painted=True, step=9)


def bubble(p):
    p.shape(rbox(6, 6, 74, 74, 16), '#f3ecdd', line=.6, shadow=.3, rim=.2, painted=True, hatch=1)


def hint_drive(p):
    bubble(p)
    wheel(p, 40, 40, 22)


def hint_bell(p):
    bubble(p)
    p.shape(np.array([(20.0, 52.0), (28.0, 28.0), (40.0, 20.0), (52.0, 28.0), (60.0, 52.0)]), '#cdaa52', line=.7, lw=1.7, shadow=.1, rim=.2, painted=True, step=7)
    p.dot(40, 57, 5, '#8d7433')


def banner(p):
    p.shape(rbox(16, 14, 404, 266, 14), '#f3ecdd', line=.6, shadow=.4, rim=.2, painted=True, hatch=1)
    house(p, 1.95, 5.15, u=22, wheels=True)
    for x, y, r in ((60, 60, 16), (360, 70, 20), (340, 190, 12), (84, 196, 12)):
        sparkle(p, x, y, r, YELLOW)


def main():
    os.makedirs(OUT, exist_ok=True)
    write('backdrop_day', backdrop(False), (2040, 540))
    write('backdrop_night', backdrop(True), (2040, 540))
    write('earth', cutout(192, 320, earth_sheet))
    write('grass', cutout(216, 44, grass_sheet))
    write('block', cutout(192, 64, block_sheet))
    write('stress', cutout(192, 16, stress_sheet))
    write('river', cutout(14 * U, 3 * U + 24, river))
    write('ice', cutout(64, 36, ice))
    write('rock_plain', cutout(128, 128, lambda p: plain_rock(p, 64, 64, 47, 45, 13)))
    write('rock_white', cutout(128, 128, lambda p: painted_rock(p, 64, 64, 47, 45, WHITE, 19, base='#e3e6ea')))
    write('rock_blue', cutout(128, 128, lambda p: painted_rock(p, 64, 64, 47, 45, BLUE, 23, base='#efe6d4', hatch=1)))
    write('wisp', cutout(170, 70, wisp))
    write('marta_white', cutout(150, 124, lambda p: marta(p, 60 / U, 116 / U, 1, tip=WHITE)))
    write('marta_blue', cutout(150, 124, lambda p: marta(p, 60 / U, 116 / U, 1, tip=BLUE)))
    write('giulio_hammer', cutout(140, 112, lambda p: giulio(p, 56 / U, 104 / U, 1, tool='hammer')))
    write('giulio_pick', cutout(140, 112, lambda p: giulio(p, 56 / U, 104 / U, 1, tool='pick')))
    write('house', cutout(540, 540, lambda p: house(p, 60 / U, 520 / U, wheels=False)))
    write('wheel', cutout(120, 120, lambda p: wheel(p, 60, 60, 49)))
    write('window', cutout(120, 120, window))
    write('glow', glow())
    write('ring', cutout(200, 200, ring))
    write('target', cutout(80, 80, target))
    write('strip_colours', cutout(196, 100, colours_strip))
    write('strip_tools', cutout(196, 100, tools_strip))
    write('selected', cutout(84, 84, selected))
    write('join', cutout(1920, 44, join))
    write('sun', cutout(120, 120, lambda p: disc(p, '#f3c95a')))
    write('moon', cutout(120, 120, lambda p: disc(p, '#31427c')))
    write('hint_drive', cutout(80, 80, hint_drive))
    write('hint_bell', cutout(80, 80, hint_bell))
    write('banner', cutout(420, 280, banner))


if __name__ == '__main__':
    main()
