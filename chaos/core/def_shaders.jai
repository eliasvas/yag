SAMPLE_VERT_SHADER :: #string DONE
#version 430 core
layout (location = 0) in vec2 in_pos;
uniform vec4 color;
uniform mat4 MVP;
out vec4 c;
out vec2 tc;
void main()
{
   gl_Position = MVP*vec4(in_pos.xy, 0.0, 1.0);
   c = color;
   tc = (in_pos.xy + 1.0)/2.0;
}
DONE

SAMPLE_FRAG_SHADER :: #string DONE
#version 430 core
in vec4 c;
in vec2 tc;
out vec4 FragColor;
uniform sampler2D tex0;
void main()
{
   FragColor = c;
   FragColor = texture2D(tex0, tc);
   FragColor.a = 1.0;
   FragColor *= c;
}
DONE



