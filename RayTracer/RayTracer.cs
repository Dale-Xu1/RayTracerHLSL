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
    public float Roughness { get; init; }

    public Color3 Emission { get; init; }

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
        Random random = new(3);
        List<Sphere> spheres = new();

        for (int i = 0; i < 200; i++)
        {
            float radius = random.NextFloat(1, 10);
            Vector3 position = new(random.NextFloat(-50, 50), radius, random.NextFloat(-50, 50));

            foreach (Sphere sphere in spheres)
            {
                float min = radius + sphere.Radius;
                if ((sphere.Position - position).LengthSquared() < min * min) goto Skip;
            }

            Color3 color = new(random.NextFloat(0, 1), random.NextFloat(0, 1), random.NextFloat(0, 1));
            Color3 albedo, specular, emission;

            albedo = color;
            specular = Vector3.Zero;
            emission = Vector3.Zero;

            if (i == 2)
            {
                albedo = Vector3.Zero;
                specular = Vector3.Zero;
                emission = Vector3.One * 100;
            }

            spheres.Add(new()
            {
                Position = position, Radius = radius,
                Material = new()
                {
                    Albedo = albedo, Specular = specular,
                    Roughness = random.NextFloat(0, 0.6f),
                    Emission = emission
                }
            });

        Skip:;
        }

        using ShaderResourceBuffer<Sphere> input = new(device, spheres.Count);
        context.ComputeShader.SetShaderResource(0, input.View);

        context.UpdateSubresource(spheres.ToArray(), input);
    }

    private void Init()
    {
        Vector3 position = new(80, 30, -80), target = new(0, 5, 0);

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
