"""Author the Open Virtual Pool table and ball assets in Blender.

Run from the repo root, either headless:

    blender -b --python tools/blender/build_pool_assets.py

or through the live Blender MCP bridge. Everything is generated from the same
numbers the Rust core publishes in TableLayout, so the visual pockets and rails
land exactly where the physics expects them.

Coordinate convention: Blender is Z-up, Godot is Y-up. Meshes are authored in
Blender at (gx, -gz, gy) and exported OBJ with forward=-Z, up=Y, which maps
them straight back to Godot's frame without any extra in-game rotation.
"""

import math
import os
import random
import struct
import zlib

import bpy

SCRIPT_FILE = globals().get("__file__", os.path.join(os.getcwd(), "tools/blender/build_pool_assets.py"))
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(SCRIPT_FILE)), "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
MODELS = os.path.join(ASSETS, "models")
TEXTURES = os.path.join(ASSETS, "textures")
BLEND = os.path.join(ROOT, "tools", "blender", "pool_assets.blend")

for directory in (MODELS, TEXTURES, os.path.dirname(BLEND)):
    os.makedirs(directory, exist_ok=True)

# ---------------------------------------------------------------------------
# Geometry numbers from TableLayout / the generated table scenes.
# ---------------------------------------------------------------------------
LENGTH = 2.54
WIDTH = 1.27
CLOTH_THICKNESS = 0.02
SLATE_SIZE = (2.66, 1.39, 0.14)
SLATE_CENTRE = (1.27, 0.635, -0.09)

# Visual openings, in Godot's frame, derived from the pocket's physics region
# so the picture cannot disagree with the core:
#   corner: centred on the drop point (mouth centre + centreline*shelf_depth),
#           radius = shelf_depth (44.45 mm). Its near edge is therefore exactly
#           the mouth line and its centre exactly the drop line. A ball looks
#           over the hole iff it is inside the core's pocket region, and it is
#           removed at the centre, which is where the core drops it.
#   side:   shelf is only 6.35 mm, so the jaw-tip half-width at the mouth centre
#           is already the honest opening and the capture point sits inside it.
POCKETS = [
    (0.00960, -0.00960, 0.04445),
    (2.53040, -0.00960, 0.04445),
    (0.00960, -1.26050, 0.04445),
    (2.53040, -1.26050, 0.04445),
    (1.27000, 0.00000, 0.064262),
    (1.27000, -1.27000, 0.064262),
]

BCA = {
    0: "f2efe6",
    1: "e8c112", 2: "1648a8", 3: "c33027", 4: "5b2a86",
    5: "e05f1e", 6: "1d7a3c", 7: "7e2024", 8: "17171a",
}

# ---------------------------------------------------------------------------
# Tiny PNG writer and 5x7 digit font, so this needs no extra Python packages.
# ---------------------------------------------------------------------------
def write_png(path, width, height, pixels):
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])
    blob = (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))
    with open(path, "wb") as handle:
        handle.write(blob)


FONT = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
}


def hex_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def put(pixels, width, x, y, rgb):
    i = (y * width + x) * 4
    pixels[i:i + 4] = bytes((rgb[0], rgb[1], rgb[2], 255))


def draw_ellipse(pixels, width, height, cx, cy, rx, ry, rgb):
    for y in range(max(0, cy - ry), min(height, cy + ry + 1)):
        for x in range(max(0, cx - rx), min(width, cx + rx + 1)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                put(pixels, width, x, y, rgb)


def draw_text(pixels, width, text, cx, cy, scale, rgb):
    glyph_w, glyph_h, gap = 5 * scale, 7 * scale, 2 * scale
    total = len(text) * glyph_w + (len(text) - 1) * gap
    start_x = cx - total // 2
    start_y = cy - glyph_h // 2
    for index, char in enumerate(text):
        origin = start_x + index * (glyph_w + gap)
        for row, line in enumerate(FONT[char]):
            for col, bit in enumerate(line):
                if bit == "1":
                    for dy in range(scale):
                        for dx in range(scale):
                            x, y = origin + col * scale + dx, start_y + row * scale + dy
                            if 0 <= x < width and 0 <= y < 1024:
                                put(pixels, width, x, y, rgb)


def paint_ball(number, path):
    width, height = 512, 256
    pixels = bytearray(width * height * 4)
    rng = random.Random(1000 + number)
    body = hex_rgb(BCA.get(number, "f2efe6"))
    band = hex_rgb(BCA.get(number - 8, "f2efe6")) if number >= 9 else body
    striped = 9 <= number <= 15

    for y in range(height):
        v = y / (height - 1)
        for x in range(width):
            rgb = band if striped and abs(v - 0.5) < 0.155 else body
            speckle = int(rng.gauss(0, 2.2))
            put(pixels, width, x, y, tuple(max(0, min(255, c + speckle)) for c in rgb))

    if number != 0:
        label = str(number)
        scale = 4 if len(label) == 1 else 3
        for centre_u in (0.25, 0.75):
            cx, cy = int(centre_u * width), height // 2
            draw_ellipse(pixels, width, height, cx, cy, 46, 46, (18, 18, 18))
            draw_ellipse(pixels, width, height, cx, cy, 43, 43, (246, 244, 234))
            draw_text(pixels, width, label, cx, cy, scale, (20, 20, 22))

    write_png(path, width, height, pixels)


def paint_surface(path, seed, base, grain, mottle=0.0):
    width = height = 512
    pixels = bytearray(width * height * 4)
    rng = random.Random(seed)
    for y in range(height):
        for x in range(width):
            wave = grain * math.sin(y * 0.11 + 3.0 * math.sin(x * 0.017 + seed))
            large = mottle * math.sin(x * 0.021 + seed) * math.sin(y * 0.026 - seed)
            noise = rng.gauss(0, 3.0)
            put(pixels, width, x, y,
                tuple(max(0, min(255, int(c + wave + large + noise))) for c in base))
    write_png(path, width, height, pixels)


print("Painting textures ...")
paint_surface(os.path.join(TEXTURES, "felt.png"), 7, (14, 84, 65), 2.5, 4.0)
paint_surface(os.path.join(TEXTURES, "wood.png"), 11, (61, 38, 23), 9.0, 5.0)
paint_surface(os.path.join(TEXTURES, "rubber.png"), 13, (19, 58, 46), 3.0, 3.0)
paint_surface(os.path.join(TEXTURES, "leather.png"), 17, (24, 22, 21), 4.0, 2.0)
paint_surface(os.path.join(TEXTURES, "pocket_dark.png"), 19, (7, 7, 8), 1.5, 0.5)
for number in range(16):
    paint_ball(number, os.path.join(TEXTURES, "ball_%02d.png" % number))

# ---------------------------------------------------------------------------
# Blender helpers.
# ---------------------------------------------------------------------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, texture, roughness=0.55, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    image = mat.node_tree.nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(os.path.join(TEXTURES, texture))
    mat.node_tree.links.new(image.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


felt = material("Felt", "felt.png", 0.92)
wood = material("Walnut", "wood.png", 0.42)
rubber = material("Cushion rubber", "rubber.png", 0.78)
leather = material("Pocket leather", "leather.png", 0.85)
pocket_dark = material("Pocket interior", "pocket_dark.png", 0.98)


def activate(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def unwrap(obj):
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(island_margin=0.01)
    except TypeError:
        bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode="OBJECT")


def bevel_box(name, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = name
    if bevel:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    unwrap(obj)
    obj.data.materials.append(mat)
    return obj


def export(obj, filename):
    activate([obj])
    path = os.path.join(MODELS, filename)
    bpy.ops.wm.obj_export(
        filepath=path,
        export_selected_objects=True,
        forward_axis="NEGATIVE_Z",
        up_axis="Y",
        export_uv=True,
        export_normals=True,
        export_materials=False,
        apply_modifiers=True,
    )
    print("wrote", path)


def cut_pockets(obj, scale=1.35):
    """Open every pocket through a decorative part so no wood shows in the throat."""
    for gx, gz, radius in POCKETS:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius * scale,
                                            depth=0.8, location=(gx, -gz, -0.24))
        cutter = bpy.context.object
        modifier = obj.modifiers.new("Pocket", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.object = cutter
        activate([obj])
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    activate([obj])


def holed_slab(name, size, centre, mat):
    bpy.ops.mesh.primitive_cube_add(size=1)
    slab = bpy.context.object
    slab.name = name
    slab.dimensions = size
    slab.location = centre
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    for gx, gz, radius in POCKETS:
        bx, by, bz = gx, -gz, centre[2]
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=0.6,
                                            location=(bx, by, bz))
        cutter = bpy.context.object
        modifier = slab.modifiers.new("Pocket", "BOOLEAN")
        modifier.operation = "DIFFERENCE"
        modifier.object = cutter
        activate([slab])
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter, do_unlink=True)

    activate([slab])
    unwrap(slab)
    slab.data.materials.append(mat)
    return slab


print("Modelling table ...")
cloth = holed_slab("Cloth with six pockets", (LENGTH, WIDTH, CLOTH_THICKNESS),
                   (LENGTH / 2, WIDTH / 2, -CLOTH_THICKNESS / 2), felt)
slate = holed_slab("Slate with six pockets", SLATE_SIZE, SLATE_CENTRE, felt)

rail = bevel_box("Rail frame", wood, 0.03)

# The long rails carry a side pocket at their midpoint, so Godot instances this
# two-piece version for the bottom/top rails and keeps the solid one on the ends.
rail_halves = []
for side in (-1, 1):
    half = bevel_box("Rail half", wood, 0.03)
    half.dimensions = (0.475, 1.0, 1.0)
    half.location = (side * 0.2625, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    rail_halves.append(half)
activate(rail_halves)
bpy.ops.object.join()
rail_split = bpy.context.object
rail_split.name = "Rail frame split for side pocket"

cushion = bevel_box("Cushion segment", rubber, 0.06)
jaw = bevel_box("Jaw face", rubber, 0.05)

# Pocket fittings are baked at the hole centres. Each opening is a black void
# starting at bed level, exactly like a real table: the cushions stop at the
# jaws and the cloth simply ends in a hole. No visible shelf.
funnels = []
facings = []
for gx, gz, mouth in POCKETS:
    vertices = []
    faces = []
    rings = [(0.0, mouth), (-0.05, mouth * 0.92),
             (-0.15, mouth * 0.76), (-0.30, mouth * 0.60)]
    for y, radius in rings:
        for i in range(48):
            angle = 2 * math.pi * i / 48
            vertices.append((gx + radius * math.cos(angle),
                             -gz + radius * math.sin(angle), y))
    for ring in range(len(rings) - 1):
        for i in range(48):
            a = ring * 48 + i
            b = ring * 48 + (i + 1) % 48
            faces.append((a, b, b + 48, a + 48))
    vertices.append((gx, -gz, -0.30))
    centre_index = len(vertices) - 1
    for i in range(48):
        faces.append((centre_index, (i + 1) % 48, i))
    mesh = bpy.data.meshes.new("Pocket throat")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    funnel = bpy.data.objects.new("Pocket throat", mesh)
    bpy.context.collection.objects.link(funnel)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    uv = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv.data[loop_index].uv = (
                (math.atan2(vertex.y + gz, vertex.x - gx) / (2 * math.pi)) + 0.5,
                (vertex.z + 0.30) / 0.30)
    mesh.materials.append(pocket_dark)
    funnels.append(funnel)

    vertices = []
    faces = []
    for radius in (mouth * 1.10, mouth):
        for i in range(48):
            angle = 2 * math.pi * i / 48
            vertices.append((gx + radius * math.cos(angle),
                             -gz + radius * math.sin(angle), 0.001))
    for i in range(48):
        nxt = (i + 1) % 48
        faces.append((i, nxt, nxt + 48, i + 48))
    mesh = bpy.data.meshes.new("Pocket facing")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    facing = bpy.data.objects.new("Pocket facing", mesh)
    bpy.context.collection.objects.link(facing)
    uv = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            uv.data[loop_index].uv = ((vertex.x - gx) / (2 * mouth) + 0.5,
                                      (vertex.y + gz) / (2 * mouth) + 0.5)
    mesh.materials.append(leather)
    facings.append(facing)

for group, filename in ((funnels, "pocket_funnels.obj"),
                        (facings, "pocket_facings.obj")):
    activate(group)
    bpy.ops.object.join()
    export(bpy.context.object, filename)

# Decorative apron and legs, authored in world coordinates and joined so
# Godot can instance them under a single node.
decor = []
for by in (-0.045, WIDTH + 0.045):
    part = bevel_box("Apron length", wood, 0.01)
    part.dimensions = (LENGTH + 0.18, 0.09, 0.16)
    part.location = (LENGTH / 2, by, -0.24)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    cut_pockets(part)
    decor.append(part)
for bx in (-0.045, LENGTH + 0.045):
    part = bevel_box("Apron end", wood, 0.01)
    part.dimensions = (0.09, WIDTH + 0.18, 0.16)
    part.location = (bx, WIDTH / 2, -0.24)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    cut_pockets(part)
    decor.append(part)

for bx in (0.11, LENGTH - 0.11):
    for by in (0.11, WIDTH - 0.11):
        bpy.ops.mesh.primitive_cube_add(size=1)
        leg = bpy.context.object
        leg.name = "Tapered leg"
        leg.dimensions = (0.13, 0.13, 0.52)
        leg.location = (bx, by, -0.52)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
        # Taper the foot by moving the four lowest vertices inward.
        for vertex in leg.data.vertices:
            if vertex.co.z < -0.25:
                vertex.co.x *= 0.78
                vertex.co.y *= 0.78
        unwrap(leg)
        leg.data.materials.append(wood)
        decor.append(leg)

activate(decor)
bpy.ops.object.join()
decor_object = bpy.context.object
decor_object.name = "Walnut frame and legs"

# A UV sphere with Blender's own unwrap; the ball textures are equirectangular.
bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0)
ball = bpy.context.object
ball.name = "Ball unit sphere"
ball.data.materials.append(material("Ball sample", "ball_01.png", 0.18))

# Save an inspectable source file and export every mesh Godot consumes.
# The OBJ exporter writes world coordinates, so slabs keep their scene location.
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

export(cloth, "cloth_with_holes.obj")
export(slate, "slate_with_holes.obj")
export(rail, "rail_frame.obj")
export(rail_split, "rail_frame_split.obj")
export(cushion, "cushion_segment.obj")
export(jaw, "jaw_face.obj")
export(decor_object, "table_frame.obj")
export(ball, "ball_sphere.obj")

print("Pool assets built in", ASSETS)
