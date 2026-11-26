class_name PerkLib
extends RefCounted
## Behaviour-changing modifiers. Each perk is a small class that overrides the
## hooks it needs. Add a new one by writing a class + an INFO entry.

const INFO := {
	# weapon behaviour affixes (Rare+)
	&"split": ["Fragmenting", "Projectiles split into 3 shards on impact."],
	&"chain": ["Arcing", "Hits have a 20% chance to chain lightning to 3 enemies."],
	&"crit_explode": ["Detonating", "Critical hits explode for 50% damage."],
	&"ammo_on_kill": ["Scavenging", "Kills restore 30% of the magazine."],
	&"momentum": ["Momentum", "Kills grant +7% fire rate for 4s (stacks 8x)."],
	# legendary
	&"fifth_shot": ["Fifth Seal", "Every 5th shot fires an explosive round."],
	&"dash_trail": ["Stormstep", "Dashing leaves a lightning trail that shocks enemies."],
	&"crit_kill_chain": ["Thunder Verdict", "Critical kills unleash chain lightning to 5 enemies."],
	&"big_boom": ["Cataclysm", "Explosions are 40% larger and leave burning ground."],
	&"kill_speed": ["Bloodrush", "Kills grant +30% move speed for 2.5s."],
	&"killstreak_dmg": ["Carnage Engine", "Kills within 2.5s stack +8% damage (max 10)."],
	# mythic
	&"elite_reset": ["Apex Predator", "Killing an elite resets all ability cooldowns."],
	&"vampiric": ["Hemophage", "Critical hits heal 2% of max HP."],
}
const WEAPON_PERKS := [&"split", &"chain", &"crit_explode", &"ammo_on_kill", &"momentum"]
const LEGENDARY := [&"fifth_shot", &"dash_trail", &"crit_kill_chain", &"big_boom", &"kill_speed", &"killstreak_dmg"]
const MYTHIC := [&"elite_reset", &"vampiric"]


static func create(id: StringName, build, weapon) -> Perk:
	var p: Perk
	match id:
		&"split": p = Split.new()
		&"chain": p = Chain.new()
		&"crit_explode": p = CritExplode.new()
		&"ammo_on_kill": p = AmmoOnKill.new()
		&"momentum": p = Momentum.new()
		&"fifth_shot": p = FifthShot.new()
		&"dash_trail": p = DashTrail.new()
		&"crit_kill_chain": p = CritKillChain.new()
		&"big_boom": p = BigBoom.new()
		&"kill_speed": p = KillSpeed.new()
		&"killstreak_dmg": p = Killstreak.new()
		&"elite_reset": p = EliteReset.new()
		&"vampiric": p = Vampiric.new()
		_: p = Perk.new()
	p.id = id
	p.build = build
	p.weapon = weapon
	return p


static func title(id: StringName) -> String:
	return INFO.get(id, ["?", ""])[0]


static func desc(id: StringName) -> String:
	return INFO.get(id, ["", "?"])[1]


class Split extends Perk:
	func on_fire(_w, projs: Array) -> void:
		for p in projs:
			p.split = 1


class Chain extends Perk:
	func after_hit(e, info: DamageInfo, _dealt: float, _killed: bool) -> void:
		if info.proc_depth == 0 and randf() < 0.2:
			var c := info.copy()
			c.amount *= 0.5
			c.type = DamageInfo.Type.SHOCK
			c.proc_depth = 1
			Game.projectiles.chain_lightning(e, 3, Iso.m(4.5), c)


class CritExplode extends Perk:
	func after_hit(_e, info: DamageInfo, _dealt: float, _killed: bool) -> void:
		if info.crit and info.proc_depth == 0 and not info.is_explosion:
			var d := info.copy()
			d.amount *= 0.5
			d.crit = false
			d.proc_depth = 1
			d.knockback *= 0.5
			Combat.explode(info.hit_pos, Iso.m(1.7), d, false, Color(1.0, 0.7, 0.3), false)


class AmmoOnKill extends Perk:
	func on_kill(_e, info: DamageInfo) -> void:
		var w = info.weapon
		if w and not w.uses_heat():
			w.mag = mini(w.s_mag, w.mag + int(ceil(w.s_mag * 0.3)))
			Events.ammo_changed.emit()


class Momentum extends Perk:
	func on_kill(_e, _info: DamageInfo) -> void:
		build.add_buff("momentum", "fire_rate_pct", 0.07, 4.0, 8)


class FifthShot extends Perk:
	func on_fire(w, projs: Array) -> void:
		if w.shots % 5 != 0:
			return
		if projs.is_empty():
			# hitscan weapons: launch a bonus explosive bolt along the aim
			var pl = build.player
			var p := Projectile.new()
			p.pos = pl.muzzle_ground()
			p.height = pl.muzzle_height()
			p.vel = pl.aim_dir * Iso.m(38.0)
			p.info = DamageInfo.make(w.s_damage * 3.0, DamageInfo.Type.EXPLOSIVE, pl)
			p.info.weapon = w
			p.info.knockback = Iso.m(6.0)
			p.max_range = Iso.m(18.0)
			p.explode_radius = Iso.m(2.2)
			p.kind = &"bolt"
			p.color = Color(1.0, 0.55, 0.2)
			p.width = 7.0
			p.length = Iso.m(1.0)
			p.radius = Iso.m(0.2)
			Game.projectiles.spawn(p)
			return
		for p in projs:
			p.explode_radius = maxf(p.explode_radius, Iso.m(2.2))
			p.color = Color(1.0, 0.55, 0.2)
			p.width *= 1.6
			p.info.knockback += Iso.m(4.0)


class DashTrail extends Perk:
	func on_dash(a: Vector2, b: Vector2) -> void:
		var n := 4
		for i in n:
			var g := a.lerp(b, (i + 0.5) / n)
			var h := GroundHazard.new()
			h.setup(g, Iso.m(0.9), 2.0, build.player)
			h.type = DamageInfo.Type.SHOCK
			h.color = Color(0.45, 0.7, 1.0)
			h.dps = 40.0 * build.mult("ability_power_pct")
			h.hurts_player = false
			Game.world.add_hazard(h)
		VFX.lightning(Iso.lift(a, 0.3), Iso.lift(b, 0.3), Color(1.2, 1.6, 4.0), 5.0, 0.3, 1.4)


class CritKillChain extends Perk:
	func on_kill(e, info: DamageInfo) -> void:
		if info.crit and info.proc_depth < 2:
			var c := info.copy()
			c.amount = maxf(info.amount * 0.6, 20.0)
			c.type = DamageInfo.Type.SHOCK
			c.proc_depth += 1
			Game.projectiles.chain_lightning(e, 5, Iso.m(6.0), c)


class BigBoom extends Perk:
	func stat_bonus() -> Dictionary:
		return {"explosion_radius_pct": 0.4}

	func on_explosion(g: Vector2, r: float, info: DamageInfo) -> void:
		if info.source == build.player and info.proc_depth < 2:
			VFX.burning_ground(g, r * 0.7, 3.0, build.player)


class KillSpeed extends Perk:
	func on_kill(_e, _info: DamageInfo) -> void:
		build.add_buff("bloodrush", "move_speed_pct", 0.3, 2.5, 1)


class Killstreak extends Perk:
	func on_kill(_e, _info: DamageInfo) -> void:
		build.add_buff("carnage", "damage_pct", 0.08, 2.5, 10)


class EliteReset extends Perk:
	func on_kill(e, _info: DamageInfo) -> void:
		if e.is_elite:
			build.player.reset_cooldowns()
			VFX.popup(build.player.gpos, 2.4, "COOLDOWNS RESET", Color(1.0, 0.3, 0.3), 28)


class Vampiric extends Perk:
	func after_hit(_e, info: DamageInfo, _dealt: float, _killed: bool) -> void:
		if info.crit:
			build.player.heal(build.player.max_hp * 0.02, false)
