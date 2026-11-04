#!/usr/bin/env python
"""Cut-paper and crayon painter for the Day & Night art style mock-ups."""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

U = 48  # pixels per block at full resolution


def rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255


INK_DAY = rgb('#3d332c')
INK_NIGHT = rgb('#0e1530')
NAVY = rgb('#1b2547')
MID = rgb('#4b6296')
PALE = rgb('#bccae6')

_cache = {}


def streaks(H, W, angle, across, along, seed):
    D = int(math.hypot(H, W)) + 8
    n = np.random.RandomState(seed).rand(D, D).astype(np.float32)
    n = ndi.gaussian_filter(n, (across, along), mode='wrap')
    n = (n - n.mean()) / n.std()
    a = np.asarray(Image.fromarray(n).rotate(angle, resample=Image.Resampling.BILINEAR))
    y, x = (D - H) // 2, (D - W) // 2
    return a[y:y + H, x:x + W].copy()


def textures(H, W, seed=11):
    key = (H, W, seed)
    if key in _cache:
        return _cache[key]
    rs = np.random.RandomState(seed)
    t = {
        'h0': streaks(H, W, 28, 0.9, 16, seed + 1),
        'h1': streaks(H, W, -32, 0.9, 16, seed + 2),
        'h2': streaks(H, W, 78, 0.9, 16, seed + 3),
        'c0': streaks(H, W, 24, 1.3, 26, seed + 4),
        'c1': streaks(H, W, -40, 1.3, 26, seed + 5),
    }
    fine = ndi.gaussian_filter(rs.rand(H, W).astype(np.float32), 0.7)
    t['f'] = np.tanh((fine - fine.mean()) / fine.std() * 0.6)
    mott = ndi.gaussian_filter(rs.rand(H, W).astype(np.float32), 18)
    t['m'] = np.tanh((mott - mott.mean()) / mott.std() * 0.7)
    _cache[key] = t
    return t


class Multi(list):
    """Several polygons that fill and outline as one shape."""


def wobble(pts, step=12, amp=1.4, seed=0, closed=True):
    pts = np.array(pts, np.float64)
    if closed:
        pts = np.vstack([pts, pts[:1]])
    seg = np.hypot(*np.diff(pts, axis=0).T)
    s = np.r_[0, np.cumsum(seg)]
    n = max(8, int(s[-1] / step))
    t = np.linspace(0, s[-1], n, endpoint=not closed)
    x = np.interp(t, s, pts[:, 0])
    y = np.interp(t, s, pts[:, 1])
    if amp <= 0:
        return np.c_[x, y]
    rs = np.random.RandomState(seed % (2 ** 31))
    mode = 'wrap' if closed else 'nearest'
    sig = min(2.0, n / 8)
    k = ndi.gaussian_filter1d(rs.randn(n), sig, mode=mode)
    l = ndi.gaussian_filter1d(rs.randn(n), sig, mode=mode)
    k = (k - k.mean()) / (k.std() + 1e-6)
    l = (l - l.mean()) / (l.std() + 1e-6)
    return np.c_[x + amp * k, y + amp * l]


def ell(cx, cy, rx, ry, n=36, rot=0.0):
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    x, y = rx * np.cos(a), ry * np.sin(a)
    c, s = math.cos(rot), math.sin(rot)
    return np.c_[cx + x * c - y * s, cy + x * s + y * c]


def rbox(x0, y0, x1, y1, r):
    r = min(r, (x1 - x0) / 2, (y1 - y0) / 2)
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for d in range(0, 91, 18):
            a = math.radians(a0 + d)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return np.array(pts)


def rock(cx, cy, rx, ry, seed, n=11):
    rs = np.random.RandomState(seed)
    a = np.linspace(0, 2 * np.pi, n, endpoint=False) + rs.rand() * 0.5
    r = 1 + (rs.rand(n) - 0.5) * 0.24
    return np.c_[cx + rx * r * np.cos(a), cy + ry * r * np.sin(a)]


def night_tone(c):
    l = float(0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
    t = min(max((l - 0.08) / 0.86, 0.0), 1.0)
    base = NAVY + (MID - NAVY) * min(t / 0.6, 1.0) if t < 0.6 else MID + (PALE - MID) * (t - 0.6) / 0.4
    return base * 0.8 + c * np.array([0.55, 0.65, 1.0], np.float32) * 0.2


class P:
    """A sheet of paper that shapes get cut out and laid onto."""

    def __init__(self, W, H, night=False, seed=11):
        self.W, self.H, self.night = W, H, night
        self.c = np.ones((H, W, 3), np.float32)
        self.t = textures(H, W, seed)
        self.n = 1000
        self.lwk = 1.0  # line weight multiplier for shapes drawn large

    def tone(self, col, painted=False):
        col = rgb(col) if isinstance(col, str) else col
        if not self.night:
            return col
        return col * np.array([0.93, 0.95, 1.02], np.float32) if painted else night_tone(col)

    def seed(self):
        self.n += 7
        return self.n

    def box(self, a, pad):
        x0 = max(int(a[:, 0].min()) - pad, 0)
        y0 = max(int(a[:, 1].min()) - pad, 0)
        x1 = min(int(a[:, 0].max()) + pad + 1, self.W)
        y1 = min(int(a[:, 1].max()) + pad + 1, self.H)
        return (x0, y0, x1, y1) if x1 > x0 and y1 > y0 else None

    def raster(self, polys, box):
        x0, y0, x1, y1 = box
        im = Image.new('L', ((x1 - x0) * 2, (y1 - y0) * 2), 0)
        d = ImageDraw.Draw(im)
        for a in polys:
            d.polygon([((x - x0) * 2, (y - y0) * 2) for x, y in a], fill=255)
        return np.asarray(im.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS), np.float32) / 255

    def shape(self, pts, col, kind='pencil', line=0.5, lw=1.9, shadow=0.2, rim=0.1, amp=1.3, step=12,
              hatch=0, seed=None, ink=None, painted=None):
        seed = self.seed() if seed is None else seed
        polys = pts if isinstance(pts, Multi) else [pts]
        ws = [wobble(a, step, amp, seed + i) for i, a in enumerate(polys)]
        box = self.box(np.vstack(ws), 16)
        if box is None:
            return
        x0, y0, x1, y1 = box
        m = self.raster(ws, box)
        c = self.c[y0:y1, x0:x1]
        if shadow > 0:
            sh = ndi.gaussian_filter(ndi.shift(m, (4, 2.5), order=1), 3.2)
            c *= 1 - shadow * (sh * (1 - m))[..., None]
        painted = kind == 'crayon' if painted is None else painted
        base = self.tone(col, painted)
        f = self.t['f'][y0:y1, x0:x1]
        mott = self.t['m'][y0:y1, x0:x1]
        if kind == 'crayon':
            h = self.t['c%d' % (hatch % 2)][y0:y1, x0:x1]
            cover = np.clip(0.5 + (h + 1.2) * 1.5, 0, 1)
            d = ndi.distance_transform_edt(m > 0.5)
            edge = np.clip((d + f * 2.2 - 0.6) / 1.8, 0, 1)
            a = (m * cover * edge)[..., None]
            fill = base[None, None, :] * (0.95 + 0.09 * np.tanh(h * 0.7))[..., None]
            c[:] = c * (1 - a) + fill * a
        else:
            h = self.t['h%d' % (hatch % 3)][y0:y1, x0:x1]
            k = 1 + 0.03 * np.tanh(h * 0.9) + 0.045 * mott + 0.012 * f
            a = m[..., None]
            c[:] = c * (1 - a) + base[None, None, :] * k[..., None] * a
        if rim > 0:
            r = np.clip(m - ndi.shift(m, (2, 1.5), order=1), 0, 1)
            c += (1 - c) * rim * r[..., None]
        if line > 0:
            ws2 = [wobble(a, step, amp + 0.6, seed + 50 + i) for i, a in enumerate(polys)]
            m2 = self.raster(ws2, box) > 0.5
            dist = ndi.distance_transform_edt(m2) + ndi.distance_transform_edt(~m2) - 1
            a = np.exp(-(dist / (lw * self.lwk)) ** 2) * np.clip(0.66 + 0.5 * f + 0.22 * mott, 0, 1) * line
            ic = (INK_NIGHT if self.night else INK_DAY) if ink is None else self.tone(ink)
            c[:] = c * (1 - a[..., None]) + ic * a[..., None]

    def line(self, pts, col, w=2.0, a=0.8, closed=False, amp=0.8, seed=None, grain=True, painted=False, step=10):
        seed = self.seed() if seed is None else seed
        q = wobble(pts, step, amp, seed, closed)
        box = self.box(q, int(w) + 6)
        if box is None:
            return
        x0, y0, x1, y1 = box
        im = Image.new('L', ((x1 - x0) * 2, (y1 - y0) * 2), 0)
        seq = [((x - x0) * 2, (y - y0) * 2) for x, y in q]
        if closed:
            seq.append(seq[0])
        ImageDraw.Draw(im).line(seq, fill=255, width=max(1, int(round(w * 2))), joint='curve')
        m = np.asarray(im.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS), np.float32) / 255
        if grain:
            m = m * np.clip(0.74 + 0.45 * self.t['f'][y0:y1, x0:x1] + 0.2 * self.t['m'][y0:y1, x0:x1], 0, 1)
        col = self.tone(col, painted)
        c = self.c[y0:y1, x0:x1]
        al = (a * m)[..., None]
        c[:] = c * (1 - al) + col * al

    def dot(self, x, y, r, col, painted=True):
        self.shape(ell(x, y, r, r, 14), col, line=0, shadow=0, rim=0, amp=0, painted=painted)

    def glow(self, x, y, r, col, a=0.6, painted=True):
        x0, y0 = max(int(x - r * 3), 0), max(int(y - r * 3), 0)
        x1, y1 = min(int(x + r * 3) + 1, self.W), min(int(y + r * 3) + 1, self.H)
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        g = np.exp(-((xx - x) ** 2 + (yy - y) ** 2) / (2 * r * r)) * a
        c = self.c[y0:y1, x0:x1]
        c[:] = 1 - (1 - c) * (1 - self.tone(col, painted) * g[..., None])

    def glow_shape(self, pts, col, spread=9, a=0.9):
        q = np.array(pts, np.float64)
        box = self.box(q, spread * 4)
        if box is None:
            return
        x0, y0, x1, y1 = box
        m = self.raster([q], box)
        g = np.clip(ndi.gaussian_filter(m, spread) * 1.5, 0, 1) * a
        c = self.c[y0:y1, x0:x1]
        c[:] = 1 - (1 - c) * (1 - self.tone(col, True) * g[..., None])

    def dashes(self, pts, col, w=3.0, dash=16, gap=12, a=1.0):
        q = wobble(pts, 3, 0.5, self.seed(), closed=True)
        q = np.vstack([q, q[:1]])
        seg = np.hypot(*np.diff(q, axis=0).T)
        s = np.r_[0, np.cumsum(seg)]
        t = 0.0
        while t < s[-1]:
            ts = np.linspace(t, min(t + dash, s[-1]), 6)
            self.line(np.c_[np.interp(ts, s, q[:, 0]), np.interp(ts, s, q[:, 1])], col, w=w, a=a, amp=0, grain=False,
                      painted=True, step=4)
            t += dash + gap

    def finish(self, grain=0.03):
        k = 1 + grain * self.t['f'] + 0.005 * self.t['m']
        self.c = np.clip(self.c * k[..., None], 0, 1)
        return self.c


def save(arr, path, size=None, **kw):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8))
    if size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    im.save(path, **kw)


# ---- the world's parts ------------------------------------------------------------------------------------------

STONE = '#a9a49a'
WOOD = '#b9946b'
WOOD_D = '#7e6147'
WOOD_L = '#d5b68f'
GRASS = '#a3b47e'
GRASS_D = '#8c9f6c'
SKIN = '#f0c9a6'
HAIR = '#5a3b28'
BOOT = '#4a3a30'
WHITE = '#fffdf5'
RED = '#e6402c'
BLUE = '#2a97e3'
YELLOW = '#ffd21f'
GREEN = '#3fb24b'
PINK = '#ff6fb0'
PURPLE = '#7a3fd1'
ORANGE = '#f08a24'
COAT = '#e0982c'
ROPE = '#b48a52'


def ridge(W, base, amps, seed, H):
    rs = np.random.RandomState(seed)
    xs = np.arange(-40, W + 41, 24, dtype=np.float64)
    ys = np.full_like(xs, base)
    for a, wl in amps:
        ys += a * np.sin(xs / wl + rs.rand() * 6.28)
    return np.vstack([np.c_[xs, ys], [W + 40, H + 40], [-40, H + 40]])


def cloud(p, cx, cy, sc, col='#f6f1e4'):
    u = U * sc
    parts = Multi([ell(cx - 1.6 * u, cy + .25 * u, 1.3 * u, .62 * u), ell(cx, cy - .2 * u, 1.7 * u, 1.0 * u),
                   ell(cx + 1.8 * u, cy + .2 * u, 1.4 * u, .7 * u), ell(cx + .4 * u, cy + .45 * u, 2.6 * u, .5 * u)])
    p.shape(parts, col, line=0.12, shadow=0.1, rim=0.25, amp=2.0, step=16, hatch=1)


def tree(p, x, gy, sc=1.0, col='#94a878', seed=1):
    u = U * sc
    X, Y = x * U, gy * U
    p.shape([[X - .22 * u, Y + 3], [X - .14 * u, Y - 2.6 * u], [X + .14 * u, Y - 2.6 * u], [X + .26 * u, Y + 3]], WOOD_D,
            line=0.4, shadow=0.15, hatch=2, seed=seed)
    parts = Multi([ell(X, Y - 3.4 * u, 1.5 * u, 1.3 * u), ell(X - 1.0 * u, Y - 2.6 * u, 1.1 * u, .9 * u),
                   ell(X + 1.05 * u, Y - 2.7 * u, 1.1 * u, .95 * u), ell(X + .1 * u, Y - 4.2 * u, 1.0 * u, .85 * u)])
    p.shape(parts, col, line=0.4, shadow=0.2, rim=0.14, amp=2.2, step=14, hatch=1, seed=seed + 3)
    for dx, dy, rx in ((-.5, -3.7, .55), (.6, -3.1, .5), (-.1, -2.7, .42)):
        p.line(ell(X + dx * u, Y + dy * u, rx * u, rx * .7 * u, 14)[2:8], GRASS_D, w=2, a=0.5, amp=.6)


def earth_block(p, x, y, col, stone=False, seed=None):
    rs = np.random.RandomState(x * 37 + y * 101)
    c = rgb(col) * (0.97 + rs.rand() * 0.07)
    px, py = x * U, y * U
    p.shape(rbox(px, py, px + U, py + U, 6), c, line=0.17, lw=1.3, shadow=0.07, rim=0.07, amp=.7,
            hatch=(x + y) % 3, step=9, seed=seed)
    if stone:
        p.shape(rock(px + U * .5, py + U * .52, U * .3, U * .24, x * 5 + y), STONE, line=0.35, lw=1.3, shadow=0.12, amp=.6,
                step=6)


def wood_block(p, x, y, stress=None):
    px, py = x * U, y * U
    p.shape(rbox(px, py, px + U, py + U, 4), WOOD, line=0.6, lw=1.8, shadow=0.2, rim=0.14, amp=.8,
            hatch=2, step=9)
    p.line([[px + 4, py + U * .36], [px + U - 4, py + U * .36]], WOOD_D, w=1.6, a=.55)
    p.line([[px + 4, py + U * .68], [px + U - 4, py + U * .68]], WOOD_D, w=1.6, a=.55)
    for ny in (.18, .84):
        p.dot(px + 7, py + U * ny, 1.8, WOOD_D, painted=False)
        p.dot(px + U - 7, py + U * ny, 1.8, WOOD_D, painted=False)
    if stress:
        p.shape(rbox(px + 6, py + U - 15, px + U - 6, py + U - 4, 3), stress, kind='crayon', line=0, shadow=0, rim=0, amp=.5,
                step=6)


def wheel(p, cx, cy, r):
    for k in range(8):
        a = k * math.pi / 4 + 0.2
        p.line([[cx, cy], [cx + r * .9 * math.cos(a), cy + r * .9 * math.sin(a)]], WOOD_D, w=r * .1, a=1, amp=.5,
               grain=False)
    p.line(ell(cx, cy, r, r, 40), WOOD_D, w=r * .19, a=1, closed=True, amp=.5, grain=False)
    p.line(ell(cx, cy, r * .96, r * .96, 40), WOOD_L, w=2.2, a=.55, closed=True, amp=.5)
    p.shape(ell(cx, cy, r * .22, r * .22, 16), WOOD, line=.6, shadow=.1)


def house(p, x, gy, u=U, wheels=True):
    L, B = x * U, gy * U
    lit = p.night
    # chimney and smoke behind the roof
    p.shape(rbox(L + 6.3 * u, B - 8.1 * u, L + 7.1 * u, B - 5.8 * u, 4), STONE, line=.5, shadow=.15, hatch=2)
    p.shape(rbox(L + 6.15 * u, B - 8.25 * u, L + 7.25 * u, B - 7.95 * u, 4), '#8f8a80', line=.5, shadow=.12)
    for k, (dx, dy, r) in enumerate(((6.9, 8.9, .34), (7.3, 9.5, .42), (7.9, 9.9, .32))):
        p.shape(ell(L + dx * u, B - dy * u, r * u, r * .8 * u, 16), '#efeadf', line=.16, shadow=.05, rim=.2, amp=1.4)
    # undercarriage and wheels
    p.shape(rbox(L + .7 * u, B - 1.42 * u, L + 8.3 * u, B - 1.08 * u, 4), WOOD_D, line=.5, shadow=.2)
    if wheels:
        wheel(p, L + 2.2 * u, B - 1.02 * u, 1.02 * u)
        wheel(p, L + 6.8 * u, B - 1.02 * u, 1.02 * u)
    # body
    p.shape(rbox(L + .35 * u, B - 5.2 * u, L + 8.65 * u, B - 1.3 * u, 10), '#dccaa6', line=.7, lw=2.2, shadow=.25, rim=.14,
            hatch=2)
    for k in range(1, 12):
        lx = L + .35 * u + k * 8.3 * u / 12
        p.line([[lx, B - 5.1 * u], [lx, B - 1.4 * u]], WOOD_D, w=1.3, a=.26)
    p.shape(rbox(L + .35 * u, B - 2.2 * u, L + 8.65 * u, B - 1.3 * u, 8), '#a9bda8', line=.6, shadow=.08, rim=.1, hatch=1)
    # roof: a barrel arch with scalloped rows
    arch = [(L + (-.25 + 9.5 * t) * u, B - (5.0 + 2.5 * math.sin(math.pi * t) ** .7) * u) for t in np.linspace(0, 1, 26)]
    roof = np.array(arch + [(L + 9.25 * u, B - 4.8 * u), (L - .25 * u, B - 4.8 * u)])
    p.shape(roof, '#bb7a60', line=.7, lw=2.2, shadow=.25, rim=.15, step=14, hatch=1)
    for row in range(1, 4):
        k = 1 - row * .24
        for t in np.arange(.06, .96, .1):
            cx = L + (-.25 + 9.5 * t) * u
            cy = B - (5.0 + 2.5 * k * math.sin(math.pi * t) ** .7) * u
            p.line(ell(cx, cy, .42 * u, .26 * u, 12)[0:7], '#8e5645', w=1.5, a=.42, amp=.4)
    # flag with her easel picture: a pixel heart
    fx, fy = L + 2.0 * u, B - 7.0 * u
    p.line([[fx, fy + .5 * u], [fx, fy - 1.9 * u]], WOOD_D, w=3.4, a=1)
    p.shape([[fx + 2, fy - 1.9 * u], [fx + 1.55 * u, fy - 1.7 * u], [fx + 1.45 * u, fy - .75 * u], [fx + 2, fy - .75 * u]],
            '#f6efdf', line=.6, shadow=.15, rim=.1, painted=True, step=10)
    grid = ('.XX.XX.', 'XXXXXXX', 'XXXXXXX', '.XXXXX.', '..XXX..', '...X...')
    s = .16 * u
    for gy_, row in enumerate(grid):
        for gx_, ch in enumerate(row):
            if ch == 'X':
                x0, y0 = fx + .2 * u + gx_ * s, fy - 1.72 * u + gy_ * s
                p.shape(rbox(x0, y0, x0 + s, y0 + s, 1), RED, line=0, shadow=0, rim=0, amp=0, step=6, painted=True)
    # window
    wx, wy = L + 2.9 * u, B - 3.55 * u
    if lit:
        p.glow(wx, wy, 1.5 * u, '#ffb44a', a=.42)
    p.shape(ell(wx, wy, .92 * u, .92 * u), WOOD, line=.7, shadow=.15, rim=.12)
    p.shape(ell(wx, wy, .72 * u, .72 * u), '#ffd070' if lit else '#cbdfe3', line=.5, shadow=0, rim=0,
            painted=lit)
    p.line([[wx - .72 * u, wy], [wx + .72 * u, wy]], WOOD_D, w=3, a=.9, amp=.4)
    p.line([[wx, wy - .72 * u], [wx, wy + .72 * u]], WOOD_D, w=3, a=.9, amp=.4)
    # door, steps, bell and lantern
    dx0, dx1 = L + 5.2 * u, L + 6.9 * u
    door = np.array([(dx0, B - 1.5 * u), (dx0, B - 3.9 * u)] +
                    [((dx0 + dx1) / 2 + (dx1 - dx0) / 2 * math.cos(a), B - 3.9 * u - .75 * u * math.sin(a))
                     for a in np.linspace(math.pi, 0, 12)] + [(dx1, B - 1.5 * u)])
    p.shape(door, '#8ea17f', line=.7, lw=2.1, shadow=.14, rim=.12, hatch=2)
    p.line([[(dx0 + dx1) / 2, B - 4.4 * u], [(dx0 + dx1) / 2, B - 1.55 * u]], rgb('#6f8262'), w=1.6, a=.6)
    p.dot(dx1 - .24 * u, B - 2.7 * u, 3.5, '#c8a75a', painted=False)
    for k in range(3):
        y = B - (1.15 - k * -.0 + k * -.42) * u
        p.shape(rbox(dx0 - .05 * u + k * 0, B - (1.3 - k * .42) * u, dx1 + .05 * u, B - (1.12 - k * .42) * u, 3), WOOD, line=.5,
                shadow=.15)
    bx, by = L + 1.1 * u, B - 3.7 * u
    p.line([[bx - .3 * u, by - .55 * u], [bx + .05 * u, by - .55 * u]], WOOD_D, w=3.5, a=1)
    p.shape(np.array([(bx - .22 * u, by + .05 * u), (bx - .14 * u, by - .34 * u), (bx - .02 * u, by - .46 * u),
                      (bx + .1 * u, by - .34 * u), (bx + .18 * u, by + .05 * u)]), '#cdaa52', line=.6, shadow=.12, rim=.2)


def face(p, X, Y, f, r):
    p.dot(X + .34 * f * r, Y - .02 * r, r * .1, '#2b211c')
    p.dot(X - .14 * f * r, Y - .02 * r, r * .1, '#2b211c')
    p.dot(X + .52 * f * r, Y + .3 * r, r * .16, '#ec9a86')
    p.dot(X - .34 * f * r, Y + .3 * r, r * .16, '#ec9a86')
    p.line([[X + .02 * f * r, Y + .36 * r], [X + .12 * f * r, Y + .43 * r], [X + .24 * f * r, Y + .35 * r]], '#7a3b2e', w=1.8,
           a=.9, amp=0, painted=True, step=3)


def marta(p, x, gy, f=1, cloak=RED, tip=WHITE, scale=1.0, brush=True):
    u = U * scale
    X, Y = x * U, gy * U
    S = dict(painted=True)
    for dx in (-.2, .1):
        p.shape(rbox(X + dx * u - .03 * u, Y - .22 * u, X + dx * u + .2 * u, Y + 1, 4), BOOT, line=.6, shadow=.12, **S)
    for k, (dx, dy, r) in enumerate(((-.42, -1.42, .13), (-.5, -1.25, .125), (-.54, -1.09, .115), (-.54, -.94, .1))):
        p.shape(ell(X + dx * f * u, Y + dy * u, r * u, r * .86 * u, 12), HAIR, line=.5, lw=1.2, shadow=.08, rim=.1, painted=True, amp=.3, step=6)
    p.dot(X - .54 * f * u, Y - .83 * u, .075 * u, YELLOW)
    # the brush, behind the near arm
    if brush:
        p.line([[X + .1 * f * u, Y - .72 * u], [X + .86 * f * u, Y - 1.72 * u]], WOOD_D, w=.09 * u, a=1, amp=.3, grain=False,
               painted=True)
        bx, by = X + .92 * f * u, Y - 1.8 * u
        p.shape(ell(bx, by, .15 * u, .24 * u, 14, rot=math.radians(36 * f)), tip, kind='crayon', line=.75, lw=1.6, shadow=.14)
    pts = [[X - .17 * u, Y - 1.5 * u], [X + .17 * u, Y - 1.5 * u], [X + .5 * u, Y - .16 * u], [X + .24 * u, Y - .1 * u],
           [X - .24 * u, Y - .1 * u], [X - .5 * u, Y - .16 * u]]
    p.shape(pts, '#efe6d4', line=0, shadow=.22, rim=0, painted=True, step=8)
    p.shape(pts, cloak, kind='crayon', line=.8, lw=2.1, shadow=0, rim=.08, step=8)
    p.shape(ell(X, Y - 1.7 * u, .52 * u, .52 * u), '#efe6d4', line=0, shadow=.12, rim=0, painted=True)
    p.shape(ell(X, Y - 1.7 * u, .52 * u, .52 * u), cloak, kind='crayon', line=.8, lw=2.1, shadow=0, hatch=1, rim=.08)
    r = .36 * u
    fx, fy = X + .1 * f * u, Y - 1.66 * u
    p.shape(ell(fx, fy, r, r * .96, 22), SKIN, line=.55, lw=1.5, shadow=.08, rim=0, painted=True, amp=.5, step=6)
    top = [(fx + r * .99 * math.cos(a), fy + r * .95 * math.sin(a)) for a in np.linspace(math.pi * 1.02, math.pi * 1.98, 16)]
    dip = [(fx + (1 - t) * r * f * .98 - t * r * f * .98 - .0, fy - r * (.02 + .42 * math.sin(math.pi * t) ** .6 - .18 * t)) for t in np.linspace(0, 1, 12)]
    if f < 0:
        dip = dip[::-1]
    p.shape(np.array(top + (dip if f > 0 else dip)[::1]), HAIR, line=.3, lw=1.3, shadow=0, rim=.08, painted=True, amp=.3, step=5)
    face(p, fx, fy + r * .12, f, r)
    p.shape(ell(X + .3 * f * u, Y - .92 * u, .13 * u, .13 * u, 12), SKIN, line=.55, lw=1.4, shadow=.1, rim=0, painted=True)


def giulio(p, x, gy, f=1, coat=COAT, tool='hammer', scale=1.0):
    u = U * scale
    X, Y = x * U, gy * U
    S = dict(painted=True)
    for dx in (-.24, .08):
        p.shape(rbox(X + dx * u - .03 * u, Y - .2 * u, X + dx * u + .2 * u, Y + 1, 4), BOOT, line=.6, shadow=.12, **S)
    # the tool behind the raised arm
    hx, hy = X + .66 * f * u, Y - 1.72 * u
    if tool in ('hammer', 'pick'):
        p.line([[X + .22 * f * u, Y - .86 * u], [hx, hy]], WOOD_L, w=.1 * u, a=1, amp=.3, grain=False, painted=True)
    if tool == 'hammer':
        p.shape(rbox(hx - .3 * u, hy - .17 * u, hx + .3 * u, hy + .17 * u, 3), '#9aa3ad', line=.75, lw=1.8, shadow=.14, rim=.2,
                painted=True, step=7)
    elif tool == 'pick':
        arc = [(hx + .62 * u * math.cos(a), hy + .5 * u + .54 * u * math.sin(a)) for a in np.linspace(-2.45, -.69, 12)]
        p.line(arc, '#9aa3ad', w=.13 * u, a=1, amp=.3, grain=False, painted=True)
    elif tool == 'rope':
        rope_coil(p, X + .5 * f * u, Y - 1.02 * u, .3 * u)
    pts = rbox(X - .4 * u, Y - 1.12 * u, X + .4 * u, Y - .16 * u, .2 * u)
    p.shape(pts, '#efe6d4', line=0, shadow=.22, rim=0, painted=True)
    p.shape(pts, coat, kind='crayon', line=.8, lw=2.1, shadow=0, rim=.08)
    p.line([[X - .38 * u, Y - .44 * u], [X + .38 * u, Y - .44 * u]], '#5e4633', w=.1 * u, a=1, amp=.3, grain=False, painted=True)
    p.dot(X + .1 * f * u, Y - .44 * u, .07 * u, '#d9c070')
    r = .4 * u
    fx, fy = X + .04 * f * u, Y - 1.38 * u
    p.shape(ell(fx, fy, r, r * .96, 22), SKIN, line=.6, lw=1.5, shadow=.1, rim=0, painted=True, amp=.5, step=6)
    face(p, fx, fy + r * .16, f, r)
    cap = np.array([(fx - r * 1.04, fy - r * .1)] + [(fx + r * 1.04 * math.cos(a), fy - r * .1 - r * 1.04 * math.sin(a))
                                                     for a in np.linspace(math.pi, 0, 14)] + [(fx + r * 1.04, fy - r * .1)])
    p.shape(cap, '#3f8f8c', line=.75, lw=1.8, shadow=.1, rim=.1, painted=True, amp=.6, step=7)
    p.shape(rbox(fx - r * 1.1, fy - r * .34, fx + r * 1.1, fy - r * .04, 3), '#e7dfcb', line=.6, lw=1.5, shadow=.06, rim=.05,
            painted=True)
    p.dot(fx, fy - r * 1.22, .1 * u, '#e7dfcb')
    p.shape(ell(X + .3 * f * u, Y - .86 * u, .12 * u, .12 * u, 12), SKIN, line=.55, lw=1.4, shadow=.1, rim=0, painted=True)


def rope_coil(p, cx, cy, r):
    for k in range(3):
        p.line(ell(cx + (k - 1) * r * .18, cy, r * .62, r, 18), ROPE, w=r * .2, a=1, closed=True, amp=.3, grain=False,
               painted=True)
    p.line([(cx + r * .4, cy + r * .8), (cx + r * .55, cy + r * 1.5)], ROPE, w=r * .2, a=1, amp=.3, grain=False, painted=True)


def sparkle(p, x, y, r, col=WHITE):
    a = .22 * r
    p.shape(np.array([(x, y - r), (x + a, y - a), (x + r, y), (x + a, y + a), (x, y + r), (x - a, y + a), (x - r, y),
                      (x - a, y - a)]), col, line=0, shadow=0, rim=0, amp=0, painted=True, step=3)


def painted_rock(p, cx, cy, rx, ry, col, seed, base=STONE, hatch=0):
    pts = rock(cx, cy, rx, ry, seed)
    p.shape(pts, base, line=0, shadow=.24, rim=.1, amp=1, step=9, seed=seed)
    p.shape(pts, col, kind='crayon', line=.78, lw=2.1, shadow=0, rim=.14, amp=1, step=9, seed=seed, hatch=hatch)
    return pts


def plain_rock(p, cx, cy, rx, ry, seed):
    pts = rock(cx, cy, rx, ry, seed)
    p.shape(pts, STONE, line=.65, lw=2.0, shadow=.24, rim=.16, amp=1, step=9, seed=seed, hatch=1)
    p.line([(cx - rx * .3, cy - ry * .2), (cx + rx * .1, cy + ry * .1), (cx + rx * .2, cy + ry * .5)], '#7c776e', w=1.6, a=.5)
    return pts


def grass_strip(p, x0, x1, gy):
    pts = [(x0, gy - 2)]
    xs = np.arange(x0, x1 + 1, 14.0)
    rs = np.random.RandomState(abs(int(x0)) + 3)
    top = [(x, gy - 3 + rs.rand() * 4) for x in xs]
    bottom = [(x, gy + 11 + 6 * math.sin(x / 19) + rs.rand() * 3) for x in xs[::-1]]
    p.shape(np.array(top + bottom), GRASS, line=.4, lw=1.7, shadow=.16, rim=.16, amp=1, step=12, hatch=1)
    for x in xs[::2]:
        for k in range(3):
            dx = rs.rand() * 10 - 5
            h = 8 + rs.rand() * 8
            p.line([(x + dx, gy + 2), (x + dx + rs.rand() * 5 - 2.5, gy - h)], GRASS_D, w=2.2, a=.8, amp=.2, step=6)


def flowers(p, xs, gy, seed):
    rs = np.random.RandomState(seed)
    for x in xs:
        X = x * U
        h = 12 + rs.rand() * 10
        p.line([(X, gy * U + 2), (X + rs.rand() * 4 - 2, gy * U - h)], GRASS_D, w=2.2, a=.9, amp=.2, step=6)
        col = ('#e6d9c0', '#d9c1b0', '#dcd2a6')[int(rs.rand() * 3)]
        for a in np.linspace(0, 6.28, 5, endpoint=False):
            p.dot(X + 4 * math.cos(a), gy * U - h + 4 * math.sin(a), 3.3, col, painted=False)
        p.dot(X, gy * U - h, 2.2, '#b99a5e', painted=False)


# ---- the river stop ---------------------------------------------------------------------------------------------

STRESS = {28: GREEN, 29: GREEN, 30: YELLOW, 31: ORANGE, 32: YELLOW, 33: GREEN, 34: GREEN, 35: YELLOW}


def river_stop(night):
    W, H = 60 * U, 15 * U
    p = P(W, H, night)
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, low = (rgb('#17214c'), rgb('#44598f')) if night else (rgb('#bfd9e0'), rgb('#f5ecd9'))
    p.c[:] = top * (1 - y) + low * y
    p.c *= (1 + .008 * np.tanh(p.t['c1']) + .016 * p.t['m'])[..., None]
    # sun or moon, stars, clouds
    sx, sy = 40 * U, 2.6 * U
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
        p.shape(ell(sx, sy, 1.25 * U, 1.25 * U), '#fbe6ad', line=.2, shadow=.08, rim=.25, painted=False, step=14)
    for cx, cy, sc in ((7, 2.2, .9), (21, 3.6, .7), (31, 1.7, 1.0), (50, 3.0, .85), (58, 1.5, .7)):
        cloud(p, cx * U, cy * U, sc, '#f5f0e3' if not night else '#8fa0c8')
    # the far land
    peaks = [(30, 15), (37, 7.4), (41, 8.9), (45, 5.9), (49, 8.1), (54, 6.4), (61, 15)]
    p.shape(np.array([(x * U, yy * U) for x, yy in peaks]), '#c6cfcf', line=.1, shadow=.05, rim=.2, step=26, amp=3)
    for x, yy, w in ((45, 5.9, .9), (54, 6.4, .8), (37, 7.4, .6)):
        p.shape(np.array([((x - w) * U, (yy + 1.15) * U), (x * U, yy * U), ((x + w) * U, (yy + 1.15) * U), ((x + .25) * U, (yy + .9) * U),
                          ((x - .2) * U, (yy + 1.2) * U)]), '#ecebe4', line=.05, shadow=0, rim=.1, amp=1.2)
    p.shape(ridge(W, 8.3 * U, ((26, 170), (14, 70)), 2, H), '#c3d0b4', line=.12, shadow=.12, rim=.2, step=20, amp=2, hatch=1)
    for x in (3.5, 6, 18, 21, 26, 33.5, 52):
        tree(p, x, 8.8, .5, '#a8b995', seed=int(x * 3))
    p.shape(ridge(W, 9.25 * U, ((18, 120), (9, 45)), 5, H), '#b2c19b', line=.14, shadow=.16, rim=.18, step=18, amp=2, hatch=2)
    # the river
    p.shape(rbox(27.6 * U, 12.45 * U, 42.4 * U, 16 * U, 6), '#9cc1c4', line=.35, shadow=.1, rim=.3, hatch=1, step=18, amp=1.6)
    for k, yy in enumerate((13.0, 13.55, 14.15, 14.6)):
        for x0 in np.arange(28 + k * .7, 42, 3.1):
            xs = np.linspace(x0, x0 + 1.5, 10) * U
            p.line(np.c_[xs, yy * U + 3 * np.sin(xs / 16)], '#c9dddc', w=2.1, a=.7, amp=.3, step=6)
    # banks: blocks of earth, a dug tunnel with a ladder, and a buried gear
    rows = ['#b39877', '#a98f70', '#9e866a', '#937c63', '#88725b']
    dug = {(20, 11), (21, 11), (22, 11), (20, 12), (21, 12), (22, 12), (23, 12), (24, 12), (20, 10)}
    stones = {(6, 12), (15, 13), (11, 14), (25, 14), (3, 11), (44, 12), (49, 13), (56, 11), (17, 12)}
    p.shape(rbox(-20, 10 * U, 28 * U, 16 * U, 0), rows[3], line=0, shadow=0, rim=0, amp=0)
    p.shape(rbox(42 * U, 10 * U, W + 20, 16 * U, 0), rows[3], line=0, shadow=0, rim=0, amp=0)
    for r, col in enumerate(rows):
        for x in list(range(0, 28)) + list(range(42, 60)):
            if (x, 10 + r) not in dug:
                earth_block(p, x, 10 + r, col, stone=(x, 10 + r) in stones)
    # back wall of the tunnel
    for x, yy in sorted(dug):
        px, py = x * U, yy * U
        p.shape(rbox(px, py, px + U, py + U, 2), '#6a5644', line=0, shadow=0, rim=0, amp=.4, step=9)
    gx, gy_ = 24.5 * U, 13.5 * U
    p.shape(ell(gx, gy_, .42 * U, .42 * U, 12), '#a7adb2', line=.7, shadow=.15, rim=.18, painted=False)
    for a in np.arange(0, 6.28, .785):
        p.line([(gx + .4 * U * math.cos(a), gy_ + .4 * U * math.sin(a)), (gx + .55 * U * math.cos(a), gy_ + .55 * U * math.sin(a))],
               '#a7adb2', w=7, a=1, amp=0, grain=False, step=4)
    p.dot(gx, gy_, .14 * U, '#6b7075', painted=False)
    for xs_ in (20.28, 20.72):
        p.line([(xs_ * U, 9.4 * U), (xs_ * U, 12.95 * U)], WOOD_D, w=3.8, a=1, amp=.5, grain=False)
    for yy in np.arange(9.7, 12.9, .42):
        p.line([(20.26 * U, yy * U), (20.74 * U, yy * U)], WOOD, w=3.6, a=1, amp=.4, grain=False)
    grass_strip(p, -20, 20 * U, 10 * U)
    grass_strip(p, 21 * U, 28 * U + 5, 10 * U)
    grass_strip(p, 42 * U - 5, W + 20, 10 * U)
    flowers(p, (.8, 2.2, 3.4, 18.6, 44.2, 45.1, 47.6, 53.2, 54.1, 58.3), 10, 3)
    tree(p, 2.2, 10, 1.0, seed=31)
    tree(p, 46.5, 10, 1.1, seed=41)
    tree(p, 57.5, 10, .95, '#8da374', seed=51)
    # a high ledge with a rock nobody can reach yet
    p.shape(rbox(50 * U, 8 * U, 59 * U, 10 * U, 0), '#a98f70', line=0, shadow=.1, rim=0, amp=0)
    for x in range(50, 59):
        for yy in (8, 9):
            earth_block(p, x, yy, '#b39877')
    grass_strip(p, 50 * U - 5, 59 * U + 5, 8 * U)
    plain_rock(p, 54.2 * U, 7.15 * U, .95 * U, .86 * U, 8)
    house(p, 7.2, 10)
    # bridge blocks, with the white rock holding it up
    wisp = Multi([ell(34 * U + dx * U, 13.1 * U + dy * U, r * U, r * .7 * U, 16) for dx, dy, r in
                  ((-.7, .05, .45), (0, .22, .6), (.7, .03, .44))])
    p.shape(wisp, '#f8f6ee', line=.2, shadow=.1, rim=.2, painted=True, amp=1)
    painted_rock(p, 34 * U, 12.05 * U, 1.12 * U, 1.0 * U, WHITE, 19, base='#e3e6ea')
    for x, yy, r in ((32.6, 12.6, 6), (35.5, 11.9, 8), (35.1, 13.0, 5)):
        sparkle(p, x * U, yy * U, r * 1.4)
    for x in range(28, 36):
        wood_block(p, x, 10, STRESS[x])
    # ice around the blue stone
    ice = np.array([(36.2, 12.46), (37.5, 12.32), (39.1, 12.28), (40.8, 12.34), (41.9, 12.44), (41.5, 12.82), (40.1, 12.95),
                    (38.4, 13.02), (36.9, 12.9)]) * U
    p.shape(ice, '#dff1f7', line=.5, shadow=.14, rim=.4, step=14, hatch=1, painted=True)
    for x0, x1 in ((37, 37.9), (39.2, 40.3), (38.2, 38.7)):
        p.line([(x0 * U, 12.62 * U), (x1 * U, 12.56 * U)], '#a9d4e6', w=2.2, a=.9, amp=.4, painted=True)
    painted_rock(p, 39 * U, 11.86 * U, .78 * U, .62 * U, BLUE, 23, hatch=1)
    # a bright stone the night view can use, and the rock she has selected
    rc = (25.4 * U, 9.18 * U)
    pts = rock(rc[0], rc[1], .95 * U, .84 * U, 13)
    q = (pts - rc) * 1.22 + rc
    if not night:
        p.glow_shape(q, '#ffefa8', spread=8, a=.55)
    plain_rock(p, rc[0], rc[1], .95 * U, .84 * U, 13)
    if night:
        p.glow(22.6 * U, 9.0 * U, 1.0 * U, '#f6c7a0', a=.34)
        for dx, dy, r in ((-.5, -.5, 5), (.4, -.9, 4), (.3, .1, 6)):
            sparkle(p, (22.6 + dx) * U, (9 + dy) * U, r, '#ffe3c2')
        giulio(p, 33.0, 10, 1)
        c = (36.5 * U, 10.5 * U)
        q = np.array([(c[0] - 27, c[1] - 27), (c[0] + 27, c[1] - 27), (c[0] + 27, c[1] + 27), (c[0] - 27, c[1] + 27)])
        p.glow_shape(q, '#ffe9b0', spread=6, a=.3)
        p.dashes(q, '#fff3d0', w=3.4, dash=13, gap=8)
    else:
        p.dashes(q, '#fff3b4', w=4, dash=15, gap=10)
        p.glow(33 * U, 9.1 * U, 1.0 * U, '#ffe7b0', a=.5)
        for dx, dy, r in ((-.5, -.5, 5), (.4, -.9, 4), (.3, .1, 6)):
            sparkle(p, (33 + dx) * U, (9 + dy) * U, r, '#fff6dc')
        marta(p, 23.1, 10, 1)
    return p.finish()


def hud(p, night_y, col_sel=0, tool_sel=0):
    # her crayons, in a paper strip
    p.shape(rbox(26, 24, 348, 112, 12), '#f3ecdd', line=.5, shadow=.3, rim=.2, painted=True, hatch=1)
    for k, col in enumerate((WHITE, BLUE, RED, YELLOW)):
        x, y = 82 + k * 70, 68
        if k == col_sel:
            p.shape(ell(x, y, 35, 35, 24), '#d9c9a4', line=.8, lw=2.4, shadow=0, rim=0, painted=True, amp=.8)
        q = ell(x, y, 25, 25, 22)
        p.shape(q, '#d9d2c2' if col == WHITE else '#efe6d4', line=0, shadow=.12, rim=0, painted=True, amp=1)
        p.shape(q, col, kind='crayon', line=.7, lw=1.8, shadow=0, rim=.08, amp=1, step=7, hatch=k)
    # his tools, in a paper strip
    y0 = night_y + 24
    p.shape(rbox(26, y0, 348, y0 + 88, 12), '#e5e0d4', line=.5, shadow=.3, rim=.2, painted=True, hatch=2)
    cx, cy = 82, y0 + 44
    p.shape(ell(cx + tool_sel * 70, cy, 35, 35, 24), '#cdbf9f', line=.8, lw=2.4, shadow=0, rim=0, painted=True, amp=.8)
    p.line([(cx - 14, cy + 20), (cx + 8, cy - 8)], WOOD_D, w=6, a=1, amp=.3, grain=False, painted=True)
    p.shape(rbox(cx - 8, cy - 22, cx + 24, cy - 4, 3), '#7f8892', line=.7, lw=1.6, shadow=.1, rim=.2, painted=True, step=6)
    cx += 70
    p.line([(cx - 14, cy + 20), (cx + 8, cy - 10)], WOOD_D, w=6, a=1, amp=.3, grain=False, painted=True)
    arc = [(cx + 4 + 26 * math.cos(a), cy + 2 + 22 * math.sin(a)) for a in np.linspace(-2.7, -.3, 10)]
    p.line(arc, '#7f8892', w=7, a=1, amp=.3, grain=False, painted=True)
    cx += 70
    p.line(ell(cx, cy, 20, 20, 24), '#a58a5f', w=5, a=1, closed=True, amp=.5, grain=False, painted=True)
    p.line(ell(cx, cy, 11, 11, 18), '#a58a5f', w=5, a=1, closed=True, amp=.5, grain=False, painted=True)
    cx += 70
    p.line(ell(cx, cy, 22, 22, 24), '#b9b2a2', w=4, a=.9, closed=True, amp=.5, painted=True)
    for k in range(4):
        a = k * math.pi / 2 + .4
        p.line([(cx, cy), (cx + 20 * math.cos(a), cy + 20 * math.sin(a))], '#b9b2a2', w=3, a=.9, amp=.2, painted=True)


def split(day, night, cam_day=0, cam_night=6 * U, col_sel=0, tool_sel=0):
    H = 15 * U
    W = int(H * 2 * 16 / 9)
    a = day[:, cam_day:cam_day + W]
    b = night[:, cam_night:cam_night + W]
    sheet = np.concatenate([a, b], axis=0)
    p = P(W, H * 2)
    p.c[:] = sheet
    # a torn edge: the day sheet lies over the night sheet
    xs = np.arange(-20, W + 21, 14.0)
    rs = np.random.RandomState(9)
    edge = ndi.gaussian_filter1d(rs.randn(len(xs)), 1.2) * 11
    torn = np.vstack([np.c_[xs, H + 9 + edge], [W + 20, H - 40], [-20, H - 40]])
    p.shape(torn, '#f4eee0', line=.3, lw=1.5, shadow=.5, rim=.1, amp=1, step=10, painted=True, hatch=1)
    p.c[:H - 1] = sheet[:H - 1]
    # the sun and moon on the join: they close in on each other along the road
    cx, cy = W / 2, H + 2
    p.shape(ell(cx - 27, cy, 44, 44, 30), '#f3c95a', line=.6, shadow=.3, rim=.2, painted=True, step=9)
    p.shape(ell(cx + 27, cy, 44, 44, 30), '#31427c', line=.6, shadow=.25, rim=.2, painted=True, step=9)
    hud(p, H, col_sel, tool_sel)
    return p.finish(.02)


# ---- the old mines: the one place it gets dark --------------------------------------------------------------------


def sootling(p, x, y, r, seed):
    rs = np.random.RandomState(seed)
    n = 18
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    rr = r * (1 + .2 * (-1.0) ** np.arange(n) + rs.rand(n) * .1)
    p.shape(np.c_[x + rr * np.cos(a), y + rr * np.sin(a) * .9], '#2a2730', line=.25, shadow=.12, rim=.03, amp=.5, step=5,
            painted=True)


def soot_eyes(p, x, y, r):
    for dx in (-.34, .34):
        p.dot(x + dx * r, y - .1 * r, r * .25, '#fff8e6')
        p.dot(x + dx * r + r * .05, y - .07 * r, r * .1, '#191622')


def mole(p, x, gy, scale=1.0):
    u = U * scale
    X, Y = x * U, gy * U
    p.shape(ell(X, Y - .44 * u, .5 * u, .48 * u, 22), '#7b6253', line=.65, lw=1.7, shadow=.18, rim=.1, painted=True, amp=.7)
    p.shape(ell(X + .04 * u, Y - .34 * u, .3 * u, .3 * u, 18), '#b79a86', line=0, shadow=0, rim=0, painted=True, amp=.5)
    p.shape(ell(X + .12 * u, Y - .62 * u, .2 * u, .14 * u, 14), '#e7b9a8', line=.5, lw=1.3, shadow=.08, rim=0, painted=True, amp=.3)
    p.dot(X + .27 * u, Y - .64 * u, .06 * u, '#d9607c')
    p.dot(X + .02 * u, Y - .72 * u, .05 * u, '#231a16')
    p.dot(X + .26 * u, Y - .76 * u, .05 * u, '#231a16')
    for dx in (-.34, .4):
        p.shape(ell(X + dx * u, Y - .3 * u, .13 * u, .1 * u, 12), '#e7b9a8', line=.5, lw=1.3, shadow=.08, rim=0, painted=True, amp=.3)


def mine_cart(p, x, gy):
    X, Y = x * U, gy * U
    wheel(p, X + .9 * U, Y - .34 * U, .32 * U)
    wheel(p, X + 2.5 * U, Y - .34 * U, .32 * U)
    for k, (dx, dy) in enumerate(((1.2, 1.9), (2.1, 1.85), (1.65, 2.2))):
        plain_rock(p, X + dx * U, Y - dy * U, .5 * U, .42 * U, 60 + k)
    p.shape(np.array([(X, Y - 1.85 * U), (X + 3.4 * U, Y - 1.85 * U), (X + 3.0 * U, Y - .5 * U), (X + .4 * U, Y - .5 * U)]), '#8c9097',
            line=.7, lw=2.1, shadow=.24, rim=.16, step=12, hatch=1)
    for k in range(5):
        p.dot(X + (.5 + k * .6) * U, Y - 1.68 * U, 2.6, '#5e6268', painted=False)


def ceiling(x):
    return int(3 + round(1.1 * math.sin(x / 4.3) + .7 * math.sin(x / 1.9 + 1)))


def support(p, x):
    X = x * U
    c = ceiling(x) + 1.0
    for dx in (-1.1, 1.1):
        p.shape(rbox(X + (dx - .2) * U, c * U, X + (dx + .2) * U, 11 * U, 3), WOOD, line=.6, shadow=.26, rim=.1, hatch=2, step=14)
    p.shape(rbox(X - 1.7 * U, c * U, X + 1.7 * U, (c + .42) * U, 3), WOOD, line=.6, shadow=.28, rim=.14, hatch=2, step=14)


YSTONES = ((13.2, 10.48, .62), (20.6, 10.5, .56), (27.8, 10.46, .6), (33.8, 10.5, .54))


def cave_scene(night, who):
    W, H = 60 * U, 15 * U
    p = P(W, H, night)
    wall = rgb('#7d776f')
    p.c[:] = p.tone(wall)
    p.c *= (1 + .05 * p.t['m'])[..., None]
    rs = np.random.RandomState(3)
    for k in range(120):
        x, y = rs.rand() * W, (2 + rs.rand() * 10) * U
        r = (.8 + rs.rand() * 1.7) * U
        p.shape(rock(x, y, r, r * .72, k + 100), wall * (.86 + rs.rand() * .2), line=.1, shadow=.08, rim=.06, amp=1.2, step=14, hatch=k % 3)
    for x in (6, 18, 30, 47, 56):
        support(p, x)
    p.shape(rbox(-20, 11 * U, W + 20, 16 * U, 0), '#8a857d', line=0, shadow=0, rim=0, amp=0)
    for x in range(60):
        c = ceiling(x)
        p.shape(rbox(x * U - 2, -10, (x + 1) * U + 2, c * U + 2, 0), '#8a857d', line=0, shadow=0, rim=0, amp=0)
        for r in range(0, c):
            earth_block(p, x, r, '#a59f95', stone=False)
        for r in range(11, 15):
            earth_block(p, x, r, ('#a59f95', '#9b958b', '#918b82', '#878178')[r - 11], stone=(x * 7 + r * 3) % 17 == 0)
        if (x * 5) % 7 == 0:
            n = .7 + (x % 3) * .5
            p.shape(np.array([(x * U + 6, c * U - 3), ((x + 1) * U - 6, c * U - 3), ((x + .5) * U, (c + n) * U)]), '#9b958b', line=.45,
                    shadow=.16, rim=.1, step=9, amp=.9)
    # rails and the cart
    for x in np.arange(0, 60, 1.3):
        p.shape(rbox(x * U, 11 * U - 7, (x + .5) * U, 11 * U + 2, 2), WOOD_D, line=.3, shadow=.1, rim=.08, amp=.4, step=8)
    p.line([(-10, 11 * U - 9), (W + 10, 11 * U - 9)], '#6e7176', w=5, a=1, amp=.5, grain=False)
    mine_cart(p, 4.4, 11 - .1)
    # the rubble that only he can dig
    rs = np.random.RandomState(8)
    for row, (yy, n, x0) in enumerate(((10.2, 5, 37.9), (8.9, 5, 38.4), (7.6, 4, 38.8), (6.4, 4, 39.0), (5.2, 3, 39.5), (4.2, 3, 39.8))):
        for k in range(n):
            plain_rock(p, (x0 + k * 1.28 + rs.rand() * .3) * U, (yy + rs.rand() * .25) * U, (.72 + rs.rand() * .2) * U,
                       (.62 + rs.rand() * .14) * U, 200 + row * 10 + k)
    mole(p, 36.6, 11)
    # the stones she painted yellow
    for k, (x, y, r) in enumerate(YSTONES):
        painted_rock(p, x * U, y * U, r * U, r * .86 * U, YELLOW, 300 + k, hatch=k)
    for x, y, r in ((47.5, 10.6, .36), (49.2, 10.55, .3), (8.5, 10.6, .32), (23.6, 4.9, .3)):
        sootling(p, x * U, y * U, r * U, int(x * 3))
    if who == 'marta':
        marta(p, 35.1, 11, 1, cloak=YELLOW, tip=YELLOW)
    else:
        giulio(p, 24.4, 11, 1, tool='pick')
    return p


def lightmap(H, W, lights):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    L = np.zeros((H, W), np.float32)
    for x, y, r, a in lights:
        L += a * np.exp(-((xx - x) ** 2 + (yy - y) ** 2) / (2 * r * r))
    return 1 - np.exp(-1.9 * L)


def cave_board():
    H = 15 * U
    W = int(H * 2 * 16 / 9)
    stones = [(x * U, y * U, 2.7 * U, 1.0) for x, y, r in YSTONES]
    warm = np.array([1.05, .98, .84], np.float32)
    # top: her cloak lights her own way
    cam = 6 * U
    lit = cave_scene(False, 'marta').c
    dark = lit * np.array([.13, .13, .18], np.float32)
    L = lightmap(H, 60 * U, stones + [(35.1 * U, 9.6 * U, 4.2 * U, 1.0)])[..., None]
    top = dark * (1 - L) + lit * warm * L
    # bottom: he has no light, only what she painted
    cam2 = 4 * U
    lit2 = cave_scene(False, 'giulio').c
    dark2 = cave_scene(True, 'giulio').c * .2
    L2 = lightmap(H, 60 * U, stones)[..., None]
    bottom = dark2 * (1 - L2) + lit2 * warm * L2
    a = P(60 * U, H)
    a.c[:] = top
    b = P(60 * U, H, True)
    b.c[:] = bottom
    for sheet, offs in ((a, 0), (b, 0)):
        for x, y, r in YSTONES:
            sheet.glow(x * U, y * U, 1.0 * U, '#ffc83a', a=.34)
            sheet.glow(x * U, y * U, 2.0 * U, '#ffb020', a=.14)
    a.glow(35.1 * U, 9.8 * U, 1.3 * U, '#ffd257', a=.22)
    for sheet in (a, b):
        for x, y, r in ((47.5, 10.6, .36), (49.2, 10.55, .3), (8.5, 10.6, .32), (23.6, 4.9, .3)):
            soot_eyes(sheet, x * U, y * U, r * U)
    return split(a.finish(), b.finish(), cam, cam2, col_sel=3, tool_sel=1)


# ---- the eclipse: one shared screen -----------------------------------------------------------------------------


def balloon(p, cx, cy, u):
    # his frame, her paint: a patchwork of painted blocks that lifts the house
    cols = (WHITE, WHITE, YELLOW, WHITE, BLUE, WHITE, PINK, WHITE, RED, WHITE, GREEN, WHITE)
    rows = ((-2, 2), (-3, 3), (-4, 4), (-4, 4), (-3, 3), (-2, 2))
    k = 0
    for r, (a, b) in enumerate(rows):
        for c in range(a, b):
            x0, y0 = cx + c * u, cy + (r - 3) * u
            q = rbox(x0, y0, x0 + u, y0 + u, 3)
            p.shape(q, '#e8e2d4', line=0, shadow=.14, rim=0, painted=True, amp=.5, step=8)
            p.shape(q, cols[k % len(cols)], kind='crayon', line=.6, lw=1.7, shadow=0, rim=.1, amp=.5, step=8, hatch=k)
            k += 5


def eclipse_scene(night):
    W, H = 2560, 1440
    p = P(W, H, night)
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, low = (rgb('#141c44'), rgb('#4a5f98')) if night else (rgb('#bcd8e2'), rgb('#f8e6c3'))
    p.c[:] = top * (1 - y) + low * y
    p.c *= (1 + .012 * p.t['m'])[..., None]
    if night:
        rs = np.random.RandomState(14)
        for k in range(170):
            x, yy = rs.rand() * W, rs.rand() * 16 * U
            r = 2 + rs.rand() * 5
            if r > 5.4:
                sparkle(p, x, yy, r * 1.6, '#e9edf9')
            else:
                p.dot(x, yy, r * .36, '#dfe6f7')
    for cx, cy, sc in ((5, 4.2, 1.1), (15, 8.5, .8), (37, 4.6, .9), (47, 8.3, 1.1)):
        cloud(p, cx * U, cy * U, sc, '#f5f0e3' if not night else '#8fa0c8')
    peaks = [(-2, 30), (6, 16.5), (10, 18.6), (15, 15.2), (21, 19), (27, 17.2), (33, 19.2), (39, 15.6), (44, 18.4), (49, 16.2), (56, 30)]
    p.shape(np.array([(x * U, yy * U) for x, yy in peaks]), '#c6cfcf', line=.1, shadow=.05, rim=.2, step=26, amp=3)
    p.shape(ridge(W, 20.2 * U, ((30, 190), (15, 80)), 7, H), '#c3d0b4', line=.12, shadow=.12, rim=.2, step=20, amp=2, hatch=1)
    for x in (4, 9, 44, 49.5, 51):
        tree(p, x, 20.4, .62, '#a8b995', seed=int(x * 3))
    p.shape(ridge(W, 22.8 * U, ((26, 150), (10, 60)), 3, H), '#b2c19b', line=.14, shadow=.16, rim=.18, step=18, amp=2, hatch=2)
    # the hill they finally stand on
    xs = np.linspace(-40, W + 40, 60)
    hill = 25.2 * U + 1.7 * U * ((xs - W / 2) / (W / 2)) ** 2
    p.shape(np.vstack([np.c_[xs, hill], [W + 40, H + 40], [-40, H + 40]]), GRASS, line=.4, lw=1.8, shadow=.2, rim=.18, step=16, hatch=1)
    rs = np.random.RandomState(6)
    for x in np.arange(30, W - 20, 34.0):
        hy = float(np.interp(x, xs, hill))
        for k in range(3):
            dx = rs.rand() * 16 - 8
            p.line([(x + dx, hy + 3), (x + dx + rs.rand() * 6 - 3, hy - 9 - rs.rand() * 11)], GRASS_D, w=2.4, a=.8, amp=.2, step=6)
    flowers(p, (6.2, 7.4, 13.1, 19.2, 33.4, 35.8, 41.3, 46.6, 47.2), 26.0, 8)
    # the house, flown here on his frame and her paint
    u = 1.25 * U
    hx, gy = 34.0, 25.6
    for dx in (.5, 2.8, 6.2, 8.5):
        roof_y = 5.0 + 2.5 * math.sin(math.pi * (dx + .25) / 9.5) ** .7
        p.line([(hx * U + dx * u, gy * U - roof_y * u + 8), (hx * U + 4.5 * u + (dx - 4.5) * 1.5 * u, gy * U - 10.4 * u)], '#d8c8a6', w=4.5, a=1, amp=.6, painted=True)
    balloon(p, hx * U + 4.5 * u, gy * U - 13.4 * u, u)
    house(p, hx, gy, u)
    return p


def eclipse_board():
    d, n = eclipse_scene(False), eclipse_scene(True)
    W, H = d.W, d.H
    xx = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    s = np.clip((xx - .34 + .008 * d.t['m']) / .32, 0, 1)
    s = (s * s * (3 - 2 * s))[..., None]
    p = P(W, H)
    p.c[:] = d.c * (1 - s) + n.c * s
    # the eclipse itself
    cx, cy = W * .5, 6.2 * U
    p.glow(cx, cy, 5.5 * U, '#ffd98a', a=.45)
    p.glow(cx, cy, 2.8 * U, '#ffe7b0', a=.7)
    for k in range(24):
        a = k * math.pi / 12
        r0, r1 = 2.5 * U, (3.5 + .9 * (k % 2)) * U
        p.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + r1 * math.cos(a), cy + r1 * math.sin(a))], '#ffd76a', w=9, a=.95,
               amp=.8, painted=True, step=12)
    p.shape(ell(cx, cy, 2.46 * U, 2.46 * U, 48), '#ffd76a', line=.3, shadow=.1, rim=.3, painted=True, step=14)
    p.shape(ell(cx, cy, 2.2 * U, 2.2 * U, 48), '#222c5c', line=.3, shadow=.05, rim=.06, painted=True, step=14, hatch=1)
    # the two of them, on one screen for the first time
    p.lwk = 1.8
    gy = 25.35
    p.glow(26.7 * U, 22.4 * U, 4.2 * U, '#fff0c8', a=.26)
    marta(p, 24.6, gy, 1, scale=2.7, brush=False)
    giulio(p, 29.2, gy + .05, -1, tool=None, scale=2.7)
    p.line([(25.4 * U, (gy - 2.48) * U), (26.8 * U, (gy - 2.05) * U), (28.4 * U, (gy - 2.3) * U)], SKIN, w=13, a=1, amp=.4, grain=False, painted=True)
    for dx, dy, r in ((-1.2, -8.2, 14), (.2, -8.9, 18), (1.5, -8.1, 12)):
        sparkle(p, (26.8 + dx) * U, (gy + dy) * U, r, '#fff7da')
    p.lwk = 1.0
    return p.finish(.022)


# ---- reference sheets --------------------------------------------------------------------------------------------


def effect(p, x, y, kind, r):
    if kind == 'white':
        wisp = Multi([ell(x + dx * r, y + 1.2 * r + dy * r, q * r, q * .62 * r, 16) for dx, dy, q in
                      ((-.8, .05, .5), (0, .2, .62), (.8, .03, .48))])
        p.shape(wisp, '#f8f6ee', line=.2, shadow=.1, rim=.2, painted=True, amp=1)
        for dx, dy, q in ((-1.3, -.2, 7), (1.25, -.7, 9), (1.1, .5, 6)):
            sparkle(p, x + dx * r, y + dy * r, q * 1.5)
    elif kind == 'red':
        p.glow(x, y, 1.5 * r, '#ff8a4a', a=.34)
        for dx in (-.55, 0, .55):
            ys = np.linspace(y - 1.2 * r, y - 2.0 * r, 12)
            p.line(np.c_[x + dx * r + 7 * np.sin((ys - y) / 13), ys], '#f07a4c', w=4, a=.9, amp=.3, painted=True, step=6)
    elif kind == 'blue':
        p.shape(np.array([(x - 1.9 * r, y + .82 * r), (x - .9 * r, y + .7 * r), (x + 1.0 * r, y + .7 * r), (x + 2.0 * r, y + .84 * r),
                          (x + 1.2 * r, y + 1.04 * r), (x - 1.1 * r, y + 1.04 * r)]), '#dff1f7', line=.5, shadow=.14, rim=.4, painted=True,
                step=12)
        for dx, dy, q in ((-1.25, -.5, 8), (1.2, -.6, 7), (.1, -1.25, 6)):
            sparkle(p, x + dx * r, y + dy * r, q * 1.6, '#c6e6f7')
    elif kind == 'yellow':
        p.glow(x, y, 1.1 * r, '#ffc83a', a=.5)
        p.glow(x, y, 2.2 * r, '#ffb020', a=.2)
        for k in range(10):
            a = k * math.pi / 5 + .2
            p.line([(x + 1.28 * r * math.cos(a), y + 1.28 * r * math.sin(a)), (x + 1.65 * r * math.cos(a), y + 1.65 * r * math.sin(a))], YELLOW,
                   w=6, a=.95, amp=.3, painted=True, step=6)
    elif kind == 'green':
        p.line([(x + .1 * r, y - .7 * r), (x - .2 * r, y - 1.3 * r), (x + .25 * r, y - 1.75 * r), (x + .05 * r, y - 2.2 * r)], GREEN, w=7, a=1,
               amp=.5, grain=False, painted=True, step=6)
        for lx, ly, rot in ((-.55, -1.45, -.7), (.62, -1.75, .6), (-.32, -2.3, -.5)):
            p.shape(ell(x + lx * r, y + ly * r, .34 * r, .17 * r, 16, rot=rot), GREEN, kind='crayon', line=.6, lw=1.6, shadow=.1, step=7)
    elif kind == 'pink':
        for k, t in enumerate(np.linspace(0, 1, 12)):
            ax, ay = x - 1.7 * r + 3.4 * r * t, y - .9 * r - 1.5 * r * 4 * t * (1 - t)
            p.dot(ax, ay, 5.5, PINK)
    elif kind == 'purple':
        for dx in (-1.25, 1.25):
            p.line([(x + dx * r, y - .75 * r), (x + dx * r, y + .25 * r)], PURPLE, w=6, a=.9, amp=.3, painted=True, step=6)
            p.line([(x + (dx - .22) * r, y - .05 * r), (x + dx * r, y + .25 * r), (x + (dx + .22) * r, y - .05 * r)], PURPLE, w=6, a=.9, amp=.2,
                   painted=True, step=5)


def paint_band(p, y0, y1, night_band):
    W = p.W
    if night_band:
        p.shape(rbox(60, y0, W - 60, y1, 16), '#26335f', line=.4, shadow=.34, rim=.1, painted=True, hatch=1, amp=2, step=22)
    else:
        p.shape(rbox(60, y0, W - 60, y1, 16), '#cfdcd2', line=.4, shadow=.34, rim=.2, painted=True, hatch=1, amp=2, step=22)
    g = '#3a4b7e' if night_band else GRASS
    xs = np.linspace(60, W - 60, 40)
    top = y1 - 120 + 8 * np.sin(xs / 90)
    p.shape(np.vstack([np.c_[xs, top], [W - 60, y1], [60, y1]]), g, line=.3, shadow=.14, rim=.14, painted=True, step=18, hatch=2)


def paint_board():
    W, H = 2560, 1440
    p = P(W, H)
    p.c[:] = rgb('#f3ecdd')
    p.c *= (1 + .007 * p.t['m'])[..., None]
    paint_band(p, 60, 620, False)
    paint_band(p, 820, 1380, True)
    cols = ((None, None), (WHITE, 'white'), (RED, 'red'), (BLUE, 'blue'), (YELLOW, 'yellow'), (GREEN, 'green'), (PINK, 'pink'), (PURPLE, 'purple'))
    p.lwk = 1.5
    for band, ground in ((0, 500), (1, 1260)):
        for k, (col, kind) in enumerate(cols):
            x = 210 + k * 306
            r = 74
            y = ground - r * .8 - (72 if kind == 'white' else 0)
            if col is None:
                night = p.night
                p.night = band == 1
                plain_rock(p, x, y, r * 1.08, r * .96, 70 + k)
                p.night = night
            else:
                if kind == 'white':
                    painted_rock(p, x, y, r * 1.08, r * .96, col, 70 + k, base='#e3e6ea', hatch=k)
                else:
                    painted_rock(p, x, y, r * 1.08, r * .96, col, 70 + k, base='#efe6d4', hatch=k)
                effect(p, x, y, kind, r)
    return p.finish(.022)


def shaggy(pts, tooth=26, depth=9, seed=0):
    """Turn an outline into a fur edge: teeth that droop with gravity."""
    a = wobble(pts, tooth / 2, 0, closed=True)
    n = len(a) - len(a) % 2
    a = a[:n]
    t = np.roll(a, -1, axis=0) - np.roll(a, 1, axis=0)
    nrm = np.c_[t[:, 1], -t[:, 0]]
    nrm /= np.hypot(*nrm.T)[:, None] + 1e-6
    if ((a - a.mean(axis=0)) * nrm).sum() < 0:
        nrm = -nrm
    k = (np.arange(n) % 2 * 2 - 1) * depth * (.7 + .5 * np.random.RandomState(seed).rand(n))
    b_ = a + nrm * k[:, None]
    b_[:, 1] += (np.arange(n) % 2) * depth * .8
    return b_


def pine(p, x, y, s):
    p.shape(rbox(x - .08 * s, y - .4 * s, x + .08 * s, y, 2), WOOD_D, line=.4, shadow=.1, painted=True, amp=.3, step=6)
    for base, apex, hw in ((.28, 1.0, .52), (.58, 1.28, .42), (.88, 1.55, .31)):
        p.shape(np.array([(x - hw * s, y - base * s), (x, y - apex * s), (x + hw * s, y - base * s)]), '#7f9a86', line=.55, lw=1.5, shadow=.12,
                rim=.12, painted=True, amp=.5, step=7)
    p.shape(np.array([(x - .17 * s, y - 1.3 * s), (x, y - 1.55 * s), (x + .17 * s, y - 1.3 * s), (x, y - 1.36 * s)]), '#f4f7f9', line=0, shadow=0,
            rim=0, painted=True, amp=.2, step=5)


def snow_giant(p, x, gy, u):
    X, Y = x * U, gy * U

    def at(*pts):
        return np.array([(X + a * u, Y + b * u) for a, b in pts])

    fur, shade, patch = '#e4ecf2', '#c5d3e0', '#f7f9fa'
    # pines on its back: it has sat on this pass long enough for trees to grow
    pine(p, X + 3.15 * u, Y - 6.7 * u, 1.05 * u)
    pine(p, X + 2.2 * u, Y - 7.9 * u, 1.55 * u)
    pine(p, X + 1.0 * u, Y - 8.7 * u, 1.15 * u)
    # far arm, hanging
    far = at((2.2, -7.2), (3.4, -6.7), (4.5, -4.6), (4.8, -2.2), (4.7, -.9), (3.7, -.7), (3.4, -2.2), (3.2, -4.2), (2.4, -5.2))
    p.shape(shaggy(far, tooth=24, depth=8, seed=2), shade, line=.6, lw=1.7, shadow=.2, rim=.12, painted=True, amp=.5, step=6, hatch=1)
    # feet
    for fx in (-1.5, 1.5):
        p.shape(ell(X + fx * u, Y - .34 * u, 1.3 * u, .55 * u, 24), '#d3dee8', line=.6, lw=1.7, shadow=.22, rim=.16, painted=True, amp=.8)
        for t in (-.6, 0, .6):
            p.line([(X + (fx + t) * u, Y - .14 * u), (X + (fx + t) * u, Y - .42 * u)], '#9fb0c0', w=3, a=.7, amp=.2, painted=True, step=5)
    # one big shaggy body, head and all
    body = at((-2.0, -.3), (-2.6, -1.4), (-3.0, -3.2), (-3.1, -5.2), (-2.7, -7.2), (-1.7, -8.6), (0, -9.2), (1.7, -8.6), (2.7, -7.2), (3.1, -5.2),
              (3.0, -3.2), (2.6, -1.4), (2.0, -.3))
    p.shape(shaggy(body, tooth=30, depth=11, seed=4), fur, line=.65, lw=1.9, shadow=.26, rim=.2, painted=True, amp=.6, step=7, hatch=2)
    p.shape(shaggy(ell(X - .3 * u, Y - 2.75 * u, 1.9 * u, 2.1 * u, 30), tooth=22, depth=6, seed=6), shade, line=0, shadow=0, rim=.08, painted=True, amp=.4,
            step=6, hatch=1)
    rs = np.random.RandomState(12)
    for k in range(46):
        a, r = rs.rand() * 6.28, rs.rand() ** .6
        fx, fy = 2.5 * r * math.cos(a) + .1, -4.6 + 3.9 * r * math.sin(a)
        if (fx + .7) ** 2 / 3.6 + (fy + 6.3) ** 2 / 2.3 < 1:
            continue
        px, py = X + fx * u, Y + fy * u
        p.line([(px - 8, py - 6), (px, py + 6), (px + 7, py - 5)], '#a9bbcb', w=2.4, a=.55, amp=.2, painted=True, step=4)
    # ice horns
    for hx, hy, lean in ((-1.45, -8.5, -.5), (.55, -9.0, .35)):
        p.shape(at((hx - .3, hy + .3), (hx + lean, hy - .95), (hx + .32, hy + .3)), '#bfe3f2', line=.65, lw=1.6, shadow=.14, rim=.3, painted=True, amp=.5, step=6)
    # the gentle face, looking at the warmth
    p.shape(shaggy(ell(X - .7 * u, Y - 6.35 * u, 1.85 * u, 1.4 * u, 30), tooth=20, depth=5, seed=8), patch, line=.35, lw=1.4, shadow=.08, rim=0, painted=True,
            amp=.3, step=6)
    for ex in (-1.5, .1):
        p.dot(X + ex * u, Y - 6.7 * u, .19 * u, '#2b2a2f')
        p.dot(X + (ex - .06) * u, Y - 6.77 * u, .06 * u, '#fbfbfb')
        p.line([(X + (ex - .32) * u, Y - 7.1 * u), (X + ex * u, Y - 7.2 * u), (X + (ex + .32) * u, Y - 7.04 * u)], '#8ea0b2', w=4.5, a=.9, amp=.2, painted=True, step=5)
    p.dot(X - 1.95 * u, Y - 6.08 * u, .3 * u, '#f3cfd3')
    p.dot(X + .55 * u, Y - 6.08 * u, .3 * u, '#f3cfd3')
    p.shape(ell(X - .7 * u, Y - 6.3 * u, .22 * u, .15 * u, 14), '#8c9dae', line=0, shadow=0, rim=0, painted=True, amp=.2)
    mouth = [(X + (-1.45 + 1.5 * t) * u, Y - (5.72 - .3 * 4 * t * (1 - t)) * u) for t in np.linspace(0, 1, 12)]
    for tx in (-1.02, -.38):
        my = float(np.interp(X + tx * u, [q[0] for q in mouth], [q[1] for q in mouth]))
        p.shape(np.array([(X + (tx - .12) * u, my + 2), (X + tx * u, my - .3 * u), (X + (tx + .12) * u, my + 2)]), '#fbfbf6', line=.55, lw=1.2, shadow=0, rim=0,
                painted=True, amp=.2, step=4)
    p.line(mouth, '#5e6a78', w=4, a=1, amp=.2, grain=False, painted=True, step=5)
    # near arm, reaching for the warm stone
    arm = at((-1.8, -5.1), (-1.5, -4.0), (-2.4, -3.4), (-3.9, -2.7), (-5.3, -1.9), (-6.4, -1.4), (-6.7, -2.4), (-5.5, -3.2), (-4.0, -4.4), (-2.9, -5.2))
    p.shape(shaggy(arm, tooth=24, depth=8, seed=9), fur, line=.65, lw=1.8, shadow=.22, rim=.16, painted=True, amp=.5, step=6, hatch=2)
    p.shape(ell(X - 6.65 * u, Y - 1.8 * u, .72 * u, .62 * u, 20), '#d3dee8', line=.6, lw=1.7, shadow=.14, rim=.14, painted=True, amp=.6)
    for fx, fy in ((-7.2, -1.35), (-7.35, -1.8), (-7.2, -2.25)):
        p.shape(ell(X + fx * u, Y + fy * u, .26 * u, .17 * u, 12), '#d3dee8', line=.55, lw=1.4, shadow=.08, rim=.1, painted=True, amp=.3)


def bird(p, x, y, r):
    X, Y = x * U, y * U
    p.shape(Multi([ell(X, Y, r * 1.1, r * .86, 20), ell(X + r * .8, Y - r * .6, r * .55, r * .52, 16)]), '#c3d4dc', line=.65, lw=1.7, shadow=.18, rim=.14,
            painted=True, amp=.8)
    p.shape(np.array([(X + r * 1.3, Y - r * .7), (X + r * 1.8, Y - r * .52), (X + r * 1.3, Y - r * .4)]), '#e0a24a', line=.5, lw=1.3, shadow=.06, painted=True,
            amp=.2, step=5)
    p.dot(X + r * .96, Y - r * .72, r * .1, '#231a16')
    p.shape(ell(X - r * .15, Y + r * .05, r * .62, r * .34, 14, rot=.3), '#a9bfc9', line=.5, lw=1.4, shadow=.06, painted=True, amp=.5)


def cast_board():
    W, H = 2560, 1440
    p = P(W, H)
    p.c[:] = rgb('#f3ecdd')
    p.c *= (1 + .007 * p.t['m'])[..., None]
    # the two heroes, by cloak and coat
    band = rbox(60, 60, W - 60, 640, 16)
    p.shape(band, '#cfdcd2', line=.4, shadow=.34, rim=.2, painted=True, hatch=1, amp=2, step=22)
    p.shape(rbox(60, 540, W - 60, 640, 14), GRASS, line=.3, shadow=.1, rim=.14, painted=True, hatch=2, amp=2, step=22)
    p.lwk = 1.7
    for k, (cloak, tip) in enumerate(((RED, RED), (WHITE, WHITE), (BLUE, BLUE), (YELLOW, YELLOW))):
        marta(p, 5.2 + k * 6.1, 11.5, 1, cloak=cloak, tip=tip, scale=4.2)
    giulio(p, 31.0, 11.5, 1, tool='hammer', scale=4.2)
    giulio(p, 38.5, 11.5, 1, coat=RED, tool='pick', scale=4.2)
    p.lwk = 1.0
    # creatures to outwit
    p.shape(rbox(60, 700, 1090, 1380, 16), '#26335f', line=.4, shadow=.34, rim=.1, painted=True, hatch=1, amp=2, step=22)
    p.shape(rbox(60, 1280, 1090, 1380, 14), '#3a4b7e', line=.3, shadow=.1, rim=.1, painted=True, hatch=2, amp=2, step=22)
    p.lwk = 1.6
    sootling(p, 180, 1200, 88, 5)
    soot_eyes(p, 180, 1200, 88)
    sootling(p, 306, 1248, 50, 8)
    soot_eyes(p, 306, 1248, 50)
    p.lwk = 1.0
    rx, ry = 432, 1296
    painted_rock(p, rx, ry, 46, 40, RED, 91, base='#efe6d4')
    effect(p, rx, ry, 'red', 42)
    p.lwk = 1.6
    snow_giant(p, 17.75, 27.75, 46)
    # creatures to help
    p.shape(rbox(1150, 700, 1810, 1380, 16), '#d8e2e0', line=.4, shadow=.34, rim=.2, painted=True, hatch=2, amp=2, step=22)
    p.shape(rbox(1150, 1280, 1810, 1380, 14), GRASS, line=.3, shadow=.1, rim=.14, painted=True, hatch=2, amp=2, step=22)
    mole(p, 27.6, 27.4, 3.4)
    bird(p, 33.9, 25.0, 92)
    p.line([(33.1 * U, 26.8 * U), (34.5 * U, 26.8 * U)], WOOD_D, w=12, a=1, amp=.6, grain=False, painted=True)
    p.line([(33.8 * U, 26.8 * U), (33.8 * U, 27.5 * U)], WOOD_D, w=12, a=1, amp=.6, grain=False, painted=True)
    # block kinds and their stress colours
    p.shape(rbox(1870, 700, W - 60, 1380, 16), '#e7dfcc', line=.4, shadow=.34, rim=.2, painted=True, hatch=1, amp=2, step=22)
    for k, (col, fn) in enumerate((('#b39877', 'earth'), ('#a59f95', 'stone'), (WOOD, 'wood'), ('#8c9097', 'iron'))):
        px, py = 1950 + (k % 2) * 240, 760 + (k // 2) * 240
        s_ = 200
        p.shape(rbox(px, py, px + s_, py + s_, 9), col, line=.6, lw=2, shadow=.24, rim=.16, hatch=k, step=14)
        if fn == 'wood':
            for t in (.36, .68):
                p.line([(px + 8, py + s_ * t), (px + s_ - 8, py + s_ * t)], WOOD_D, w=4, a=.55)
        if fn == 'iron':
            for a_, b_ in ((.16, .16), (.84, .16), (.16, .84), (.84, .84)):
                p.dot(px + s_ * a_, py + s_ * b_, 7, '#5e6268', painted=False)
        if fn == 'earth':
            p.shape(rock(px + 60, py + 130, 26, 20, 3), STONE, line=.4, shadow=.1, amp=.6, step=7)
    for k, col in enumerate((GREEN, '#a6c23a', YELLOW, ORANGE, RED)):
        px = 1950 + k * 90
        p.shape(rbox(px, 1270, px + 80, 1320, 5), col, kind='crayon', line=.5, shadow=.1, step=10, hatch=k)
    p.lwk = 1.0
    return p.finish(.022)


if __name__ == '__main__':
    import sys
    import time
    out = sys.argv[1]
    which = sys.argv[2:] or ['river', 'cave', 'eclipse', 'paint', 'cast']
    t0 = time.time()
    for name in which:
        if name == 'river':
            sheet = split(river_stop(False), river_stop(True))
        elif name == 'cave':
            sheet = cave_board()
        elif name == 'eclipse':
            sheet = eclipse_board()
        elif name == 'paint':
            sheet = paint_board()
        else:
            sheet = cast_board()
        save(sheet, f'{out}/{name}.webp', quality=92, method=5)
        save(sheet, f'{out}/{name}-preview.png', size=(1600, 900))
        print(name, round(time.time() - t0, 1), flush=True)
