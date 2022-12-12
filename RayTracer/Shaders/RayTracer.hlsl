static const float PI = 3.1415926535;

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

StructuredBuffer<Triangle> Input;
RWTexture2D<float4> Result;

int Width;
int Height;

uint Sample;

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	if ((id.x & id.y) == 0)
	{
		Result[id.xy] = float4(0, 0, 0, 1);
		return;
	}

	int i = id.y * Width + id.x + Sample;

	float h = Hash(i + Sample);
	float4 current = float4(h, h, h, 1);

	float a = 1.0 / (Sample + 1);
	Result[id.xy] = Result[id.xy] * (1 - a) + current * a;

	//Result[id.xy] += float4(1, 3.0 * id.x / Width, 0.5 * id.y / Height, 0) * 0.03;

	//if (Result[id.xy].r > 1.0) Result[id.xy] = float4(0, Result[id.xy].g, Result[id.xy].b, 1);
	//if (Result[id.xy].g > 1.0) Result[id.xy] = float4(Result[id.xy].r, 0, Result[id.xy].b, 1);
	//if (Result[id.xy].b > 1.0) Result[id.xy] = float4(Result[id.xy].r, Result[id.xy].g, 0, 1);
}
