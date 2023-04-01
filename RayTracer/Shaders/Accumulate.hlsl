static const float3x3 ACESInput =
{
    { 0.59719, 0.35458, 0.04823 },
    { 0.07600, 0.90834, 0.01566 },
    { 0.02840, 0.13383, 0.83777 }
};

static const float3x3 ACESOutput =
{
    { 1.60475, -0.53108, -0.07367 },
    { -0.10208, 1.10813, -0.00605 },
    { -0.00327, -0.07276, 1.07602 }
};

RWTexture2D<float4> Render : register(u1);
RWTexture2D<float4> Result : register(u0);

uint Sample;

float3 RRTAndODT(float3 v)
{
    float3 a = v * (v + 0.0245786f) - 0.000090537f;
    float3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

float3 HillACES(float3 color)
{
    color = mul(ACESInput, color);
    
    color = RRTAndODT(color);
    color = mul(ACESOutput, color);
    
    return saturate(color);
}

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
    // HDR tone mapping
    float3 render = HillACES(Render[id.xy].rgb);
 
	// Average result with previous samples   
    float a = 1 / float(Sample + 1);
    Result[id.xy] = lerp(Result[id.xy], float4(render, 1), a);
}
