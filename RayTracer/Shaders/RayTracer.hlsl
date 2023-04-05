#include "Object.hlsl"

static const uint LIGHT_BOUNCES = 8;
static const float PI = 3.1415926535;

struct CameraParams
{
    float4x4 toWorld;
    float4x4 inverseProjection;

    float aperture;
    float distance;
};

StructuredBuffer<Triangle> Triangles : register(t0);
StructuredBuffer<Sphere> Spheres : register(t1);

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
    float a = 2 * PI * Random(state);
	
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
    float3 direction = float3(s * cos(p), s * sin(p), c);
    return mul(direction, transform);
}


Intersection Trace(Ray ray)
{
	Intersection min = Intersection::GroundPlane(ray);
	uint length, stride;
	
	// Find closest intersection
    Triangles.GetDimensions(length, stride);
    for (uint i = 0; i < length; i++)
    {
        Intersection intersection = Triangles[i].Intersect(ray);
        if (intersection.distance < min.distance) min = intersection;
    }
	
    Spheres.GetDimensions(length, stride);
	for (i = 0; i < length; i++)
	{
		Intersection intersection = Spheres[i].Intersect(ray);
		if (intersection.distance < min.distance) min = intersection;
	}

	return min;
}

Ray BRDF(Ray ray, Intersection intersection, inout uint state)
{
    Material material = intersection.material;
	
	// Add epsilon to sure new ray does not intersect current object
    float3 normal = intersection.normal;
    float3 position = intersection.position + normal * EPSILON;
    
    float3 direction, light;
    if (Random(state) > material.t)
    {
        // Diffuse BRDF
        direction = RandomHemisphere(normal, 1, state); // Sample new direction randomly
        light = ray.light * material.albedo;
    }
    else
    {
        // Specular BRDF
        float3 reflection = reflect(ray.direction, normal);
        
        if (material.roughness == 0) direction = reflection;
        else
        {
            float alpha = 2 / pow(material.roughness, 4) - 2;
            direction = RandomHemisphere(reflection, alpha, state);
        }
        
        light = ray.light * material.specular;
    }
    
    return Ray::New(position, direction, light);
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

Ray CameraRay(float2 uv, inout uint state)
{
	// Transform camera origin into world space
    float3 offset = float3(RandomCircle(Camera.aperture / 2, state), 0); // Randomly sample within aperture
    float3 position = mul(Camera.toWorld, float4(offset, 1)).xyz;

	// Invert perspctive projection
    float3 direction = mul(Camera.inverseProjection, float4(uv, 0, 1)).xyz;
	
    direction = Camera.distance * direction - offset; // Reorient direction on focal plane
    direction = mul(Camera.toWorld, float4(direction, 0)).xyz; // Transform from camera to world space

    return Ray::New(position, normalize(direction));
}

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	uint width, height;
	Render.GetDimensions(width, height);
	
	// Calculate seed based on pixel position and time
	uint state = id.y * width + id.x + NextState(Sample);
	
	// Use uv coordinate of current pixel to generate camera ray
    float2 offset = float2(Random(state), Random(state));
    float2 uv = (id.xy + offset) / float2(width, height) * 2 - 1;
	
    Ray ray = CameraRay(float2(uv.x, -uv.y), state);
	float3 result = 0;
	
    for (uint i = 0; i < LIGHT_BOUNCES; i++)
	{
		Intersection intersection = Trace(ray);
		if (intersection.distance < 1.#INF)
		{
            // First term of rendering equation
            result += ray.light * intersection.material.emission;
			
            ray = BRDF(ray, intersection, state); // Get next ray
            if (!any(ray.light)) break;
        }
		else
        {
			// Sample skybox if no objects are hit
            result += ray.light * SampleSkybox(ray);
            break;
        }
	}
	
    Render[id.xy] = float4(result, 1);
}
