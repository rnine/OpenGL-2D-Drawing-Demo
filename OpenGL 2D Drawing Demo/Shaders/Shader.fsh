#version 150

uniform sampler2D meter;

in vec2 texCoord;

out vec4 fragColor;

void main(void)
{
    fragColor = texture(meter, texCoord);
}
