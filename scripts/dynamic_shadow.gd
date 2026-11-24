extends Node2D
class_name DynamicShadow

## Soft grounded contact shadow + real-time directional cast shadow driven by nearby PointLight2D sources.
## Attach as a child of a Y-sorted character or furniture node (position at floor contact origin).

@export var contact_size: Vector2 = Vector2(14.0, 6.0)
@export var contact_offset: Vector2 = Vector2(0.0, -1.0)
@export var contact_alpha: float = 0.42
@export var cast_enabled: bool = true
@export var cast_radius: Vector2 = Vector2(8.0, 4.5)
@export var cast_max_length: float = 19.0
@export var cast_alpha: float = 0.28
@export var is_rect_contact: bool = false
@export var max_light_dist: float = 210.0

var _lights: Array[PointLight2D] = []
var _exclude_rids: Array[RID] = []
var _shadow_casts: Array[Dictionary] = []
var _update_accum: float = 0.0
var _last_parent_pos: Vector2 = Vector2(1e9, 1e9)


func _ready() -> void:
	z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	call_deferred("_discover_scene_context")


func _discover_scene_context() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		# Walk up to the top scene root right beneath Viewport (works in tool/test runners too)
		var cur: Node = self
		while cur.get_parent() != null and not (cur.get_parent() is Viewport):
			cur = cur.get_parent()
		root = cur
	if root == null:
		return
	_lights.clear()
	_exclude_rids.clear()
	_collect_nodes(root)
	_recompute_shadows()
	queue_redraw()


func _collect_nodes(node: Node) -> void:
	if node is PointLight2D:
		var pl := node as PointLight2D
		# Skip personal ambient hero glow & tiny specular halos; cast from true room/lamp/window lights
		if pl.name != "AmbientHeroLight" and pl.name != "DeskLampCoreHalo":
			_lights.append(pl)
	elif node is CollisionObject2D:
		# Exclude characters & furniture bodies from line-of-sight wall raycasts so only walls block light
		if node is CharacterBody2D or node is StaticBody2D:
			_exclude_rids.append((node as CollisionObject2D).get_rid())
	for child in node.get_children():
		_collect_nodes(child)


func _process(delta: float) -> void:
	if not cast_enabled:
		return
	_update_accum += delta
	var cur_pos := global_position
	var moved := cur_pos.distance_squared_to(_last_parent_pos) > 0.25
	# Recompute every frame while moving, or ~10Hz when static (to react to lamp flicker/toggles)
	if moved or _update_accum >= 0.10:
		_update_accum = 0.0
		_last_parent_pos = cur_pos
		_recompute_shadows()
		queue_redraw()


func _recompute_shadows() -> void:
	_shadow_casts.clear()
	if not cast_enabled or _lights.is_empty():
		return

	var origin := global_position + contact_offset
	var space := get_world_2d().direct_space_state if get_world_2d() != null else null
	var candidates: Array[Dictionary] = []

	for pl in _lights:
		if not is_instance_valid(pl) or not pl.visible or not pl.enabled or pl.energy <= 0.04:
			continue
		var lpos := pl.global_position
		var diff := origin - lpos
		var dist := diff.length()
		if dist < 4.0 or dist > max_light_dist:
			continue
		# Check wall occlusion between light source and shadow caster
		if space != null:
			var q := PhysicsRayQueryParameters2D.create(lpos, origin, 1, _exclude_rids)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				continue
		var falloff := clampf(1.0 - (dist / max_light_dist), 0.0, 1.0)
		var weight := pl.energy * (falloff * falloff)
		if weight < 0.04:
			continue
		var dir := diff / dist
		# Closer lights stretch less steeply; medium-angle lights cast crisp readable shadows
		var stretch := clampf(dist / 78.0, 0.35, 1.0) * cast_max_length
		candidates.append({
			"dir": dir,
			"len": stretch,
			"weight": weight,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["weight"] > b["weight"])
	var max_casts := mini(2, candidates.size())
	for i in range(max_casts):
		_shadow_casts.append(candidates[i])


func _draw() -> void:
	var c := contact_offset
	var shadow_rgb := Color(0.025, 0.028, 0.055, 1.0)

	# 1. Dynamic directional cast shadows projected away from dominant visible lights
	for sc in _shadow_casts:
		var dir: Vector2 = sc["dir"]
		var slen: float = sc["len"]
		var w: float = clampf(sc["weight"] * 1.45, 0.0, 1.0)
		var alpha := cast_alpha * w
		if alpha <= 0.015:
			continue
		var angle := dir.angle()
		# Soft 2-layer elongated ellipse cast along light direction
		var mid_pos := c + dir * (slen * 0.45)
		_draw_rotated_ellipse(mid_pos, Vector2(slen * 0.62 + cast_radius.x * 0.45, cast_radius.y * 1.15), angle, Color(shadow_rgb.r, shadow_rgb.g, shadow_rgb.b, alpha * 0.52))
		_draw_rotated_ellipse(c + dir * (slen * 0.34), Vector2(slen * 0.44 + cast_radius.x * 0.35, cast_radius.y * 0.80), angle, Color(shadow_rgb.r, shadow_rgb.g, shadow_rgb.b, alpha * 0.68))

	# 2. Grounded ambient-occlusion contact shadow directly under feet / furniture base
	if is_rect_contact:
		var outer := Rect2(c - contact_size * 0.5 - Vector2(3.0, 2.0), contact_size + Vector2(6.0, 4.0))
		var inner := Rect2(c - contact_size * 0.5, contact_size)
		draw_rect(outer, Color(shadow_rgb.r, shadow_rgb.g, shadow_rgb.b, contact_alpha * 0.42))
		draw_rect(inner, Color(shadow_rgb.r, shadow_rgb.g, shadow_rgb.b, contact_alpha * 0.78))
	else:
		_draw_rotated_ellipse(c, contact_size * 0.66, 0.0, Color(shadow_rgb.r, shadow_rgb.g, shadow_rgb.b, contact_alpha * 0.45))
		_draw_rotated_ellipse(c, contact_size * 0.46, 0.0, Color(shadow_rgb.r, shadow_rgb.g, shadow_rgb.b, contact_alpha * 0.78))


func _draw_rotated_ellipse(center: Vector2, radii: Vector2, angle: float, col: Color, segments: int = 16) -> void:
	var pts := PackedVector2Array()
	pts.resize(segments)
	var ca := cos(angle)
	var sa := sin(angle)
	for i in range(segments):
		var t := TAU * float(i) / float(segments)
		var lx := cos(t) * radii.x
		var ly := sin(t) * radii.y
		pts[i] = center + Vector2(lx * ca - ly * sa, lx * sa + ly * ca)
	draw_colored_polygon(pts, col)
