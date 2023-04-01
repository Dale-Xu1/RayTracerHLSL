#include "Object.hlsl"

static const float PI = 3.1415926535;
static const float EPSILON = 0.001;

StructuredBuffer<Sphere> Spheres : register(t0);
Texture2D<float4> Skybox : register(t1);

RWTexture2D<float4> Render : register(u1);

float4x4 CameraToWorld;
float4x4 InverseProjection;

uint Sample;

uint NextState(uint state) { return state * 747796405 + 2891336453; }
float Random(inout uint state)
{
	state = NextState(state);

	uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
	result = (result >> 22) ^ result;
	
	return result / 4294967295.0;
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

Ray CameraRay(float2 uv)
{
		// Transform camera origin into world space
    float3 position = mul(CameraToWorld, float4(0, 0, 0, 1)).xyz;

		// Invert perspctive projection
    float3 direction = mul(InverseProjection, float4(uv, 0, 1)).xyz;
    direction = mul(CameraToWorld, float4(direction, 0)).xyz; // Transform from camera to world space

    return Ray::New(position, normalize(direction));
}

SamplerState Sampler;

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
	
    Ray ray = CameraRay(float2(uv.x, -uv.y));

	// Trace ray
	float3 result = 0, light = 1;
	for (uint i = 0; i < 8; i++)
	{
		Intersection intersection = Trace(ray);
		if (intersection.distance < 1.#INF)
		{
			Material material = intersection.material;

			// Add epsilon to sure new ray does not intersect current object
			float3 position = intersection.position + intersection.normal * EPSILON;
            float3 direction = RandomHemisphere(intersection.normal, 1, state); // Sample new direction randomly

			// Evaluate first term of the rendering equation
			result += light * material.emission;
			light *= material.albedo;
			
            if (!any(light)) break;
            ray = Ray::New(position, direction);
        }
		else
        {
			// Sample the skybox
            float theta = acos(ray.direction.y) / PI;
            float phi = -0.5 * atan2(ray.direction.x, -ray.direction.z) / PI;
		
            result += light * pow(Skybox.SampleLevel(Sampler, (float2(phi, theta) + 1) % 1, 0).rgb, 2) * 2;
            break;
        }
	}
	
    Render[id.xy] = float4(result, 1);
}
