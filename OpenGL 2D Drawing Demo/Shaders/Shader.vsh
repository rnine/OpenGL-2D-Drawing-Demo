#version 150

uniform vec2 p;
uniform mat4 modelViewProjectionMatrix;

in vec4 position;
in vec4 color;

out vec2 texCoordV;
out vec2 positionV;
out vec4 colorV;

void main(void)
{
    colorV = color;
    vec4 mPos = modelViewProjectionMatrix * position;
    vec4 mP = modelViewProjectionMatrix * vec4(p, 0.0, 0.0);

    texCoordV   = mPos.xy + vec2(1.0);
    positionV   = vec2(0.5) * (mPos.xy + mP.xy + vec2(1.0));
    gl_Position = mPos + mP;
}
