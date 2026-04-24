#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

struct Uniforms {
    float2 viewportSize;
    float2 mousePosition;
    float time;
    float brightness;
    float colorTemperature;
    float borderWidth;
    float maxHDRFactor;
    float currentHDRFactor;
    float primaryAngle;
    float secondaryAngle;
    float pointerRadius;
    float pointerFeather;
    float screenScale;
    float professionalPrimaryEnergy;
    float professionalSecondaryEnergy;
    float professionalRingScale;
    float professionalKeyHDRIntensityBoost;
    uint effectMode;
    uint hasMouse;
    uint isHDREnabled;
    uint padding;
};

struct EffectState {
    float3 leadingColor;
    float3 trailingColor;
    float leadingPower;
    float trailingPower;
    float ambientPower;
};

vertex VertexOut displayFillVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    return out;
}

float roundedRectSDF(float2 point, float2 center, float2 halfSize, float radius) {
    float2 q = abs(point - center) - (halfSize - radius);
    return length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float ringMask(float2 point, constant Uniforms& uniforms, float thicknessScale, float blur) {
    float2 size = uniforms.viewportSize;
    float thickness = max(1.0, uniforms.borderWidth * thicknessScale);
    float radius = max(44.0, min(size.x, size.y) * 0.18 + (uniforms.borderWidth * 0.7));
    float feather = max(1.0, blur);
    float outer = roundedRectSDF(point, size * 0.5, size * 0.5, radius);
    float inner = roundedRectSDF(
        point,
        size * 0.5,
        max(float2(1.0), (size * 0.5) - thickness),
        max(0.0, radius - thickness)
    );
    float outerAlpha = 1.0 - smoothstep(-feather, feather, outer);
    float innerAlpha = smoothstep(-feather, feather, inner);
    return saturate(outerAlpha * innerAlpha);
}

float softDisc(float2 point, float2 center, float radius, float blur) {
    float distanceToEdge = distance(point, center) - max(1.0, radius);
    float feather = max(1.0, blur);
    return 1.0 - smoothstep(-feather, feather, distanceToEdge);
}

float2 orientedLocalPoint(float2 point, float2 center, float angle) {
    float radians = angle * 0.017453292519943295;
    float2 delta = point - center;
    return float2(
        (delta.x * cos(radians)) - (delta.y * sin(radians)),
        (delta.x * sin(radians)) + (delta.y * cos(radians))
    );
}

float softEllipse(float2 point, float2 center, float angle, float2 radii, float blur) {
    float2 localPoint = orientedLocalPoint(point, center, angle);
    float2 normalized = localPoint / max(float2(1.0), radii);
    float distanceToEdge = (length(normalized) - 1.0) * min(radii.x, radii.y);
    return 1.0 - smoothstep(-max(1.0, blur), max(1.0, blur), distanceToEdge);
}

float beamFalloff(float2 point, float2 center, float angle, float radiusX) {
    float localX = orientedLocalPoint(point, center, angle).x / max(1.0, radiusX);
    return 0.38 + (0.62 * (1.0 - smoothstep(-0.20, 0.92, localX)));
}

float radialGlow(float2 point, float2 center, float radius, float softness, float cutoffStart, float cutoffEnd) {
    float normalizedDistance = distance(point, center) / max(1.0, radius);
    float glow = exp2(-(normalizedDistance * normalizedDistance) * max(0.001, softness));
    float cutoff = 1.0 - smoothstep(cutoffStart, cutoffEnd, normalizedDistance);
    return glow * cutoff;
}

float3 blendColor(float3 a, float3 b, float amount) {
    return a + ((b - a) * saturate(amount));
}

float3 temperatureColor(float value) {
    float3 warm = float3(1.0, 0.74, 0.42);
    float3 neutral = float3(1.0, 0.985, 0.965);
    float3 cool = float3(0.58, 0.79, 1.0);
    float t = saturate(value);

    if (t <= 0.5) {
        return blendColor(warm, neutral, t / 0.5);
    }

    return blendColor(neutral, cool, (t - 0.5) / 0.5);
}

float3 highlightColor(constant Uniforms& uniforms) {
    float3 baseColor = temperatureColor(uniforms.colorTemperature);
    if (uniforms.isHDREnabled == 1) {
        return baseColor;
    }

    return blendColor(baseColor, float3(1.0), 0.36);
}

float effectiveHDRFactor(constant Uniforms& uniforms) {
    float potentialHeadroom = max(1.0, uniforms.maxHDRFactor);
    float currentHeadroom = max(1.0, uniforms.currentHDRFactor);
    if (currentHeadroom <= 1.01) {
        return potentialHeadroom;
    }

    return min(potentialHeadroom, currentHeadroom);
}

float lowHeadroomCompensation(constant Uniforms& uniforms) {
    if (uniforms.isHDREnabled == 0) {
        return 0.0;
    }

    return saturate((8.0 - effectiveHDRFactor(uniforms)) / 4.0);
}

float curvedBrightness(constant Uniforms& uniforms) {
    float exponent = uniforms.isHDREnabled == 1 ? 1.35 : 1.5;
    return pow(saturate(uniforms.brightness), exponent);
}

float targetIntensity(constant Uniforms& uniforms) {
    float maxIntensity = uniforms.isHDREnabled == 1 ? effectiveHDRFactor(uniforms) : 1.35;
    float compensation = uniforms.isHDREnabled == 1 ? 1.0 + (lowHeadroomCompensation(uniforms) * 0.24) : 1.0;
    return maxIntensity * (0.18 + (curvedBrightness(uniforms) * 0.82)) * compensation;
}

float renderIntensity(constant Uniforms& uniforms) {
    if (uniforms.isHDREnabled == 1) {
        return max(1.0, targetIntensity(uniforms));
    }

    return 1.0 + (targetIntensity(uniforms) * 0.10);
}

float pointerCutoutMask(float2 point, constant Uniforms& uniforms) {
    float d = distance(point, uniforms.mousePosition);
    float brightnessSoftness = curvedBrightness(uniforms);
    float hdrSoftness = uniforms.isHDREnabled == 1
        ? saturate((targetIntensity(uniforms) - 1.0) / max(1.0, effectiveHDRFactor(uniforms) - 1.0))
        : 0.0;
    float softness = saturate((brightnessSoftness * 0.72) + (hdrSoftness * 0.38));
    float innerRadius = uniforms.pointerRadius * mix(0.92, 0.72, softness);
    float feather = uniforms.pointerFeather * mix(0.85, 1.85, softness);
    float outerRadius = uniforms.pointerRadius + feather;
    float mask = smoothstep(innerRadius, outerRadius, d);
    float perceptualMask = pow(mask, mix(1.0, 0.72, softness * 0.65));
    return saturate(perceptualMask);
}

float temperatureStrength(constant Uniforms& uniforms) {
    return abs(saturate(uniforms.colorTemperature) - 0.5) * 2.0;
}

float flashStrength(float phase, float start, float duration) {
    if (phase < start || phase > start + duration) {
        return 0.0;
    }

    float progress = (phase - start) / duration;
    float triangle = 1.0 - abs((progress * 2.0) - 1.0);
    return triangle * triangle * (3.0 - (2.0 * triangle));
}

float3 paletteColor4(float3 c0, float3 c1, float3 c2, float3 c3, float progress) {
    float scaled = fract(progress) * 4.0;
    float blend = fract(scaled);
    int index = int(floor(scaled));

    if (index == 0) {
        return blendColor(c0, c1, blend);
    }
    if (index == 1) {
        return blendColor(c1, c2, blend);
    }
    if (index == 2) {
        return blendColor(c2, c3, blend);
    }
    return blendColor(c3, c0, blend);
}

EffectState effectFrameState(uint mode, float time) {
    EffectState state;
    state.leadingColor = float3(1.0);
    state.trailingColor = float3(1.0);
    state.leadingPower = 0.0;
    state.trailingPower = 0.0;
    state.ambientPower = 0.0;

    if (mode == 2) {
        float phase = fmod(time, 1.18);
        state.leadingColor = float3(0.12, 0.42, 1.0);
        state.trailingColor = float3(1.0, 0.14, 0.12);
        state.leadingPower = max(
            flashStrength(phase, 0.02, 0.12),
            flashStrength(phase, 0.16, 0.12)
        );
        state.trailingPower = max(
            flashStrength(phase, 0.62, 0.12),
            flashStrength(phase, 0.76, 0.12)
        );
        state.ambientPower = 0.08 + (max(state.leadingPower, state.trailingPower) * 0.18);
        return state;
    }

    if (mode == 3) {
        float phase = fmod(time, 1.52);
        float leadingA = max(flashStrength(phase, 0.00, 0.14), flashStrength(phase, 0.18, 0.14));
        float leadingB = flashStrength(phase, 0.36, 0.14);
        float trailingBurst = flashStrength(phase, 0.90, 0.24);

        state.leadingColor = float3(1.0, 0.20, 0.12);
        state.trailingColor = float3(1.0, 0.58, 0.08);
        state.leadingPower = max(leadingA, leadingB);
        state.trailingPower = min(1.0, 0.18 + (trailingBurst * 0.82));
        state.ambientPower = 0.14 + (max(state.leadingPower, state.trailingPower * 0.75) * 0.16);
        return state;
    }

    if (mode == 4) {
        float flameDrift = 0.5 + (sin(time * 1.18) * 0.5);
        float flickerA = 0.5 + (sin((time * 4.6) + 0.8) * 0.5);
        float flickerB = 0.5 + (sin((time * 7.9) + 2.1) * 0.5);
        float emberPulse = 0.5 + (sin((time * 2.7) - 0.6) * 0.5);
        float sparkLick = 0.5 + (sin((time * 11.8) + (sin(time * 1.9) * 0.9)) * 0.5);

        state.leadingColor = blendColor(
            float3(1.0, 0.76, 0.18),
            float3(1.0, 0.46, 0.08),
            (flameDrift * 0.58) + (sparkLick * 0.12)
        );
        state.trailingColor = blendColor(
            float3(1.0, 0.46, 0.08),
            float3(0.92, 0.20, 0.06),
            (emberPulse * 0.62) + ((1.0 - flameDrift) * 0.12)
        );
        state.leadingPower = min(1.0, max(0.0, 0.26 + (flickerA * 0.34) + (sparkLick * 0.24)));
        state.trailingPower = min(1.0, max(0.0, 0.22 + (flickerB * 0.30) + (emberPulse * 0.28)));
        state.ambientPower = min(1.0, 0.22 + ((flickerA + flickerB) * 0.10) + (emberPulse * 0.14));
        return state;
    }

    if (mode == 5) {
        float beatPhase = fmod(time, 0.82);
        float kick = max(
            max(flashStrength(beatPhase, 0.00, 0.16), flashStrength(beatPhase, 0.28, 0.16)),
            flashStrength(beatPhase, 0.54, 0.16)
        );
        float leadingBurst = max(flashStrength(beatPhase, 0.06, 0.16), flashStrength(beatPhase, 0.44, 0.16));
        float trailingBurst = max(flashStrength(beatPhase, 0.18, 0.16), flashStrength(beatPhase, 0.62, 0.16));
        float3 magenta = float3(1.0, 0.12, 0.76);
        float3 cyan = float3(0.08, 0.95, 1.0);
        float3 lime = float3(0.55, 1.0, 0.18);
        float3 violet = float3(0.54, 0.24, 1.0);

        state.leadingColor = paletteColor4(magenta, cyan, lime, violet, time * 0.56);
        state.trailingColor = paletteColor4(cyan, violet, magenta, lime, (time * 0.62) + 0.23);
        state.leadingPower = min(1.0, 0.26 + (leadingBurst * 0.74));
        state.trailingPower = min(1.0, 0.24 + (trailingBurst * 0.76));
        state.ambientPower = 0.18 + (kick * 0.22);
        return state;
    }

    return state;
}

float2 directionalPoint(float angle, float2 size) {
    float radians = angle * 0.017453292519943295;
    float2 center = size * 0.5;
    float2 direction = float2(cos(radians), -sin(radians));
    float xReach = (size.x * 0.5) / max(abs(direction.x), 0.0001);
    float yReach = (size.y * 0.5) / max(abs(direction.y), 0.0001);
    return center + (direction * min(xReach, yReach));
}

void addNormalLight(
    thread float3& color,
    thread float& alpha,
    float2 point,
    constant Uniforms& uniforms,
    float brightnessScale
) {
    float scale = max(1.0, uniforms.screenScale);
    float cb = curvedBrightness(uniforms);
    float compensation = lowHeadroomCompensation(uniforms);
    float tempStrength = temperatureStrength(uniforms);
    float lowBrightnessLift = compensation * pow(1.0 - cb, 1.18);
    float baseRadius = uniforms.isHDREnabled == 1 ? 26.0 : 20.0;
    float outerRadius = uniforms.isHDREnabled == 1 ? 24.0 : 16.0;
    float coreBloomRadius = max(10.0 * scale, (baseRadius * scale) + (uniforms.borderWidth * 0.10) - (uniforms.brightness * 6.0 * scale));
    float outerBloomRadius = coreBloomRadius + (outerRadius * scale);
    float outerBloomMask = ringMask(point, uniforms, 1.06, outerBloomRadius);
    float baseMask = ringMask(point, uniforms, 1.00, max(1.0, scale));
    float highlightMask = ringMask(point, uniforms, 0.72, coreBloomRadius);
    float baseOpacity;
    float bloomOpacity;
    float highlightOpacity;

    if (uniforms.isHDREnabled == 1) {
        baseOpacity = min(1.0, 0.20 + (cb * (0.24 + compensation * 0.36)) + (tempStrength * 0.06));
        bloomOpacity = min(1.0, 0.10 + (cb * (0.18 + compensation * 0.14)) + (tempStrength * 0.05) + (lowBrightnessLift * 0.10));
        highlightOpacity = min(1.0, 0.10 + (cb * (0.14 + compensation * 0.12)) + (tempStrength * 0.04) + (lowBrightnessLift * 0.06));
    } else {
        baseOpacity = min(1.0, 0.24 + (cb * 0.76));
        bloomOpacity = min(1.0, 0.06 + (cb * 0.22));
        highlightOpacity = min(1.0, 0.08 + (cb * 0.28) + (targetIntensity(uniforms) * 0.10));
    }

    float intensity = renderIntensity(uniforms);
    float ringScale = min(1.0, max(0.0, brightnessScale));
    float3 baseColor = temperatureColor(uniforms.colorTemperature);
    float3 brightColor = highlightColor(uniforms);

    color += baseColor * outerBloomMask * bloomOpacity * intensity * 0.88 * ringScale;
    color += baseColor * baseMask * baseOpacity * intensity * ringScale;
    color += brightColor * highlightMask * highlightOpacity * intensity * 1.04 * ringScale;
    alpha += outerBloomMask * bloomOpacity * ringScale;
    alpha += baseMask * baseOpacity * ringScale;
    alpha += highlightMask * highlightOpacity * ringScale;

    if (uniforms.isHDREnabled == 1) {
        float hdrBloomMask = ringMask(point, uniforms, 0.88, outerBloomRadius * 1.20);
        float hdrBloomOpacity = min(1.0, 0.10 + (cb * (0.16 + compensation * 0.12)) + (tempStrength * 0.06) + (lowBrightnessLift * 0.12));
        color += baseColor * hdrBloomMask * hdrBloomOpacity * intensity * 1.18 * ringScale;
        alpha += hdrBloomMask * hdrBloomOpacity * ringScale;
    }
}

void addDirectionalLight(
    thread float3& color,
    thread float& alpha,
    float2 point,
    constant Uniforms& uniforms,
    float angle,
    bool isKeyLight
) {
    float2 size = uniforms.viewportSize;
    float2 center = size * 0.5;
    float2 source = directionalPoint(angle, size);
    float maxDimension = max(size.x, size.y);
    float sourceScale = isKeyLight ? 0.5 : 1.0;
    float blurScale = 1.0 + (lowHeadroomCompensation(uniforms) * 0.18);
    float lightEnergy = isKeyLight ? uniforms.professionalPrimaryEnergy : uniforms.professionalSecondaryEnergy;
    float hdrBoost = isKeyLight ? uniforms.professionalKeyHDRIntensityBoost : 1.0;
    float intensity = renderIntensity(uniforms) * lightEnergy * hdrBoost;
    float2 beamPoint = center + ((source - center) * (isKeyLight ? 0.82 : 0.74));
    float beamRadiusX = maxDimension * (isKeyLight ? 0.0814 : 0.1000);
    float beamRadiusY = maxDimension * (isKeyLight ? 0.0308 : 0.0360);
    float sourceRadius = maxDimension * (isKeyLight ? 0.155 : 0.210);
    float sourceGlow = radialGlow(point, source, sourceRadius * blurScale, isKeyLight ? 1.45 : 1.36, 0.56, 1.08);
    float sourceCore = radialGlow(point, source, sourceRadius * (isKeyLight ? 0.74 : 0.68) * blurScale, isKeyLight ? 3.20 : 3.05, 0.62, 1.08);
    float sourceHotspot = radialGlow(point, source, sourceRadius * sourceScale * 0.52 * blurScale, isKeyLight ? 6.20 : 5.60, 0.68, 1.10);
    float beam = softEllipse(
        point,
        beamPoint,
        angle,
        float2(beamRadiusX, beamRadiusY),
        maxDimension * (isKeyLight ? 0.021 : 0.026) * blurScale
    ) * beamFalloff(point, beamPoint, angle, beamRadiusX);
    float cb = curvedBrightness(uniforms);
    float glowOpacity = min(1.0, (isKeyLight ? 0.24 : 0.14) + (cb * (isKeyLight ? 0.36 : 0.22)));
    float coreOpacity = min(1.0, (isKeyLight ? 0.24 : 0.11) + (cb * (isKeyLight ? 0.30 : 0.16)));
    float hotspotOpacity = min(1.0, (isKeyLight ? 0.18 : 0.08) + (cb * (isKeyLight ? 0.20 : 0.08)));
    float beamOpacity = min(1.0, (isKeyLight ? 0.16 : 0.07) + (cb * (isKeyLight ? 0.22 : 0.11)));
    float3 baseColor = temperatureColor(uniforms.colorTemperature);
    float3 brightColor = highlightColor(uniforms);

    color += baseColor * beam * beamOpacity * intensity;
    color += baseColor * sourceGlow * glowOpacity * intensity;
    color += brightColor * sourceCore * coreOpacity * intensity * 1.04;
    color += brightColor * sourceHotspot * hotspotOpacity * intensity * (isKeyLight ? 1.10 : 1.04);
    alpha += beam * beamOpacity;
    alpha += sourceGlow * glowOpacity;
    alpha += sourceCore * coreOpacity;
    alpha += sourceHotspot * hotspotOpacity;
}

void addEffectLight(
    thread float3& color,
    thread float& alpha,
    float2 point,
    constant Uniforms& uniforms
) {
    float cb = curvedBrightness(uniforms);
    float scale = max(1.0, uniforms.screenScale);
    float coreBloomRadius = max(10.0 * scale, (26.0 * scale) + (uniforms.borderWidth * 0.10) - (uniforms.brightness * 6.0 * scale));
    float outerBloomRadius = coreBloomRadius + (uniforms.isHDREnabled == 1 ? 24.0 : 16.0) * scale;
    float leftSide = 1.0 - smoothstep(uniforms.viewportSize.x * 0.20, uniforms.viewportSize.x * 0.80, point.x);
    float rightSide = smoothstep(uniforms.viewportSize.x * 0.20, uniforms.viewportSize.x * 0.80, point.x);
    float bridgeSide = 1.0 - smoothstep(uniforms.viewportSize.x * 0.10, uniforms.viewportSize.x * 0.22, abs(point.x - uniforms.viewportSize.x * 0.5));
    EffectState state = effectFrameState(uniforms.effectMode, uniforms.time);
    float blendAmount = state.trailingPower / max(0.001, state.leadingPower + state.trailingPower);
    float3 overallColor = blendColor(state.leadingColor, state.trailingColor, blendAmount);
    float overallOpacity = min(1.0, (0.06 + (cb * 0.14)) + state.ambientPower);
    float leadingBaseOpacity = min(1.0, (0.08 + (cb * 0.18)) + (state.leadingPower * 0.60));
    float trailingBaseOpacity = min(1.0, (0.08 + (cb * 0.18)) + (state.trailingPower * 0.60));
    float leadingHighlightOpacity = min(1.0, (0.04 + (cb * 0.12)) + (state.leadingPower * 0.54));
    float trailingHighlightOpacity = min(1.0, (0.04 + (cb * 0.12)) + (state.trailingPower * 0.54));
    float intensity = renderIntensity(uniforms);
    float leadingIntensity = uniforms.isHDREnabled == 1 ? max(1.0, intensity * (0.52 + (state.leadingPower * 0.92))) : 1.0;
    float trailingIntensity = uniforms.isHDREnabled == 1 ? max(1.0, intensity * (0.52 + (state.trailingPower * 0.92))) : 1.0;
    float overallIntensity = uniforms.isHDREnabled == 1 ? max(1.0, intensity * (0.42 + (state.ambientPower * 0.80))) : 1.0;

    float ambientMask = ringMask(point, uniforms, 1.08, outerBloomRadius * 1.22);
    float outerMask = ringMask(point, uniforms, 1.02, outerBloomRadius);
    float baseMask = ringMask(point, uniforms, 1.00, max(1.0, scale));
    float highlightMask = ringMask(point, uniforms, 0.72, coreBloomRadius);

    color += overallColor * ambientMask * overallOpacity * overallIntensity;
    alpha += ambientMask * overallOpacity;

    color += state.leadingColor * outerMask * leftSide * min(1.0, leadingBaseOpacity * 0.78) * leadingIntensity * 0.92;
    color += state.trailingColor * outerMask * rightSide * min(1.0, trailingBaseOpacity * 0.78) * trailingIntensity * 0.92;
    color += overallColor * outerMask * bridgeSide * min(1.0, (leadingBaseOpacity + trailingBaseOpacity) * 0.11) * max(leadingIntensity, trailingIntensity) * 0.88;
    alpha += outerMask * (leftSide * min(1.0, leadingBaseOpacity * 0.78) + rightSide * min(1.0, trailingBaseOpacity * 0.78));
    alpha += outerMask * bridgeSide * min(1.0, (leadingBaseOpacity + trailingBaseOpacity) * 0.11);

    color += state.leadingColor * baseMask * leftSide * leadingBaseOpacity * leadingIntensity;
    color += state.trailingColor * baseMask * rightSide * trailingBaseOpacity * trailingIntensity;
    alpha += baseMask * (leftSide * leadingBaseOpacity + rightSide * trailingBaseOpacity);

    color += state.leadingColor * highlightMask * leftSide * leadingHighlightOpacity * leadingIntensity * 1.06;
    color += state.trailingColor * highlightMask * rightSide * trailingHighlightOpacity * trailingIntensity * 1.06;
    alpha += highlightMask * (leftSide * leadingHighlightOpacity + rightSide * trailingHighlightOpacity);

    if (uniforms.isHDREnabled == 1) {
        float hdrMask = ringMask(point, uniforms, 0.90, outerBloomRadius * 1.16);
        float leadingHDR = min(1.0, 0.06 + (state.leadingPower * 0.42));
        float trailingHDR = min(1.0, 0.06 + (state.trailingPower * 0.42));
        color += state.leadingColor * hdrMask * leftSide * leadingHDR * leadingIntensity * 1.16;
        color += state.trailingColor * hdrMask * rightSide * trailingHDR * trailingIntensity * 1.16;
        alpha += hdrMask * (leftSide * leadingHDR + rightSide * trailingHDR);
    }
}

fragment float4 displayFillFragment(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    float2 point = in.position.xy;
    float3 color = float3(0.0);
    float alpha = 0.0;

    if (uniforms.effectMode >= 2) {
        addEffectLight(color, alpha, point, uniforms);
    } else {
        if (uniforms.effectMode == 1) {
            addDirectionalLight(color, alpha, point, uniforms, uniforms.secondaryAngle, false);
            addDirectionalLight(color, alpha, point, uniforms, uniforms.primaryAngle, true);
        }

        float ringScale = uniforms.effectMode == 1 ? uniforms.professionalRingScale : 1.0;
        addNormalLight(color, alpha, point, uniforms, ringScale);
    }

    if (uniforms.hasMouse == 1) {
        float hole = pointerCutoutMask(point, uniforms);
        color *= hole;
        alpha *= hole;
    }

    alpha = saturate(alpha);
    return float4(color, alpha);
}
