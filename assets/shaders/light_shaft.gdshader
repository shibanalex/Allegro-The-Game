shader_type canvas_item;
render_mode blend_add;

uniform vec4 ray_color : source_color = vec4(0.62, 0.78, 1.0, 0.22);
uniform float beam_start_x : hint_range(0.0, 0.6) = 0.06;
uniform float beam_width : hint_range(0.15, 0.8) = 0.42;
uniform float angle_skew : hint_range(-0.6, 0.6) = 0.42;
uniform float spread_growth : hint_range(0.0, 0.4) = 0.14;
uniform float ray_frequency : hint_range(1.0, 24.0) = 7.0;
uniform float shimmer_speed : hint_range(0.0, 3.0) = 0.42;
uniform float edge_softness : hint_range(0.05, 0.48) = 0.32;
uniform float vertical_fade_power : hint_range(0.5, 3.0) = 1.45;

void fragment() {
	// Local beam coordinate [0..1] that shifts with UV.y and widens smoothly
	float cur_start = beam_start_x + UV.y * angle_skew;
	float cur_width = beam_width + UV.y * spread_growth;
	float local_x = (UV.x - cur_start) / max(0.05, cur_width);

	// Smooth horizontal fade inside local_x [0..1] AND hard safety fade at ColorRect UV borders
	float h_mask = smoothstep(0.0, edge_softness, local_x) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, local_x));
	float rect_safety = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));

	// Layered soft volumetric shafts with slow organic shimmer
	float wave1 = 0.5 + 0.5 * sin(local_x * ray_frequency * 6.28318 + TIME * shimmer_speed);
	float wave2 = 0.5 + 0.5 * sin(local_x * (ray_frequency * 1.65) * 6.28318 - TIME * shimmer_speed * 0.7 + 1.4);
	float rays = mix(0.45, 1.0, wave1 * 0.65 + wave2 * 0.35);

	// Smooth vertical falloff from window/lamp source (UV.y = 0) down to the floor (UV.y = 1)
	float v_fade = smoothstep(0.0, 0.10, UV.y) * pow(clamp(1.0 - UV.y, 0.0, 1.0), vertical_fade_power);

	float alpha = ray_color.a * h_mask * rect_safety * rays * v_fade;
	COLOR = vec4(ray_color.rgb, alpha);
}
