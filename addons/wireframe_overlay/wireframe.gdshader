shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 wire_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform float wire_width : hint_range(0.5, 5.0) = 1.2;

void fragment() {
	// Barycentric coords are stored in vertex COLOR by the plugin
	vec3 bary = COLOR.rgb;
	vec3 fw = fwidth(bary);
	vec3 edge3 = smoothstep(fw * 0.5, fw * (wire_width + 0.5), bary);
	float interior = min(min(edge3.x, edge3.y), edge3.z);

	if (interior > 0.9) discard;

	ALBEDO = wire_color.rgb;
	ALPHA = (1.0 - interior) * wire_color.a;
}
