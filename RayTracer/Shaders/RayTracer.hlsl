﻿#include "Object.hlsl"

static const uint LIGHT_BOUNCES = 8;

static const float PI = 3.1415926535;
static const float EPSILON = 0.001;

struct CameraParams
{
    float4x4 toWorld;
    float4x4 inverseProjection;

    float aperture;
    float distance;
};

StructuredBuffer<Sphere> Spheres : register(t0);
RWTexture2D<float4> Render : register(u1);

uint Sample;
CameraParams Camera;

static uint NextState(uint state) { return state * 747796405 + 2891336453; }
float Random(inout uint state)
{
	state = NextState(state);

	uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
	result = (result >> 22) ^ result;
	
	return result / 4294967295.0;
}

float2 RandomCircle(float radius, inout uint state)
{
	float r = radius * sqrt(Random(state));
	float a = Random(state) * 2 * PI;
	
	return float2(r * cos(a), r * sin(a));
}

float3 RandomHemisphere(float3 normal, float alpha, inout uint state)
{	
    // Generate transformation matrix based on normal vector
    float3 helper = float3(1, 0, 0);
    if (abs(normal.x) > 0.9) helper = float3(0, 0, 1);

    float3 tangent = normalize(cross(normal, helper));
    float3 binormal = normalize(cross(normal, tangent));

    float3x3 transform = float3x3(tangent, binormal, normal);
	
	// Uniformly sample from hemisphere
    float c = pow(Random(state), 1 / (alpha + 1));
    float s = sqrt(1 - c * c);
    float p = 2 * PI * Random(state);

    // Transform random direction into world space
    float3 direction = float3(cos(p) * s, sin(p) * s, c);
    return mul(direction, transform);
}

Intersection Trace(Ray ray)
{
	Intersection min = IntersectGroundPlane(ray);

	uint length, stride;
	Spheres.GetDimensions(length, stride);

	// Find closest intersection
	for (uint i = 0; i < length; i++)
	{
		Intersection intersection = IntersectSphere(ray, Spheres[i]);
		if (intersection.distance < min.distance) min = intersection;
	}

	return min;
}

Ray BRDF(Ray ray, Intersection intersection, inout uint state)
{
	float3 normal = intersection.normal;
	
	// Add epsilon to sure new ray does not intersect current object
    float3 position = intersection.position + normal * EPSILON;
    float3 direction = RandomHemisphere(normal, 1, state); // Sample new direction randomly
	
	// TODO: Specular materials
	// float3 direction = reflect(ray.direction, normal);
	
    return Ray::New(position, direction);
}


Ray CameraRay(float2 uv, inout uint state)
{
	// Transform camera origin into world space
    float3 offset = float3(RandomCircle(Camera.aperture, state), 0); // Randomly sample within aperture
    float3 position = mul(Camera.toWorld, float4(offset, 1)).xyz;

	// Invert perspctive projection
    float3 direction = mul(Camera.inverseProjection, float4(uv, 0, 1)).xyz;
	
    direction = normalize(direction) * Camera.distance - offset; // Reorient direction on focal plane
    direction = mul(Camera.toWorld, float4(direction, 0)).xyz; // Transform from camera to world space

    return Ray::New(position, normalize(direction));
}

float3 SampleSkybox(Ray ray)
{
	// Don't look at this please
    float3 direction = ray.direction;
	
    float3 horizon = float3(1, 1, 1), zenith = float3(120, 170, 247) / 255;
	float3 sunDir = normalize(float3(-2, -2, -5));
	float focus = 80, intensity = 1000;
	
	float t = pow(smoothstep(0, 0.4, direction.y), 0.35);
	float3 gradient = lerp(horizon, zenith, t);
	
    float sun = pow(max(0, dot(direction, -sunDir)), focus) * intensity;
	
	return (gradient + sun) * 1.5;
}

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	uint width, height;
	Render.GetDimensions(width, height);
	
	// Calculate seed based on pixel position and time
	uint state = id.y * width + id.x + NextState(Sample);
	
	// Create camera ray for given uv coordinate
    float2 offset = float2(Random(state), Random(state));
    float2 uv = (id.xy + offset) / float2(width, height) * 2 - 1;
	
    Ray ray = CameraRay(float2(uv.x, -uv.y), state);

	// Trace ray
	float3 result = 0, light = 1;
    for (uint i = 0; i < LIGHT_BOUNCES; i++)
	{
		Intersection intersection = Trace(ray);
		if (intersection.distance < 1.#INF)
		{
			Material material = intersection.material;
			
			// Evaluate first term of the rendering equation
			result += light * material.emission;
			light *= material.albedo;
			
            if (!any(light)) break;
            ray = BRDF(ray, intersection, state);
        }
		else
        {
			// Sample skybox
            result += light * SampleSkybox(ray);
            break;
        }
	}
	
    Render[id.xy] = float4(result, 1);
}
