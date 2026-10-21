// Murs de la map (textures précalculées dans Blender) éclairés par la torche.
// Certaines faces de la map (escaliers) ont des normales cassées à l'export : on recalcule
// la normale depuis la géométrie, tournée vers la caméra, pour que la torche les éclaire comme le reste.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D texture_mur : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 luminosite : source_color = vec4(2.0, 2.0, 2.0, 1.0); // éclaircit la texture (très sombre)

void fragment() {
	ALBEDO = texture(texture_mur, UV).rgb * luminosite.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n, VIEW) < 0.0 ? -n : n;
}
