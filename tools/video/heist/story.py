"""Deterministic character blocking and camera animation for the heist trailer."""
import math
import bpy
from mathutils import Vector

PI = math.pi

def lerp(a, b, p):
    p = max(0, min(1, p))
    return Vector(a).lerp(Vector(b), p)

def face(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat('-Z', 'Y').to_euler()

def pose(name, position, yaw, t, run=False, carry=False, cheer=False, crouch=False):
    root = bpy.data.objects[name]
    root.location = position
    root.rotation_euler.z = yaw
    cycle = math.sin(t * (19 if run else 7))
    root.location.z += abs(cycle) * (0.16 if run else 0.015)
    if crouch:
        root.location.z -= 0.2
    for side, sign in [('L', 1), ('R', -1)]:
        bpy.data.objects[name + '_Leg' + side].rotation_euler.x = cycle * sign * (0.7 if run else 0.06)
        arm = bpy.data.objects[name + '_Arm' + side]
        arm.rotation_euler = (0, 0, 0)
        if carry:
            arm.rotation_euler.x = -1.18
        elif cheer:
            arm.rotation_euler.y = sign * (2.3 + cycle * 0.12)
        else:
            arm.rotation_euler.x = -cycle * sign * (0.65 if run else 0.08)
    if name == 'Owner':
        bpy.data.objects[name + '_ArmR'].rotation_euler.x = -0.65 + (cycle * 0.5 if run else 0)

def held(root, z=2.0):
    p = root.location.copy()
    yaw = root.rotation_euler.z
    return p + Vector((math.sin(yaw) * 1.02, -math.cos(yaw) * 1.02, z))

def update(t):
    hero, owner, friend, loot = (bpy.data.objects[n] for n in ['Hero', 'Owner', 'Friend', 'Loot'])
    cam = bpy.context.scene.camera
    pose('Hero', (-12, -3, 0), PI, t, crouch=True)
    pose('Owner', (-15, 6, 0), PI, t)
    pose('Friend', (17.4, 8, 0), 0, t)
    loot.location = (-12, 6, 1.05)
    loot.rotation_euler.z = 0
    cam.data.lens = 30
    if t < 2.2:
        p = t / 2.2
        pose('Hero', lerp((0, -3, 0), (5, -3, 0), p), PI/2, t, run=True, carry=True)
        pose('Owner', hero.location - Vector((3.8, 0, 0)), PI/2, t, run=True)
        loot.location = held(hero)
        loot.rotation_euler.z = PI/2
        cam.location = hero.location + Vector((4.8, -7.8, 3.4))
        face(cam, hero.location + Vector((0, 0, 1.9)))
    elif t < 4.5:
        p = (t - 2.2)/2.3
        pose('Hero', (-14.4, -1.2, 0), PI, t, crouch=True)
        cam.location = lerp((-3, -6, 12), (-5, -4, 10), p)
        cam.data.lens = 27
        face(cam, (-12, 4.2, 1.2))
    elif t < 7.7:
        p = (t - 4.5)/3.2
        pos = lerp((-12, -1, 0), (-12, 4.8, 0), min(1, p * 1.4))
        pose('Hero', pos, PI, t, run=p < 0.67, carry=p > 0.65)
        if p > 0.7:
            loot.location = lerp((-12, 6, 1.05), held(hero), (p - 0.7)/0.2)
            loot.rotation_euler.z = PI
        cam.location = lerp((-7.5, 0, 4.6), (-8.8, 1.7, 3.5), p)
        face(cam, (-12, 5.2, 2.0))
    elif t < 9.8:
        p = (t - 7.7)/2.1
        pose('Hero', lerp((-12, 4.8, 0), (-12, -3, 0), p), 0, t, run=True, carry=True)
        pose('Owner', (-15, 6, 0), 0, t)
        bpy.data.objects['Owner_ArmR'].rotation_euler.x = -1.8
        loot.location = held(hero)
        cam.location = lerp((-12.5, 0.2, 3.9), (-13, 1.3, 3.7), p)
        cam.data.lens = 32
        face(cam, (-15, 6, 2.25))
    elif t < 13.8:
        p = (t - 9.8)/4
        pos = lerp((-12, -3, 0), (14, -3, 0), p)
        jump = max(0, math.sin((p - 0.32)/0.22 * PI)) if 0.32 < p < 0.54 else 0
        pos.z += jump * 1.6
        pose('Hero', pos, PI/2, t, run=True, carry=True)
        pose('Owner', pos - Vector((4, 0, pos.z)), PI/2, t, run=True)
        loot.location = held(hero)
        loot.rotation_euler.z = PI/2
        cam.location = hero.location + Vector((3.2, -10, 3.9 - pos.z*0.6))
        cam.location.z += math.sin(t * 30) * 0.04
        cam.data.lens = 27
        face(cam, hero.location + Vector((-0.6, 0, 1.6)))
    elif t < 16.3:
        p = (t - 13.8)/2.5
        pos = lerp((14, -3, 0), (14, 4.6, 0), min(1, p*1.4))
        pose('Hero', pos, PI if p < 0.75 else 0, t, run=p < 0.65, carry=p < 0.76, cheer=p >= 0.76)
        pose('Owner', (10, -3, 0), PI/2, t)
        loot.location = held(hero) if p < 0.76 else Vector((14, 6, 1.05))
        cam.location = lerp((21, -5, 7), (19, -2, 5.8), p)
        face(cam, (14, 4, 1.8))
    elif t < 18.6:
        p = (t - 16.3)/2.3
        pose('Hero', (14, 4.1, 0), 0, t, cheer=True)
        if p < 0.38:
            pos = lerp((17.4, 8, 0), (14.8, 6.6, 0), p/0.38)
        else:
            pos = lerp((14.8, 6.6, 0), (17.7, -1, 0), (p-0.38)/0.62)
        pose('Friend', pos, 0, t, run=p > 0.38, carry=p > 0.38)
        pose('Owner', (10, -3, 0), PI/2, t)
        loot.location = held(friend) if p > 0.38 else Vector((14, 6, 1.05))
        cam.location = lerp((20, -3, 5), (19.2, -1.8, 4.5), p)
        face(cam, (15.1, 4.8, 2.0))
    else:
        p = (t - 18.6)/3.4
        pose('Hero', (14, 4.1, 0), 0, t)
        bpy.data.objects['Hero_ArmL'].rotation_euler.y = 0.65
        bpy.data.objects['Hero_ArmR'].rotation_euler.y = -0.65
        pose('Friend', lerp((17.7, -1, 0), (24, -3, 0), p), PI/2, t, run=True, carry=True)
        pose('Owner', (10, -3, 0), PI/2, t)
        loot.location = held(friend)
        cam.location = lerp((20, -6, 6), (21, -8, 7), p)
        face(cam, (14, 4, 1.9))
    # Dim red warning strips pulse only during the alarm and pursuit.
    alarm = bpy.data.materials.get('Alarm')
    if alarm:
        node = alarm.node_tree.nodes.get('Principled BSDF')
        node.inputs['Emission Strength'].default_value = (2 + 3 * max(0, math.sin(t*16))) if 7.7 <= t < 13.8 else 0.3

def handler(scene, *args):
    update((scene.frame_current - 1) / scene.render.fps)

def register():
    bpy.app.handlers.frame_change_pre.clear()
    bpy.app.handlers.frame_change_pre.append(handler)
    update((bpy.context.scene.frame_current - 1) / 30)
