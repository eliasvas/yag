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
   sampler2D specular;
   float shininess;
};
uniform BlinnPhongMaterial material;

struct Light {
    vec3 pos;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};
uniform Light light;

out vec4 FragColor;

void main()
{
   // calc diffuse 'effect'
   vec3 norm = normalize(f_normal);
   vec3 light_dir = normalize(light.pos - world_pos);
   float diff = max(dot(norm, light_dir), 0.0);

   // calc spec 'effect'
   float specular_str = 0.5;
   vec3 view_dir = normalize(view_pos - world_pos);
   vec3 reflect_dir = reflect(-light_dir, norm);
   float spec = pow(max(dot(view_dir, reflect_dir), 0.0), material.shininess);

   // calc final colors
   vec3 ambient  = light.ambient  * vec3(texture(material.diffuse, tc));
   vec3 diffuse  = light.diffuse  * diff * vec3(texture(material.diffuse, tc));  
   vec3 specular = light.specular * spec * vec3(texture(material.specular, tc));
   FragColor = vec4(ambient + diffuse + specular, 1.0);
}
DONE

LIGHT_FRAG_SHADER :: #string DONE
#version 430 core
out vec4 FragColor;
void main() {
   FragColor = vec4(1,1,1,1);
}
DONE



