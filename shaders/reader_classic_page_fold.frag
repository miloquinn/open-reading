#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uFoldPoint;
uniform vec2 uFoldNormal;
uniform float uShadowWidth;
uniform float uBackInkOpacity;
uniform float uReverse;
uniform float uBindingGuard;
uniform vec4 uPaperColor;
uniform sampler2D uCurrentPage;

out vec4 fragColor;

bool insidePage(vec2 point) {
    return point.x >= 0.0 && point.x <= uSize.x &&
           point.y >= 0.0 && point.y <= uSize.y;
}

void main() {
    vec2 point = FlutterFragCoord().xy;
    vec2 normal = normalize(uFoldNormal);

    // The source sheet is glued to the left edge on a forward turn. During a
    // backward turn the current target sheet owns the mirrored right edge.
    // Keep that narrow physical seam unchanged even when a steep reflected
    // fold would otherwise sample across it.
    if (uReverse < 0.5 && point.x <= uBindingGuard) {
        fragColor = texture(uCurrentPage, point / uSize);
        return;
    }
    if (uReverse >= 0.5 && point.x >= uSize.x - uBindingGuard) {
        fragColor = vec4(0.0);
        return;
    }

    float signedDistance = dot(point - uFoldPoint, normal);
    float shadowWidth = max(uShadowWidth, 1.0);

    // The positive half-plane is the source paper that has lifted away. The
    // target leaf is painted below this shader; only its cast shadow remains.
    if (signedDistance > 0.0) {
        float castShadow = 1.0 - smoothstep(0.0, shadowWidth, signedDistance);
        fragColor = vec4(0.0, 0.0, 0.0, castShadow * 0.18);
        return;
    }

    vec2 reflected = point - 2.0 * signedDistance * normal;
    if (insidePage(reflected)) {
        vec4 source = texture(uCurrentPage, reflected / uSize);
        vec3 mutedInk = mix(uPaperColor.rgb, source.rgb, uBackInkOpacity);
        float rollLight = mix(
            0.82,
            1.02,
            smoothstep(-shadowWidth * 1.8, 0.0, signedDistance)
        );
        fragColor = vec4(mutedInk * rollLight, 1.0);
        return;
    }

    vec4 source = texture(uCurrentPage, point / uSize);
    float creaseShade =
        1.0 - smoothstep(0.0, shadowWidth * 0.72, -signedDistance);
    source.rgb *= 1.0 - creaseShade * 0.12;
    fragColor = source;
}
