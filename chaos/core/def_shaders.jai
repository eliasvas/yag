BP_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;
uniform mat4 proj;
uniform mat4 view;
uniform mat4 model;
uniform mat4 light_space_matrix; // World Space -> light's Clip Space
out vec2 tc;
out vec3 world_pos;
out vec3 f_normal;
out vec4 f_lsp_vert_coords;
void main()
{
   gl_Position = proj*view*model*vec4(in_pos.xyz, 1.0);
   world_pos = vec3(model*vec4(in_pos.xyz, 1.0));
   f_normal = mat3(transpose(inverse(model))) * in_norm;
   f_lsp_vert_coords = light_space_matrix*model*vec4(in_pos.xyz, 1.0);
   tc = in_tc;
}
DONE

BP_FRAG_SHADER :: #string DONE
#version 430 core

in vec2 tc;
in vec3 world_pos;
in vec3 f_normal;
in vec4 f_lsp_vert_coords;
uniform sampler2D shadow_map;


uniform vec3 view_pos;
struct BlinnPhongMaterial {
   sampler2D diffuse;
   vec4 diffuse_mod;
   sampler2D specular;
   vec4 specular_mod;
   float shininess;
};
uniform BlinnPhongMaterial material;

struct DirLight {
    vec3 dir;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};
uniform DirLight dir_light;

struct PointLight {
    vec3 pos;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};
// TODO: make multiple
uniform PointLight point_light;

out vec4 FragColor;

float calc_shadow(vec4 light_space_coords) {
   vec3 ndc_coords = light_space_coords.xyz / light_space_coords.w;
   vec2 light_tc = ndc_coords.xy * 0.5 + 0.5;
   float depth_in_shadow_map = texture(shadow_map, light_tc).r;
   if (depth_in_shadow_map < ndc_coords.z) {
      return 1.0;
   }
   return 0.0;
}

vec3 calc_dir_light(DirLight light, vec3 normal, vec3 view_dir)
{
    vec3 light_dir = normalize(-light.dir);
    // diffuse factor 
    float diff = max(dot(normal, light_dir), 0.0);
    // specular factor
    //vec3 reflect_dir = reflect(-light_dir, normal);
    //float spec = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);
    vec3 halfway_dir = normalize(light_dir + view_dir);  
    float spec = pow(max(dot(normal, halfway_dir), 0.0), material.shininess);
    // combine results
    vec3 ambient  = light.ambient  * vec3(texture(material.diffuse, tc)*material.diffuse_mod);
    vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.diffuse, tc)*material.diffuse_mod);
    vec3 specular = light.specular * spec * vec3(texture(material.specular, tc)*material.specular_mod);
    float s = calc_shadow(f_lsp_vert_coords);
    return (ambient + (1.0-s)*(diffuse + specular));
}

vec3 calc_point_light(PointLight light, vec3 normal, vec3 world_pos, vec3 view_dir)
{
    vec3 light_dir = normalize(light.pos- world_pos);
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
    vec3 ambient  = light.ambient  * vec3(texture(material.diffuse, tc)*material.diffuse_mod);
    vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.diffuse, tc)*material.diffuse_mod);
    vec3 specular = light.specular * spec * vec3(texture(material.specular, tc)*material.specular_mod);
    ambient  *= attenuation;
    diffuse  *= attenuation;
    specular *= attenuation;
    return (ambient + diffuse + specular);
}

void main()
{
   vec3 norm = normalize(f_normal);
   vec3 view_dir = normalize(view_pos - world_pos);

   vec3 dl = calc_dir_light(dir_light, norm, view_dir);
   vec3 pl = calc_point_light(point_light, norm, world_pos, view_dir);

   FragColor = vec4(pl + dl, 1.0);
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



