"""第四章原理图：符号总表、公差带形状、作用尺寸与边界、动态公差图。

运行：
    python scripts/figures/fig_ic_ch4.py
"""

from __future__ import annotations

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from gdt import Fig, INK, RED, BLUE, GRAY, W_THICK, W_THIN, W_THINNER, draw_symbol
from fig_ic_parts import stepped_shaft

OUT = os.path.abspath(
    os.path.join(HERE, "..", "..", "courses", "interchangeability", "src", "assets", "figs")
)

ROWS = [
    ("straightness", "直线度"), ("flatness", "平面度"),
    ("roundness", "圆度"), ("cylindricity", "圆柱度"),
    ("profile_line", "线轮廓度"), ("profile_surface", "面轮廓度"),
    ("parallelism", "平行度"), ("perpendicularity", "垂直度"),
    ("angularity", "倾斜度"), ("position", "位置度"),
    ("concentricity", "同轴度"), ("symmetry", "对称度"),
    ("circular_runout", "圆跳动"), ("total_runout", "全跳动"),
]


def sym_legend():
    """14 项几何公差符号总表。"""
    cols, cw, ch = 2, 250, 46
    f = Fig(560, 30 + ch * 7 + 20)
    f.text(280, 22, "几何公差 14 项特征符号", size=14, weight="bold")
    for i, (sym, name) in enumerate(ROWS):
        col, row = i % cols, i // cols
        x = 40 + col * cw
        y = 44 + row * ch
        f.rect(x, y, 44, 34, sw=W_THIN)
        draw_symbol(f, sym, x + 22, y + 17, 12)
        f.text(x + 56, y + 10, name, size=12.5, anchor="start")
        linked = sym in ("parallelism", "perpendicularity", "angularity",
                         "position", "concentricity", "symmetry",
                         "circular_runout", "total_runout")
        f.text(x + 56, y + 27, "有基准" if linked else "无基准", size=10,
               color=GRAY, anchor="start")
    f.save(os.path.join(OUT, "ch4-fuhao.png"))


def gongchadai():
    """常用公差带形状：两平行直线 / 两平行平面 / 圆柱面 / 两同心圆 / 同轴圆柱面 / 球。"""
    f = Fig(760, 300)
    items = [
        ("两平行直线（给定平面直线度）", "lines"),
        ("两平行平面（平面度/定向）", "planes"),
        ("圆柱面（任意方向/同轴度）", "cyl"),
        ("两同心圆（圆度）", "circles"),
        ("两同轴圆柱面（圆柱度/全跳动）", "twocyl"),
        ("球（Sφ 位置度）", "sphere"),
    ]
    for i, (label, kind) in enumerate(items):
        col, row = i % 3, i // 3
        cx = 130 + col * 250
        cy = 90 + row * 130
        if kind == "lines":
            f.line(cx - 70, cy - 12, cx + 70, cy - 12, w=W_THIN)
            f.line(cx - 70, cy + 12, cx + 70, cy + 12, w=W_THIN)
            f.line(cx - 80, cy - 18, cx - 60, cy - 18, w=W_THINNER)
            f.line(cx - 80, cy + 18, cx - 60, cy + 18, w=W_THINNER)
            f.text(cx + 76, cy, "t", size=12, anchor="start")
        elif kind == "planes":
            f.poly([(cx - 70, cy - 10), (cx + 50, cy - 22), (cx + 70, cy - 14),
                    (cx - 50, cy - 2)], w=W_THIN, close=True)
            f.poly([(cx - 70, cy + 12), (cx + 50, cy), (cx + 70, cy + 8),
                    (cx - 50, cy + 20)], w=W_THIN, close=True)
            f.text(cx + 76, cy + 4, "t", size=12, anchor="start")
        elif kind == "cyl":
            f.rect(cx - 46, cy - 40, 92, 80, sw=W_THIN)
            f.add(f'<ellipse cx="{cx}" cy="{cy - 40}" rx="46" ry="12" fill="none" '
                  f'stroke="{INK}" stroke-width="1"/>')
            f.add(f'<ellipse cx="{cx}" cy="{cy + 40}" rx="46" ry="12" fill="none" '
                  f'stroke="{INK}" stroke-width="1" stroke-dasharray="5,3"/>')
            f.text(cx + 54, cy, "φt", size=12, anchor="start")
        elif kind == "circles":
            f.circle(cx, cy, 42, sw=W_THIN)
            f.circle(cx, cy, 32, sw=W_THIN)
            f.text(cx + 50, cy, "t", size=12, anchor="start")
        elif kind == "twocyl":
            f.rect(cx - 50, cy - 34, 100, 68, sw=W_THIN)
            f.rect(cx - 38, cy - 24, 76, 48, sw=W_THIN)
            f.text(cx + 58, cy, "t", size=12, anchor="start")
        else:
            f.circle(cx, cy, 38, sw=W_THIN)
            f.add(f'<ellipse cx="{cx}" cy="{cy}" rx="38" ry="12" fill="none" '
                  f'stroke="{INK}" stroke-width="0.8" stroke-dasharray="4,3"/>')
            f.add(f'<ellipse cx="{cx}" cy="{cy}" rx="12" ry="38" fill="none" '
                  f'stroke="{INK}" stroke-width="0.8" stroke-dasharray="4,3"/>')
            f.text(cx + 44, cy, "Sφt", size=12, anchor="start")
        f.text(cx, cy + 62, label, size=10.5, color=GRAY)
    f.save(os.path.join(OUT, "ch4-gongchadai.png"))


def zuoyong_chicun():
    """体外作用尺寸：弯曲的轴 + 体外相接的最小理想孔。"""
    f = Fig(760, 340)
    ox, oy = 150, 165
    r, bow = 42, 8
    n = 60
    up, dn = [], []
    for i in range(n + 1):
        x = ox + i * 7
        b = bow * math.sin(math.pi * i / n)
        up.append((x, oy - r - b))
        dn.append((x, oy + r - b))
    f.poly(up, w=W_THICK)
    f.poly(dn, w=W_THICK)
    f.line(ox, oy - r, ox, oy + r, w=W_THICK)
    f.line(ox + n * 7, oy - r, ox + n * 7, oy + r, w=W_THICK)
    f.centerline(ox - 36, oy, ox + n * 7 + 36, oy)
    # 体外相接的最小理想孔
    xa, xb = ox - 18, ox + n * 7 + 18
    for yy in (oy - r - bow, oy + r + bow):
        f.line(xa, yy, xb, yy, w=W_THIN, dash="9,5", color=BLUE)
    f.line(xa, oy - r - bow, xa, oy + r + bow, w=W_THIN, dash="9,5", color=BLUE)
    f.line(xb, oy - r - bow, xb, oy + r + bow, w=W_THIN, dash="9,5", color=BLUE)
    f.text(xa + 120, oy - r - bow - 14, "体外相接的最小理想孔（直径 = dfe）",
           size=12, color=BLUE, anchor="start")
    f.text(ox + 120, oy + 22, "实际轴（直径 da，带形状误差 f）", size=12,
           color=RED, anchor="start")
    f.text(ox + 120, oy + r + bow + 26, "dfe = da + f形位", size=14, weight="bold",
           anchor="start")
    f.text(40, oy + r + bow + 66, "轴的体外作用尺寸 dfe = da + f：与实际轴体外相接的最小理想孔的直径，", size=11.5, anchor="start")
    f.text(40, oy + r + bow + 84, "是「装配时真正起作用」的尺寸；孔的体外作用尺寸 Dfe = Da − f。", size=11.5, anchor="start")
    f.save(os.path.join(OUT, "ch4-zuoyong.png"))


def _axes(f, x0, y0, w, h):
    f.line(x0, y0, x0, y0 - h, w=W_THIN)
    f.line(x0, y0, x0 + w, y0, w=W_THIN)
    f.arrowhead(x0, y0 - h, -90)
    f.arrowhead(x0 + w, y0, 0)
    f.text(x0 + 8, y0 - h + 2, "形位公差 t", size=11.5, anchor="start")
    f.text(x0 + w / 2, y0 + 40, "实际尺寸 da", size=11.5, anchor="middle")


def tol_diagram(kind):
    """动态公差图：t 随实际尺寸变化的三条线。"""
    f = Fig(640, 430)
    x0, y0, w, h = 170, 320, 360, 190
    dmin, dmax = 0.0, 10.0
    T, t0 = 0.3, 0.1
    _axes(f, x0, y0, w, h)
    X = lambda d: x0 + (d - dmin) / (dmax - dmin) * w
    Y = lambda t: y0 - t / 0.5 * h
    f.line(X(dmin), y0 - 5, X(dmin), y0 + 5, w=W_THIN)
    f.line(X(dmax), y0 - 5, X(dmax), y0 + 5, w=W_THIN)
    f.text(X(dmin), y0 + 18, "dmin", size=11)
    f.text(X(dmax), y0 + 18, "dmax", size=11)

    title = {"E": "包容要求的动态公差图", "M": "最大实体要求的动态公差图",
             "L": "最小实体要求的动态公差图"}[kind]
    f.text(40, 26, title, size=13.5, weight="bold", anchor="start")

    # 独立原则参考线
    f.line(X(dmin), Y(t0), X(dmax), Y(t0), w=W_THIN, dash="7,4", color=GRAY)
    f.text(X(dmin) + 6, Y(t0) - 9, "独立原则：t 恒为定值", size=10.5,
           color=GRAY, anchor="start")

    if kind == "E":
        f.line(X(dmax), Y(0), X(dmin), Y(T), w=W_THICK, color=RED)
        f.text(X(dmin) + 6, Y(T) - 9, "t 最大 = T = 尺寸公差", size=11, color=RED,
               anchor="start")
        f.text(X(dmax) - 4, Y(0) - 10, "t = 0", size=11, color=RED, anchor="end")
        f.text(40, 56, "① 实际尺寸偏离最大实体，形位公差由「尺寸公差让出」", size=11.5, color=RED, anchor="start")
        f.text(40, 76, "② 遵守最大实体边界 MMB（φdmax），保证配合性质", size=11.5, color=RED, anchor="start")
        f.text(40, 392, "合格判据：dfe ≥ dmin 且 da ≤ dmax", size=11.5, anchor="start")
    elif kind == "M":
        f.line(X(dmax), Y(t0), X(dmin), Y(t0 + T), w=W_THICK, color=RED)
        f.text(X(dmax) + 8, Y(t0) + 4, "t0", size=11.5, color=RED, anchor="start")
        f.text(X(dmin) + 6, Y(t0 + T) - 9, "t0 + T", size=11.5, color=RED, anchor="start")
        f.text(40, 56, "① 实际尺寸偏离最大实体尺寸时，形位公差按偏离量等量补偿", size=11.5, color=RED, anchor="start")
        f.text(40, 76, "② 遵守最大实体实效边界 MMVB（dMV = dmax + t），保证可装配", size=11.5, color=RED, anchor="start")
        f.text(40, 392, "合格判据：dfe ≤ dMV 且 dmin ≤ da ≤ dmax", size=11.5, anchor="start")
    else:
        f.line(X(dmin), Y(t0), X(dmax), Y(t0 + T), w=W_THICK, color=BLUE)
        f.text(X(dmin) + 6, Y(t0) - 9, "t0", size=11.5, color=BLUE, anchor="start")
        f.text(X(dmax), Y(t0 + T) - 9, "t0 + T", size=11.5, color=BLUE, anchor="end")
        f.text(40, 56, "① 实际尺寸偏离最小实体尺寸时，形位公差按偏离量等量补偿", size=11.5, color=BLUE, anchor="start")
        f.text(40, 76, "② 遵守最小实体实效边界 LMVB（dLV = dmin − t），保最小壁厚", size=11.5, color=BLUE, anchor="start")
        f.text(40, 392, "合格判据：dfi ≤ dLV 且 dmin ≤ da ≤ dmax", size=11.5, anchor="start")

    f.save(os.path.join(OUT, f"ch4-{'baorong' if kind == 'E' else 'zuidashiti' if kind == 'M' else 'zuixiaoshiti'}.png"))


def bianjie():
    """四种边界与极限尺寸的关系（轴）。"""
    f = Fig(780, 320)
    xs = [110, 260, 410, 560]
    for x, color in zip(xs, (BLUE, INK, INK, RED)):
        f.line(x, 74, x, 206, w=W_THIN, dash="8,5", color=color)
    f.text(xs[0], 62, "dmin − t", size=11.5, color=BLUE)
    f.text(xs[1], 226, "dmin", size=11.5)
    f.text(xs[2], 226, "dmax", size=11.5)
    f.text(xs[3], 62, "dmax + t", size=11.5, color=RED)
    # 尺寸公差带
    f.line(xs[1], 112, xs[2], 112, w=W_THIN)
    f.arrowhead(xs[1], 112, 180)
    f.arrowhead(xs[2], 112, 0)
    f.text((xs[1] + xs[2]) / 2, 98, "尺寸公差带 T", size=12)
    f.text((xs[1] + xs[2]) / 2, 140, "实际尺寸允许范围 da", size=11, color=GRAY)
    # 边界说明
    f.text(40, 262, "最小实体实效边界 LMVB：φ(dmin − t)　　最大实体边界 MMB：φdmax", size=11.5, anchor="start")
    f.text(40, 284, "最小实体边界 LMB：φdmin　　　最大实体实效边界 MMVB：φ(dmax + t)", size=11.5, anchor="start")
    f.text(40, 306, "（轴用「理想孔」作边界，孔用「理想轴」作边界；t 为带 Ⓜ/Ⓛ 的形位公差值）", size=11, color=GRAY, anchor="start")
    f.save(os.path.join(OUT, "ch4-bianjie.png"))


if __name__ == "__main__":
    sym_legend()
    gongchadai()
    zuoyong_chicun()
    for k in ("E", "M", "L"):
        tol_diagram(k)
    bianjie()


def roughness_card():
    """表面粗糙度：三种符号 + 注法位置 + 统一注法。"""
    from gdt import roughness, uniform_roughness
    f = Fig(760, 420)
    # 三种符号
    f.line(60, 150, 560, 150, w=2.4)
    roughness(f, 130, 150, "Ra 3.2", mode="basic")
    roughness(f, 300, 150, "Ra 3.2", mode="remove")
    roughness(f, 470, 150, "Ra 1.6", mode="none")
    f.text(130, 220, "基本符号（任何方法）", size=11, color=GRAY)
    f.text(300, 220, "去除材料（切削）", size=11, color=GRAY)
    f.text(470, 220, "不去除材料（铸锻）", size=11, color=GRAY)

    # 尖端指向表面
    f.rect(620, 90, 120, 60, sw=2.4)
    roughness(f, 620, 120, "Ra 6.3", mode="remove", angle=-90)
    f.text(680, 176, "尖端指向表面", size=10.5, color=GRAY)

    # 统一注法
    uniform_roughness(f, 120, 330, "Ra 6.3")
    f.text(120, 372, "统一注法：写在图样右上角或技术要求中，", size=11, color=GRAY,
           anchor="start")
    f.text(120, 392, "表示「图上未注明的表面」。", size=11, color=GRAY, anchor="start")

    f.text(430, 330, "参数写在符号上方（长边一侧）：", size=11, anchor="start")
    f.text(430, 352, "Ra 3.2 / Rz 6.3 / Ra 1.6", size=11.5, anchor="start",
           weight="bold")
    f.text(430, 384, "上限值直接写；需要下限时写「max / min」", size=10.5,
           color=GRAY, anchor="start")
    f.save(os.path.join(OUT, "czd-fuhao.png"))


def _arc_arrow(f, cx, cy, r, a0, a1, color=INK, w=1.6, head=9.0):
    import math
    n = 40
    pts = [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1))),
            cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1))))
           for i in range(n)]
    f.poly(pts, w=w, color=color)
    (x1, y1), (x2, y2) = pts[-2], pts[-1]
    f.arrowhead(x2, y2, math.degrees(math.atan2(y2 - y1, x2 - x1)),
                size=head, color=color)


def bearing_load_types():
    """滚动轴承的三种负荷类型：局部 / 循环 / 摆动。"""
    f = Fig(780, 300)
    cx0, cy, R, r = 130, 150, 62, 38
    titles = ["局部负荷", "循环负荷", "摆动负荷"]
    subs = ["套圈不转：负荷总压在\n同一段滚道上",
            "套圈转：负荷依次压过\n整个滚道",
            "套圈摆动：介于两者\n之间"]
    for i in range(3):
        cx = cx0 + i * 250
        f.circle(cx, cy, R, sw=W_THICK)
        f.circle(cx, cy, r, sw=W_THICK)
        f.circle(cx, cy, (R + r) / 2, sw=0.8)
        # 径向负荷（固定方向）
        f.line(cx, 42, cx, cy - R - 3, w=2.0)
        f.arrowhead(cx, cy - R - 3, 90, size=10)
        f.text(cx + 6, 48, "F", size=12, anchor="start", weight="bold")
        # 承受负荷的滚道标记
        f.line(cx - 10, cy - R + 3, cx + 10, cy - R + 3, w=3.0, color=RED)
        if i == 0:
            f.line(cx - 26, cy - 84, cx - 6, cy - 64, w=1.4, color=GRAY)
            f.line(cx - 6, cy - 84, cx - 26, cy - 64, w=1.4, color=GRAY)
        elif i == 1:
            _arc_arrow(f, cx, cy, R + 16, -30, 210, color=BLUE)
        else:
            _arc_arrow(f, cx, cy, R + 16, -40, 20, color=BLUE)
            _arc_arrow(f, cx, cy, R + 16, 200, 140, color=BLUE)
        f.text(cx, cy + R + 40, titles[i], size=13, weight="bold")
        for j, line in enumerate(subs[i].split("\n")):
            f.text(cx, cy + R + 62 + j * 17, line, size=10.5, color=GRAY)
    f.save(os.path.join(OUT, "ch7-fuhe-leixing.png"))
