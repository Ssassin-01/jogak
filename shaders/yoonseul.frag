#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uSize;
uniform vec2 uTouch;

out vec4 fragColor;

// Noise function for water surface
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for waves
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = m * p;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    float aspect = uSize.x / uSize.y;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= aspect;

    // Time-based wave movement
    float t = uTime * 0.4;
    
    // Water ripple based on touch
    float dist = length(p - (uTouch / uSize * 2.0 - 1.0) * vec2(aspect, 1.0));
    float ripple = sin(dist * 20.0 - uTime * 5.0) * exp(-dist * 3.0) * 0.05;

    // Multi-layered waves (Confined to [0, 1])
    float wave = fbm(p * 2.0 + t + ripple) * 0.5;
    wave += fbm(p * 4.0 - t * 0.5 + wave) * 0.25;

    // Deep Lake Colors (Deep Ink Navy)
    vec3 colorA = vec3(0.007, 0.015, 0.031); // #020408
    vec3 colorB = vec3(0.05, 0.08, 0.15);    // Slightly lighter blue
    vec3 waterColor = mix(colorA, colorB, wave);

    // Shimmer (Yoonseul) Calculation - Highlight only the peaks
    float shimmer = pow(max(0.0, wave - 0.3) * 1.8, 10.0);
    shimmer = clamp(shimmer, 0.0, 1.0);
    
    // Sharp sparkles (Sparkling Yoonseul)
    float sparks = step(0.99, hash(p * 200.0 + t)) * shimmer;
    
    vec3 finalColor = waterColor + vec3(0.6, 0.7, 0.8) * shimmer; // Silver-blue shimmer
    finalColor += vec3(0.9, 0.8, 0.6) * sparks; // Soft golden sparkles

    fragColor = vec4(finalColor, 1.0);
}
