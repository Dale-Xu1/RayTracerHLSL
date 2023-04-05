using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using RayTracer.DirectX;

using SharpDX;
using SharpDX.DXGI;

namespace RayTracer;

using SharpDX.Direct3D11;

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Constants
{

    public uint Sample { get; init; }
    private readonly Vector3 padding;

    public Camera Camera { get; init; }

}

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Camera
{

    public Matrix ToWorld { get; init; }
    public Matrix InverseProjection { get; init; }

    public float Aperture { get; init; }
    public float Distance { get; init; }

}

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Material
{

    public Color3 Albedo { get; init; }
    public Color3 Specular { get; init; }
    public Color3 Emission { get; init; }

    public float Roughness { get; init; }
    public float T { get; init; }

}

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Triangle
{

    public Vector3 A { get; init; }
    public Vector3 B { get; init; }
    public Vector3 C { get; init; }

    public Material Material { get; init; }

}

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Sphere
{

    public Vector3 Position { get; init; }
    public float Radius { get; init; }

    public Material Material { get; init; }

}

internal class RayTracerRenderer : ComputeRenderer
{

    private readonly ConstantBuffer<Constants> buffer;
    private Constants constants;

    private readonly ComputeShader renderer;
    private readonly ComputeShader accumulate;


    public RayTracerRenderer(Window window, int width, int height) : base(window, width, height)
    {
        renderer = Compile("RayTracer.hlsl");
        accumulate = Compile("Accumulate.hlsl");

        // Separate texture for ray tracer to render to
        using UnorderedAccessTexture render = new(device, width, height, Format.R16G16B16A16_Float);
        context.ComputeShader.SetUnorderedAccessView(1, render.View);

        // Create constant buffer
        buffer = new ConstantBuffer<Constants>(device);
        context.ComputeShader.SetConstantBuffer(0, buffer);

        LoadSceneData();
        Init();
    }

    private void LoadSceneData()
    {
        // Generate random spheres
        Random random = new(1);

        //List<Triangle> triangles = new();
        List<Sphere> spheres = new();

        for (int i = 0; i < 200; i++)
        {
            float radius = random.NextFloat(1, 6);
            Vector3 position = new(random.NextFloat(-60, 60), radius, random.NextFloat(-60, 60));

            foreach (Sphere sphere in spheres)
            {
                float min = radius + sphere.Radius;
                if ((sphere.Position - position).LengthSquared() < min * min) goto Skip;
            }

            Color3 color = new(random.NextFloat(0.2f, 1), random.NextFloat(0.2f, 1), random.NextFloat(0.2f, 1));
            Color3 albedo, specular, emission;
            float t = 0;

            double r = random.NextDouble();
            if (r < 0.6)
            {
                albedo = color;
                specular = Color3.White * 0.8f;
                emission = Color3.Black;
                t = 0.2f;
            }
            else if (r < 0.8)
            {
                albedo = color;
                specular = Color3.Black;
                emission = Color3.Black;
            }
            else if (r < 0.9)
            {
                albedo = Color3.Black;
                specular = color;
                emission = Color3.Black;
                t = 1;
            }
            else
            {
                albedo = Color3.Black;
                specular = Color3.Black;
                emission = Color3.White * 500;
            }

            spheres.Add(new Sphere
            {
                Position = position,
                Radius = radius,
                Material = new Material
                {
                    Albedo = albedo, Specular = specular,
                    Emission = emission,
                    Roughness = random.NextFloat(0, 0.6f),
                    T = t
                }
            });

        Skip:;
        }

        //triangles.Add(new Triangle
        //{
        //    A = new Vector3(0, 0, 0),
        //    B = new Vector3(0, 80, 80),
        //    C = new Vector3(0, 0, 80),
        //    Material = new Material
        //    {
        //        Albedo = new Color3(0.6f, 0.6f, 0.6f),
        //        Specular = Color3.Black,
        //        Emission = Color3.Black,
        //        Roughness = 0
        //    }
        //});

        using ShaderResourceBuffer<Triangle> triangleBuffer = new(device, spheres.Count);
        context.ComputeShader.SetShaderResource(0, triangleBuffer.View);

        using ShaderResourceBuffer<Sphere> sphereBuffer = new(device, spheres.Count);
        context.ComputeShader.SetShaderResource(1, sphereBuffer.View);

        //context.UpdateSubresource(triangles.ToArray(), triangleBuffer);
        context.UpdateSubresource(spheres.ToArray(), sphereBuffer);
    }

    private void Init()
    {
        Vector3 position = new(80, 25, -80), target = new(0, 0, 0);

        Matrix toWorld = Matrix.LookAtLH(position, target, Vector3.Up);
        Matrix projection = Matrix.PerspectiveFovLH((float) Math.PI / 4, (float) width / height, 0.1f, 100);

        toWorld.Invert();
        projection.Invert();

        Camera camera = new()
        {
            ToWorld = toWorld, InverseProjection = projection,
            Aperture = 2,
            Distance = Vector3.Distance(position, target)
        };
        constants = new Constants { Camera = camera };
    }

    public new void Dispose()
    {
        base.Dispose();

        buffer.Dispose();

        renderer.Dispose();
        accumulate.Dispose();
    }


    private uint sample = 0;
    public override void Render()
    {
        constants = constants with { Sample = sample++ };
        context.UpdateSubresource(ref constants, buffer);

        // Dispatch shaders
        context.ComputeShader.Set(renderer);
        context.Dispatch((width + 7) / 8, (height + 7) / 8, 1);

        context.ComputeShader.Set(accumulate);
        context.Dispatch((width + 7) / 8, (height + 7) / 8, 1);

        base.Render();
    }

}
