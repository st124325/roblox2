import bpy
import sys
import time
scene = bpy.context.scene
engine = sys.argv[-1]
scene.frame_set(30)
if engine == 'WORKBENCH':
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = 'BOTH'
    scene.display.shading.background_type = 'WORLD'
    for mat in bpy.data.materials:
        if mat.use_nodes:
            node = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if node:
                mat.diffuse_color = node.inputs['Base Color'].default_value
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = f'//diagnostics/{engine.lower()}.png'
t = time.monotonic()
bpy.ops.render.render(write_still=True)
print('RENDER_SECONDS', time.monotonic() - t, flush=True)
