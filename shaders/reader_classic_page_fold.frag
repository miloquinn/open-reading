#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uPosA;
uniform vec2 uPosB;
uniform float uBindingOnRight;
uniform sampler2D uSourcePage;

out vec4 fragColor;

float denominator(vec2 line1a, vec2 line1b, vec2 line2a, vec2 line2b) {
    return ((line1a.x - line1b.x) * (line2a.y - line2b.y))
         - ((line1a.y - line1b.y) * (line2a.x - line2b.x));
}

vec2 lineLineIntersection(
    float den,
    vec2 line1a,
    vec2 line1b,
    vec2 line2a,
    vec2 line2b
) {
    float x1 = ((line1a.x * line1b.y) - (line1a.y * line1b.x))
        * (line2a.x - line2b.x);
    float x2 = (line1a.x - line1b.x)
        * ((line2a.x * line2b.y) - (line2a.y * line2b.x));
    float y1 = ((line1a.x * line1b.y) - (line1a.y * line1b.x))
        * (line2a.y - line2b.y);
    float y2 = (line1a.y - line1b.y)
        * ((line2a.x * line2b.y) - (line2a.y * line2b.x));
    return vec2((x1 - x2) / den, (y1 - y2) / den);
}

bool isRayIntersectSegment(vec2 p, inout vec2 a, inout vec2 b) {
    if (a.y == b.y) {
        return false;
    }
    if (a.y > b.y) {
        vec2 swap = a;
        a = b;
        b = swap;
    }
    if (p.y < a.y || p.y >= b.y) {
        return false;
    }
    float t = (p.y - a.y) / (b.y - a.y);
    float x = a.x + t * (b.x - a.x);
    return x > p.x;
}

bool isInsideQuad(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
    int intersections = 0;
    vec2 a1 = a;
    vec2 b1 = b;
    vec2 a2 = b;
    vec2 b2 = c;
    vec2 a3 = c;
    vec2 b3 = d;
    vec2 a4 = d;
    vec2 b4 = a;
    intersections += int(isRayIntersectSegment(p, a1, b1));
    intersections += int(isRayIntersectSegment(p, a2, b2));
    intersections += int(isRayIntersectSegment(p, a3, b3));
    intersections += int(isRayIntersectSegment(p, a4, b4));
    return mod(float(intersections), 2.0) > 0.0;
}

vec2 canonicalPoint(vec2 physicalPoint) {
    return uBindingOnRight > 0.5
        ? vec2(uSize.x - physicalPoint.x, physicalPoint.y)
        : physicalPoint;
}

vec2 physicalPoint(vec2 canonical) {
    return uBindingOnRight > 0.5
        ? vec2(uSize.x - canonical.x, canonical.y)
        : canonical;
}

vec4 sampleSource(vec2 canonical) {
    return texture(uSourcePage, physicalPoint(canonical) / uSize);
}

bool prepareClippedContent(
    vec2 p,
    vec2 topCurlOffset,
    vec2 bottomCurlOffset
) {
    return isInsideQuad(
        p,
        vec2(0.0),
        topCurlOffset,
        bottomCurlOffset,
        vec2(0.0, uSize.y)
    );
}

mat3 matTranslate(vec2 p) {
    return mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0),
        vec3(p.x, p.y, 1.0)
    );
}

mat3 matRotate(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(c, -s, 0.0),
        vec3(s, c, 0.0),
        vec3(0.0, 0.0, 1.0)
    );
}

vec2 curlTransform(vec2 pos, vec2 bottomCurlOffset, float angle) {
    mat3 translateToPivot = matTranslate(-bottomCurlOffset);
    mat3 translateBack = matTranslate(bottomCurlOffset);
    mat3 rotation = matRotate(angle);
    mat3 mirrorX = mat3(
        vec3(-1.0, 0.0, 0.0),
        vec3(0.0, 1.0, 0.0),
        vec3(0.0, 0.0, 1.0)
    );
    return (
        (translateBack * rotation * mirrorX * translateToPivot)
            * vec3(pos, 1.0)
    ).xy;
}

vec2 offsetRotate(vec2 offset, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(
        offset.x * c - offset.y * s,
        offset.x * s + offset.y * c
    );
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    vec2 p = canonicalPoint(FlutterFragCoord().xy);
    fragColor = vec4(0.0);

    if (all(equal(uPosA, vec2(0.0)))
            && all(equal(uPosB, vec2(0.0, uSize.y)))) {
        return;
    }

    float topDen = denominator(vec2(0.0), vec2(uSize.x, 0.0), uPosA, uPosB);
    float bottomDen = denominator(
        vec2(0.0, uSize.y),
        vec2(uSize.x, uSize.y),
        uPosA,
        uPosB
    );
    if (topDen == 0.0 || bottomDen == 0.0) {
        fragColor = sampleSource(p);
        return;
    }

    if (uPosA.x == uSize.x && uPosA.y == 0.0
            && uPosB.x == uSize.x && uPosB.y == uSize.y) {
        fragColor = sampleSource(p);
        return;
    }

    vec2 topIntersection = lineLineIntersection(
        topDen,
        vec2(0.0),
        vec2(uSize.x, 0.0),
        uPosA,
        uPosB
    );
    vec2 bottomIntersection = lineLineIntersection(
        bottomDen,
        vec2(0.0, uSize.y),
        vec2(uSize.x, uSize.y),
        uPosA,
        uPosB
    );

    // The recovered hard binding: both crease intersections are clamped to
    // canonical x=0, and the entire binding-side quad remains identity source.
    vec2 topCurlOffset = vec2(max(0.0, topIntersection.x), topIntersection.y);
    vec2 bottomCurlOffset = vec2(
        max(0.0, bottomIntersection.x),
        bottomIntersection.y
    );

    if (prepareClippedContent(p, topCurlOffset, bottomCurlOffset)) {
        fragColor = sampleSource(p);
    }

    vec2 polygon1;
    vec2 polygon2;
    vec2 polygon3;
    vec2 polygon4;

    if (topCurlOffset.x < uSize.x) {
        polygon1 = topCurlOffset;
        polygon2 = vec2(uSize.x, topCurlOffset.y);
    } else {
        float den = denominator(
            topCurlOffset,
            bottomCurlOffset,
            vec2(uSize.x, 0.0),
            vec2(uSize.x, uSize.y)
        );
        vec2 hit = den != 0.0
            ? lineLineIntersection(
                den,
                topCurlOffset,
                bottomCurlOffset,
                vec2(uSize.x, 0.0),
                vec2(uSize.x, uSize.y)
            )
            : topCurlOffset;
        polygon1 = hit;
        polygon2 = hit;
    }

    if (bottomCurlOffset.x < uSize.x) {
        polygon3 = vec2(uSize.x, uSize.y);
        polygon4 = bottomCurlOffset;
    } else {
        float den = denominator(
            topCurlOffset,
            bottomCurlOffset,
            vec2(uSize.x, 0.0),
            vec2(uSize.x, uSize.y)
        );
        vec2 hit = den != 0.0
            ? lineLineIntersection(
                den,
                topCurlOffset,
                bottomCurlOffset,
                vec2(uSize.x, 0.0),
                vec2(uSize.x, uSize.y)
            )
            : bottomCurlOffset;
        polygon3 = hit;
        polygon4 = hit;
    }

    vec2 lineVector = topCurlOffset - bottomCurlOffset;
    float angle = 3.14159274 - (atan(lineVector.y, lineVector.x) * 2.0);
    vec2 transformedPos = curlTransform(p, bottomCurlOffset, angle);

    vec2 shadowOffset = offsetRotate(
        vec2(5.0, 0.0),
        6.28318548 - angle
    );
    vec2 transformedShadow = transformedPos - shadowOffset;
    float distanceToCurl = min(
        min(
            sdSegment(transformedShadow, polygon1, polygon2),
            sdSegment(transformedShadow, polygon2, polygon3)
        ),
        min(
            sdSegment(transformedShadow, polygon3, polygon4),
            sdSegment(transformedShadow, polygon1, polygon4)
        )
    );
    // The curl polygon collapses at both flat terminal poses. Fade its shadow
    // continuously as the crease approaches either edge so the final exact
    // identity/transparent frame does not pop a dark seam on or off.
    float creaseCenterX = clamp(
        (topCurlOffset.x + bottomCurlOffset.x) * 0.5,
        0.0,
        uSize.x
    );
    float edgeFadeDistance = max(1.0, min(48.0, uSize.x * 0.12));
    float terminalShadowFade =
        smoothstep(0.0, edgeFadeDistance, creaseCenterX)
        * smoothstep(
            0.0,
            edgeFadeDistance,
            uSize.x - creaseCenterX
        );
    float shadow = smoothstep(30.0, 0.0, distanceToCurl)
        * terminalShadowFade;

    if (fragColor.a == 0.0) {
        fragColor.a = mix(0.0, 1.0, shadow * 0.2);
    } else {
        fragColor.rgb = mix(fragColor.rgb, vec3(0.0), shadow * 0.2);
    }

    if (isInsideQuad(
            transformedPos,
            polygon1,
            polygon2,
            polygon3,
            polygon4
        )) {
        fragColor = sampleSource(transformedPos);
        fragColor.rgb = mix(fragColor.rgb, vec3(1.0), 0.10);
    }
}
