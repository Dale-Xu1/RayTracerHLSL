static const float PI = 3.1415926535;

struct Ray
{
    float3 position;
    float3 direction;
	float3 color;
};

struct RayHit
{
	float3 position;
	float distance;
	float3 normal;

	float3 albedo;
	float3 specular;
};

struct Sphere
{
	float3 position;
	float radius;
	float3 albedo;
	float3 specular;
};

Ray InitRay(float3 position, float3 direction)
{
	Ray ray;

	ray.position = position;
	ray.direction = direction;
	ray.color = 1;

	return ray;
}

RayHit InitRayHit()
{
	RayHit hit;

	hit.position = 0;
	hit.distance = 1.#INF;
	hit.normal = 0;

	hit.albedo = 0;
	hit.specular = 0;

	return hit;
}

float Hash(uint state)
{
	state ^= 2747636419u;
	state *= 2654435769u;
	state ^= state >> 16;
	state *= 2654435769u;
	state ^= state >> 16;
	state *= 2654435769u;

	return state / 4294967295.0;
}

StructuredBuffer<Sphere> Spheres : register(t0);
Texture2D<float4> Skybox : register(t1);

RWTexture2D<float4> Result;

SamplerState Sampler;

float4x4 CameraToWorld;
float4x4 InverseProjection;

uint Sample;

Ray InitCameraRay(float2 uv)
{
	// Transform camera origin into world space
	float3 position = mul(CameraToWorld, float4(0, 0, 0, 1)).xyz;

	// Invert perspctive projection
	float3 direction = mul(InverseProjection, float4(uv, 0, 1)).xyz;
	direction = mul(CameraToWorld, float4(direction, 0)).xyz; // Transform from camera to world space

    return InitRay(position, normalize(direction));
}

void IntersectGroundPlane(Ray ray, inout RayHit hit)
{
	// Calculate distance along the ray where the ground plane is intersected
	float t = -ray.position.y / ray.direction.y;
	if (t > 0 && t < hit.distance)
	{
		hit.distance = t;
		hit.position = ray.position + t * ray.direction;
		hit.normal = float3(0, 1, 0);

		hit.albedo = 0.8;
		hit.specular = 0.03;
	}
}

void IntersectSphere(Ray ray, inout RayHit hit, uint i)
{
	Sphere sphere = Spheres[i];

	// Calculate distance along the ray where the sphere is intersected
    float3 d = ray.position - sphere.position;
    float p1 = -dot(ray.direction, d);

    float p2sq = p1 * p1 - dot(d, d) + sphere.radius * sphere.radius;
    if (p2sq < 0) return;

    float p2 = sqrt(p2sq);
    float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;

    if (t > 0 && t < hit.distance)
    {
        hit.distance = t;
        hit.position = ray.position + ray.direction * t;
        hit.normal = normalize(hit.position - sphere.position);

		hit.albedo = sphere.albedo;
		hit.specular = sphere.specular;
    }
}

RayHit Trace(Ray ray)
{
	RayHit hit = InitRayHit();

	IntersectGroundPlane(ray, hit);

	uint length, stride;
	Spheres.GetDimensions(length, stride);

	for (uint i = 0; i < length; i++) IntersectSphere(ray, hit, i);
	return hit;
}

float3 Shade(inout Ray ray, RayHit hit)
{
	if (hit.distance < 1.#INF)
	{
		// Reflct ray and multiply color with specular reflection
		float4 light = float4(normalize(float3(0.3, -1, 0.5)), 1);

		ray.position = hit.position + hit.normal * 0.001;
		ray.direction = reflect(ray.direction, hit.normal);
		ray.color *= hit.specular;

		// Return diffuse-shaded color
		Ray shadowRay = InitRay(hit.position + hit.normal * 0.001, -1 * light.xyz);
		RayHit shadowHit = Trace(shadowRay);

		if (shadowHit.distance != 1.#INF) return 0;
		return saturate(dot(hit.normal, light.xyz) * -1) * light.w * hit.albedo;
	}

	ray.color = 0;

	// Sample the skybox
	float theta = acos(ray.direction.y) / PI;
	float phi = -0.5 * atan2(ray.direction.x, -ray.direction.z) / PI;
	
	return pow(Skybox.SampleLevel(Sampler, (float2(phi, theta) + 1) % 1, 0), 1.3) * 1.12;
}

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	uint width, height;
	Result.GetDimensions(width, height);

	// Generate random offset for pixel
	int i = id.y * width + id.x + Sample;
	float2 offset = float2(Hash(i), Hash(i + 1));

	// Create camera ray for current pixel
    float2 uv = (id.xy + offset) / float2(width, height) * 2 - 1;
	Ray ray = InitCameraRay(float2(uv.x, -uv.y));

	// Trace and shade ray
	float3 result = 0;
	for (int i = 0; i < 8; i++)
	{
		RayHit hit = Trace(ray);
		result += ray.color * Shade(ray, hit);

		if (!any(ray.color)) break;
	}

	// Average result with previous samples
	float a = 1.0 / (Sample + 1);
	Result[id.xy] = Result[id.xy] * (1 - a) + float4(result, 1) * a;
}
