#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uCurlPos;
uniform vec2 uCurlDir;
uniform float uRadius;
uniform float uShadowWidth;
uniform float uBackInkOpacity;
uniform float uReverse;
uniform float uBindingGuard;
uniform vec4 uPaperColor;
uniform sampler2D uCurrentPage;
uniform sampler2D uTargetPage;

out vec4 fragColor;

const float kPi = 3.14159265359;

vec4 shadeBack(vec4 source, float lighting) {
    vec3 inkOnPaper = mix(uPaperColor.rgb, source.rgb, uBackInkOpacity);
    float paperLuma = dot(uPaperColor.rgb, vec3(0.299, 0.587, 0.114));
    float inkLuma = dot(inkOnPaper, vec3(0.299, 0.587, 0.114));
    vec3 lowContrast = mix(vec3(paperLuma), vec3(inkLuma), 0.55);
    inkOnPaper = mix(inkOnPaper, lowContrast, 0.28);
    return vec4(inkOnPaper * lighting, 1.0);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;

    // Forward turns keep the source's left binding seam flat. Reverse turns
    // keep the target's mirrored right seam flat. The host also clamps the
    // moving curl line to the leaf bounds, so this is a shader-level hard lock
    // rather than a decorative spine overlay.
    float guardUv = uBindingGuard / max(uSize.x, 1.0);
    if (uReverse < 0.5 && uv.x <= guardUv) {
        fragColor = texture(uCurrentPage, uv);
        return;
    }
    if (uReverse >= 0.5 && uv.x >= 1.0 - guardUv) {
        fragColor = texture(uTargetPage, uv);
        return;
    }

    vec2 dir = normalize(uCurlDir);
    vec2 curlPos = uCurlPos;

    vec2 origin;
    if (abs(dir.x) > 0.001) {
        origin = curlPos - dir * (curlPos.x / dir.x);
    } else {
        origin = vec2(0.0, curlPos.y);
    }
    origin = clamp(origin, 0.0, 1.0);

    float fragDist = dot(uv - origin, dir);
    float curlDist = dot(curlPos - origin, dir);
    float d = fragDist - curlDist;
    float r = uRadius;
    vec2 linePoint = uv - d * dir;
    vec4 color;

    if (d > r) {
        color = texture(uTargetPage, uv);
        float shadowDistance = d - r;
        float shadowSpan = max(uShadowWidth * r * 3.0, 0.0001);
        if (shadowDistance < shadowSpan) {
            float shadow = mix(
                0.86,
                1.0,
                clamp(shadowDistance / shadowSpan, 0.0, 1.0)
            );
            color.rgb *= shadow;
        }
    } else if (d > 0.0 && r > 0.0) {
        float theta = asin(clamp(d / r, -1.0, 1.0));
        vec2 frontPoint = linePoint + dir * (theta * r);
        vec2 backPoint = linePoint + dir * ((kPi - theta) * r);

        if (backPoint.x >= 0.0 && backPoint.x <= 1.0 &&
            backPoint.y >= 0.0 && backPoint.y <= 1.0) {
            vec4 source = texture(uCurrentPage, backPoint);
            float light = mix(
                0.78,
                0.94,
                clamp(theta / (kPi * 0.5), 0.0, 1.0)
            );
            color = shadeBack(source, light);
        } else if (frontPoint.x >= 0.0 && frontPoint.x <= 1.0 &&
                   frontPoint.y >= 0.0 && frontPoint.y <= 1.0) {
            color = texture(uCurrentPage, frontPoint);
            color.rgb *= mix(
                0.94,
                1.0,
                clamp(theta / (kPi * 0.5), 0.0, 1.0)
            );
        } else {
            color = texture(uTargetPage, uv);
        }
    } else if (r > 0.0) {
        vec2 backPoint = linePoint + dir * (kPi * r - d);
        if (backPoint.x >= 0.0 && backPoint.x <= 1.0 &&
            backPoint.y >= 0.0 && backPoint.y <= 1.0) {
            vec4 source = texture(uCurrentPage, backPoint);
            float light = mix(
                0.80,
                0.96,
                clamp(-d / (r * 2.0), 0.0, 1.0)
            );
            color = shadeBack(source, light);
        } else {
            color = texture(uCurrentPage, uv);
        }
    } else {
        color = texture(uCurrentPage, uv);
    }

    fragColor = color;
}
