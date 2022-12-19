struct Ray
{
    float3 position;
    float3 direction;
};

struct Triangle
{
	float3 a;
	float3 b;
	float3 c;
};

StructuredBuffer<Triangle> Input;
RWTexture2D<float4> Result;

uint Sample;

int Width;
int Height;

float4x4 CameraToWorld;
float4x4 InverseProjection;

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

bool IntersectSphere(Ray ray, float4 sphere)
{
    float3 d = ray.position - sphere.xyz;
    float p1 = -dot(ray.direction, d);

    float p2sq = p1 * p1 - dot(d, d) + sphere.w * sphere.w;
    if (p2sq < 0) return false;

    float p2 = sqrt(p2sq);
    float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;

    return t > 0;
}

bool IntersectTriangle(Ray ray, Triangle t)
{
	return false;
}

// TODO: Create triangle intersection function
// TODO: Use input buffer data for triangles
// TODO: Add colors!

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	// Generate random offset for pixel
	int i = id.y * Width + id.x + Sample;
	float2 offset = float2(Hash(i + Sample), Hash(i + Sample + 1));

	// Create camera ray for current pixel
    float2 uv = (id.xy + offset) / float2(Width, Height) * 2 - 1;
	Ray ray = InitCameraRay(uv);

	float4 result;
	if (IntersectSphere(ray, float4(0, 0, 0, 1))) result = 1;
	else result = 0;

	// Average result with previous samples
	float a = 1.0 / (Sample + 1);
	Result[id.xy] = Result[id.xy] * (1 - a) + result * a;
}
