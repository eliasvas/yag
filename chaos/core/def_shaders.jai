//FIXME: This file shouldn't exist! These shaders need to be inside /gfx

BP_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;
uniform mat4 model;
uniform mat4 lsm[4]; // World Space -> light's Clip Space

layout(std140, binding = 0) uniform GlobalData {
   mat4 proj;
   mat4 view;
};

out VS_OUT
{
   vec2 tc;
   vec3 world_pos;
   vec3 normal;
   vec4 lsp_vert_coords[4];
} vs_out;

void main()
{
   gl_Position = proj*view*model*vec4(in_pos.xyz, 1.0);
   vs_out.world_pos = vec3(model*vec4(in_pos.xyz, 1.0));
   vs_out.normal = mat3(transpose(inverse(model))) * in_norm;
   for (int i = 0; i < 4; ++i) {
      vs_out.lsp_vert_coords[i] = lsm[i]*model*vec4(in_pos.xyz, 1.0);
   }
   vs_out.tc = in_tc;
}
DONE

BP_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT
{
   vec2 tc;
   vec3 world_pos;
   vec3 normal;
   vec4 lsp_vert_coords[4];
} fs_in;

struct BlinnPhongMaterial {
   sampler2D diffuse;
   vec4 diffuse_mod;
   sampler2D specular;
   vec4 specular_mod;
   float shininess;
};

struct DirLight {
    vec3 dir;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct PointLight {
    vec3 pos;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

// TODO: make multiple PointLight's possible
uniform PointLight point_light;

uniform DirLight dir_light;
uniform BlinnPhongMaterial material;
uniform vec3 view_pos;
uniform int cascade_count = 4;
uniform float cascade_plane_distances[4];
uniform mat4 view_csm; //for debug purposes we might want our view matrix to be different
uniform sampler2DArray shadow_map;


float g_shadow_bias = 0.005;
float calc_shadow(vec4 light_space_coords, int cascade_index) {
   vec3 ndc_coords = light_space_coords.xyz / light_space_coords.w;
   vec3 coords01 = ndc_coords * 0.5 + 0.5;
   vec2 light_tc = coords01.xy;
   float depth_in_shadow_map = texture(shadow_map, vec3(light_tc,cascade_index)).r;
   // 1. if our fragment is further that shadow maps far plane, we disable shadow
   if (coords01.z > 1.0) {
      return 0.0;
   }
   // 2. if the depth in shadow map is less than our fragment's, the fragment is in shadow
   float shadow = 0.0;
   vec2 texel_size = 1.0 / textureSize(shadow_map, 0).xy;
   for(int x = -1; x <= 1; ++x)
   {
     for(int y = -1; y <= 1; ++y)
     {
       float pcf_d = texture(shadow_map, vec3(coords01.xy + vec2(x, y) * texel_size,cascade_index)).r; 
       shadow += coords01.z - g_shadow_bias > pcf_d ? 1.0 : 0.0;        
     }
   }
   shadow /= 9.0;
   return shadow;
}


int calc_cascade_map_layer_index() {
   vec4 frag_pos_lsp = view_csm * vec4(fs_in.world_pos,1.0);
   float frag_depth = abs(frag_pos_lsp).z;
   int layer = -1;
   for (int i = 0; i < cascade_count; ++i) {
      if (frag_depth < cascade_plane_distances[i]) {
         layer = i;
         break;
      }
   }
   if (layer == -1) {
      layer = cascade_count;
   }
   return layer;
}

vec3 calc_dir_light(DirLight light, vec3 normal, vec3 view_dir)
{
    vec3 light_dir = normalize(light.dir);
    // diffuse factor 
    float diff = max(dot(normal, light_dir), 0.0);
    // specular factor
    //vec3 reflect_dir = reflect(-light_dir, normal);
    //float spec = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);
    vec3 halfway_dir = normalize(light_dir + view_dir);  
    float spec = pow(max(dot(normal, halfway_dir), 0.0), material.shininess);
    // combine results
    vec3 ambient  = light.ambient  * vec3(texture(material.diffuse, fs_in.tc)*material.diffuse_mod);
    vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.diffuse, fs_in.tc)*material.diffuse_mod);
    vec3 specular = light.specular * spec * vec3(texture(material.specular, fs_in.tc)*material.specular_mod);
    int layer = calc_cascade_map_layer_index();
    float s = calc_shadow(fs_in.lsp_vert_coords[layer], layer);
    return (ambient + (1.0-s)*(diffuse + specular));
}

vec3 calc_point_light(PointLight light, vec3 normal, vec3 world_pos, vec3 view_dir)
{
    vec3 light_dir = normalize(light.pos-world_pos);
    // diffuse factor
    float diff = max(dot(normal, light_dir), 0.0);
    // specular factor
    //vec3 reflect_dir = reflect(-light_dir, normal);
    //float spec = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);
    vec3 halfway_dir = normalize(light_dir + view_dir);  
    float spec = pow(max(dot(normal, halfway_dir), 0.0), material.shininess);
    // light attenuation
    float distance    = length(light.pos - world_pos);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));    
    // combine results
    vec3 ambient  = light.ambient  * vec3(texture(material.diffuse, fs_in.tc)*material.diffuse_mod);
    vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.diffuse, fs_in.tc)*material.diffuse_mod);
    vec3 specular = light.specular * spec * vec3(texture(material.specular, fs_in.tc)*material.specular_mod);
    ambient  *= attenuation;
    diffuse  *= attenuation;
    specular *= attenuation;
    return (ambient + diffuse + specular);
}

void main()
{
   vec3 norm = normalize(fs_in.normal);
   vec3 view_dir = normalize(view_pos - fs_in.world_pos);

   g_shadow_bias = max(0.05 * (1.0 - dot(norm, dir_light.dir)), 0.005);

   vec3 dl = calc_dir_light(dir_light, norm, view_dir);
   vec3 pl = calc_point_light(point_light, norm, fs_in.world_pos, view_dir);

   FragColor = vec4(pl + dl, texture(material.diffuse, fs_in.tc).w);
}
DONE

EMPTY_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

void main() {
   // gl_FragDepth = gl_FragCoord.z;
   float actual_depth = gl_FragCoord.z;
   FragColor = vec4(vec3(actual_depth),1.0);
}
DONE



WS_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_wpos;
layout (location = 1) in vec4 in_color;

// TODO: these should be a UBO
uniform mat4 proj;
uniform mat4 view;

out VS_OUT {
    vec4 color;
} vs_out;

void main()
{
   gl_Position = proj*view*vec4(in_wpos.xyz, 1.0);
   vs_out.color = in_color;
}
DONE

WS_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;

in VS_OUT {
    vec4 color;
} fs_in;

void main() {
   FragColor = fs_in.color;
}
DONE
