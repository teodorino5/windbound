"""
Generate Solarpunk Flying Turbine (Airborne Wind Turbine / Aerostat)
High-fidelity stylized 3D model matching the concept art illustration.
"""

import bpy
import bmesh
import math
from mathutils import Vector, Matrix, Euler
import os
import shutil

OUTPUT_DIR = "/Users/matejsvanda/.gemini/antigravity/scratch/Windbound_Assets"
ARTIFACT_DIR = "/Users/matejsvanda/.gemini/antigravity/brain/66f22b8f-8a5a-47f1-9bd8-b205ddbd45dd"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(ARTIFACT_DIR, exist_ok=True)

# 1. Clean scene
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# Configure Render Settings: Cycles with 32 samples
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'

# Enable GPU if available
prefs = bpy.context.preferences
cprefs = prefs.addons['cycles'].preferences
for compute_dev_type in ('METAL', 'CUDA', 'OPTIX'):
    try:
        cprefs.compute_device_type = compute_dev_type
        for d in cprefs.devices:
            d.use = True
        break
    except:
        pass

# 2. Materials
def create_materials():
    mats = {}
    
    # 1. Inflatable Canvas Envelope with Ambient Occlusion for dark crevice seams
    mat_canvas = bpy.data.materials.new(name="Mat_InflatableCanvas")
    mat_canvas.use_nodes = True
    nodes = mat_canvas.node_tree.nodes
    links = mat_canvas.node_tree.links
    nodes.clear()
    
    node_out = nodes.new(type='ShaderNodeOutputMaterial')
    node_bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    node_ao = nodes.new(type='ShaderNodeAmbientOcclusion')
    node_mix = nodes.new(type='ShaderNodeMix')
    node_mix.data_type = 'RGBA'
    
    # AO node darkens the crevices between lobes like the concept art
    node_ao.inputs['Distance'].default_value = 0.8
    
    # Base canvas color: warm ivory white (0.95, 0.94, 0.89)
    # Seam crevice color: soft warm shadow (0.62, 0.60, 0.54)
    node_mix.inputs['Factor'].default_value = 1.0 # driven by AO
    node_mix.inputs[6].default_value = (0.58, 0.56, 0.50, 1.0) # Shadow color in creases
    node_mix.inputs[7].default_value = (0.95, 0.95, 0.90, 1.0) # Puffy canvas color
    
    links.new(node_ao.outputs['AO'], node_mix.inputs['Factor'])
    links.new(node_mix.outputs[2], node_bsdf.inputs['Base Color'])
    
    node_bsdf.inputs['Roughness'].default_value = 0.35
    if 'Subsurface Weight' in node_bsdf.inputs:
        node_bsdf.inputs['Subsurface Weight'].default_value = 0.15
        node_bsdf.inputs['Subsurface Radius'].default_value = (1.0, 0.85, 0.70)
    elif 'Subsurface' in node_bsdf.inputs:
        node_bsdf.inputs['Subsurface'].default_value = 0.15
        
    links.new(node_bsdf.outputs['BSDF'], node_out.inputs['Surface'])
    mats['canvas'] = mat_canvas

    # 2. Central Turbine Nacelle & Stators (Slate Titanium)
    mat_metal = bpy.data.materials.new(name="Mat_TurbineMetal")
    mat_metal.use_nodes = True
    bsdf = mat_metal.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.22, 0.28, 0.32, 1.0) # Deep slate teal titanium
        bsdf.inputs['Metallic'].default_value = 0.92
        bsdf.inputs['Roughness'].default_value = 0.18
    mats['metal'] = mat_metal

    # 3. Rotor Blades (Light titanium with solarpunk amber tip)
    mat_blade = bpy.data.materials.new(name="Mat_RotorBlade")
    mat_blade.use_nodes = True
    bsdf = mat_blade.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.85, 0.88, 0.90, 1.0)
        bsdf.inputs['Metallic'].default_value = 0.35
        bsdf.inputs['Roughness'].default_value = 0.22
    mats['blade'] = mat_blade

    # 4. Solarpunk Cyan Sensor Glow
    mat_glow = bpy.data.materials.new(name="Mat_SolarGlow")
    mat_glow.use_nodes = True
    bsdf = mat_glow.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.1, 0.85, 1.0, 1.0)
        if 'Emission Color' in bsdf.inputs:
            bsdf.inputs['Emission Color'].default_value = (0.1, 0.85, 1.0, 1.0)
            bsdf.inputs['Emission Strength'].default_value = 6.0
        elif 'Emission' in bsdf.inputs:
            bsdf.inputs['Emission'].default_value = (0.1, 0.85, 1.0, 1.0)
    mats['glow'] = mat_glow

    # 5. Tether Cable
    mat_cable = bpy.data.materials.new(name="Mat_TetherCable")
    mat_cable.use_nodes = True
    bsdf = mat_cable.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.92, 0.94, 0.95, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.45
    mats['cable'] = mat_cable

    return mats

materials = create_materials()

# 3. Build Full Inflatable Ducted Shroud
def build_shroud(mats):
    mesh = bpy.data.meshes.new("FlyingTurbine_Shroud")
    obj = bpy.data.objects.new("FlyingTurbine_Shroud", mesh)
    bpy.context.collection.objects.link(obj)
    
    bm = bmesh.new()
    
    # Dimensions:
    L = 5.2                # Length from intake (-Y) to exhaust (+Y)
    R_inner = 1.35         # Inner duct radius
    R_outer = 2.35         # Outer aerostat radius
    num_lobes = 7          # 7 prominent puffy longitudinal gas chambers (matches art)
    num_radial = 56        # Resolution around circumference
    num_profile = 36       # Points around the closed airfoil cross-section
    
    verts_grid = []
    
    for ip in range(num_profile):
        alpha = (ip / num_profile) * 2 * math.pi
        y = (L * 0.5) * math.cos(alpha)
        is_outer = (alpha > math.pi * 0.85 and alpha < math.pi * 2.0 - 0.15)
        
        t_chord = (y + L * 0.5) / L
        aerostat_camber = math.sin(t_chord * math.pi) ** 0.65
        outer_r_base = R_inner + 0.45 + (R_outer - R_inner - 0.45) * aerostat_camber
        
        if alpha <= math.pi:
            t_inner = math.sin(alpha)
            r_base = R_inner + 0.12 * ((y / (L*0.5)) ** 2)
            if alpha > math.pi * 0.8:
                w = (alpha - math.pi * 0.8) / (math.pi * 0.2)
                r_base = (1 - w) * r_base + w * ((R_inner + outer_r_base) * 0.5)
        else:
            if alpha < math.pi * 1.2:
                w = (alpha - math.pi) / (math.pi * 0.2)
                r_base = (1 - w) * ((R_inner + outer_r_base) * 0.5) + w * outer_r_base
            elif alpha > math.pi * 1.85:
                w = (alpha - math.pi * 1.85) / (math.pi * 0.15)
                r_base = (1 - w) * outer_r_base + w * (R_inner + 0.15)
            else:
                r_base = outer_r_base
                
        ring = []
        for ir in range(num_radial):
            theta = (ir / num_radial) * 2 * math.pi
            
            if is_outer:
                cos_val = math.cos(num_lobes * theta)
                puff_shape = math.copysign(abs(cos_val) ** 0.65, cos_val)
                lip_fade = math.sin(t_chord * math.pi) ** 0.4
                puff_amp = 0.26 * lip_fade
                
                ring_seam = math.cos(3.0 * math.pi * t_chord)
                seam_indent = -0.045 * (max(0, ring_seam) ** 6)
                
                r = r_base + (puff_shape * puff_amp) + seam_indent
            else:
                r = r_base
                
            x = r * math.cos(theta)
            z = r * math.sin(theta)
            ring.append(bm.verts.new((x, y, z)))
            
        verts_grid.append(ring)
        
    bm.verts.ensure_lookup_table()
    
    for ip in range(num_profile):
        next_ip = (ip + 1) % num_profile
        for ir in range(num_radial):
            next_ir = (ir + 1) % num_radial
            v1 = verts_grid[ip][ir]
            v2 = verts_grid[ip][next_ir]
            v3 = verts_grid[next_ip][next_ir]
            v4 = verts_grid[next_ip][ir]
            bm.faces.new((v1, v2, v3, v4))
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    
    obj.data.materials.append(mats['canvas'])
    for poly in obj.data.polygons: poly.use_smooth = True
    
    subsurf = obj.modifiers.new(name="Subdivision", type='SUBSURF')
    subsurf.levels = 1
    subsurf.render_levels = 2
    
    return obj

# 4. Build Stabilizer Fins (Dorsal Fin & Dual Ventral Fins)
def build_fin(name, length, height, thickness, rotation_euler, position, mats):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    
    bm = bmesh.new()
    num_h = 10
    num_c = 12
    
    verts_profile = []
    for ih in range(num_h):
        th = ih / (num_h - 1)
        h = th * height
        
        sweep = th * (length * 0.42)
        chord = length * (1.0 - 0.40 * th)
        thick = thickness * (1.0 - 0.45 * th)
        
        row = []
        for ic in range(num_c):
            tc = ic / (num_c - 1)
            y_loc = sweep + tc * chord - length * 0.5
            z_loc = h
            
            half_t = thick * 2.6 * (0.2969 * math.sqrt(max(0, tc)) - 0.126 * tc - 0.3516 * tc**2 + 0.2843 * tc**3 - 0.1015 * tc**4)
            half_t += 0.025 * math.sin(tc * math.pi) * (1.0 - th * 0.5)
            
            vl = bm.verts.new((-half_t, y_loc, z_loc))
            vr = bm.verts.new((half_t, y_loc, z_loc))
            row.append((vl, vr))
        verts_profile.append(row)
        
    bm.verts.ensure_lookup_table()
    
    for ih in range(num_h - 1):
        for ic in range(num_c - 1):
            vl1 = verts_profile[ih][ic][0]
            vl2 = verts_profile[ih][ic+1][0]
            vl3 = verts_profile[ih+1][ic+1][0]
            vl4 = verts_profile[ih+1][ic][0]
            bm.faces.new((vl1, vl4, vl3, vl2))
            
            vr1 = verts_profile[ih][ic][1]
            vr2 = verts_profile[ih][ic+1][1]
            vr3 = verts_profile[ih+1][ic+1][1]
            vr4 = verts_profile[ih+1][ic][1]
            bm.faces.new((vr1, vr2, vr3, vr4))
            
        bm.faces.new((verts_profile[ih][0][0], verts_profile[ih+1][0][0], verts_profile[ih+1][0][1], verts_profile[ih][0][1]))
        bm.faces.new((verts_profile[ih][-1][1], verts_profile[ih+1][-1][1], verts_profile[ih+1][-1][0], verts_profile[ih][-1][0]))
        
    for ic in range(num_c - 1):
        bm.faces.new((verts_profile[-1][ic][0], verts_profile[-1][ic+1][0], verts_profile[-1][ic+1][1], verts_profile[-1][ic][1]))
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    
    obj.data.materials.append(mats['canvas'])
    for poly in obj.data.polygons: poly.use_smooth = True
    subsurf = obj.modifiers.new(name="Subsurf", type='SUBSURF')
    subsurf.levels = 1
    
    obj.rotation_euler = rotation_euler
    obj.location = position
    
    return obj

# 5. Build Central Generator Core, Stators & Sensor Glow
def build_turbine_core(mats):
    mesh = bpy.data.meshes.new("Nacelle")
    nacelle = bpy.data.objects.new("Turbine_Nacelle", mesh)
    bpy.context.collection.objects.link(nacelle)
    
    bm = bmesh.new()
    num_rings = 22
    num_seg = 24
    length = 2.6
    r_max = 0.38
    
    rings = []
    for i in range(num_rings):
        t = i / (num_rings - 1)
        y = (t - 0.42) * length
        if t < 0.42:
            r = r_max * math.sqrt(max(0, 1.0 - ((0.42 - t) / 0.42) ** 2))
        else:
            r = r_max * (1.0 - 0.88 * ((t - 0.42) / 0.58) ** 1.3)
            
        ring = []
        for j in range(num_seg):
            theta = (j / num_seg) * 2 * math.pi
            x = r * math.cos(theta)
            z = r * math.sin(theta)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
        
    bm.verts.ensure_lookup_table()
    
    for i in range(num_rings - 1):
        for j in range(num_seg):
            nj = (j + 1) % num_seg
            bm.faces.new((rings[i][j], rings[i][nj], rings[i+1][nj], rings[i+1][j]))
            
    v_front = bm.verts.new((0, -0.42 * length, 0))
    v_rear = bm.verts.new((0, 0.58 * length, 0))
    for j in range(num_seg):
        nj = (j + 1) % num_seg
        bm.faces.new((v_front, rings[0][nj], rings[0][j]))
        bm.faces.new((v_rear, rings[-1][j], rings[-1][nj]))
        
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    
    nacelle.data.materials.append(mats['metal'])
    for p in nacelle.data.polygons: p.use_smooth = True
    
    for i in range(3):
        angle = i * (2 * math.pi / 3) + math.pi * 0.5
        s_mesh = bpy.data.meshes.new(f"Strut_{i}")
        s_obj = bpy.data.objects.new(f"Strut_{i}", s_mesh)
        bpy.context.collection.objects.link(s_obj)
        
        sbm = bmesh.new()
        bmesh.ops.create_cube(sbm, size=1.0)
        span = 1.02
        bmesh.ops.scale(sbm, vec=(0.045, 0.32, span * 0.5), verts=sbm.verts)
        bmesh.ops.translate(sbm, vec=(0, -0.05, span * 0.5 + 0.35), verts=sbm.verts)
        bmesh.ops.rotate(sbm, cent=(0,0,0), matrix=Matrix.Rotation(-angle, 3, 'Y'), verts=sbm.verts)
        sbm.to_mesh(s_mesh)
        sbm.free()
        
        s_obj.data.materials.append(mats['metal'])
        for p in s_obj.data.polygons: p.use_smooth = True
        s_obj.parent = nacelle
        
    ring_mesh = bpy.data.meshes.new("SensorRing")
    ring_obj = bpy.data.objects.new("SensorRing", ring_mesh)
    bpy.context.collection.objects.link(ring_obj)
    rbm = bmesh.new()
    bmesh.ops.create_circle(rbm, cap_ends=False, radius=r_max * 1.02, segments=32)
    res = bmesh.ops.extrude_edge_only(rbm, edges=rbm.edges)
    extruded_verts = [v for v in res['geom'] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(rbm, vec=(0, 0.09, 0), verts=extruded_verts)
    bmesh.ops.recalc_face_normals(rbm, faces=rbm.faces)
    rbm.to_mesh(ring_mesh)
    rbm.free()
    ring_obj.location = (0, -0.06, 0)
    ring_obj.data.materials.append(mats['glow'])
    ring_obj.parent = nacelle
    
    return nacelle

# 6. Build Wind Turbine Rotor (3 Twisted High-Aerodynamic Blades)
def build_turbine_rotor(mats):
    hub_mesh = bpy.data.meshes.new("RotorHub")
    hub = bpy.data.objects.new("Turbine_Rotor", hub_mesh)
    bpy.context.collection.objects.link(hub)
    
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=24, radius1=0.36, radius2=0.03, depth=0.60)
    bmesh.ops.rotate(bm, cent=(0,0,0), matrix=Matrix.Rotation(math.pi/2, 3, 'X'), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, -0.42, 0), verts=bm.verts)
    
    blade_length = 0.95
    for b_idx in range(3):
        blade_angle = b_idx * (2 * math.pi / 3) + math.radians(20)
        num_sec = 10
        blade_verts = []
        for isec in range(num_sec):
            t = isec / (num_sec - 1)
            span_r = 0.35 + t * blade_length
            chord = 0.24 * (1.0 - 0.40 * t)
            twist = math.radians(26.0 * (1.0 - 0.65 * t))
            thick = 0.045 * (1.0 - 0.45 * t)
            
            sec_verts = []
            for ic in range(6):
                tc = ic / 5.0
                xc = (tc - 0.3) * chord
                half_t = thick * math.sin(tc * math.pi)
                v_up = (xc, half_t, 0)
                v_dn = (xc, -half_t, 0)
                
                rot_twist = Matrix.Rotation(twist, 3, 'X')
                pos_up = rot_twist @ Vector(v_up) + Vector((0, -0.40, span_r))
                pos_dn = rot_twist @ Vector(v_dn) + Vector((0, -0.40, span_r))
                rot_hub = Matrix.Rotation(blade_angle, 3, 'Y')
                
                sec_verts.append((bm.verts.new(rot_hub @ pos_up), bm.verts.new(rot_hub @ pos_dn)))
            blade_verts.append(sec_verts)
            
        for isec in range(num_sec - 1):
            for ic in range(5):
                bm.faces.new((blade_verts[isec][ic][0], blade_verts[isec][ic+1][0], blade_verts[isec+1][ic+1][0], blade_verts[isec+1][ic][0]))
                bm.faces.new((blade_verts[isec][ic][1], blade_verts[isec+1][ic][1], blade_verts[isec+1][ic+1][1], blade_verts[isec][ic+1][1]))
            bm.faces.new((blade_verts[isec][0][0], blade_verts[isec+1][0][0], blade_verts[isec+1][0][1], blade_verts[isec][0][1]))
            bm.faces.new((blade_verts[isec][-1][1], blade_verts[isec+1][-1][1], blade_verts[isec+1][-1][0], blade_verts[isec][-1][0]))
        for ic in range(5):
            bm.faces.new((blade_verts[-1][ic][0], blade_verts[-1][ic+1][0], blade_verts[-1][ic+1][1], blade_verts[-1][ic][1]))
            
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(hub_mesh)
    bm.free()
    
    hub.data.materials.append(mats['blade'])
    for p in hub.data.polygons: p.use_smooth = True
    
    return hub

# 7. Build Tether Rigging & Cable
def build_tether(mats):
    curve_data = bpy.data.curves.new('TetherCurve', type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.bevel_depth = 0.035
    curve_data.bevel_resolution = 4
    
    polyline = curve_data.splines.new('POLY')
    pts = [
        Vector((-0.6, -1.0, -2.1)),
        Vector((0.0, -1.5, -2.5)),
        Vector((0.6, -1.0, -2.1)),
        Vector((0.0, -1.5, -2.5)),
        Vector((0.0, -4.5, -6.5)),
        Vector((-1.5, -12.0, -18.0)),
        Vector((-3.5, -24.0, -36.0)),
    ]
    polyline.points.add(len(pts) - 1)
    for idx, p in enumerate(pts):
        polyline.points[idx].co = (p.x, p.y, p.z, 1.0)
        
    tether_obj = bpy.data.objects.new('TetherCable', curve_data)
    bpy.context.collection.objects.link(tether_obj)
    tether_obj.data.materials.append(mats['cable'])
    
    return tether_obj

# Instantiate Models
shroud = build_shroud(materials)
fin_dorsal = build_fin("Fin_Dorsal", length=2.4, height=1.65, thickness=0.22,
                       rotation_euler=(0, 0, 0), position=(0, 1.25, 2.30), mats=materials)
r_fin = 2.20
y_fin = 1.25
ang_vL = math.radians(-130)
pos_vL = (r_fin * math.cos(ang_vL), y_fin, r_fin * math.sin(ang_vL))
rot_vL = (0, 0, math.radians(140))
fin_ventral_L = build_fin("Fin_Ventral_L", length=2.0, height=1.35, thickness=0.18,
                          rotation_euler=rot_vL, position=pos_vL, mats=materials)

ang_vR = math.radians(-50)
pos_vR = (r_fin * math.cos(ang_vR), y_fin, r_fin * math.sin(ang_vR))
rot_vR = (0, 0, math.radians(-140))
fin_ventral_R = build_fin("Fin_Ventral_R", length=2.0, height=1.35, thickness=0.18,
                          rotation_euler=rot_vR, position=pos_vR, mats=materials)

nacelle = build_turbine_core(materials)
rotor = build_turbine_rotor(materials)
tether = build_tether(materials)

fin_dorsal.parent = shroud
fin_ventral_L.parent = shroud
fin_ventral_R.parent = shroud
nacelle.parent = shroud
rotor.parent = nacelle
tether.parent = shroud

# Lighting & Sky
world = bpy.data.worlds.new("SolarpunkSky")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs['Color'].default_value = (0.48, 0.72, 0.95, 1.0)
    bg.inputs['Strength'].default_value = 1.35

sun_data = bpy.data.lights.new(name="Sunspire_Sun", type='SUN')
sun_data.energy = 5.5
sun_data.color = (1.0, 0.97, 0.90)
sun_obj = bpy.data.objects.new("Sunspire_Sun", sun_data)
bpy.context.collection.objects.link(sun_obj)
sun_obj.rotation_euler = (math.radians(52), math.radians(24), math.radians(-42))

fill_data = bpy.data.lights.new(name="Meadow_Bounce", type='SUN')
fill_data.energy = 2.0
fill_data.color = (0.75, 0.90, 0.82)
fill_obj = bpy.data.objects.new("Meadow_Bounce", fill_data)
bpy.context.collection.objects.link(fill_obj)
fill_obj.rotation_euler = (math.radians(-60), 0, math.radians(140))

rim_data = bpy.data.lights.new(name="Rim_Light", type='SUN')
rim_data.energy = 2.8
rim_data.color = (0.9, 0.95, 1.0)
rim_obj = bpy.data.objects.new("Rim_Light", rim_data)
bpy.context.collection.objects.link(rim_obj)
rim_obj.rotation_euler = (math.radians(15), math.radians(-75), math.radians(35))

cam_data = bpy.data.cameras.new("MainCamera")
cam_data.lens = 52
cam_obj = bpy.data.objects.new("MainCamera", cam_data)
bpy.context.collection.objects.link(cam_obj)
scene.camera = cam_obj

cameras = {
    "hero": {
        "pos": (-10.5, -12.2, 5.8),
        "rot": (math.radians(68), 0, math.radians(-42)),
        "file": "flying_turbine_preview_hero.png"
    },
    "intake": {
        "pos": (0.0, -13.5, 0.0),
        "rot": (math.radians(90), 0, 0),
        "file": "flying_turbine_preview_intake.png"
    },
    "side": {
        "pos": (-14.8, 0.0, 0.8),
        "rot": (math.radians(87), 0, math.radians(-90)),
        "file": "flying_turbine_preview_side.png"
    },
    "quarter_rear": {
        "pos": (-10.2, 12.8, 5.4),
        "rot": (math.radians(68), 0, math.radians(-142)),
        "file": "flying_turbine_preview_rear.png"
    }
}

for view_name, cfg in cameras.items():
    cam_obj.location = cfg["pos"]
    cam_obj.rotation_euler = cfg["rot"]
    out_path = os.path.join(ARTIFACT_DIR, cfg["file"])
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    copy_path = os.path.join(OUTPUT_DIR, cfg["file"])
    shutil.copyfile(out_path, copy_path)

blend_path = os.path.join(OUTPUT_DIR, "FlyingTurbine.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

fbx_path = os.path.join(OUTPUT_DIR, "FlyingTurbine.fbx")
bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=False, global_scale=1.0)
