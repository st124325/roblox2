# Blender (headless) batch conversion of the Quaternius monsters for Roblox:
# rest pose, no armature/animations, texture embedded, feet at the origin, facing -Z (Roblox front).
# Usage: blender -b --python tools/models/convert.py -- <src.fbx> <atlas.png> <out.fbx>
import sys
import bpy
from mathutils import Vector

src, atlas, out = sys.argv[sys.argv.index("--") + 1:][:3]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)

# Pose every armature at the first frame of its Idle animation (the bind pose is a T-pose),
# bake that pose into the meshes, then drop armatures and animations
idle = next((a for a in bpy.data.actions if a.name.split("|")[-1] == "Idle"), None) \
    or next((a for a in bpy.data.actions if "Idle" in a.name), None)
idle_name = idle.name.split("|")[-1] if idle else None
for arm in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
    if idle is not None:
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = idle
        bpy.context.scene.frame_set(int(idle.frame_range[0]))
for obj in [o for o in bpy.data.objects if o.type == "MESH"]:
    if obj.data.shape_keys:
        obj.shape_key_clear()
    for mod in list(obj.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
for obj in list(bpy.data.objects):
    obj.animation_data_clear()
for obj in list(bpy.data.objects):
    if obj.type != "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
# Bake transforms, then join into one mesh (one MeshPart in Roblox)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.parent = None
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = "Monster"
for group in list(obj.vertex_groups):
    obj.vertex_groups.remove(group)

# Point every material at the atlas so the exporter can embed it
image = bpy.data.images.load(atlas)
for slot in obj.material_slots:
    mat = slot.material
    if not mat:
        continue
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    tex = next((n for n in nodes if n.type == "TEX_IMAGE"), None)
    if tex is None:
        tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    if bsdf is not None:
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

# Feet on the origin, centred horizontally
corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
minv = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
maxv = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
offset = Vector(((minv.x + maxv.x) / 2, (minv.y + maxv.y) / 2, minv.z))
obj.data.transform(__import__("mathutils").Matrix.Translation(-offset))
dims = maxv - minv
print(f"CONVERTED {out} idle={idle_name} tris={sum(len(p.vertices) - 2 for p in obj.data.polygons)} size={dims.x:.2f}x{dims.y:.2f}x{dims.z:.2f}")

bpy.ops.export_scene.fbx(
    filepath=out,
    use_selection=False,
    object_types={"MESH"},
    bake_anim=False,
    path_mode="COPY",
    embed_textures=True,
    axis_forward="-Z",
    axis_up="Y",
    apply_scale_options="FBX_SCALE_ALL",
)
