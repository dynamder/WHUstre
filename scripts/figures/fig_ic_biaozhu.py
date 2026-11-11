"""标注题插图：题图（只给尺寸，形位公差待标）+ 答图（标全 + 红圈编号）。

答图只负责「标成什么样」：改正后的标注用黑线画全，改动处用红圈 + 红色编号
①②③ 标出；具体文字解释写在 md 正文里，图面不堆字，保证可读性。

运行：
    python scripts/figures/fig_ic_biaozhu.py
"""

from __future__ import annotations

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from gdt import Fig, INK, RED, BLUE, GRAY, W_THICK, W_THIN
from fig_ic_parts import (stepped_shaft, sleeve_section, plate_top,
                          bearing_section)

OUT = os.path.abspath(
    os.path.join(HERE, "..", "..", "courses", "interchangeability", "src", "assets", "figs")
)


def note(f, x, y, s, size=11.5, anchor="start"):
    f.note(x, y, s, size=size, anchor=anchor)


def badge(f, n, x, y, color=BLUE, r=10):
    f.badge(n, x, y, r=r, color=color)


def size_block(f, x, y, base, dev=None, mod=None, size=13.0, sub=9.5,
               color=INK, anchor="start"):
    """尺寸基本情况：基本尺寸一行，上下偏差两小行，修饰符带圈排在后面。"""
    f.text(x, y, base, size=size, color=color, anchor=anchor)
    w = 0.58 * size * sum(1 for c in base if ord(c) < 0x2E7F) + \
        size * sum(1 for c in base if ord(c) >= 0x2E7F)
    right = x + w if anchor == "start" else x - w
    if dev:
        up, dn = dev
        f.text(right + 3, y - sub * 0.7, up, size=sub, color=color, anchor="start")
        f.text(right + 3, y + sub * 0.7, dn, size=sub, color=color, anchor="start")
        right += 3 + max(0.58 * sub * len(up), 0.58 * sub * len(dn))
    if mod:
        f.circle(right + 11, y, 7.5, sw=1.3, color=color)
        f.text(right + 11, y + 0.5, mod, size=10.5, color=color, weight="bold")


# ---------------------------------------------------------------- 标注 1
def biaozhu1(which: str):
    """阶梯轴：包容要求 Ⓔ + 同轴度 + 径向全跳动。"""
    f = Fig(880, 470)
    a = stepped_shaft(f, ox=300, oy=240, r_big=48, r_small=22,
                      len_big=180, len_small=140, keyway=False)
    tb, bb, ts, bs = a["top_big"], a["bot_big"], a["top_small"], a["bot_small"]
    oy, x0, x1, x2 = a["axis"], a["x0"], a["x1"], a["x2"]
    f.dim_v(tb, bb, 200, None, ext_x=x0)
    f.dim_v(ts, bs, x2 + 92, None, ext_x=x2)
    size_block(f, 210, oy - 22, "φ40", ("0", "-0.033"),
               mod="E" if which == "a" else None)
    f.text(x2 + 98, oy + 2, "φ20", size=13)
    f.dim_h(x0, x1, oy + 142, "180")
    f.dim_h(x1, x2, oy + 142, "140")

    if which == "a":
        # 同轴度（φ40 轴线 → φ20 轴线 A）
        r1 = f.frame(54, 60, [("sym", "concentricity"), ("val", "φ0.02"), ("dat", "A")])
        f.leader([(r1["x0"], r1["cy"]), (200, r1["cy"]), (200, bb + 2)], head=False)
        f.datum(x2 + 92, bs + 4, "down", "A")
        # 径向全跳动（φ40 圆柱面 → A）
        r2 = f.frame(846, 60, [("sym", "total_runout"), ("val", "0.03"), ("dat", "A")],
                     anchor="right")
        f.leader([(r2["x0"], r2["cy"]), (680, r2["cy"]), (680, tb - 3)])
        badge(f, 1, 300, oy + 22, color=RED)
        badge(f, 2, r1["x0"] + 42, r1["cy"] - 28, color=RED)
        badge(f, 3, 660, tb - 40, color=RED)
    else:
        note(f, 60, 60, "技术要求（请把下列要求标注在图上）：", size=12.5)
        note(f, 60, 88, "(1) φ40 圆柱面尺寸为 φ40 0/-0.033，采用包容要求；", size=11.5)
        note(f, 60, 110, "(2) φ40 轴线对 φ20 轴线的同轴度 φ0.02；", size=11.5)
        note(f, 60, 132, "(3) φ40 圆柱面对 φ20 轴线的径向全跳动 0.03。", size=11.5)
    f.save(os.path.join(OUT, f"bz1-{'q' if which == 'q' else 'a'}.png"))


# ---------------------------------------------------------------- 标注 2
def biaozhu2(which: str):
    """板件：两孔位置度（三基面）+ 底面平面度 + 左侧面垂直度。"""
    f = Fig(880, 560)
    a = plate_top(f, ox=250, oy=176, w=280, h=170, holes=((80, 66), (200, 66)))
    (h1x, h1y), (h2x, h2y) = a["holes"]
    yv = a["y1"] + 66

    def hdim(xa, xb, label):
        f.line(xa, a["y1"], xa, yv - 4, w=W_THIN, color=GRAY)
        f.line(xb, a["y1"], xb, yv - 4, w=W_THIN, color=GRAY)
        f.line(xa, yv, xb, yv, w=W_THIN)
        f.arrowhead(xa, yv, 0)
        f.arrowhead(xb, yv, 180)
        w = 40
        f.rect((xa + xb) / 2 - w / 2, yv - 11, w, 22, sw=W_THIN, fill="#ffffff")
        f.text((xa + xb) / 2, yv + 1, label, size=13)

    hdim(a["x0"], h1x, "80")
    hdim(h1x, h2x, "120")
    f.dim_v(h1y, a["y1"], a["x1"] + 78, "66", ext_x=h2x + 16)
    f.text(h1x + 20, h1y - 24, "2×φ12", size=12.5, anchor="start")

    f.datum(a["x0"] + 34, a["y1"], "down", "A")
    f.datum(a["x0"], a["y0"] + 112, "left", "B")
    f.datum(a["x0"] + 180, a["y0"], "up", "C")

    if which == "a":
        r1 = f.frame(54, 54, [("sym", "position"), ("val", "φ0.1"), ("dat", "A"),
                              ("dat", "B"), ("dat", "C")])
        f.leader([(r1["x1"], r1["cy"]), (h2x, r1["cy"]), (h2x, h2y - 19)])
        r2 = f.frame(54, 424, [("sym", "flatness"), ("val", "0.05")])
        f.leader([(r2["x1"], r2["cy"]), (230, r2["cy"]), (230, a["y1"] + 5)],
                 head=False)
        f.arrowhead(230, a["y1"] + 2, -90)
        r3 = f.frame(846, 250, [("sym", "perpendicularity"), ("val", "0.04"),
                                ("dat", "A")], anchor="right")
        f.leader([(r3["x0"], r3["cy"]), (632, r3["cy"]),
                  (632, a["y0"] + 50), (a["x1"] + 3, a["y0"] + 50)])
        badge(f, 1, r1["x0"] + 44, r1["cy"] - 28, color=RED)
        badge(f, 2, 210, a["y1"] - 24, color=RED)
        badge(f, 3, r3["x0"] + 30, r3["cy"] - 26, color=RED)
    else:
        note(f, 60, 60, "技术要求（请标注在图上）：", size=12.5)
        note(f, 60, 88, "(1) 两个 φ12 孔的位置度 φ0.1，基准 A（底面）、B（左侧面）、", size=11.5)
        note(f, 60, 110, "     C（后面）；定位尺寸均取理论正确尺寸；", size=11.5)
        note(f, 60, 132, "(2) 板底面平面度 0.05；", size=11.5)
        note(f, 60, 154, "(3) 左侧面对底面 A 的垂直度 0.04。", size=11.5)
    f.save(os.path.join(OUT, f"bz2-{'q' if which == 'q' else 'a'}.png"))


# ---------------------------------------------------------------- 标注 3
def biaozhu3(which: str):
    """套筒：内孔包容要求 + 垂直度 + 端面圆跳动 + 圆柱度。"""
    f = Fig(880, 520)
    a = sleeve_section(f, ox=250, oy=250, r_out=62, r_in=36, length=240,
                       flange_r=78, flange_w=26)
    to, bo, ti, bi = a["top_out"], a["bot_out"], a["top_in"], a["bot_in"]
    oy, x0, x1 = a["axis"], a["x0"], a["x1"]
    f.dim_v(to, bo, 180, "φ80", ext_x=x0)
    f.dim_v(ti, bi, x1 + 86, None, ext_x=x1)
    size_block(f, x1 + 96, oy + 4, "φ45", mod="E" if which == "a" else None)

    f.datum(x0 + 4, oy - 62, "left", "A")
    if which == "a":
        # 垂直度：内孔轴线对左端面 A
        r1 = f.frame(54, 54, [("sym", "perpendicularity"), ("val", "φ0.02"),
                              ("dat", "A")])
        f.leader([(r1["x0"], r1["cy"]), (x1 + 86, r1["cy"]), (x1 + 86, oy - 54)],
                 head=False)
        # 端面圆跳动：右端面 → 内孔轴线 B
        r2 = f.frame(846, 150, [("sym", "circular_runout"), ("val", "0.03"),
                               ("dat", "B")], anchor="right")
        f.leader([(r2["x0"], r2["cy"]), (x1 + 46, r2["cy"]),
                  (x1 + 46, bo - 20), (x1 + 3, bo - 20)])
        f.datum(x1 + 86, bi + 4, "down", "B")
        # 圆柱度：φ80 外圆（从左侧绕到上方，避开零件本体）
        r3 = f.frame(54, 420, [("sym", "cylindricity"), ("val", "0.01")])
        f.leader([(r3["x1"], r3["cy"]), (228, r3["cy"]), (228, 156),
                  (330, 156), (330, to - 3)], head=False)
        f.arrowhead(330, to - 1, -90)
        badge(f, 1, x1 + 112, oy - 26, color=RED)
        badge(f, 2, r2["x0"] - 16, r2["cy"] + 4, color=RED)
        badge(f, 3, 360, 132, color=RED)
    else:
        note(f, 60, 60, "技术要求（请标注在图上）：", size=12.5)
        note(f, 60, 88, "(1) 内孔 φ45 采用包容要求；", size=11.5)
        note(f, 60, 110, "(2) 内孔轴线对左端面 A 的垂直度 φ0.02；", size=11.5)
        note(f, 60, 132, "(3) 右端面对内孔轴线 B 的端面圆跳动 0.03；", size=11.5)
        note(f, 60, 154, "(4) φ80 外圆柱面的圆柱度 0.01。", size=11.5)
    f.save(os.path.join(OUT, f"bz3-{'q' if which == 'q' else 'a'}.png"))


# ---------------------------------------------------------------- 标注 4（应用）
def biaozhu4(which: str):
    """滚动轴承装配（断面）：标轴颈 / 外壳孔配合代号 + 轴颈径向圆跳动。"""
    f = Fig(760, 640)
    a = bearing_section(f, cx=360, cy=290, r_shaft=36, r_in_out=54,
                        r_out_in=72, r_out_out=90, r_housing=112)
    f.text(120, 112, "轴颈", size=12.5, anchor="middle")
    f.leader([(120, 124), (360 - 26, 290 - 26)])
    f.text(660, 112, "外壳孔", size=12.5, anchor="middle")
    f.leader([(660, 124), (360 + 64, 290 - 64)])
    f.text(120, 470, "断面示意：轴 / 内圈 / 滚动体 / 外圈 / 壳体", size=11,
           color=GRAY, anchor="start")

    if which == "a":
        f.text(120, 170, "φ50k6", size=14, color=RED, weight="bold")
        f.text(120, 188, "基孔制", size=11, color=RED)
        f.text(660, 170, "φ90H7", size=14, color=RED, weight="bold")
        f.text(660, 188, "基轴制", size=11, color=RED)
        r1 = f.frame(430, 520, [("sym", "circular_runout"), ("val", "0.01"),
                                ("dat", "A")])
        f.leader([(r1["x0"], r1["cy"]), (430, 430), (400, 332)], head=False)
        f.arrowhead(386, 316, -135)
        f.datum(360, 290 + 136, "down", "A")
        badge(f, 1, 120, 96, color=RED)
        badge(f, 2, 660, 96, color=RED)
        badge(f, 3, 470, 336, color=RED)
    else:
        note(f, 60, 480, "0 级深沟球轴承：内径 d=φ50，外径 D=φ90。", size=12)
        note(f, 60, 508, "(1) 写出轴颈、外壳孔在装配图上应标注的尺寸公差带代号，", size=11.5)
        note(f, 60, 528, "     并说明各采用什么基准制；", size=11.5)
        note(f, 60, 556, "(2) 把这两个代号标在图上；", size=11.5)
        note(f, 60, 584, "(3) 若要求轴颈对轴承配合面的径向圆跳动不超过 0.01，", size=11.5)
        note(f, 60, 604, "     应如何标注？", size=11.5)
    f.save(os.path.join(OUT, f"bz4-{'q' if which == 'q' else 'a'}.png"))


if __name__ == "__main__":
    for fn in (biaozhu1, biaozhu2, biaozhu3, biaozhu4):
        for w in ("q", "a"):
            fn(w)
