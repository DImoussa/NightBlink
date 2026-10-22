// Aura jaune des objets avec lesquels on peut interagir (surbrillance.gd) :
// une coque un peu plus grande que l'objet, dont on ne voit que le bord qui dépasse (halo autour de la silhouette).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front;

uniform vec4 couleur : source_color = vec4(1.0, 0.78, 0.2, 1.0);
uniform float epaisseur = 0.02;   // mètres : largeur du halo autour de l'objet
uniform float force = 0.35;

void vertex() {
	// Épaisseur en mètres, quelle que soit l'échelle de l'objet (la clé est minuscule dans son modèle)
	VERTEX += NORMAL * epaisseur / length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	ALBEDO = couleur.rgb * force;
}
