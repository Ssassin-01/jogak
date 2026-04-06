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

    // Time-based wave movement (Slightly slower for calmness)
    float t = uTime * 0.3;
    
    // Water ripple based on touch (Smooth ripple)
    float dist = length(p - (uTouch / uSize * 2.0 - 1.0) * vec2(aspect, 1.0));
    float ripple = sin(dist * 15.0 - uTime * 4.0) * exp(-dist * 2.5) * 0.08;

    // Multi-layered waves (Fractal noise base)
    float wave = fbm(p * 1.5 + t + ripple) * 0.55;
    wave += fbm(p * 3.0 - t * 0.4 + wave) * 0.25;

    // Deep Misty Purple Colors (은은한 보랏빛 호수)
    // Deepest: #070612 (Purple black)
    vec3 colorA = vec3(0.027, 0.024, 0.071); 
    // Mid: #1D1E4A (Deep Navy Purple)
    vec3 colorB = vec3(0.12, 0.12, 0.35);    
    // Lightest (Wave edge): #342A5E (Lavender Navy)
    vec3 colorC = vec3(0.2, 0.16, 0.37);     
    
    vec3 waterColor = mix(colorA, colorB, wave);
    waterColor = mix(waterColor, colorC, pow(wave, 2.0) * 0.4);

    // Shimmer (Yoonseul) Calculation - High contrast peaks
    // 진주빛 광채가 부서지는 효과
    float shimmer = pow(max(0.0, wave - 0.25) * 2.2, 12.0);
    shimmer = clamp(shimmer, 0.0, 1.0);
    
    // Sharp particles (Reflective diamonds)
    float sparks = step(0.985, hash(p * 150.0 + t * 0.5)) * shimmer;
    
    // Final Luminous Color Mix
    vec3 finalColor = waterColor + vec3(0.75, 0.82, 1.0) * shimmer; // Pearl Blue Shimmer
    finalColor += vec3(0.85, 0.75, 1.0) * sparks; // Lavender Diamond Sparkle
    
    // Ambient Atmosphere (Center light)
    float glow = (1.0 - length(p * 0.5)) * 0.1;
    finalColor += vec3(0.1, 0.05, 0.2) * glow;

    fragColor = vec4(finalColor, 1.0);
}
