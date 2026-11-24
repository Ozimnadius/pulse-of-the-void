shader_type canvas_item;
uniform vec4 cloth : source_color = vec4(0.4, 0.7, 0.7, 1.0);

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// Тёплые насыщенные оттенки ткани в атласе; блики кожи и металл сохраняют цвет.
	if (pixel.r > pixel.g * 1.33 && pixel.g > pixel.b * 1.44) {
		pixel.rgb = min(vec3(1.0), cloth.rgb * (pixel.r / 0.78));
	}
	COLOR = pixel;
}
