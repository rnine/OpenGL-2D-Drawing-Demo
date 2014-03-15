#version 150

uniform vec2 p;

in vec4 position;
in vec4 color;

out vec2 texCoordV;
out vec2 positionV;
out vec4 colorV;

void main(void)
{
    colorV = color;
    texCoordV   = position.xy + vec2(0.5);
    positionV   = vec2(0.5) * (position.xy + p + vec2(1.0));
    gl_Position = position    + vec4(p, 0.0, 0.0);
}
