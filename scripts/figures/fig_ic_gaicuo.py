"""改错题插图：每道题一对图（题图 = 带错标注；答图 = 改正 + 红字说明）。

运行：
    python scripts/figures/fig_ic_gaicuo.py
输出到 courses/interchangeability/src/assets/figs/
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from gdt import Fig, INK, RED, BLUE, GRAY, W_THICK, W_THIN
from fig_ic_parts import stepped_shaft, sleeve_section, plate_top, keyway_section

OUT = os.path.abspath(
    os.path.join(HERE, "..", "..", "courses", "interchangeability", "src", "assets", "figs")
)


def tag(f, n, x, y, r=10, color=BLUE):
    f.badge(n, x, y, r=r, color=color)


def note(f, x, y, s, size=11.5, anchor="start"):
    f.note(x, y, s, size=size, anchor=anchor)


def del_mark(f, x, y_top, label="φ", size=15):
    """在框格上方画一个「划掉的 φ」，表示这一项要删掉，并用红线指到框格。"""
    f.text(x, y_top - 17, label, size=size, color=RED, weight="bold")
    w = 0.55 * size
    f.line(x - w, y_top - 12, x + w, y_top - 21, w=1.8, color=RED)
    f.line(x, y_top - 9, x, y_top - 1, w=1.6, color=RED)


def led(f, r, pts, head=True, side="left"):
    end = r["x0"] if side == "left" else r["x1"]
    f.leader([(end, r["cy"])] + list(pts), head=head)


# ---------------------------------------------------------------- 改错 1
def gaicuo1(which: str):
    """阶梯轴：圆度加 φ / 同轴度漏 φ / 平行度漏基准。"""
    f = Fig(880, 500)
    a = stepped_shaft(f, ox=270, oy=240, r_big=48, r_small=22,
                      len_big=190, len_small=140, keyway=False)
    tb, bb, ts, bs = a["top_big"], a["bot_big"], a["top_small"], a["bot_small"]
    oy, x0, x1, x2 = a["axis"], a["x0"], a["x1"], a["x2"]
    f.dim_v(tb, bb, 190, "φ40", ext_x=x0)
    f.dim_v(ts, bs, 700, "φ20", ext_x=x2)
    f.dim_h(x0, x1, oy + 140, "180")
    f.dim_h(x1, x2, oy + 140, "130")
    f.datum(700, ts, "up", "A")

    # ① 圆度（φ40 圆柱面）
    r1 = f.frame(54, 54, [("sym", "roundness"),
                          ("val", "φ0.008" if which == "q" else "0.008")])
    led(f, r1, [(330, r1["cy"]), (330, tb - 3)], side="right")
    # ② 同轴度（被测 φ40 轴线）
    r2 = f.frame(54, 344, [("sym", "concentricity"),
                           ("val", "0.02" if which == "q" else "φ0.02"), ("dat", "A")])
    led(f, r2, [(190, r2["cy"]), (190, bb + 2)], side="right", head=False)
    # ③ 平行度（轴肩端面 → φ40 轴线 A）
    r3 = f.frame(846, 54, [("sym", "parallelism"), ("val", "0.02")]
                 + ([("dat", "A")] if which == "a" else []),
                 anchor="right")
    led(f, r3, [(520, r3["cy"]), (520, oy - 34), (x1 + 3, oy - 34)])

    if which == "q":
        tag(f, 1, r1["x1"] + 15, r1["cy"])
        tag(f, 2, r2["x1"] + 15, r2["cy"])
        tag(f, 3, r3["x0"] - 15, r3["cy"])
    else:
        del_mark(f, r1["x0"] + 26 + 30, r1["y0"])
        note(f, 54, 140, "① 圆度公差带是两同心圆之间的区域，公差值是半径差 → 不加 φ")
        f.mark_circle(r2["x0"] + 42, r2["cy"], 26, 15, color=RED)
        note(f, 54, 420, "② 同轴度的公差带是圆柱面 → 必须加 φ")
        f.mark_circle(r3["x1"] - 13, r3["cy"], 15, 15, color=RED)
        note(f, 620, 130, "③ 平行度是定向公差，必须有基准 → 补 A")
    f.save(os.path.join(OUT, f"gc1-{'q' if which == 'q' else 'a'}.png"))


# ---------------------------------------------------------------- 改错 2
def gaicuo2(which: str):
    """套筒全剖：圆度箭头对尺寸线 / 端面圆跳动加 φ / 基准字母用 M。"""
    f = Fig(880, 520)
    a = sleeve_section(f, ox=250, oy=250, r_out=64, r_in=38, length=250,
                       flange_r=80, flange_w=26)
    to, bo, ti, bi = a["top_out"], a["bot_out"], a["top_in"], a["bot_in"]
    oy, x0, x1 = a["axis"], a["x0"], a["x1"]
    f.dim_v(to, bo, 180, "φ80", ext_x=x0)
    f.dim_v(ti, bi, x1 + 74, "φ45", ext_x=x1)

    # ① 圆度（φ80 外圆柱面）
    r1 = f.frame(54, 54, [("sym", "roundness"), ("val", "0.005")])
    if which == "q":
        led(f, r1, [(232, r1["cy"]), (232, oy), (183, oy)], side="right")
    else:
        led(f, r1, [(330, r1["cy"]), (330, to - 3)], side="right")
        f.mark_circle(330, to - 26, 22, 26, color=RED)
        note(f, 54, 128, "① 箭头应指轮廓线，并与尺寸线明显错开")
    # ② 端面圆跳动（右端面）
    r2 = f.frame(846, 54, [("sym", "circular_runout"),
                           ("val", "φ0.02" if which == "q" else "0.02"), ("dat", "A")],
                 anchor="right")
    led(f, r2, [(x1 + 46, r2["cy"]), (x1 + 46, to + 22), (x1 + 3, to + 22)])
    # ③ 垂直度（右端面 → 内孔轴线 A）
    r3 = f.frame(846, 402, [("sym", "perpendicularity"), ("val", "0.03"),
                            ("dat", "M" if which == "q" else "A")],
                 anchor="right")
    led(f, r3, [(x1 + 46, r3["cy"]), (x1 + 46, bo - 20), (x1 + 3, bo - 20)])
    f.datum(x1 + 74, bi, "down", "M" if which == "q" else "A")

    if which == "q":
        tag(f, 1, r1["x1"] + 15, r1["cy"])
        tag(f, 2, r2["x0"] - 15, r2["cy"])
        tag(f, 3, r3["x0"] - 15, r3["cy"])
    else:
        del_mark(f, r2["x0"] + 40, r2["y0"])
        note(f, 500, 140, "② 端面跳动的公差带沿轴向，宽度为 t → 不加 φ")
        f.mark_circle(r3["x1"] - 13, r3["cy"], 15, 15, color=RED)
        f.mark_circle(x1 + 74, bi + 26, 17, 17, color=RED)
        note(f, 452, 432, "③ M 是禁用基准字母，改 A（字母水平书写）")
    f.save(os.path.join(OUT, f"gc2-{'q' if which == 'q' else 'a'}.png"))


# ---------------------------------------------------------------- 改错 3
def gaicuo3(which: str):
    """板件：位置度漏 φ / 理论正确尺寸没加方框 / 平面度带基准。"""
    f = Fig(880, 520)
    a = plate_top(f, ox=250, oy=110, w=270, h=160, holes=((75, 62), (195, 62)))
    (h1x, h1y), (h2x, h2y) = a["holes"]
    yv = a["y1"] + 68

    def hdim(xa, xb, label, boxed):
        f.line(xa, a["y1"], xa, yv - 4, w=W_THIN, color=GRAY)
        f.line(xb, a["y1"], xb, yv - 4, w=W_THIN, color=GRAY)
        f.line(xa, yv, xb, yv, w=W_THIN)
        f.arrowhead(xa, yv, 0)
        f.arrowhead(xb, yv, 180)
        if boxed:
            bw = 36
            f.rect((xa + xb) / 2 - bw / 2, yv - 10, bw, 20, sw=W_THIN, fill="#ffffff")
            f.text((xa + xb) / 2, yv + 1, label, size=13)
        else:
            f.text((xa + xb) / 2, yv - 12, label, size=13)

    hdim(a["x0"], h1x, "75", True)
    hdim(h1x, h2x, "120", which == "a")
    f.dim_v(h1y, a["y1"], a["x1"] + 62, "62", ext_x=h2x + 14)

    # ① 位置度（两孔）
    r1 = f.frame(54, 54, [("sym", "position"),
                          ("val", "0.1" if which == "q" else "φ0.1"),
                          ("dat", "A"), ("dat", "B"), ("dat", "C")])
    led(f, r1, [(620, r1["cy"]), (620, h2y), (h2x + 17, h2y)], side="right")
    # ③ 平面度（板底面）
    r3 = f.frame(560, 396, [("sym", "flatness"), ("val", "0.05")]
                 + ([("dat", "A")] if which == "q" else []))
    led(f, r3, [(480, r3["cy"]), (480, a["y1"] + 5)], side="left", head=False)
    f.arrowhead(480, a["y1"] + 1, -90)

    f.datum(a["x0"] + 34, a["y1"], "down", "A")
    f.datum(a["x0"], a["y0"] + 108, "left", "B")
    f.datum(a["x0"] + 172, a["y0"], "up", "C")

    if which == "q":
        tag(f, 1, r1["x0"] + 40, r1["cy"] - 26)
        tag(f, 2, (h1x + h2x) / 2 + 34, yv - 34)
        tag(f, 3, r3["x1"] + 15, r3["cy"])
    else:
        f.mark_circle(r1["x0"] + 44, r1["cy"], 24, 15, color=RED)
        note(f, 54, 148, "① 位置度公差带是直径为 φt 的圆柱面 → 必须加 φ")
        tag(f, 2, (h1x + h2x) / 2 + 40, yv - 30, color=RED)
        note(f, 150, yv + 62, "② 理论正确尺寸必须加方框（只改注法，不改公差值）", size=11.5)
        f.mark_circle(r3["x1"] - 12, r3["cy"], 14, 15, color=RED)
        note(f, 452, 452, "③ 平面度是形状公差 → 不加 φ，也不标基准", size=11.5)
    f.save(os.path.join(OUT, f"gc3-{'q' if which == 'q' else 'a'}.png"))


# ---------------------------------------------------------------- 改错 4
def gaicuo4(which: str):
    """键槽断面：对称度加 φ / 基准 A 贴轮廓线 / 指引线弯折三次。"""
    f = Fig(780, 470)
    cx, cy, r, w, d = 320, 230, 64, 40, 20
    a = keyway_section(f, cx, cy, r=r, width=w, depth=d)
    f.dim_v(cy - r, cy + r, 170, "φ40", ext_x=cx - r - 4)
    f.dim_h(cx - w / 2, cx + w / 2, cy - r - 52, "12", ext_y=cy - r + 6)

    # ① 对称度：被测要素是键槽中心平面 → 指引线与宽度 12 的尺寸线对齐
    r1 = f.frame(392, 30, [("sym", "symmetry"),
                           ("val", "φ0.02" if which == "q" else "0.02"), ("dat", "A")])
    f.leader([(r1["x0"], r1["cy"]), (cx + w / 2, r1["cy"]),
              (cx + w / 2, cy - r - 52)], head=False)
    f.arrowhead(cx + w / 2, cy - r - 48, -90)
    # ② 基准 A
    if which == "q":
        f.datum(cx + r, cy + 34, "right", "A")      # 错：贴在轮廓线上
    else:
        f.datum(170, cy + r + 5, "down", "A")
    # ③ 圆度（φ40 外圆）
    r3 = f.frame(470, 372, [("sym", "roundness"), ("val", "0.008")])
    if which == "q":
        f.leader([(r3["x0"], r3["cy"]), (447, r3["cy"]), (447, 306),
                  (380, 306), (380, 258)], head=False)
        f.arrowhead(380, 256, -90)
    else:
        f.leader([(r3["x0"], r3["cy"]), (380, r3["cy"]), (380, 258)], head=False)
        f.arrowhead(380, 256, -90)

    if which == "q":
        tag(f, 1, r1["x1"] + 15, r1["cy"])
        tag(f, 2, cx + r + 52, cy + 28)
        tag(f, 3, 420, 300)
    else:
        del_mark(f, r1["x0"] + 26 + 30, r1["y0"])
        note(f, 392, 96, "① 对称度公差带是两平行平面 → 不加 φ")
        f.mark_circle(170, cy + r + 15, 24, 22, color=RED)
        note(f, 54, cy + r + 66, "② 基准是轴线：三角形底边贴 φ40 尺寸界线，")
        note(f, 54, cy + r + 82, "   细实线与尺寸线对齐（错图贴在轮廓线上）")
        f.mark_circle(402, 300, 52, 32, color=RED)
        note(f, 470, 344, "③ 指引线弯折不得超过两次，箭头指向公差带宽度方向")
    f.save(os.path.join(OUT, f"gc4-{'q' if which == 'q' else 'a'}.png"))


if __name__ == "__main__":
    for fn in (gaicuo1, gaicuo2, gaicuo3, gaicuo4):
        for w in ("q", "a"):
            fn(w)
