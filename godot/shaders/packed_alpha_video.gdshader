shader_type canvas_item;

void fragment() {
    vec2 color_uv = vec2(UV.x * 0.5, UV.y);
    vec2 alpha_uv = vec2(UV.x * 0.5 + 0.5, UV.y);
    vec4 color_sample = texture(TEXTURE, color_uv);
    float alpha_sample = texture(TEXTURE, alpha_uv).r;
    COLOR = vec4(color_sample.rgb, alpha_sample);
}
