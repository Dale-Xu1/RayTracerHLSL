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
    
    static Intersection GroundPlane(Ray ray)
    {
        Intersection intersection = Intersection::New();

        float t = -ray.position.y / ray.direction.y;
        if (t < 0) return intersection;
	    
	    // Calculate intersection data
        intersection.distance = t;
        intersection.position = ray.position + t * ray.direction;
        intersection.normal = float3(0, 1, 0);

        intersection.material = Material::New(1, 0, 0);
        return intersection;
    }
};


struct Triangle
{
    float3 a;
    float3 b;
    float3 c;
    
    Material material;
    
    Intersection Intersect(Ray ray)
    {
        Intersection intersection = Intersection::New();
        
        float3 e1 = b - a;
        float3 e2 = c - a;
        
        float3 h = cross(ray.direction, e2);
        float r = dot(e1, h);
        
        // Backfacing triangles are rejected
        if (r < EPSILON) return intersection;
        
        float f = 1 / r;
        
        float3 s = ray.position - a;
        float u = f * dot(s, h);
        
        if (u < 0 || u > 1) return intersection;
        
        float3 q = cross(s, e1);
        float v = f * dot(ray.direction, q);
        
        if (v < 0 || u + v > 1) return intersection;
        
	    // Calculate intersection data
        float d = f * dot(e2, q);
        
        intersection.distance = d;
        intersection.position = ray.position + d * ray.direction;
        intersection.normal = normalize(cross(e1, e2));
        
        intersection.material = material;
        return intersection;
    }
};

struct Sphere
{
    float3 position;
    float radius;

    Material material;
    
    Intersection Intersect(Ray ray)
    {
        Intersection intersection = Intersection::New();

        float3 d = ray.position - position;
        float p1 = -dot(ray.direction, d);

        float l = p1 * p1 - dot(d, d) + radius * radius;
        if (l < 0) return intersection;

        float p2 = sqrt(l);
        float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
	
        if (t < 0) return intersection;

	    // Calculate intersection data
        float3 p = ray.position + ray.direction * t;

        intersection.distance = t;
        intersection.position = p;
        intersection.normal = normalize(p - position);

        intersection.material = material;
        return intersection;
    }
};
