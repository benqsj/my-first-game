#!/usr/bin/env python3
"""Regenerates the `Level/Scatter` block of the greybox world.

The old scatter spread single tufts evenly over the whole ground, which reads as
noise rather than as vegetation. This lays the grass down as *meadows* instead:
a handful of meandering ribbons and blobs, filled on a jittered lattice tight
enough that neighbouring tufts overlap and merge into one continuous mat, with
the density (and the height of the blades) falling off towards the edges so the
patches have a soft border instead of a hard circle.

Everything outside a meadow is left as bare ground, and rocks are dropped along
the meadow edges and out on the open plain.

Deterministic: same seed in, same scatter out.

    python3 tools/build_scatter.py            # rewrite the scene in place
    python3 tools/build_scatter.py --dry-run  # just report the counts
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

SCENE = Path(__file__).resolve().parent.parent / "scenes/world/greybox_world.tscn"

SEED = 20240819

# --- World -------------------------------------------------------------------
# Half-extent of the ground plane. Meadows and rocks stay inside this, minus a
# margin so nothing pokes through the boundary walls.
GROUND_HALF = 60.0
EDGE_MARGIN = 2.5

# --- Meadows -----------------------------------------------------------------
# Distance between lattice samples, in metres. A clump is ~1 m across at the
# scale it goes down at, so at this spacing neighbours overlap and the patch
# reads as one mat rather than as a scatter of dots. It is also the main dial
# on how much the meadows cost to draw: the count goes as 1/spacing².
SPACING = 1.05
# Fraction of the spacing a sample is allowed to wander, to kill the lattice
# without opening holes in it.
JITTER = 0.34
# The meadows are built out of `grass2` clumps. The other asset, `grass.glb`,
# is a tenth of the triangles but ships untextured and reads as flat green
# leaf cards rather than blades, so it is only worth using where it is small
# and sparse — set this to a number above 1 to mix that many tufts in per
# clump, or leave it at 0 for clumps alone.
TUFTS_PER_CLUMP = 0

# Ribbons: polylines of (x, z, radius). The band around each segment is filled,
# so consecutive points with overlapping radii give one unbroken swath.
RIBBONS = [
    # A long swath curling around the south and east of the play area.
    [(-26, -22, 2.6), (-19, -25, 3.4), (-11, -24, 3.9), (-3, -27, 3.2),
     (5, -25, 2.7), (12, -21, 3.3), (17, -14, 3.6), (18, -6, 2.8)],
    # The northern meadow, wider and the deepest grass on the map.
    [(-14, 17, 3.0), (-7, 20, 4.2), (1, 21, 4.6), (9, 19, 3.8), (15, 14, 2.9)],
    # A thin trail linking the northern meadow down towards the spawn.
    [(1, 21, 2.2), (2, 15, 1.9), (5, 10, 2.1), (8, 5, 2.4)],
    # West of the house, running up the flank.
    [(-24, -6, 2.8), (-27, 2, 3.4), (-25, 10, 3.0), (-19, 16, 2.5)],
    # Out on the far plain to the north-east, past the tower.
    [(33, 22, 3.2), (39, 28, 3.8), (46, 31, 2.9)],
    # Far south-west corner.
    [(-40, -34, 3.4), (-33, -38, 4.0), (-26, -37, 3.0)],
    # Out on the open plain, so the far half of the map is not dead ground.
    [(-50, -6, 3.0), (-48, 4, 3.6), (-44, 13, 3.0)],
    [(20, 44, 3.4), (29, 47, 4.0), (38, 44, 3.0)],
    [(46, -30, 3.2), (52, -22, 3.6)],
]

# Standalone blobs: (x, z, radius).
BLOBS = [
    (-8, -8, 3.2),
    (24, -30, 4.4),
    (-44, 12, 3.6),
    (42, -14, 3.0),
    (6, 36, 3.8),
    (-16, 40, 3.4),
    (-38, 44, 3.2),
    (52, 16, 3.0),
    (14, -46, 3.6),
    (-24, -50, 3.2),
    (40, -50, 2.8),
    (-52, 30, 2.8),
]

# --- Keep-out zones ----------------------------------------------------------
# (x, z, radius) around the level geometry. Grass has no collision, so these are
# only about not growing tufts through a wall or a staircase.
NO_GRASS = [
    (-10.0, -1.5, 4.6),    # stairs
    (-10.0, -6.3, 5.0),    # platform
    (10.0, -4.0, 5.6),     # ramp
    (4.0, 4.0, 1.6),       # pillar 1
    (-4.0, 6.0, 1.6),      # pillar 2
    (0.0, 10.0, 2.6),      # pillar 3
    (-18.5, -16.0, 6.5),   # house
    (-13.0, -11.0, 2.8),   # cart
    (27.6, 4.4, 7.5),      # tower
    (20.0, -4.0, 3.6),     # big rock 1
    (-20.0, 16.0, 3.6),    # big rock 2
    (8.0, -20.0, 3.6),     # big rock 3
    (-22.0, 2.0, 3.6),     # big rock 4
]

# Rocks are solid, so they get a wider berth: they must never wall off a ramp,
# a staircase or the spawn, and the headless tests dash through (6, z 7..13).
NO_ROCK = NO_GRASS + [
    (0.0, 0.0, 5.0),       # spawn clearing
    (6.0, 10.0, 5.0),      # the dash corridor the smoke test uses
    (16.0, -12.0, 3.0),    # wolf 1 spawn
    (-8.0, 18.0, 3.0),     # wolf 2 spawn
    (-20.0, 8.0, 3.0),     # golem 1 spawn
    (30.0, 26.0, 3.0),     # golem 2 spawn
]

# Rocks sit at the edge of a meadow or alone on the plain; hand-placed so they
# read as deliberate cover rather than litter. (x, z, scale).
#
# Kept to a couple of dozen on purpose: `rock.glb` is one cluster of seven
# lumps at 57 647 triangles, so these are by far the most expensive thing per
# instance in the scatter and a plain sprinkled with them costs more than all
# the grass put together.
ROCK_SPOTS = [
    (-15.0, -20.0, 0.9), (-4.0, -22.0, 1.15), (9.0, -17.5, 0.8),
    (17.5, -2.0, 1.05), (-22.0, -3.0, 0.85), (-28.5, 6.0, 1.2),
    (-21.5, 14.0, 0.9), (-4.0, 23.0, 1.1), (7.0, 22.5, 0.85),
    (14.0, 11.0, 1.0), (-11.0, -6.0, 0.95), (25.5, -27.0, 1.25),
    (-42.0, 10.0, 1.1), (36.0, 24.0, 0.95), (44.0, 30.0, 1.15),
    (-31.0, -36.0, 1.05), (-38.0, -31.0, 0.9), (40.0, -12.0, 1.0),
    (4.0, 34.0, 0.95), (-14.0, 38.0, 1.1), (-48.0, -14.0, 1.2),
    (48.0, 6.0, 1.0), (22.0, 40.0, 1.15), (-36.0, 26.0, 0.9),
    (12.0, -40.0, 1.05), (-6.0, -44.0, 1.2), (34.0, -40.0, 0.95),
    (-46.0, 40.0, 1.1), (50.0, -34.0, 1.0), (2.0, 48.0, 1.15),
    (-50.0, 0.0, 1.05), (26.0, 46.0, 1.2), (49.0, -26.0, 0.95),
    (-35.0, 46.0, 1.1), (16.0, -44.0, 1.15), (-27.0, -47.0, 0.9),
]

# The smoke test grabs the first `GrassClump*` and the first `Rocks*` child and
# teleports the player around them, so both need clear, flat ground.
TEST_CLUMP = (-6.0, 30.0)
TEST_ROCK = (-2.0, 30.5, 1.0)


def _fmt(value: float) -> str:
    """Godot writes floats without a trailing `.0`; match that to keep diffs small."""
    text = f"{value:.6g}"
    return "0" if text in ("-0", "0") else text


def _transform(x: float, z: float, yaw: float, scale: float, y_scale: float) -> str:
    cos_y, sin_y = math.cos(yaw) * scale, math.sin(yaw) * scale
    parts = [cos_y, 0.0, -sin_y, 0.0, y_scale, 0.0, sin_y, 0.0, cos_y, x, 0.0, z]
    return "transform = Transform3D(%s)" % ", ".join(_fmt(p) for p in parts)


def _blocked(x: float, z: float, zones) -> bool:
    return any((x - cx) ** 2 + (z - cz) ** 2 < r * r for cx, cz, r in zones)


def _blobs_from_ribbons() -> list[tuple[float, float, float]]:
    """Walks every ribbon segment and drops overlapping discs along it."""
    blobs: list[tuple[float, float, float]] = list(BLOBS)
    for ribbon in RIBBONS:
        for (x0, z0, r0), (x1, z1, r1) in zip(ribbon, ribbon[1:]):
            length = math.hypot(x1 - x0, z1 - z0)
            steps = max(1, int(length / 0.75))
            for i in range(steps + 1):
                t = i / steps
                blobs.append((x0 + (x1 - x0) * t, z0 + (z1 - z0) * t, r0 + (r1 - r0) * t))
    return blobs


def _coverage(x: float, z: float, blobs) -> float:
    """0 outside every meadow, 1 at a meadow's core. Drives density and height."""
    best = 0.0
    for cx, cz, r in blobs:
        d2 = (x - cx) ** 2 + (z - cz) ** 2
        if d2 >= r * r:
            continue
        best = max(best, 1.0 - math.sqrt(d2) / r)
        if best > 0.999:
            break
    return best


def build_scatter() -> tuple[str, int, int]:
    rng = random.Random(SEED)
    blobs = _blobs_from_ribbons()

    limit = GROUND_HALF - EDGE_MARGIN
    min_x = max(-limit, min(cx - r for cx, _, r in blobs))
    max_x = min(limit, max(cx + r for cx, _, r in blobs))
    min_z = max(-limit, min(cz - r for _, cz, r in blobs))
    max_z = min(limit, max(cz + r for _, cz, r in blobs))

    # Hexagonal rows pack tighter than a square grid for the same spacing.
    row_step = SPACING * math.sqrt(3.0) / 2.0
    tufts: list[str] = []
    clumps: list[str] = []
    row = 0
    z = min_z
    while z <= max_z:
        offset = (SPACING / 2.0) if row % 2 else 0.0
        x = min_x + offset
        while x <= max_x:
            px = x + rng.uniform(-JITTER, JITTER) * SPACING
            pz = z + rng.uniform(-JITTER, JITTER) * SPACING
            x += SPACING
            if abs(px) > limit or abs(pz) > limit:
                continue

            cover = _coverage(px, pz, blobs)
            if cover <= 0.0:
                continue
            # Solid through the body of the patch, thinning only at the rim.
            if rng.random() > min(1.0, cover * 3.4 + 0.15):
                continue
            if _blocked(px, pz, NO_GRASS):
                continue

            yaw = rng.uniform(-math.pi, math.pi)
            # Width and height are set apart: the blades spread wide enough to
            # touch their neighbours, while staying knee-high in the middle of
            # the patch and shorter around its edge.
            height = 0.5 + 0.42 * cover
            # Counted over *everything* placed: keying the choice off the tuft
            # count alone latches, because that count stops moving as soon as a
            # clump is chosen.
            placed = len(tufts) + len(clumps)
            if TUFTS_PER_CLUMP > 0 and placed % (TUFTS_PER_CLUMP + 1) != 0:
                scale = (2.15 + 1.15 * cover) * rng.uniform(0.9, 1.12)
                tufts.append(_transform(px, pz, yaw, scale, scale * height * rng.uniform(0.94, 1.08)))
            else:
                scale = (0.95 + 0.55 * cover) * rng.uniform(0.85, 1.15)
                clumps.append(_transform(px, pz, yaw, scale,
                        scale * (0.8 + 0.25 * cover) * rng.uniform(0.9, 1.1)))
        z += row_step
        row += 1

    lines: list[str] = []
    lines.append('[node name="Scatter" type="Node3D" parent="Level"]')
    lines.append('script = ExtResource("6_grass_field")')
    lines.append("")

    # Test anchors first: the headless tests pick the first clump and the first
    # rock, and both need room around them.
    lines.append('[node name="GrassClump1" parent="Level/Scatter" instance=ExtResource("3_grass2")]')
    lines.append(_transform(TEST_CLUMP[0], TEST_CLUMP[1], 0.4, 1.0, 1.0))
    lines.append("")
    lines.append('[node name="Rocks1" parent="Level/Scatter" instance=ExtResource("5_rock")]')
    lines.append(_transform(TEST_ROCK[0], TEST_ROCK[1], 0.9, TEST_ROCK[2], TEST_ROCK[2]))
    lines.append("")

    for i, transform in enumerate(tufts, start=1):
        lines.append('[node name="GrassTuft%d" parent="Level/Scatter" instance=ExtResource("4_grass")]' % i)
        lines.append(transform)
        lines.append("")

    for i, transform in enumerate(clumps, start=2):
        lines.append('[node name="GrassClump%d" parent="Level/Scatter" instance=ExtResource("3_grass2")]' % i)
        lines.append(transform)
        lines.append("")

    rock_index = 2
    for x, z, scale in ROCK_SPOTS:
        if _blocked(x, z, NO_ROCK) or abs(x) > limit or abs(z) > limit:
            continue
        lines.append('[node name="Rocks%d" parent="Level/Scatter" instance=ExtResource("5_rock")]' % rock_index)
        lines.append(_transform(x, z, rng.uniform(-math.pi, math.pi), scale, scale))
        lines.append("")
        rock_index += 1

    return "\n".join(lines), len(tufts) + len(clumps) + 1, rock_index - 1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="report the counts, write nothing")
    args = parser.parse_args()

    block, grass_count, rock_count = build_scatter()
    print("%d grass instances, %d rock clusters" % (grass_count, rock_count))
    if args.dry_run:
        return

    text = SCENE.read_text()
    start = text.index('[node name="Scatter" type="Node3D" parent="Level"]')
    end = text.index('[node name="WallEast"')
    SCENE.write_text(text[:start] + block + "\n" + text[end:])
    print("rewrote %s" % SCENE)


if __name__ == "__main__":
    main()
