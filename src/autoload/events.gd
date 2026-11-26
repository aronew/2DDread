extends Node
## Global signal bus. Systems emit facts; HUD, audio, VFX, progression and
## encounters subscribe. Nothing here holds state.

# combat
signal enemy_spawned(enemy)
signal enemy_damaged(enemy, info, amount)
signal enemy_killed(enemy, info)
signal player_damaged(info, amount)
signal player_died
signal player_healed(amount)
signal shot_fired(weapon)
signal explosion(ground_pos: Vector2, radius: float, info)
signal status_applied(target, status: StringName)

# player state
signal weapon_switched(index: int)
signal weapon_reloaded(weapon)
signal ammo_changed
signal ability_used(slot: int)
signal dashed(from_g: Vector2, to_g: Vector2)

# progression / loot
signal xp_gained(amount: int)
signal level_up(level: int)
signal item_picked(item)
signal item_dropped(item, ground_pos: Vector2)
signal inventory_changed
signal stats_changed

# world
signal room_entered(room)
signal room_locked(room)
signal room_cleared(room)
signal encounter_beat(room, beat_index: int)
signal elite_engaged(enemy)
signal message(text: String, color: Color)
signal depth_changed(depth: int)
