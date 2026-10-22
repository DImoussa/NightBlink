// Aura jaune (surbrillance.gd), partie 1 : voile très léger sur l'objet, un peu plus fort sur ses bords.
// Utile pour les portes encastrées, dont le halo (surbrillance.gdshader) est caché par le mur.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 couleur : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform float force = 0.012;
uniform float force_contour = 0.05;

void fragment() {
	float contour = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = couleur.rgb * (force + contour * force_contour);
}
