#version 150

uniform vec2 p;

in vec4 position;
in vec4 color;

out vec4 colorV;

void main(void)
{
    colorV = color;
    gl_Position = vec4(p, 0.0, 0.0) + position;
}
