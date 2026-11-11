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

from gdt import (Fig, INK, RED, BLUE, GRAY, W_THICK, W_THIN,
                 roughness, uniform_roughness)
from fig_ic_parts import (stepped_shaft, sleeve_section, plate_top,
                          bearing_section, key_joint_cross)

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
    """滚动轴承装配（断面）：配合代号 + 轴颈径向圆跳动 + 表面粗糙度。"""
    f = Fig(800, 700)
    a = bearing_section(f, cx=400, cy=320, r_shaft=36, r_in_out=54,
                        r_out_in=72, r_out_out=90, r_housing=112)
    f.text(120, 112, "轴颈", size=12.5, anchor="middle")
    f.leader([(120, 124), (400 - 26, 320 - 26)])
    f.text(680, 112, "外壳孔", size=12.5, anchor="middle")
    f.leader([(680, 124), (400 + 64, 320 - 64)])
    f.text(120, 654, "断面示意：轴 / 内圈 / 滚动体 / 外圈 / 壳体", size=11,
           color=GRAY, anchor="start")

    if which == "a":
        # ① ② 配合代号
        f.text(120, 170, "φ50k6", size=14, color=RED, weight="bold")
        f.text(120, 188, "（基孔制）", size=11, color=RED)
        f.text(680, 170, "φ90H7", size=14, color=RED, weight="bold")
        f.text(680, 188, "（基轴制）", size=11, color=RED)
        # ③ 形位公差：轴颈径向圆跳动
        r1 = f.frame(470, 560, [("sym", "circular_runout"), ("val", "0.01"),
                                ("dat", "A")])
        f.leader([(r1["x0"], r1["cy"]), (470, 470), (420, 348)], head=False)
        f.arrowhead(408, 334, -135)
        f.datum(400, 320 + 136, "down", "A")
        # ④ ⑤ 表面粗糙度：轴颈 / 外壳孔
        roughness(f, 190, 430, "Ra 1.6", mode="remove", s=24)
        f.leader([(190, 430), (400 - 30, 320 + 16)], head=False, size=6)
        f.dot(400 - 30, 320 + 16, r=2.2, color=RED)
        roughness(f, 610, 430, "Ra 3.2", mode="remove", s=24)
        f.leader([(610, 430), (400 + 58, 320 + 58)], head=False, size=6)
        f.dot(400 + 58, 320 + 58, r=2.2, color=RED)
        uniform_roughness(f, 590, 640, "Ra 6.3")
        badge(f, 1, 120, 96, color=RED)
        badge(f, 2, 680, 96, color=RED)
        badge(f, 3, 440, 300, color=RED)
        badge(f, 4, 158, 396, color=RED)
        badge(f, 5, 646, 396, color=RED)
    else:
        note(f, 60, 470, "0 级深沟球轴承：内径 d=φ50，外径 D=φ90。", size=12)
        note(f, 60, 498, "在装配图上完成（尺寸公差 + 形位公差 + 表面粗糙度）：", size=11.5)
        note(f, 60, 526, "(1) 转轴、正常负荷：轴颈、外壳孔取什么公差带？说明基准制；", size=11.5)
        note(f, 60, 554, "(2) 轴颈对轴承配合面的径向圆跳动不超过 0.01，如何标注？", size=11.5)
        note(f, 60, 582, "(3) 轴颈 Ra 1.6、外壳孔 Ra 3.2，其余 Ra 6.3，请标注。", size=11.5)
    f.save(os.path.join(OUT, f"bz4-{'q' if which == 'q' else 'a'}.png"))


def biaozhu5(which: str):
    """键连接（平键）断面：尺寸公差 + 对称度 + 表面粗糙度。"""
    f = Fig(820, 620)
    cx, cy = 330, 300
    a = key_joint_cross(f, cx=cx, cy=cy, r_shaft=64, r_hub=112,
                        width=41, t1=13, t2=8)
    half, h_s = a["half"], a["h_s"]
    y_dim = 92
    for x in (cx - half, cx + half):
        f.line(x, cy - h_s + 4, x, y_dim, w=W_THIN, color=GRAY)
    f.line(cx - half, y_dim, cx + half, y_dim, w=W_THIN)
    f.arrowhead(cx - half, y_dim, 180)
    f.arrowhead(cx + half, y_dim, 0)
    f.text(cx, y_dim - 13, "16", size=13)

    if which == "a":
        # ① 对称度：被测是键槽中心平面 → 指引线与 16 的尺寸线对齐
        f.line(cx + half, y_dim, 500, y_dim, w=W_THIN)
        f.frame(500, y_dim - 13, [("sym", "symmetry"), ("val", "0.02"),
                                  ("dat", "A")])
        f.datum(cx, cy + 148, "down", "A")
        # ② 轴槽宽配合（轴槽与键）
        note(f, 600, 330, "16N9/h8", size=13)
        f.leader([(596, 326), (cx + half + 4, cy - 56)], head=False, size=6)
        f.dot(cx + half + 4, cy - 56, r=2.2, color=RED)
        # ③ 轮毂槽宽配合
        note(f, 600, 250, "16JS9/h8", size=13)
        f.leader([(596, 246), (cx + half + 4, cy - 66)], head=False, size=6)
        f.dot(cx + half + 4, cy - 66, r=2.2, color=RED)
        # ④ 槽侧面 Ra 3.2（注在尺寸界线延长线上）
        roughness(f, cx - half, cy - 150, "Ra 3.2", mode="remove", s=22, angle=-90)
        f.dot(cx - half, cy - 150, r=2.2, color=RED)
        uniform_roughness(f, 560, 520, "Ra 6.3", s=22)
        badge(f, 1, 506, y_dim - 40, color=RED)
        badge(f, 2, 704, 306, color=RED)
        badge(f, 3, 704, 226, color=RED)
        badge(f, 4, 246, 122, color=RED)
    else:
        note(f, 60, 460, "键连接（平键）：轴 φ50，键 16×10，一般联结。", size=12)
        note(f, 60, 488, "在装配图上完成（尺寸公差 + 形位公差 + 表面粗糙度）：", size=11.5)
        note(f, 60, 516, "(1) 标出轴槽、轮毂槽的键宽配合代号（键宽 h8，标准件不标）；", size=11.5)
        note(f, 60, 544, "(2) 键槽两侧面对轴线的对称度 0.02，基准 A 为轴线；", size=11.5)
        note(f, 60, 572, "(3) 键槽侧面 Ra 3.2、槽底 Ra 6.3、其余 Ra 6.3。", size=11.5)
    f.save(os.path.join(OUT, f"bz5-{'q' if which == 'q' else 'a'}.png"))


if __name__ == "__main__":
    for fn in (biaozhu1, biaozhu2, biaozhu3, biaozhu4, biaozhu5):
        for w in ("q", "a"):
            fn(w)
