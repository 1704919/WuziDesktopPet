 1 | shader_type canvas_item;
 2 | 
 3 | void fragment() {
 4 |     vec2 color_uv = vec2(UV.x * 0.5, UV.y);
 5 |     vec2 alpha_uv = vec2(UV.x * 0.5 + 0.5, UV.y);
 6 |     vec4 color_sample = texture(TEXTURE, color_uv);
 7 |     float alpha_sample = texture(TEXTURE, alpha_uv).r;
 8 |     COLOR = vec4(color_sample.rgb, alpha_sample);
 9 | }
