class_name Weapon
extends RefCounted
## Runtime weapon: ammo/heat/charge state + final stats (base × rarity × affixes × build).

var data: WeaponData
var item = null              # Item that carries rarity/affixes (optional)

var mag := 0
var cooldown := 0.0
var reloading := false
var reload_t := 0.0
var heat := 0.0
var overheated := false
var heat_delay := 0.0
var charge := 0.0
var charging := false
var bloom := 0.0
var shots := 0
var _press_buffer := 0.0

# final stats
var s_damage := 0.0
var s_interval := 0.1
var s_crit := 0.0
var s_crit_mult := 2.0
var s_mag := 1
var s_reload := 1.0
var s_pierce := 0
var s_ricochet := 0
var s_speed := 1000.0
var s_spread := 0.0
var s_range := 1000.0
var s_status := {}
var s_explode := 0.0
var s_chain := 0
var s_knockback := 0.0
var s_stagger := 0.0
var local := {}              # weapon-local stat bonuses from its item


func _init(d: WeaponData, it = null) -> void:
	data = d
	item = it
	recalc(null)
	mag = s_mag


func display_name() -> String:
	return item.display_name() if item else data.display_name


func recalc(build) -> void:
	local = item.local_stats() if item else {}
	var g := func(name: String) -> float:
		var v: float = local.get(name, 0.0)
		if build:
			v += build.stat(name)
		return v
	var rarity_mult: float = item.power_mult() if item else 1.0
	s_damage = data.damage * rarity_mult * (1.0 + g.call("damage_pct"))
	s_interval = data.fire_interval / maxf(0.2, 1.0 + g.call("fire_rate_pct"))
	s_crit = data.crit_chance + g.call("crit_chance")
	s_crit_mult = data.crit_mult + g.call("crit_damage")
	s_mag = maxi(1, int(round(data.mag_size * (1.0 + g.call("mag_pct")))))
	s_reload = data.reload_time / maxf(0.2, 1.0 + g.call("reload_speed_pct"))
	s_pierce = data.pierce + int(g.call("pierce"))
	s_ricochet = data.ricochet + int(g.call("ricochet"))
	s_speed = Iso.m(data.projectile_speed_m) * (1.0 + g.call("projectile_speed_pct"))
	s_range = Iso.m(data.range_m) * (1.0 + g.call("range_pct"))
	s_spread = data.spread_deg
	s_explode = Iso.m(data.explode_radius_m)
	s_chain = data.chain_count + int(g.call("chain"))
	s_knockback = Iso.m(data.knockback_m)
	s_stagger = data.stagger * (1.0 + g.call("stagger_pct"))
	s_status = data.status.duplicate()
	var burn: float = g.call("burn_chance")
	if burn > 0.0:
		s_status[&"burn"] = s_status.get(&"burn", 0.0) + burn
	var shock: float = g.call("shock_chance")
	if shock > 0.0:
		s_status[&"shock"] = s_status.get(&"shock", 0.0) + shock
	if mag > s_mag:
		mag = s_mag


func uses_heat() -> bool:
	return data.ammo_type == "heat"


func reserve(owner) -> int:
	if uses_heat():
		return -1
	return owner.ammo.get(data.ammo_type, 0)


func update(dt: float, owner, held: bool, pressed: bool, released: bool, active: bool) -> void:
	cooldown = maxf(cooldown - dt, -0.05)
	bloom = maxf(0.0, bloom - data.bloom_recovery * dt)
	_press_buffer = maxf(0.0, _press_buffer - dt)
	if uses_heat():
		if overheated:
			heat -= dt / data.overheat_time
			if heat <= 0.0:
				heat = 0.0
				overheated = false
		else:
			heat_delay -= dt
			if heat_delay <= 0.0:
				heat = maxf(0.0, heat - data.heat_cool_rate * dt)
	if not active:
		charging = false
		charge = 0.0
		return
	if reloading:
		reload_t -= dt
		if reload_t <= 0.0:
			_finish_reload_step(owner)
		# shotguns can interrupt a per-shell reload by firing
		if not (data.reload_per_round and pressed and mag > 0):
			return
		reloading = false
	if pressed:
		_press_buffer = 0.14
	match data.fire_mode:
		"auto":
			if held:
				_try_fire(owner, 1.0)
		"semi":
			if _press_buffer > 0.0 and _try_fire(owner, 1.0):
				_press_buffer = 0.0
		"charge":
			if held and _can_fire(owner):
				if not charging:
					charging = true
					charge = 0.0
					Audio.play("rail_charge", owner.gpos)
				charge = minf(1.0, charge + dt / maxf(0.01, data.charge_time))
			elif charging and not held:
				charging = false
				if charge >= 0.18:
					_try_fire(owner, charge)
				charge = 0.0
	if not uses_heat() and mag <= 0 and not reloading and owner.ammo.get(data.ammo_type, 0) > 0:
		start_reload(owner)


func _can_fire(owner) -> bool:
	if cooldown > 0.0:
		return false
	if uses_heat():
		return not overheated
	if mag <= 0:
		if owner.ammo.get(data.ammo_type, 0) <= 0:
			if _press_buffer > 0.0:
				Audio.play("empty", owner.gpos)
				_press_buffer = 0.0
		return false
	return true


func _try_fire(owner, charge_factor: float) -> bool:
	if not _can_fire(owner):
		return false
	cooldown += s_interval
	if cooldown < 0.0:
		cooldown = s_interval * 0.5
	shots += 1
	if uses_heat():
		heat += data.heat_per_shot
		heat_delay = 0.25
		if heat >= 1.0:
			heat = 1.0
			overheated = true
			Audio.play("overheat", owner.gpos)
			VFX.popup(owner.gpos, 2.2, "OVERHEAT", Color(1.0, 0.5, 0.3), 26)
	else:
		mag -= 1
	_fire(owner, charge_factor)
	Events.shot_fired.emit(self)
	Events.ammo_changed.emit()
	return true


func _base_info(owner, charge_factor: float) -> DamageInfo:
	var d := DamageInfo.make(s_damage * charge_factor, data.damage_type, owner)
	d.weapon = self
	d.knockback = s_knockback
	d.stagger = s_stagger * charge_factor
	d.status = s_status.duplicate()
	return d


func _fire(owner, charge_factor: float) -> void:
	var dir: Vector2 = owner.aim_dir
	var origin: Vector2 = owner.muzzle_ground()
	var mh: float = owner.muzzle_height()
	var spread := deg_to_rad(s_spread + bloom)
	bloom = minf(data.bloom_max_deg, bloom + data.bloom_per_shot_deg)
	var projs: Array = []
	if data.hitscan:
		owner.build.on_fire(self, projs)
		if data.proj_kind == "arc":
			Game.projectiles.fire_arc(owner, self, origin, mh, dir.rotated(randf_range(-spread, spread)), _base_info(owner, charge_factor))
		else:
			Game.projectiles.fire_rail(owner, self, origin, mh, dir, _base_info(owner, charge_factor), charge_factor)
	else:
		for i in data.pellets:
			var a := randf_range(-spread, spread)
			if data.pellets > 1:
				a = lerpf(-spread, spread, (i + randf()) / data.pellets)
			var p := Projectile.new()
			p.team = 0
			p.pos = origin
			p.prev = origin
			p.height = mh
			var spd := s_speed * (randf_range(0.85, 1.15) if data.pellets > 1 else 1.0)
			p.vel = dir.rotated(a) * spd
			p.info = _base_info(owner, charge_factor)
			p.crit_chance = s_crit
			p.crit_mult = s_crit_mult
			p.pierce = s_pierce
			p.ricochet = s_ricochet
			p.max_range = s_range * (randf_range(0.85, 1.0) if data.pellets > 1 else 1.0)
			p.falloff_start = Iso.m(data.falloff_start_m)
			p.falloff_min = data.falloff_min
			p.explode_radius = s_explode
			p.chain = s_chain
			p.kind = StringName(data.proj_kind)
			p.color = data.proj_color
			p.width = data.proj_width
			p.length = Iso.m(data.proj_length_m)
			p.radius = Iso.m(0.12)
			p.weapon = self
			p.impact_style = data.impact_style
			if data.proj_kind == "grenade":
				p.setup_lob(origin, owner.aim_target, mh, spd)
			projs.append(p)
		owner.build.on_fire(self, projs)
		for p in projs:
			Game.projectiles.spawn(p)
	var ms: Vector2 = owner.muzzle_screen()
	VFX.muzzle(ms, dir, {"color": data.muzzle_color, "scale": data.muzzle_scale, "wide": data.muzzle_wide,
		"light": data.muzzle_light, "range": 3.5 + data.muzzle_scale * 2.0, "sparks": 0.25 if data.pellets > 1 else 0.0})
	Audio.play(data.sound_fire, owner.gpos)
	owner.on_weapon_fired(self, charge_factor)


func start_reload(owner) -> void:
	if reloading or uses_heat() or mag >= s_mag:
		return
	if owner.ammo.get(data.ammo_type, 0) <= 0:
		return
	reloading = true
	charging = false
	reload_t = s_reload * (0.6 if data.reload_per_round and mag == 0 else 1.0)
	Audio.play("reload", owner.gpos)


func _finish_reload_step(owner) -> void:
	var res: int = owner.ammo.get(data.ammo_type, 0)
	if data.reload_per_round:
		if res > 0 and mag < s_mag:
			mag += 1
			owner.ammo[data.ammo_type] = res - 1
		if mag < s_mag and owner.ammo.get(data.ammo_type, 0) > 0:
			reload_t = s_reload
			Audio.play("reload", owner.gpos)
			Events.ammo_changed.emit()
			return
	else:
		var need := s_mag - mag
		var take := mini(need, res)
		mag += take
		owner.ammo[data.ammo_type] = res - take
	reloading = false
	Audio.play("reload_done", owner.gpos)
	Events.weapon_reloaded.emit(self)
	Events.ammo_changed.emit()


func reload_progress() -> float:
	if not reloading:
		return 0.0
	return 1.0 - reload_t / maxf(0.01, s_reload)
