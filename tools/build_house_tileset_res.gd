@tool
extends SceneTree

func _make_occ(pts: PackedVector2Array) -> OccluderPolygon2D:
	var poly := OccluderPolygon2D.new()
	poly.polygon = pts
	poly.closed = true
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	return poly


func _init() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	# Real-time 2D shadow occlusion layer (blocks room lights cleanly at walls & doorway jambs)
	tileset.add_occlusion_layer()
	tileset.set_occlusion_layer_light_mask(0, 1)

	var atlas := TileSetAtlasSource.new()
	# Normal-mapped CanvasTexture gives floorboards, wainscot, wallpaper & radiators subtle 3D light response
	var tex: Texture2D = load("res://assets/materials/house_atlas_canvas.tres")
	if tex == null:
		tex = load("res://assets/tilesets/house_atlas.png")
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)

	var json_text := FileAccess.get_file_as_string("res://assets/tilesets/house_tiles.json")
	var data: Dictionary = JSON.parse_string(json_text)
	var tiles: Dictionary = data["tiles"]

	var full_cell := PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	var south_walltop_cell := PackedVector2Array([
		Vector2(-16, -6), Vector2(16, -6), Vector2(16, 16), Vector2(-16, 16)
	])
	# Slightly inset walltop occluders so wooden cutaway rim trim still catches soft light while sealing rooms
	var occ_walltop_full := PackedVector2Array([
		Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13)
	])
	var occ_walltop_south := PackedVector2Array([
		Vector2(-13, -2), Vector2(13, -2), Vector2(13, 13), Vector2(-13, 13)
	])
	var full_2x2 := PackedVector2Array([
		Vector2(-16, -16), Vector2(48, -16), Vector2(48, 48), Vector2(-16, 48)
	])
	var jamb_left := PackedVector2Array([
		Vector2(-16, -16), Vector2(-4, -16), Vector2(-4, 48), Vector2(-16, 48)
	])
	var jamb_right := PackedVector2Array([
		Vector2(36, -16), Vector2(48, -16), Vector2(48, 48), Vector2(36, 48)
	])
	var occ_jamb_left := PackedVector2Array([
		Vector2(-16, -14), Vector2(-6, -14), Vector2(-6, 46), Vector2(-16, 46)
	])
	var occ_jamb_right := PackedVector2Array([
		Vector2(38, -14), Vector2(48, -14), Vector2(48, 46), Vector2(38, 46)
	])
	var cap_jamb_left := PackedVector2Array([
		Vector2(-16, -6), Vector2(-4, -6), Vector2(-4, 16), Vector2(-16, 16)
	])
	var cap_jamb_right := PackedVector2Array([
		Vector2(36, -6), Vector2(48, -6), Vector2(48, 16), Vector2(36, 16)
	])
	var occ_cap_left := PackedVector2Array([
		Vector2(-16, -2), Vector2(-6, -2), Vector2(-6, 14), Vector2(-16, 14)
	])
	var occ_cap_right := PackedVector2Array([
		Vector2(38, -2), Vector2(48, -2), Vector2(48, 14), Vector2(38, 14)
	])

	for tile_name: String in tiles.keys():
		var info: Dictionary = tiles[tile_name]
		var ac: Array = info["atlas"]
		var sz: Array = info["size"]
		var coords := Vector2i(int(ac[0]), int(ac[1]))
		var size_v := Vector2i(int(sz[0]), int(sz[1]))
		atlas.create_tile(coords, size_v)
		var td := atlas.get_tile_data(coords, 0)
		if size_v == Vector2i(2, 2):
			td.texture_origin = Vector2i(-16, -16)
		elif size_v == Vector2i(2, 1):
			td.texture_origin = Vector2i(-16, 0)
		if tile_name == "hall_passage":
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, jamb_left)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 1, jamb_right)
			td.set_occluder_polygons_count(0, 2)
			td.set_occluder_polygon(0, 0, _make_occ(occ_jamb_left))
			td.set_occluder_polygon(0, 1, _make_occ(occ_jamb_right))
		elif tile_name == "passage_cap":
			# Rendered on floor layer; collision + foreground jambs & occlusion live on passage_cap_fg inside WallTopMap.
			pass
		elif tile_name == "passage_cap_fg":
			td.y_sort_origin = 16
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, cap_jamb_left)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 1, cap_jamb_right)
			td.set_occluder_polygons_count(0, 2)
			td.set_occluder_polygon(0, 0, _make_occ(occ_cap_left))
			td.set_occluder_polygon(0, 1, _make_occ(occ_cap_right))
		elif tile_name.begins_with("walltop_"):
			var mask_val: int = int(tile_name.split("_")[1])
			td.add_collision_polygon(0)
			td.set_occluder_polygons_count(0, 1)
			if (mask_val & 4) != 0:
				td.y_sort_origin = 16
				td.set_collision_polygon_points(0, 0, south_walltop_cell)
				td.set_occluder_polygon(0, 0, _make_occ(occ_walltop_south))
			else:
				td.set_collision_polygon_points(0, 0, full_cell)
				td.set_occluder_polygon(0, 0, _make_occ(occ_walltop_full))
		elif tile_name == "void":
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full_cell)
			td.set_occluder_polygons_count(0, 1)
			td.set_occluder_polygon(0, 0, _make_occ(full_cell))
		elif tile_name.contains("_wall_"):
			# Front painted north walls have NO occluder so room lights illuminate wallpaper, radiators & paintings cleanly!
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full_cell)
		elif size_v == Vector2i(2, 2):
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full_2x2)

	tileset.add_terrain_set(0)
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tileset.add_terrain(0, 0)
	tileset.set_terrain_name(0, 0, "Room Floor")
	tileset.set_terrain_color(0, 0, Color(0.55, 0.38, 0.28))
	tileset.add_terrain(0, 1)
	tileset.set_terrain_name(0, 1, "Hallway Floor")
	tileset.set_terrain_color(0, 1, Color(0.68, 0.50, 0.36))

	var all_bits := [
		TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
	]

	for v in range(4):
		var rf_coords := Vector2i(v, 2)
		var rtd := atlas.get_tile_data(rf_coords, 0)
		rtd.terrain_set = 0
		rtd.terrain = 0
		rtd.probability = 3.0 if v == 0 else (2.0 if v < 3 else 1.0)
		for bit in all_bits:
			rtd.set_terrain_peering_bit(bit, 0)

		var hf_coords := Vector2i(4 + v, 2)
		var htd := atlas.get_tile_data(hf_coords, 0)
		htd.terrain_set = 0
		htd.terrain = 1
		htd.probability = 4.0 if v == 0 else 1.5
		for bit in all_bits:
			htd.set_terrain_peering_bit(bit, 1)

	var err := ResourceSaver.save(tileset, "res://assets/tilesets/house_tileset.tres")
	print("Saved house_tileset.tres with occlusion + normal-mapped CanvasTexture err=", err)
	quit()
