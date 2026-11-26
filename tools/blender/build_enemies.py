"""Enemy archetypes rendered in 16 directions; one sheet per animation."""
import math
import common as C  # noqa: E402  (imports bpy, which provides mathutils)
from mathutils import Vector

DIRS = 16


def _leg_chain(M, parent, hip, out_sign, femur, tibia, r0, r1, mat_leg, mat_tip=None):
    """Insect leg built inside a root empty so it can be swung (Z) and lifted (X)."""
    root = C.empty("leg", hip, parent)
    k = Vector((0, femur[0] * out_sign, femur[1]))
    f = Vector((0, tibia[0] * out_sign, tibia[1]))
    C.tube_between((0, 0, 0), k, r0, mat_leg, root, r2=r0 * 0.8)
    C.sphere(r0 * 1.1, k, mat_leg, root, segs=10)
    C.tube_between(k, f, r0 * 0.8, mat_tip or mat_leg, root, r2=r1)
    return root


# =================================================================== MITE

def mite(M):
    root = C.empty("mite")
    body = C.empty("body", (0, 0, 0.3), root)
    car = M["carapace"]
    C.sphere(0.17, (0, 0, 0), car, body, scale=(1.25, 1.0, 0.8), subsurf=1)
    C.sphere(0.24, (-0.33, 0, 0.07), car, body, scale=(1.45, 1.1, 0.9), subsurf=1, displace=0.02)
    for i, x in enumerate((-0.18, -0.3, -0.43)):
        C.sphere(0.2 - i * 0.03, (x, 0, 0.17 - i * 0.01), M["plate"], body, scale=(0.6, 1.1, 0.45))
    for x, y in ((-0.25, 0.14), (-0.38, 0.17), (-0.47, 0.1), (-0.25, -0.14), (-0.38, -0.17), (-0.47, -0.1)):
        C.sphere(0.035, (x, y, 0.1), M["bio"], body, segs=8)
    for x in (-0.12, -0.26, -0.4):
        C.cyl(0.035, 0.16, (x, 0, 0.26), M["bone"], body, r2=0.0, verts=8, rot=(0, -0.35, 0))
    head = C.empty("head", (0.24, 0, 0.0), body)
    C.sphere(0.12, (0.0, 0, 0), car, head, scale=(1.25, 1.05, 0.85))
    for s in (-1, 1):
        C.sphere(0.03, (0.1, 0.06 * s, 0.05), M["eye"], head, segs=8)
        C.sphere(0.022, (0.07, 0.09 * s, 0.07), M["eye"], head, segs=8)
        C.tube_between((0.1, 0.06 * s, -0.03), (0.24, 0.02 * s, -0.07), 0.025, M["bone"], head, r2=0.004)
    legs = []
    for i, x in enumerate((0.1, -0.02, -0.14)):
        for s in (-1, 1):
            base_yaw = (0.55 - i * 0.55) * s
            lg = _leg_chain(M, body, (x, 0.1 * s, -0.02), s, (0.2, 0.14), (0.36, -0.3), 0.028, 0.008, car,
                            M["plate"])
            lg["base_yaw"] = base_yaw
            lg["group"] = (i + (0 if s > 0 else 1)) % 2
            legs.append(lg)
    return root, {"body": body, "head": head, "legs": legs}


def mite_run(R, t):
    p = t * 2 * math.pi
    for lg in R["legs"]:
        q = p + (math.pi if lg["group"] else 0)
        lg.rotation_euler = (0.32 * max(0, math.cos(q)) * (1 if lg.location.y > 0 else -1) * -1, 0,
                             lg["base_yaw"] + 0.38 * math.sin(q))
    R["body"].location.z = 0.3 + 0.025 * math.cos(2 * p)
    R["body"].rotation_euler = (0.06 * math.sin(p), 0, 0)


def mite_lunge(R, t):
    # 0-0.45 rear up (telegraph), 0.45-0.7 strike, 0.7-1 recover
    if t < 0.45:
        k = t / 0.45
        pitch, fwd, rise = -0.55 * k, -0.06 * k, 0.12 * k
    elif t < 0.7:
        k = (t - 0.45) / 0.25
        pitch, fwd, rise = -0.55 + 0.85 * k, -0.06 + 0.3 * k, 0.12 - 0.14 * k
    else:
        k = (t - 0.7) / 0.3
        pitch, fwd, rise = 0.3 * (1 - k), 0.24 * (1 - k), -0.02 * (1 - k)
    R["body"].rotation_euler = (0, pitch, 0)
    R["body"].location = (fwd, 0, 0.3 + rise)
    for lg in R["legs"]:
        front = lg.location.x > 0.05
        lift = (-pitch * 1.4 if front else 0.0) * (1 if lg.location.y > 0 else -1) * -1
        lg.rotation_euler = (lift, 0, lg["base_yaw"])


# =================================================================== SPITTER

def spitter(M):
    root = C.empty("spitter")
    body = C.empty("body", (0, 0, 0.62), root)
    C.sphere(0.26, (0, 0, 0), M["chitin"], body, scale=(1.3, 1.05, 0.75), subsurf=1, displace=0.015)
    sac = C.empty("sac", (-0.22, 0, 0.28), body)
    C.sphere(0.3, (0, 0, 0), M["acid"], sac, scale=(1.1, 1.0, 1.05), subsurf=1, displace=0.03)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        C.tube_between((0.0, 0, -0.28), (0.25 * math.cos(ang), 0.25 * math.sin(ang), 0.12), 0.018, M["chitin"],
                       sac, r2=0.01)
    neck = C.empty("neck", (0.25, 0, 0.08), body)
    C.tube_between((0, 0, 0), (0.18, 0, 0.3), 0.07, M["chitin"], neck, r2=0.05)
    head = C.empty("head", (0.2, 0, 0.34), neck)
    C.sphere(0.1, (0, 0, 0), M["chitin"], head, scale=(1.4, 0.9, 0.8))
    C.cyl(0.065, 0.16, (0.15, 0, -0.02), M["chitin"], head, r2=0.04, rot=(0, math.pi / 2, 0), verts=12)
    C.sphere(0.045, (0.23, 0, -0.02), M["acid"], head, segs=10)
    for s in (-1, 1):
        C.sphere(0.025, (0.06, 0.07 * s, 0.05), M["eye_g"], head, segs=8)
    legs = []
    for i, (x, yaw) in enumerate(((0.12, 0.6), (-0.12, -0.6))):
        for s in (-1, 1):
            lg = _leg_chain(M, body, (x, 0.18 * s, 0.0), s, (0.36, 0.26), (0.5, -0.62), 0.05, 0.015,
                            M["chitin"], M["chitin"])
            lg["base_yaw"] = yaw * s
            lg["group"] = (i + (0 if s > 0 else 1)) % 2
            legs.append(lg)
    return root, {"body": body, "sac": sac, "neck": neck, "head": head, "legs": legs}


def spitter_walk(R, t):
    p = t * 2 * math.pi
    for lg in R["legs"]:
        q = p + (math.pi if lg["group"] else 0)
        lg.rotation_euler = (-0.22 * max(0, math.cos(q)) * (1 if lg.location.y > 0 else -1), 0,
                             lg["base_yaw"] + 0.3 * math.sin(q))
    R["body"].location.z = 0.62 + 0.03 * math.cos(2 * p)
    R["sac"].scale = (1, 1, 1 + 0.04 * math.sin(2 * p))
    R["neck"].rotation_euler = (0, 0.08 * math.sin(p), 0)


def spitter_spit(R, t):
    # inflate 0-0.55 (neck rears back), fire at 0.6, recover
    if t < 0.55:
        k = t / 0.55
        sac, neck = 1 + 0.3 * k, 0.5 * k
    elif t < 0.72:
        k = (t - 0.55) / 0.17
        sac, neck = 1.3 - 0.45 * k, 0.5 - 0.95 * k
    else:
        k = (t - 0.72) / 0.28
        sac, neck = 0.85 + 0.15 * k, -0.45 * (1 - k)
    R["sac"].scale = (sac, sac, sac)
    R["neck"].rotation_euler = (0, neck, 0)
    for lg in R["legs"]:
        lg.rotation_euler = (0, 0, lg["base_yaw"])
    R["body"].location.z = 0.62


# =================================================================== BRUTE

def brute(M):
    root = C.empty("brute")
    body = C.empty("body", (0, 0, 1.15), root)
    C.sphere(0.55, (0, 0, 0), M["flesh"], body, scale=(1.05, 1.2, 0.95), subsurf=1, displace=0.04)
    # bone armour on the front / shoulders
    # curved chest shield (frontal armour - the brute shrugs off shots from the front)
    C.sphere(1.0, (0.5, 0, 0.02), M["armor"], body, scale=(0.2, 0.62, 0.5), rot=(0, -0.3, 0), subsurf=1,
             displace=0.02)
    C.sphere(1.0, (0.58, 0, -0.08), M["horn"], body, scale=(0.1, 0.4, 0.3), rot=(0, -0.3, 0))
    # beetle carapace shell + dorsal spikes
    C.sphere(1.0, (-0.08, 0, 0.3), M["armor"], body, scale=(0.62, 0.72, 0.42), subsurf=1, displace=0.035,
             disp_scale=0.7)
    for i in range(4):
        C.cyl(0.07, 0.36, (0.25 - i * 0.2, 0, 0.84 - abs(i - 1.2) * 0.06), M["bone"], body, r2=0.0, verts=8,
              rot=(0, -0.5 + i * 0.25, 0))
    for s in (-1, 1):
        C.cyl(0.07, 0.38, (0.25, 0.55 * s, 0.5), M["horn"], body, r2=0.0, rot=(0.6 * s, -0.5, 0), verts=10)
    # glowing weak points on the back
    for (x, y, z, r) in ((-0.6, 0.2, 0.1, 0.11), (-0.64, -0.16, 0.0, 0.13), (-0.55, 0.0, 0.28, 0.1),
                         (-0.58, 0.05, -0.15, 0.09)):
        C.sphere(r, (x, y, z), M["core"], body, segs=14)
    head = C.empty("head", (0.6, 0, -0.08), body)
    C.sphere(0.2, (0, 0, 0), M["flesh"], head, scale=(1.2, 1.0, 0.85))
    C.sphere(0.22, (0.05, 0, 0.08), M["armor"], head, scale=(1.1, 1.05, 0.55))
    for s in (-1, 1):
        C.sphere(0.035, (0.2, 0.08 * s, -0.02), M["eye_o"], head, segs=8)
        C.tube_between((0.18, 0.1 * s, -0.1), (0.32, 0.14 * s, -0.22), 0.03, M["horn"], head, r2=0.005)
    arms = []
    for s in (-1, 1):
        sh = C.empty("shoulder", (0.18, 0.62 * s, 0.3), body)
        C.sphere(0.24, (0, 0, 0.06), M["armor"], sh, scale=(1.25, 1.0, 0.55))
        C.tube_between((0, 0, 0), (0.18, 0.1 * s, -0.55), 0.16, M["flesh"], sh, r2=0.13)
        el = C.empty("elbow", (0.18, 0.1 * s, -0.55), sh)
        C.tube_between((0, 0, 0), (0.22, 0, -0.62), 0.13, M["flesh"], el, r2=0.17)
        C.sphere(1.0, (0.12, 0.05 * s, -0.3), M["armor"], el, scale=(0.18, 0.16, 0.34))
        fist = C.empty("fist", (0.22, 0, -0.62), el)
        C.sphere(0.2, (0.05, 0, -0.05), M["flesh"], fist, scale=(1.2, 1.0, 0.8))
        for c in (-1, 0, 1):
            C.tube_between((0.12, 0.08 * c, -0.05), (0.38, 0.1 * c, -0.18), 0.04, M["horn"], fist, r2=0.005)
        arms.append((sh, el, s))
    legs = []
    for s in (-1, 1):
        hp = C.empty("hip", (-0.3, 0.3 * s, -0.4), body)
        C.tube_between((0, 0, 0), (0.15, 0.05 * s, -0.4), 0.17, M["flesh"], hp, r2=0.14)
        kn = C.empty("knee", (0.15, 0.05 * s, -0.4), hp)
        C.tube_between((0, 0, 0), (-0.15, 0, -0.35), 0.13, M["flesh"], kn, r2=0.11)
        C.sphere(1.0, (0.0, 0, -0.38), M["armor"], kn, scale=(0.3, 0.16, 0.1))
        legs.append((hp, kn, s))
    return root, {"body": body, "head": head, "arms": arms, "legs": legs}


def brute_walk(R, t):
    p = t * 2 * math.pi
    for sh, el, s in R["arms"]:
        q = p + (0 if s > 0 else math.pi)
        sh.rotation_euler = (0.1 * s, -0.45 * math.sin(q) - 0.1, 0)
        el.rotation_euler = (0, -0.2 + 0.25 * max(0, math.cos(q)), 0)
    for hp, kn, s in R["legs"]:
        q = p + (math.pi if s > 0 else 0)
        hp.rotation_euler = (0, -0.4 * math.sin(q), 0)
        kn.rotation_euler = (0, 0.4 * max(0, math.cos(q)), 0)
    R["body"].location.z = 1.15 + 0.05 * math.cos(2 * p)
    R["body"].rotation_euler = (0.06 * math.sin(p), 0.18, 0.05 * math.sin(p))


def brute_slam(R, t):
    # wind up 0-0.5 (arms overhead), slam 0.5-0.65, recover
    if t < 0.5:
        k = math.sin(t / 0.5 * math.pi / 2)
        arm, elb, lean, z = -2.5 * k, -0.6 * k, 0.18 - 0.5 * k, 1.15 + 0.12 * k
    elif t < 0.65:
        k = (t - 0.5) / 0.15
        arm, elb, lean, z = -2.5 + 2.2 * k, -0.6 + 0.4 * k, -0.32 + 0.8 * k, 1.27 - 0.32 * k
    else:
        k = (t - 0.65) / 0.35
        arm, elb, lean, z = -0.3 + 0.2 * k, -0.2, 0.48 - 0.3 * k, 0.95 + 0.2 * k
    for sh, el, s in R["arms"]:
        sh.rotation_euler = (0.1 * s, arm, 0)
        el.rotation_euler = (0, elb, 0)
    for hp, kn, s in R["legs"]:
        hp.rotation_euler = (0, -0.2 * lean, 0)
        kn.rotation_euler = (0, 0.25, 0)
    R["body"].rotation_euler = (0, lean, 0)
    R["body"].location.z = z


# =================================================================== BLOATER

def bloater(M):
    root = C.empty("bloater")
    body = C.empty("body", (0, 0, 0.72), root)
    sac = C.empty("sac", (0, 0, 0), body)
    C.sphere(0.5, (0, 0, 0), M["bloat"], sac, scale=(1.0, 0.95, 0.92), subsurf=1, displace=0.12, disp_scale=0.5)
    for a in range(7):
        ang = a * 2 * math.pi / 7
        C.sphere(0.09, (0.42 * math.cos(ang), 0.42 * math.sin(ang), 0.15 + 0.1 * math.sin(a)), M["pustule"],
                 sac, segs=10)
    C.sphere(0.32, (0.0, 0, -0.3), M["flesh2"], body, scale=(1.2, 1.1, 0.6))
    head = C.empty("head", (0.42, 0, -0.18), body)
    C.sphere(0.13, (0, 0, 0), M["flesh2"], head, scale=(1.2, 1.0, 0.8))
    for s in (-1, 1):
        C.sphere(0.025, (0.11, 0.05 * s, 0.03), M["eye_g"], head, segs=8)
    legs = []
    for i, x in enumerate((0.2, -0.2)):
        for s in (-1, 1):
            lg = _leg_chain(M, body, (x, 0.25 * s, -0.35), s, (0.18, 0.05), (0.3, -0.38), 0.06, 0.03,
                            M["flesh2"], M["bone"])
            lg["base_yaw"] = (0.4 if x > 0 else -0.4) * s
            lg["group"] = (i + (0 if s > 0 else 1)) % 2
            legs.append(lg)
    return root, {"body": body, "sac": sac, "head": head, "legs": legs}


def bloater_walk(R, t):
    p = t * 2 * math.pi
    for lg in R["legs"]:
        q = p + (math.pi if lg["group"] else 0)
        lg.rotation_euler = (-0.25 * max(0, math.cos(q)) * (1 if lg.location.y > 0 else -1), 0,
                             lg["base_yaw"] + 0.35 * math.sin(q))
    pulse = 1 + 0.06 * math.sin(2 * p)
    R["sac"].scale = (pulse, pulse, 1 + 0.08 * math.sin(2 * p + 1))
    R["body"].location.z = 0.72 + 0.03 * math.cos(2 * p)
    R["body"].rotation_euler = (0.1 * math.sin(p), 0, 0)


def bloater_prime(R, t):
    p = t * 2 * math.pi * 3
    pulse = 1.1 + 0.14 * math.sin(p)
    R["sac"].scale = (pulse, pulse, pulse * 1.05)
    for lg in R["legs"]:
        lg.rotation_euler = (0, 0, lg["base_yaw"])
    R["body"].location.z = 0.7


# =================================================================== driver

def materials():
    return {
        "carapace": C.mat("e_carapace", (0.42, 0.04, 0.08), metal=0.1, rough=0.38, coat=0.3, noise=0.5,
                          noise_scale=10, noise_color=(0.18, 0.02, 0.08), subsurface=0.1),
        "plate": C.mat("e_plate", (0.2, 0.03, 0.06), metal=0.2, rough=0.25, coat=0.6),
        "bio": C.mat("e_bio", (0.1, 0.5, 0.9), emit=(0.2, 0.75, 1.0), emit_strength=8),
        "eye": C.mat("e_eye", (0.2, 0.8, 1.0), emit=(0.4, 0.95, 1.0), emit_strength=9),
        "bone": C.mat("e_bone", (0.75, 0.68, 0.58), rough=0.4, noise=0.3, noise_scale=20),
        "chitin": C.mat("e_chitin", (0.13, 0.08, 0.2), metal=0.15, rough=0.3, coat=0.5, noise=0.45,
                        noise_scale=12, noise_color=(0.05, 0.12, 0.08)),
        "acid": C.mat("e_acid", (0.16, 0.42, 0.05), rough=0.15, subsurface=0.15, emit=(0.45, 1.0, 0.15),
                      emit_strength=3.0, noise=0.8, noise_scale=7, noise_color=(0.03, 0.1, 0.02), bump=0.4),
        "eye_g": C.mat("e_eye_g", (0.5, 1.0, 0.2), emit=(0.6, 1.0, 0.2), emit_strength=9),
        "flesh": C.mat("e_flesh", (0.32, 0.08, 0.07), rough=0.5, subsurface=0.08, noise=0.5, noise_scale=7,
                       noise_color=(0.08, 0.03, 0.06), bump=0.5),
        "armor": C.mat("e_armor", (0.075, 0.07, 0.09), metal=0.45, rough=0.3, coat=0.6, noise=0.7, noise_scale=11,
                       noise_color=(0.2, 0.06, 0.05), bump=0.7),
        "horn": C.mat("e_horn", (0.12, 0.1, 0.1), metal=0.3, rough=0.3),
        "core": C.mat("e_core", (1.0, 0.4, 0.05), emit=(1.0, 0.45, 0.06), emit_strength=8),
        "eye_o": C.mat("e_eye_o", (1.0, 0.5, 0.1), emit=(1.0, 0.55, 0.1), emit_strength=10),
        "bloat": C.mat("e_bloat", (0.45, 0.48, 0.1), rough=0.22, subsurface=0.2, emit=(0.9, 0.85, 0.15),
                       emit_strength=2.0, noise=0.9, noise_scale=6, noise_color=(0.16, 0.06, 0.03), bump=0.5),
        "pustule": C.mat("e_pustule", (1.0, 0.7, 0.1), emit=(1.0, 0.75, 0.15), emit_strength=8),
        "flesh2": C.mat("e_flesh2", (0.3, 0.2, 0.12), rough=0.55, noise=0.4, noise_scale=8, bump=0.4),
    }


ENEMIES = {
    # name: (builder, frame (w,h,origin), {anim: (frames, pose_fn)})
    "mite": (mite, (128, 128, (64, 84)), {"run": (8, mite_run), "attack": (6, mite_lunge)}),
    "spitter": (spitter, (176, 176, (88, 128)), {"walk": (8, spitter_walk), "attack": (6, spitter_spit)}),
    "brute": (brute, (256, 320, (128, 236)), {"walk": (8, brute_walk), "attack": (7, brute_slam)}),
    "bloater": (bloater, (176, 176, (88, 130)), {"walk": (8, bloater_walk), "attack": (4, bloater_prime)}),
}


def render_enemy(name):
    build, (fw, fh, org), anims = ENEMIES[name]
    for anim, (nf, pose) in anims.items():
        C.reset_scene()
        C.setup_lights()
        M = materials()
        root, R = build(M)
        C.setup_camera(fw, fh, org)
        sw = C.SheetWriter("enemies", "%s_%s" % (name, anim), fw, fh, org, DIRS, nf,
                           meta={"dirs": DIRS, "frames": nf, "anim": anim})
        for d in range(DIRS):
            phi = d * 2 * math.pi / DIRS
            root.rotation_euler = (0, 0, C.yaw_for_ground_angle(phi))
            for f in range(nf):
                pose(R, f / nf)
                sw.put(d, f, C.render_passes())
        sw.save()


if __name__ == "__main__":
    import sys
    what = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(ENEMIES.keys())
    for n in what:
        render_enemy(n)
