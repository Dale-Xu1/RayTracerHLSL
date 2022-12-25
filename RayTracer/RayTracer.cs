using System;
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
internal readonly struct Triangle
{

    public Vector3 A { get; init; }
    public Vector3 B { get; init; }
    public Vector3 C { get; init; }

}

[StructLayout(LayoutKind.Sequential)]
internal readonly struct Sphere
{

    public Vector3 Position { get; init; }
    public float Radius { get; init; }

    public Color3 Albedo { get; init; }
    public Color3 Specular { get; init; }

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
        Random random = new(3);
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
            Color3 albedo, specular;

            if (random.NextFloat(0, 1) < 0.5)
            {
                albedo = Vector3.Zero;
                specular = color;
            }
            else
            {
                albedo = color;
                specular = new Vector3(0.04f, 0.04f, 0.04f);
            }

            spheres.Add(new()
            {
                Position = position, Radius = radius,
                Albedo = albedo, Specular = specular
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
