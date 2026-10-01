shader_type spatial;
// Hit / attack-telegraph flash, drawn as a material overlay on every part of
// an entity or vehicle while it flashes (EntityVisual.set_flash,
// VehicleVisual.set_flash). One material per visual, attached only while the
// flash is on: no per-instance shader buffer (the Compatibility renderer caps
// it at 4096 slots, which a populated village overflows).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

// rgb = colour, a = amount.
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	ALBEDO = flash.rgb * flash.a * 1.5;
}
