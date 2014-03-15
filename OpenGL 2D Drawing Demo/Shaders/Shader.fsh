#version 150

in vec2 positionV;
in vec2 texCoordV;
in vec4 colorV;

out vec4 fragColor;

uniform vec2 p;

uniform sampler2D background;
uniform sampler2D hole;

void main(void)
{
    vec4 holeColor = texture(hole, texCoordV);

    fragColor = colorV + (1.0 - holeColor.a) * texture(background, positionV);
}
