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

struct Triangle
{
    float3 a;
    float3 b;
    float3 c;
    
    Material material;
};

struct Sphere
{
    float3 position;
    float radius;

    Material material;
};

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

    intersection.material = Material::New(0.9, 0, 0);
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
