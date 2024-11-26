BP_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 1) in vec3 in_norm;
layout (location = 2) in vec2 in_tc;
uniform mat4 proj;
uniform mat4 view;
uniform mat4 model;
out vec2 tc;
out vec3 world_pos;
out vec3 f_normal;
void main()
{
   gl_Position = proj*view*model*vec4(in_pos.xyz, 1.0);
   world_pos = vec3(model*vec4(in_pos.xyz, 1.0));
   f_normal = mat3(transpose(inverse(model))) * in_norm;
   tc = in_tc;
}
DONE

BP_FRAG_SHADER :: #string DONE
#version 430 core

in vec2 tc;
in vec3 world_pos;
in vec3 f_normal;


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
    return (ambient + diffuse + specular);
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

LIGHT_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;
void main() {
   FragColor = vec4(1,1,1,1);
}
DONE



