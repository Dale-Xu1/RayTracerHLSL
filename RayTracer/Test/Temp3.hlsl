static const float PI = 3.1415926535;
static const float EPSILON = 0.001;

struct Material
{
	float3 albedo;

	float3 specular;
	float roughness;

	float3 emission;
	

	static Material New(float3 albedo, float3 specular, float roughness, float3 emission = 0)
	{
		Material material;

		material.albedo = albedo;
		material.specular = specular;
		material.roughness = roughness;
		material.emission = emission;

		return material;
	}
};

struct Sphere
{
	float3 position;
	float radius;

	Material material;
};

StructuredBuffer<Sphere> Spheres : register(t0);
Texture2D<float4> Skybox : register(t1);

RWTexture2D<float4> Result;

float4x4 CameraToWorld;
float4x4 InverseProjection;

uint Sample;


struct Ray
{
    float3 position;
    float3 direction;


	static Ray New(float3 position, float3 direction)
	{
		Ray ray;

		ray.position = position;
		ray.direction = direction;

		return ray;
	}

	static Ray Camera(float2 uv)
	{
		// Transform camera origin into world space
		float3 position = mul(CameraToWorld, float4(0, 0, 0, 1)).xyz;

		// Invert perspctive projection
		float3 direction = mul(InverseProjection, float4(uv, 0, 1)).xyz;
		direction = mul(CameraToWorld, float4(direction, 0)).xyz; // Transform from camera to world space

		return New(position, normalize(direction));
	}
};

struct Intersection
{
	float3 position;
	float distance;
	float3 normal;

	Material material;
	

	static Intersection New()
	{
		Intersection intersection;
		intersection.distance = 1.#INF;

		return intersection;
	}
};


Intersection IntersectGroundPlane(Ray ray)
{
	Intersection intersection = Intersection::New();

	float t = -ray.position.y / ray.direction.y;
	if (t < 0) return intersection;
	
	// Calculate intersection data
	intersection.distance = t;
	intersection.position = ray.position + t * ray.direction;
	intersection.normal = float3(0, 1, 0);

	intersection.material = Material::New(0.9, 0.04, 0.3);
	return intersection;
}

Intersection IntersectSphere(Ray ray, in Sphere sphere)
{
	Intersection intersection = Intersection::New();

    float3 d = ray.position - sphere.position;
    float p1 = -dot(ray.direction, d);

    float discriminant = p1 * p1 - dot(d, d) + sphere.radius * sphere.radius;
    if (discriminant < 0) return intersection;

    float p2 = sqrt(discriminant);
    float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
	
    if (t < 0) return intersection;

	// Calculate intersection data
	float3 position = ray.position + ray.direction * t;

    intersection.distance = t;
    intersection.position = position;
    intersection.normal = normalize(position - sphere.position);

	intersection.material = sphere.material;
	return intersection;
}


float Random(float2 seed)
{
	return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}

float3 RandomHemisphere(float3 normal, float alpha, float2 seed)
{	
    // Generate transformation matrix based on normal vector
    float3 helper = float3(1, 0, 0);
    if (abs(normal.x) > 0.9) helper = float3(0, 0, 1);

    float3 tangent = normalize(cross(normal, helper));
    float3 binormal = normalize(cross(normal, tangent));

    float3x3 transform = float3x3(tangent, binormal, normal);
	
	// Uniformly sample from hemisphere
    float c = pow(Random(seed), 1 / (alpha + 1));
    float s = sqrt(1 - c * c);
    float p = 2 * PI * Random(seed + EPSILON);

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

float energy(float3 color)
{
    return dot(color, 1 / float(3));
}

SamplerState Sampler;

[numthreads(8, 8, 1)]
void Main(uint3 id : SV_DispatchThreadID)
{
	uint width, height;
	Result.GetDimensions(width, height);

	float2 seed = id.xy / float2(width, height) + Sample;
	
	// Create camera ray for current pixel
	float2 offset = float2(Random(seed), Random(seed + 1));
    float2 uv = (id.xy + offset) / float2(width, height) * 2 - 1;

	Ray ray = Ray::Camera(float2(uv.x, -uv.y));

	// Trace ray
	float3 result = 0, light = 1;
	for (uint i = 0; i < 8; i++)
	{
		Intersection intersection = Trace(ray);
		if (intersection.distance < 1.#INF)
		{
			Material material = intersection.material;

			ray.position = intersection.position + intersection.normal * EPSILON;
			
			// Janky shadow code
			//float3 lightDirection = -normalize(float3(0.3, -1, 0.5));
			//Ray shadowRay = Ray::New(intersection.position + intersection.normal * EPSILON, lightDirection);
			//Intersection shadowIntersection = Trace(shadowRay);

			//float shadow = 1 * dot(intersection.normal, lightDirection);
			//if (shadowIntersection.distance < 1.#INF) shadow = 0;

			//float shadow = 0;


			//float3 reflected = reflect(ray.direction, intersection.normal);
			//ray.direction = RandomHemisphere(intersection.normal, 0, seed + i);

			//float3 diffuse = 2 * min(1 - material.specular, material.albedo);
			//float alpha = 15;

			//float3 specular = material.specular * (alpha + 2) * pow(saturate(dot(ray.direction, reflected)), alpha);
			//light *= (diffuse + specular + shadow) * dot(intersection.normal, ray.direction);

			
			result += light * material.emission;

			float specular = energy(material.specular);
			float diffuse = energy(material.albedo);

			float total = specular + diffuse;
			specular /= total;
			diffuse /= total;
			
			if (Random(seed + i - 0.01) < specular)
			{
				if (material.roughness == 0) ray.direction = reflect(ray.direction, intersection.normal);
				else
				{
					float alpha = 2 / pow(material.roughness, 4) - 2;
					float f = (alpha + 2) / (alpha + 1);

					ray.direction = RandomHemisphere(reflect(ray.direction, intersection.normal), alpha, seed + i);
					light *= f;
				}

				light *= material.specular / specular;
			}
			else if (diffuse > 0)
			{
				ray.direction = RandomHemisphere(intersection.normal, 1, seed + i);
				light *= material.albedo / diffuse;
			}
			else light = 0;


			//ray.direction = RandomHemisphere(intersection.normal, 1, seed + i);
			
			//result += light * material.emission;
			//light *= material.albedo;
			
			if (any(light)) continue;
			else break;
		}

		// Sample the skybox
		float theta = acos(ray.direction.y) / PI;
		float phi = -0.5 * atan2(ray.direction.x, -ray.direction.z) / PI;
		
		result += light * pow(Skybox.SampleLevel(Sampler, (float2(phi, theta) + 1) % 1, 0), 2) * 1.8;
		break;
	}

	// Average result with previous samples
	float a = 1 / float(Sample + 1);
	Result[id.xy] = lerp(Result[id.xy], float4(result, 1), a);
}
