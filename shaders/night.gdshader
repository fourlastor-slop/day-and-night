shader_type canvas_item;
render_mode blend_premul_alpha;

// Turns the day world into the same world by night: blue tones, and everything stays visible.
// Only paint is strongly saturated, so saturation alone tells this shader what to leave in colour.

const vec3 NAVY = vec3(0.106, 0.145, 0.278);
const vec3 MID = vec3(0.294, 0.384, 0.588);
const vec3 PALE = vec3(0.737, 0.792, 0.902);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.a > 0.001 ? c.rgb / c.a : c.rgb;
	float t = clamp((dot(rgb, vec3(0.3, 0.59, 0.11)) - 0.08) / 0.86, 0.0, 1.0);
	vec3 tone = t < 0.6 ? mix(NAVY, MID, t / 0.6) : mix(MID, PALE, (t - 0.6) / 0.4);
	tone = tone * 0.8 + rgb * vec3(0.55, 0.65, 1.0) * 0.2;
	float high = max(rgb.r, max(rgb.g, rgb.b));
	float low = min(rgb.r, min(rgb.g, rgb.b));
	float sat = high > 0.001 ? (high - low) / high : 0.0;
	vec3 lit = mix(tone, rgb * vec3(0.93, 0.95, 1.02), smoothstep(0.58, 0.72, sat));
	COLOR = vec4(lit * c.a, c.a);
}
