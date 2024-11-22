SAMPLE_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec3 in_pos;
layout (location = 0) in vec3 in_norm;
layout (location = 0) in vec2 in_tc;
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

SAMPLE_FRAG_SHADER :: #string DONE
#version 430 core

in vec2 tc;
in vec3 world_pos;
in vec3 f_normal;

out vec4 FragColor;

uniform sampler2D tex0;
uniform vec4 light_color = vec4(1,1,1,1);
uniform vec4 color;
uniform vec3 light_pos = vec3(8, 4.0, 8.0);
uniform vec3 view_pos;

void main()
{
   float ambient_str = 0.1;
   vec3 ambient = ambient_str * light_color.xyz;

   vec3 norm = normalize(f_normal);
   vec3 light_dir = normalize(light_pos - world_pos);

   float diff = max(dot(norm, light_dir), 0.0);
   vec3 diffuse = diff * light_color.xyz;

   float specular_str = 0.5;
   vec3 view_dir = normalize(view_pos - world_pos);
   vec3 reflect_dir = reflect(-light_dir, norm);
   float spec = pow(max(dot(view_dir, reflect_dir), 0.0), 128);
   vec3 specular = specular_str * spec * light_color.xyz;



   vec3 result = (ambient+diffuse+specular) * color.xyz;

   FragColor = vec4(texture2D(tex0, tc).xyz, 1.0);
   FragColor.xyz *= result;
}
DONE



