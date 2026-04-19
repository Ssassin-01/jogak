#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uSize;

out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep
    return mix(
        mix(hash(i), hash(i + vec2(1,0)), f.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
        f.y
    );
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        p = rot * p * 2.1;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float aspect = uSize.x / uSize.y;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= aspect;

    float t = uTime * 0.2;
    vec2 drift = vec2(-t * 0.4, -t * 0.28);

    // Domain Warping — 강도를 줄여 은은하게
    vec2 q = vec2(
        fbm(p * 1.5 + drift),
        fbm(p * 1.5 + drift + vec2(5.2, 1.3))
    );

    vec2 r = vec2(
        fbm(p * 1.5 + 1.5 * q + drift * 0.5 + vec2(1.7, 9.2)),
        fbm(p * 1.5 + 1.5 * q + drift * 0.5 + vec2(8.3, 2.8))
    );

    float nebula = fbm(p * 1.2 + 2.5 * r + drift * 0.2);

    // ── 색상: 대부분 어두운 우주 — 성운은 극히 은은하게 ─────────────
    vec3 col = vec3(0.006, 0.012, 0.022); // 딥스페이스 베이스

    // 색 강도를 1/4 수준으로 줄여 우주 느낌 살리기
    col += vec3(0.0, 0.08, 0.12) * smoothstep(0.2, 0.75, nebula);       // 청록 성운 (아주 은은하게)
    col += vec3(0.06, 0.02, 0.10) * smoothstep(0.4, 0.85, nebula);      // 보라 성운 (극히 은은하게)
    col += vec3(0.01, 0.04, 0.10) * smoothstep(0.55, 0.9, nebula) * 0.4; // 딥블루 하이라이트

    // 별빛 반짝임 (유지)
    float shimmer = pow(max(0.0, nebula - 0.5) * 3.0, 8.0);
    float sparks = step(0.991, hash(uv * 180.0 + t * 0.08)) * shimmer;
    col += vec3(0.6, 0.85, 1.0) * shimmer * 0.08;
    col += vec3(1.0, 0.95, 1.0) * sparks * 0.4;

    fragColor = vec4(col, 1.0);
}
