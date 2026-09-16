import argparse
import math
import random
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

CLASSES = {
    "back": "◥",
    "front": "◤",
    "hull": "■",
    "cabin": "⌒",
    "tent": "⋏",
    "flag": "⚑",
    "sail": "◮",
    "chimney": "ᴛ",
}
NAMES = list(CLASSES)
SIZE = 640
PATCH = 220


# Generated code ahead! This code is meant to generate training data.

def font_for(size, font_path=None):
    candidates = [
        font_path,
        "DejaVuSans.ttf",
        "NotoSansSymbols2-Regular.ttf",
        "NotoSansSymbols-Regular.ttf",
        "Arial Unicode.ttf",
        "seguisym.ttf",
    ]
    for candidate in candidates:
        if not candidate:
            continue
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    raise RuntimeError(
        "No Unicode font found. Install DejaVu Sans or Noto Sans Symbols, "
        "or pass --font /path/to/font.ttf"
    )


def render_glyph(glyph, rng, font_path=None):
    mask = Image.new("L", (PATCH, PATCH), 0)
    draw = ImageDraw.Draw(mask)
    font = font_for(rng.randint(115, 150), font_path)
    box = draw.textbbox((0, 0), glyph, font=font, stroke_width=1)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (PATCH - w) // 2 - box[0] + rng.randint(-9, 9)
    y = (PATCH - h) // 2 - box[1] + rng.randint(-9, 9)
    draw.text(
        (x, y),
        glyph,
        fill=rng.randint(205, 255),
        font=font,
        stroke_width=rng.choice([0, 1, 2]),
        stroke_fill=220,
    )
    arr = np.array(mask)
    if rng.random() < 0.45:
        k = rng.choice([3, 5])
        arr = cv2.GaussianBlur(arr, (k, k), rng.uniform(0.3, 1.1))
    if rng.random() < 0.25:
        kernel = np.ones((2, 2), np.uint8)
        arr = cv2.erode(arr, kernel, iterations=1)
    return arr


def wood_patch(rng):
    base = np.zeros((PATCH, PATCH, 3), np.float32)
    color = np.array(
        [rng.randint(105, 170), rng.randint(145, 205), rng.randint(175, 225)],
        dtype=np.float32,
    )  # BGR
    base[:] = color
    yy, xx = np.mgrid[:PATCH, :PATCH]
    angle = rng.uniform(0, math.pi)
    grain = np.sin(
        (xx * math.cos(angle) + yy * math.sin(angle)) / rng.uniform(7, 18)
        + rng.uniform(0, 20)
    )
    grain += 0.35 * np.sin(
        (xx * math.cos(angle) + yy * math.sin(angle)) / rng.uniform(2, 6)
    )
    base += grain[..., None] * rng.uniform(5, 15)
    base += np.random.default_rng(rng.randrange(2**32)).normal(
        0, rng.uniform(2, 7), base.shape
    )
    base = np.clip(base, 0, 255).astype(np.uint8)
    cv2.rectangle(base, (3, 3), (PATCH - 4, PATCH - 4), (80, 110, 145), 4)
    return base


def background(rng):
    bgr = np.array(
        [rng.randint(75, 190), rng.randint(75, 190), rng.randint(75, 190)],
        dtype=np.float32,
    )
    img = np.empty((SIZE, SIZE, 3), np.float32)
    img[:] = bgr
    noise = np.random.default_rng(rng.randrange(2**32)).normal(
        0, rng.uniform(3, 12), img.shape
    )
    img += noise
    gradient = np.linspace(rng.uniform(-18, 8), rng.uniform(-8, 18), SIZE)
    img += gradient[:, None, None]
    return np.clip(img, 0, 255).astype(np.uint8)


def destination_quad(cx, cy, side, angle, rng):
    half = side / 2
    pts = np.array(
        [[-half, -half], [half, -half], [half, half], [-half, half]],
        np.float32,
    )
    c, s = math.cos(angle), math.sin(angle)
    rotation = np.array([[c, -s], [s, c]], np.float32)
    pts = pts @ rotation.T
    perspective = side * rng.uniform(0.02, 0.10)
    pts += np.array(
        [
            [rng.uniform(-perspective, perspective), rng.uniform(-perspective, perspective)]
            for _ in range(4)
        ],
        np.float32,
    )
    pts += np.array([cx, cy], np.float32)
    return pts


def place_block(scene, class_name, cx, cy, side, rng, font_path):
    patch = wood_patch(rng)
    glyph_mask = render_glyph(CLASSES[class_name], rng, font_path)
    ink = np.array(
        [rng.randint(15, 60), rng.randint(15, 60), rng.randint(15, 60)],
        np.uint8,
    )
    alpha = (glyph_mask.astype(np.float32) / 255.0)[..., None]
    patch = (patch * (1 - alpha) + ink * alpha).astype(np.uint8)

    src = np.array(
        [[0, 0], [PATCH - 1, 0], [PATCH - 1, PATCH - 1], [0, PATCH - 1]],
        np.float32,
    )
    quad = destination_quad(cx, cy, side, rng.uniform(-math.pi, math.pi), rng)
    matrix = cv2.getPerspectiveTransform(src, quad)

    face_mask = np.full((PATCH, PATCH), 255, np.uint8)
    warped_face = cv2.warpPerspective(patch, matrix, (SIZE, SIZE))
    warped_alpha = cv2.warpPerspective(face_mask, matrix, (SIZE, SIZE))
    warped_symbol = cv2.warpPerspective(glyph_mask, matrix, (SIZE, SIZE))

    shadow_matrix = matrix.copy()
    shadow_matrix[0, 2] += rng.randint(5, 14)
    shadow_matrix[1, 2] += rng.randint(7, 18)
    shadow = cv2.warpPerspective(face_mask, shadow_matrix, (SIZE, SIZE))
    shadow = cv2.GaussianBlur(shadow, (21, 21), 0)
    scene[:] = (
        scene.astype(np.float32) * (1 - 0.28 * shadow[..., None] / 255.0)
    ).astype(np.uint8)

    a = warped_alpha.astype(np.float32)[..., None] / 255.0
    scene[:] = (scene * (1 - a) + warped_face * a).astype(np.uint8)

    ys, xs = np.where(warped_symbol > 35)
    if len(xs) < 20:
        return None
    x1, x2 = int(xs.min()), int(xs.max())
    y1, y2 = int(ys.min()), int(ys.max())
    if (x2 - x1) < 10 or (y2 - y1) < 10:
        return None
    return x1, y1, x2, y2


def camera_effects(img, rng):
    img = cv2.convertScaleAbs(
        img, alpha=rng.uniform(0.82, 1.18), beta=rng.uniform(-18, 18)
    )
    if rng.random() < 0.35:
        img = cv2.GaussianBlur(img, rng.choice([(3, 3), (5, 5)]), 0)
    if rng.random() < 0.25:
        quality = rng.randint(55, 90)
        ok, encoded = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, quality])
        if ok:
            img = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    return img


def yolo_line(class_id, box):
    x1, y1, x2, y2 = box
    xc = ((x1 + x2) / 2) / SIZE
    yc = ((y1 + y2) / 2) / SIZE
    w = (x2 - x1) / SIZE
    h = (y2 - y1) / SIZE
    return f"{class_id} {xc:.6f} {yc:.6f} {w:.6f} {h:.6f}"


def make_preview(output, font_path):
    cell = 220
    preview = Image.new("RGB", (cell * 4, cell * 2), "white")
    draw = ImageDraw.Draw(preview)
    font = font_for(110, font_path)
    label_font = font_for(18, font_path)
    for idx, (name, glyph) in enumerate(CLASSES.items()):
        x = (idx % 4) * cell
        y = (idx // 4) * cell
        box = draw.textbbox((0, 0), glyph, font=font)
        gx = x + (cell - (box[2] - box[0])) // 2 - box[0]
        gy = y + 24 - box[1]
        draw.text((gx, gy), glyph, fill="black", font=font)
        draw.text((x + 8, y + 188), name, fill="black", font=label_font)
    preview.save(output / "glyph_preview.png")


def generate(count, output, seed, font_path):
    output.mkdir(parents=True, exist_ok=True)
    make_preview(output, font_path)

    for split in ("train", "valid", "test"):
        (output / "images" / split).mkdir(parents=True, exist_ok=True)
        (output / "labels" / split).mkdir(parents=True, exist_ok=True)

    for index in range(count):
        rng = random.Random(seed + index * 1009)
        ratio = index / count
        split = "train" if ratio < 0.8 else "valid" if ratio < 0.9 else "test"
        scene = background(rng)
        labels = []

        # About 10% true negatives: blank scenes/blank wooden blocks.
        negative = rng.random() < 0.10
        n_blocks = rng.randint(1, 6)
        grid = [(x, y) for y in (135, 320, 505) for x in (135, 320, 505)]
        rng.shuffle(grid)

        for block_index in range(n_blocks):
            cx, cy = grid[block_index]
            cx += rng.randint(-35, 35)
            cy += rng.randint(-35, 35)
            side = rng.randint(105, 175)

            if negative:
                # Render a blank face without retaining a label.
                class_name = rng.choice(NAMES)
                patch_scene = scene.copy()
                box = place_block(
                    patch_scene, class_name, cx, cy, side, rng, font_path
                )
                # Cover the glyph with matching local wood color to produce a blank block.
                if box:
                    x1, y1, x2, y2 = box
                    color = tuple(int(v) for v in np.median(
                        patch_scene[max(0, y1-8):min(SIZE, y2+8),
                                    max(0, x1-8):min(SIZE, x2+8)], axis=(0, 1)
                    ))
                    cv2.rectangle(patch_scene, (x1, y1), (x2, y2), color, -1)
                scene = patch_scene
                continue

            # Cyclic base assignment guarantees balance; shuffle adds variety.
            class_id = (index + block_index) % len(NAMES)
            if rng.random() < 0.35:
                class_id = rng.randrange(len(NAMES))
            class_name = NAMES[class_id]
            box = place_block(scene, class_name, cx, cy, side, rng, font_path)
            if box:
                labels.append(yolo_line(class_id, box))

        scene = camera_effects(scene, rng)
        stem = f"scene_{index:05d}"
        cv2.imwrite(str(output / "images" / split / f"{stem}.jpg"), scene)
        (output / "labels" / split / f"{stem}.txt").write_text(
            "\n".join(labels), encoding="utf-8"
        )

    yaml = (
        f"path: {output.resolve().as_posix()}\n"
        "train: images/train\n"
        "val: images/valid\n"
        "test: images/test\n"
        f"nc: {len(NAMES)}\n"
        f"names: {NAMES!r}\n"
    )
    (output / "data.yaml").write_text(yaml, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=4000)
    parser.add_argument("--output", type=Path, default=Path("wooden_block_symbols"))
    parser.add_argument("--seed", type=int, default=20260916)
    parser.add_argument("--font", default=None)
    args = parser.parse_args()
    generate(args.count, args.output, args.seed, args.font)
    print(f"Dataset written to: {args.output.resolve()}")
    print(f"Review glyphs at: {(args.output / 'glyph_preview.png').resolve()}")
