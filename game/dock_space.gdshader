shader_type canvas_item;

uniform sampler2D space_mask : filter_linear, repeat_disable;
uniform sampler2D stars : source_color, filter_linear, repeat_enable;
uniform sampler2D asteroids : source_color, filter_linear, repeat_enable;
uniform vec2 drift;

void fragment() {
	// Маска начинается у правого края станции и включает просветы в перилах.
	vec2 mask_size = vec2(textureSize(space_mask, 0));
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	pixel.x -= 1.0 / TEXTURE_PIXEL_SIZE.x - mask_size.x;
	if (pixel.x >= 0.0) {
		float opening = texture(space_mask, pixel / mask_size).r;
		if (opening > 0.0) {
			vec2 sky_uv = pixel / vec2(textureSize(stars, 0));
			vec3 sky = texture(stars, sky_uv + vec2(drift.x, 0.0)).rgb;
			vec4 rock = texture(asteroids, sky_uv + vec2(drift.y, 0.0));
			COLOR.rgb = mix(COLOR.rgb, mix(sky, rock.rgb, rock.a), opening);
		}
	}
}
