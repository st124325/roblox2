"""Repair the shield in a prepared scene without rebuilding the other shots."""
import bpy
import math
from pathlib import Path

dome = next(o for o in bpy.data.objects if any(s.material and s.material.name == 'Dome' for s in o.material_slots))
dome.hide_render = True
mat = bpy.data.materials.new('ShieldRing')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.16, 0.69, 1, 1)
bsdf.inputs['Emission Color'].default_value = (0.16, 0.69, 1, 1)
bsdf.inputs['Emission Strength'].default_value = 2
for rotation in ((0, 0, 0), (math.pi / 2, 0, 0), (0, math.pi / 2, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=8, minor_radius=0.055,
        major_segments=96, minor_segments=8, location=(0, 0, 0), rotation=rotation)
    ring = bpy.context.object
    ring.parent = dome
    ring.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(Path('build/ad.blend').resolve()))
