shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Octopath Traveler HD-2D parameters
uniform float tilt_shift_amount : hint_range(0.0, 3.5) = 1.65;
uniform float focus_center_y : hint_range(0.2, 0.8) = 0.50;
uniform float focus_half_band : hint_range(0.05, 0.45) = 0.21;
uniform float bloom_strength : hint_range(0.0, 1.2) = 0.32;
uniform float bloom_threshold : hint_range(0.3, 0.95) = 0.62;
uniform float ca_strength : hint_range(0.0, 0.008) = 0.0016;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.58;
uniform float grain_strength : hint_range(0.0, 0.10) = 0.014;
uniform float sepia_mix : hint_range(0.0, 1.0) = 0.12;
uniform float contrast_boost : hint_range(0.9, 1.35) = 1.08;
uniform float paper_texture_strength : hint_range(0.0, 0.10) = 0.0;
uniform float desaturate_amount : hint_range(0.0, 1.0) = 0.0;
uniform float melancholy_grade : hint_range(0.0, 1.0) = 0.0;
uniform float vhs_strength : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 12-tap Golden-Angle disk offsets for smooth bokeh tilt-shift & bloom
const vec2 DISK_OFFSETS[12] = vec2[](
	vec2(0.326, -0.406),
	vec2(-0.840, -0.074),
	vec2(-0.696, 0.457),
	vec2(-0.203, 0.621),
	vec2(0.962, -0.195),
	vec2(0.473, -0.480),
	vec2(0.519, 0.767),
	vec2(0.185, -0.893),
	vec2(0.507, 0.064),
	vec2(0.896, 0.412),
	vec2(-0.322, -0.933),
	vec2(-0.792, -0.598)
);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float dist_sq = dot(centered, centered);

	// Soft, delicate cassette VHS memory overlay (no distracting full-screen wobble)
	float vhs = clamp(vhs_strength, 0.0, 1.0);
	float t_cycle = fract(TIME * 0.08 + 0.35);
	float bar_y = t_cycle * 1.3 - 0.15;
	float bar_band = exp(-pow((uv.y - bar_y) * 26.0, 2.0)) * smoothstep(0.0, 0.10, t_cycle) * smoothstep(0.85, 0.55, t_cycle);
	float head_zone = smoothstep(0.982, 0.996, uv.y);
	float head_jit = (hash(vec2(floor(uv.y * 270.0), floor(TIME * 24.0))) - 0.5) * 0.004 * head_zone;
	float track_jit = (hash(vec2(floor(uv.y * 240.0), floor(TIME * 18.0))) - 0.5) * 0.0007 * bar_band;
	vec2 sample_uv_base = (vhs > 0.001)
		? clamp(uv + vec2((track_jit + head_jit) * vhs, 0.0), vec2(0.001), vec2(0.999))
		: uv;

	// 1. Tilt-Shift Depth of Field (sharp center band, smooth bokeh at top & bottom)
	float dy = abs(sample_uv_base.y - focus_center_y);
	float blur_factor = smoothstep(focus_half_band, 0.50, dy);

	// Subtle radial chromatic aberration at outer edges + light VHS R/B phase nudge
	float rim_factor = smoothstep(0.04, 0.36, dist_sq);
	vec2 ca_offset = centered * rim_factor * ca_strength * (0.45 + 0.55 * blur_factor * min(tilt_shift_amount, 1.0));
	vec2 vhs_chroma_shift = vec2(0.00050 * vhs, 0.0);
	vec3 base_col;
	base_col.r = texture(screen_texture, clamp(sample_uv_base + ca_offset + vhs_chroma_shift, vec2(0.001), vec2(0.999))).r;
	base_col.g = texture(screen_texture, sample_uv_base).g;
	base_col.b = texture(screen_texture, clamp(sample_uv_base - ca_offset - vhs_chroma_shift, vec2(0.001), vec2(0.999))).b;

	// Light chroma-only horizontal VHS softness (luminance stays sharp for crisp sprites)
	if (vhs > 0.001) {
		vec3 col_l = texture(screen_texture, clamp(sample_uv_base - vec2(0.0010 * vhs, 0.0), vec2(0.001), vec2(0.999))).rgb;
		vec3 col_r = texture(screen_texture, clamp(sample_uv_base + vec2(0.0014 * vhs, 0.0), vec2(0.001), vec2(0.999))).rgb;
		float lum_c = dot(base_col, vec3(0.299, 0.587, 0.114));
		vec3 chroma_sharp = base_col - lum_c;
		vec3 col_avg = 0.45 * col_l + 0.55 * col_r;
		vec3 chroma_soft = col_avg - dot(col_avg, vec3(0.299, 0.587, 0.114));
		base_col = clamp(vec3(lum_c) + mix(chroma_sharp, chroma_soft, 0.45 * vhs), 0.0, 1.0);
	}

	// Sample 12-tap bokeh disk for Tilt-Shift DoF (only when enabled) and Soft Highlight Bloom
	vec3 dof_accum = base_col;
	float dof_weight = 1.0;
	vec3 bloom_accum = vec3(0.0);

	float dof_mix = clamp(blur_factor * tilt_shift_amount, 0.0, 1.0);
	bool do_dof = tilt_shift_amount > 0.001 && blur_factor > 0.005;
	vec2 texel_radius = vec2(0.0028, 0.0046) * (blur_factor * tilt_shift_amount);
	vec2 bloom_radius = vec2(0.0045, 0.0070);

	for (int i = 0; i < 12; i++) {
		// Tilt-shift sample (bypassed cleanly when tilt_shift_amount == 0)
		if (do_dof) {
			vec2 sample_uv = clamp(sample_uv_base + DISK_OFFSETS[i] * texel_radius, vec2(0.001), vec2(0.999));
			vec3 s_col = textureLod(screen_texture, sample_uv, blur_factor * 1.4 * min(tilt_shift_amount, 1.0)).rgb;
			float lum_w = 1.0 + max(0.0, dot(s_col, vec3(0.299, 0.587, 0.114)) - 0.55) * 1.4;
			dof_accum += s_col * lum_w;
			dof_weight += lum_w;
		}

		// Soft Bloom sample around bright lights/particles
		vec2 b_uv = clamp(sample_uv_base + DISK_OFFSETS[i] * bloom_radius, vec2(0.001), vec2(0.999));
		vec3 b_col = textureLod(screen_texture, b_uv, 1.8).rgb;
		float b_lum = max(b_col.r, max(b_col.g, b_col.b));
		float bright = max(0.0, b_lum - bloom_threshold) / max(0.001, 1.0 - bloom_threshold);
		bloom_accum += b_col * (bright * bright);
	}

	vec3 col = do_dof ? mix(base_col, dof_accum / dof_weight, dof_mix) : base_col;

	// Add warm or wintry-cold highlight bloom
	vec3 bloom_tint = mix(vec3(1.06, 0.98, 0.90), vec3(0.86, 0.93, 1.04), melancholy_grade);
	col += (bloom_accum / 12.0) * bloom_strength * bloom_tint;

	// 2. Desaturation + Split-Toning + Melancholy Winter Tape Grade
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	if (desaturate_amount > 0.001) {
		col = mix(col, vec3(lum), desaturate_amount);
	}

	vec3 sepia = vec3(lum * 1.07, lum * 0.95, lum * 0.82);
	col = mix(col, sepia, sepia_mix);

	vec3 shadow_tint = mix(vec3(0.92, 0.94, 1.06), vec3(0.84, 0.89, 0.99), melancholy_grade);
	vec3 highlight_tint = mix(vec3(1.05, 1.00, 0.92), vec3(0.93, 0.96, 1.01), melancholy_grade);
	col *= mix(shadow_tint, highlight_tint, smoothstep(0.15, 0.78, lum));

	// Gentle contrast curve + lifted analog shadow floor when melancholy_grade > 0
	col = (col - 0.45) * contrast_boost + 0.45;
	if (melancholy_grade > 0.001) {
		col += vec3(0.014, 0.017, 0.026) * melancholy_grade * clamp(1.0 - lum * 1.6, 0.0, 1.0);
	}

	// 3. Delicate cassette VHS raster scanlines + rare faint dropout + thin head-switch snow
	if (vhs > 0.001) {
		float scan = sin(uv.y * 360.0 * 6.283185) * 0.5 + 0.5;
		col *= 1.0 - (1.0 - scan) * (0.030 * vhs);

		// Very sparse subtle tape speck
		float line_id = floor(uv.y * 240.0);
		float time_tick = floor(TIME * 10.0);
		float line_rng = hash(vec2(line_id, time_tick));
		float seg_seed = hash(vec2(line_id * 1.37, time_tick + 7.1));
		float streak_x = smoothstep(0.0, 0.03, fract(uv.x + seg_seed)) * smoothstep(0.12, 0.05, fract(uv.x + seg_seed));
		float dropout = step(0.9975, line_rng) * streak_x * (0.04 + 0.03 * seg_seed);
		col += vec3(dropout * vhs);

		float track_snow = (hash(uv * vec2(320.0, 220.0) + floor(TIME * 16.0)) - 0.5) * 0.022 * bar_band * vhs;
		float head_snow = (hash(vec2(floor(uv.x * 340.0), floor(uv.y * 270.0) + floor(TIME * 20.0))) - 0.5) * 0.07 * head_zone * vhs;
		col += track_snow + head_snow;
		col += vec3(0.008, 0.011, 0.015) * bar_band * vhs;
	}

	if (paper_texture_strength > 0.0005) {
		float fiber_a = value_noise(uv * vec2(420.0, 240.0));
		float fiber_b = value_noise(uv * vec2(170.0, 310.0) + 19.3);
		float paper = ((fiber_a * 0.6 + fiber_b * 0.4) - 0.5) * paper_texture_strength;
		col *= (1.0 + paper * vec3(1.0, 0.98, 0.94));
	}
	float n = (hash(uv * 1200.0 + floor(TIME * 6.0) * 0.17) - 0.5) * grain_strength;
	col += n;

	// 4. Soft corner vignette
	float vig = smoothstep(0.11, 0.68, dist_sq);
	col *= (1.0 - vig * vignette_strength);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
