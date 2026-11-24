@tool
extends SceneTree

func _init() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var atlas := TileSetAtlasSource.new()
	var tex: Texture2D = load("res://assets/tilesets/dorm_a_atlas.png")
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)

	var json_text := FileAccess.get_file_as_string("res://assets/tilesets/dorm_a_tiles.json")
	var data: Dictionary = JSON.parse_string(json_text)
	var tiles: Dictionary = data["tiles"]

	var full_cell := PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	# For 2x3 multi-tiles anchored at top-left cell (texture_origin = (-16, -32)),
	# bottom 32px row relative to anchor cell center is x=[-16..48], y=[48..80]
	var prop_bottom_row := PackedVector2Array([
		Vector2(-16, 48), Vector2(48, 48), Vector2(48, 80), Vector2(-16, 80)
	])

	for tile_name: String in tiles.keys():
		var info: Dictionary = tiles[tile_name]
		var ac: Array = info["atlas"]
		var sz: Array = info["size"]
		var coords := Vector2i(int(ac[0]), int(ac[1]))
		var size_v := Vector2i(int(sz[0]), int(sz[1]))
		atlas.create_tile(coords, size_v)
		var td := atlas.get_tile_data(coords, 0)
		if size_v == Vector2i(2, 3):
			td.texture_origin = Vector2i(-16, -32)
		if tile_name.begins_with("walltop_") or tile_name.contains("_wall_bot_"):
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full_cell)
		elif size_v == Vector2i(2, 3):
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, prop_bottom_row)

	# Add terrain set for easy brush painting in editor (Terrains: 0=RoomFloor, 1=CorrFloor, 2=WallTop)
	tileset.add_terrain_set(0)
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tileset.add_terrain(0, 0)
	tileset.set_terrain_name(0, 0, "Room Floor")
	tileset.set_terrain_color(0, 0, Color(0.55, 0.38, 0.28))
	tileset.add_terrain(0, 1)
	tileset.set_terrain_name(0, 1, "Corridor Floor")
	tileset.set_terrain_color(0, 1, Color(0.45, 0.48, 0.40))

	for v in range(4):
		var rf_coords := Vector2i(v, 3)
		var rtd := atlas.get_tile_data(rf_coords, 0)
		rtd.terrain_set = 0
		rtd.terrain = 0
		rtd.probability = 3.0 if v == 0 else (2.0 if v < 3 else 1.0)
		for bit in [
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
		]:
			rtd.set_terrain_peering_bit(bit, 0)

		var cf_coords := Vector2i(4 + v, 3)
		var ctd := atlas.get_tile_data(cf_coords, 0)
		ctd.terrain_set = 0
		ctd.terrain = 1
		ctd.probability = 5.0 if v == 0 else 1.0
		for bit in [
			TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER
		]:
			ctd.set_terrain_peering_bit(bit, 1)

	var err := ResourceSaver.save(tileset, "res://assets/tilesets/dorm_a_tileset.tres")
	print("Saved dorm_a_tileset.tres err=", err)
	quit()
