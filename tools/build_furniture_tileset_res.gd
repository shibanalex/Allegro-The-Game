@tool
extends SceneTree


func _build_furniture_tileset() -> int:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var atlas := TileSetAtlasSource.new()
	var tex: Texture2D = load("res://assets/materials/house_furniture_atlas_canvas.tres")
	if tex == null:
		tex = load("res://assets/tilesets/house_furniture_atlas.png")
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/house_furniture_tiles.json"))
	var tiles: Dictionary = data["tiles"]

	for tile_name: String in tiles.keys():
		var info: Dictionary = tiles[tile_name]
		var ac: Array = info["atlas"]
		var sz: Array = info["size"]
		var coords := Vector2i(int(ac[0]), int(ac[1]))
		var cw := int(sz[0])
		var ch := int(sz[1])
		atlas.create_tile(coords, Vector2i(cw, ch))
		var td := atlas.get_tile_data(coords, 0)
		td.texture_origin = Vector2i(-(cw - 1) * 16, -(ch - 1) * 16)

		var is_rug := bool(info.get("rug", false))
		if is_rug:
			td.z_index = -1
		else:
			td.y_sort_origin = ch * 32 - 16
			var cr = info.get("col_rect", null)
			if cr is Array and (cr as Array).size() == 4:
				var arr: Array = cr
				var bx := float((cw - 1) * 16)
				var by := float(ch * 32 - 16)
				var x0 := bx + float(arr[0])
				var y0 := by + float(arr[1])
				var x1 := bx + float(arr[2])
				var y1 := by + float(arr[3])
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)
				]))

	var err := ResourceSaver.save(tileset, "res://assets/tilesets/house_furniture_tileset.tres")
	print("Saved house_furniture_tileset.tres err=", err, " count=", tiles.size())
	return err


func _build_props_tileset() -> int:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)

	var atlas := TileSetAtlasSource.new()
	var tex: Texture2D = load("res://assets/materials/house_props_atlas_canvas.tres")
	if tex == null:
		tex = load("res://assets/tilesets/house_props_atlas.png")
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/house_props_tiles.json"))
	var tiles: Dictionary = data["tiles"]

	for tile_name: String in tiles.keys():
		var info: Dictionary = tiles[tile_name]
		var ac: Array = info["atlas"]
		var coords := Vector2i(int(ac[0]), int(ac[1]))
		atlas.create_tile(coords, Vector2i(1, 1))
		var td := atlas.get_tile_data(coords, 0)
		td.y_sort_origin = 16

	var err := ResourceSaver.save(tileset, "res://assets/tilesets/house_props_tileset.tres")
	print("Saved house_props_tileset.tres err=", err, " count=", tiles.size())
	return err


func _init() -> void:
	var e1 := _build_furniture_tileset()
	var e2 := _build_props_tileset()
	quit(e1 + e2)
