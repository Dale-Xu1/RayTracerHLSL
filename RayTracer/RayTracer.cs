﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

using SharpDX;
using SharpDX.Direct3D11;
using SharpDX.WIC;

namespace RayTracer;

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Constants
{

    public Matrix CameraToWorld { get; init; }
    public Matrix InverseProjection { get; init; }

    public uint Sample { get; init; }

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

internal class RayTracerRenderer : Renderer
{

    private readonly ConstantBuffer<Constants> buffer;
    private Constants constants;


    public RayTracerRenderer(Window window) : base(window, "Shaders/RayTracer.hlsl")
    {
        using Texture2D skybox = TextureLoader.LoadFromFile(device, "skybox.jpg");

        ShaderResourceView view = new(device, skybox);
        context.ComputeShader.SetShaderResource(1, view);

        // Create constant buffers
        buffer = new ConstantBuffer<Constants>(device);
        context.ComputeShader.SetConstantBuffer(0, buffer);

        // Load object data
        Random random = new(2);
        List<Sphere> spheres = new();

        for (int i = 0; i < 100; i++)
        {
            float radius = random.NextFloat(2, 12);
            Vector3 position = new(random.NextFloat(-50, 50), radius, random.NextFloat(-50, 50));

            foreach (Sphere sphere in spheres)
            {
                float min = radius + sphere.Radius;
                if ((sphere.Position - position).LengthSquared() < min * min) goto Skip;
            }

            Color3 color = new(random.NextFloat(0, 1), random.NextFloat(0, 1), random.NextFloat(0, 1));
            Color3 albedo, specular, emission;

            float r = random.NextFloat(0, 1);
            if (r < 0.5)
            {
                albedo = color;
                specular = new Vector3(0.04f, 0.04f, 0.04f);
                emission = Vector3.Zero;
            }
            else if (r < 0.9)
            {
                albedo = Vector3.Zero;
                specular = color;
                emission = Vector3.Zero;
            }
            else
            {
                albedo = Vector3.Zero;
                specular = Vector3.Zero;
                emission = new Vector3(1.5f, 1.5f, 1.5f);
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

        using ShaderBuffer<Sphere> input = new(device, spheres.Count);
        context.ComputeShader.SetShaderResource(0, input.View);

        context.UpdateSubresource(spheres.ToArray(), input);
        Init();
    }

    private void Init()
    {
        Matrix camera = Matrix.LookAtLH(new Vector3(80, 30, -80), new Vector3(0, 1, 0), Vector3.Up);
        Matrix projection = Matrix.PerspectiveFovLH((float) Math.PI / 4, (float) width / height, 0.1f, 100);

        camera.Invert();
        projection.Invert();

        constants = new Constants
        {
            CameraToWorld = camera,
            InverseProjection = projection
        };
    }

    protected override void OnResize()
    {
        sample = 0;
        Init();
    }

    public new void Dispose()
    {
        base.Dispose();
        buffer.Dispose();
    }


    private uint sample = 0;
    public override void Render()
    {
        constants = constants with { Sample = sample++ };
        context.UpdateSubresource(ref constants, buffer);

        base.Render();
    }

}
