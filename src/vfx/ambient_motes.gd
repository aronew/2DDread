class_name AmbientMotes
extends GPUParticles2D
## Life in the air: embers and dust motes drifting slowly up through the light, spawned
## in a box around the camera (world coordinates, so they stay put as the camera moves
## and the view always has some). Faint and additive, so they never compete with the
## fight. Scaled by the graphics preset's particle setting.

const AREA := Vector2(2600, 1600)   # spawn box around the camera, screen px


func _ready() -> void:
	amount = 170
	lifetime = 7.0
	preprocess = 7.0
	explosiveness = 0.0
	randomness = 0.6
	local_coords = false
	texture = VFX.T.core
	material = VFX.add_mat
	z_index = 6
	visibility_rect = Rect2(-AREA * 0.6, AREA * 1.2)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(AREA.x * 0.5, AREA.y * 0.5, 0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 35.0
	m.initial_velocity_min = 6.0
	m.initial_velocity_max = 26.0
	m.gravity = Vector3(0, -4.0, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 6.0
	m.scale_min = 0.05
	m.scale_max = 0.15
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	# mostly warm embers, a few cold green soul-motes
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.55, 0.57, 1.0])
	cg.colors = PackedColorArray([Color(1.6, 0.8, 0.35), Color(1.4, 0.95, 0.55), Color(0.5, 1.6, 0.8), Color(0.45, 1.4, 0.75)])
	var cgt := GradientTexture1D.new()
	cgt.gradient = cg
	m.color_initial_ramp = cgt
	process_material = m
	modulate = Color(1, 1, 1, 0.8)
	amount_ratio = clampf(VFX.particle_scale, 0.2, 1.0)
	emitting = true
