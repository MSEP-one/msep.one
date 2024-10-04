// NOTE: Shader automatically converted from Godot Engine 4.0.1.rc's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

// wavy uv
const float wave_aplitude = 0.05;
const float wave_frequency = 3.230;
const float wave_aplitude_x = 0.08;
const float wave_frequency_x = 7.000;

//
const float DETAIL_POWER = 1.0;
const float COLOR_ADDITIONAL_POWER = 0.05;
const float ATLAS_SIZE_XY = 4.0;
const float UV_ATLAS_SIZE = 1.0 / ATLAS_SIZE_XY;

uniform float atlas_id: hint_range(0, 15, 1);
uniform vec4 noise_albedo : source_color;
uniform vec4 albedo : source_color;
uniform sampler2D texture_noise : source_color,filter_linear_mipmap,repeat_enable;
uniform float point_size : hint_range(0,128);
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r,filter_linear_mipmap,repeat_enable;
uniform float specular;
uniform float metallic;
uniform float rim : hint_range(0,1);
uniform float rim_tint : hint_range(0,1);
uniform sampler2D texture_rim : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform float clearcoat : hint_range(0,1);
uniform float clearcoat_roughness : hint_range(0,1);
uniform sampler2D texture_clearcoat : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_detail_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_detail_normal : hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D texture_detail_mask : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;


vec2 wave(vec2 uv, float time) {
	float speed_y = 1.0;
	float speed_x = 0.8;
	uv.y += wave_aplitude * sin(wave_frequency * (uv.x + time * speed_y));
	uv.x += wave_aplitude_x * sin(wave_frequency_x * (uv.y + time * speed_x));
	return uv;
}


vec3 srgb(vec3 in_color) {
	return mix(pow((in_color + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), in_color * (1.0 / 12.92), lessThan(in_color, vec3(0.04045)));
}


void vertex() {
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
	
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	UV2=UV2*uv2_scale.xy+uv2_offset.xy;
}


void fragment() {
	
	// this factor value is arbitrary, the shader don't give exact the same results color wise as it's multimesh counterpart (not sure why)
	// and it's to mitigate that problem a little (brightness is right now, but it's slightly different tone)
	vec4 final_noise_albedo = noise_albedo * 1.15;
	
	vec2 atlas_pos = vec2(mod(atlas_id, ATLAS_SIZE_XY), floor(atlas_id / ATLAS_SIZE_XY)) * UV_ATLAS_SIZE;
	//do not use edge pixels, prevents floating point problems on the edges
	vec4 atlas_uv = vec4(atlas_pos + 0.001, UV_ATLAS_SIZE - 0.002, UV_ATLAS_SIZE - 0.002);
	vec2 base_uv = atlas_uv.xy + atlas_uv.zw * fract(wave(UV, TIME * 0.05));
	
	vec2 base_uv2 = UV2;
	vec4 noise_tex = texture(texture_noise,base_uv);
	noise_tex.rgb = mix(pow((noise_tex.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)),vec3(2.4)),noise_tex.rgb.rgb * (1.0 / 12.92),lessThan(noise_tex.rgb,vec3(0.04045)));
	noise_tex *= final_noise_albedo;
	
	//
	ALBEDO = albedo.rgb + albedo.rgb * COLOR_ADDITIONAL_POWER;
	
	//noise tex is an addon to base color
	noise_tex *= final_noise_albedo;
	vec3 albedofinal = mix(ALBEDO.rgb,ALBEDO.rgb+noise_tex.rgb,noise_tex.a);
	ALBEDO.rgb = albedofinal.rgb;
	
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(1.0,0.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	vec2 rim_tex = texture(texture_rim,base_uv).xy;
	RIM = rim*rim_tex.x;	RIM_TINT = rim_tint*rim_tex.y;
	vec2 clearcoat_tex = texture(texture_clearcoat,base_uv).xy;
	CLEARCOAT = clearcoat*clearcoat_tex.x;	CLEARCOAT_ROUGHNESS = clearcoat_roughness*clearcoat_tex.y;
	vec4 detail_tex = texture(texture_detail_albedo,base_uv2);
	vec4 detail_norm_tex = texture(texture_detail_normal,base_uv2);
	vec4 detail_mask_tex = texture(texture_detail_mask,base_uv);
	vec3 detail = mix(ALBEDO.rgb,ALBEDO.rgb+detail_tex.rgb * DETAIL_POWER,detail_tex.a);
	vec3 detail_norm = mix(NORMAL_MAP,detail_norm_tex.rgb,detail_tex.a);
	NORMAL_MAP = mix(NORMAL_MAP,detail_norm,detail_mask_tex.r);
	ALBEDO.rgb = mix(ALBEDO.rgb,detail,detail_mask_tex.r);
}

