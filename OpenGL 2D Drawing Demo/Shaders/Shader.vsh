#version 150

uniform mat4 TLD_MVPMatrix;

in vec2 i_position;
in vec2 i_textCoord;

out vec2 texCoord;

void main(void)
{
    texCoord = i_textCoord;
    gl_Position = TLD_MVPMatrix * vec4(i_position, 0.0, 1.0);
}
