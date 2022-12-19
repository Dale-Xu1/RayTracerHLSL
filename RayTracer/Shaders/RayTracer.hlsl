static const float PI = 3.1415926535;

struct Ray
{
    float3 position;
    float3 direction;
};

StructuredBuffer<int> Input : register(t0);
Texture2D<float4> Skybox : register(t1);

RWTexture2D<float4> Result;

SamplerState Sampler;

float4x4 CameraToWorld;
float4x4 InverseProjection;

uint Sample;

Ray InitRay(float3 position, float3 direction)
{
	Ray ray;

	ray.position = position;
	ray.direction = direction;

	return ray;
}

Ray InitCameraRay(float2 uv)
{
	// Transform camera origin into world space
	float3 position = mul(CameraToWorld, float4(0, 0, 0, 1)).xyz;

	// Invert perspctive projection
	float3 direction = mul(InverseProjection, float4(uv, 0, 1)).xyz;
	direction = mul(CameraToWorld, float4(direction, 0)).xyz; // Transform from camera to world space

    return InitRay(position, normalize(direction));
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
	Ray ray = InitCameraRay(uv);

	// Sample the skybox
	float theta = acos(ray.direction.y) / -PI;
	float phi = atan2(ray.direction.x, -ray.direction.z) / -PI * 0.5;
	
	float4 result = pow(Skybox.SampleLevel(Sampler, (float2(phi, theta) + 1) % 1, 0), 1.2) * 1.1;

	// Average result with previous samples
	float a = 1.0 / (Sample + 1);
	Result[id.xy] = Result[id.xy] * (1 - a) + result * a;
}
