RWTexture2D<float4> Render : register(u1);
RWTexture2D<float4> Result : register(u0);

float4x4 CameraToWorld;
float4x4 InverseProjection;

uint Sample;

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	// Average result with previous samples
    float a = 1 / float(Sample + 1);
    Result[id.xy] = lerp(Result[id.xy], Render[id.xy], a);
}
