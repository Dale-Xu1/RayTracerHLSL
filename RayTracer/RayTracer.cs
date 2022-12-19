using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media.Imaging;

using SharpDX;
using SharpDX.Direct3D11;
using SharpDX.DXGI;

namespace RayTracer;

[StructLayout(LayoutKind.Sequential)]
internal struct Constants
{

    public Matrix CameraToWorld { get; init; }
    public Matrix InverseProjection { get; init; }

    public uint Sample { get; init; }

}

[StructLayout(LayoutKind.Sequential)]
internal struct Triangle
{

    public Vector3 A { get; init; }
    public Vector3 B { get; init; }
    public Vector3 C { get; init; }

}

internal class RayTracerRenderer : Renderer
{

    private readonly ConstantBuffer<Constants> buffer;
    private Constants constants;


    public RayTracerRenderer(Window window) : base(window, "Shaders/RayTracer.hlsl")
    {
        using ShaderBuffer<Triangle> input = new(device, 1);
        context.ComputeShader.SetShaderResource(0, input.View);

        Texture2D texture = TextureLoader.CreateTexture2DFromBitmap(device,
            TextureLoader.LoadBitmap(new SharpDX.WIC.ImagingFactory2(), "cape_hill.jpg"));

        ShaderResourceView view = new(device, texture);
        context.ComputeShader.SetShaderResource(1, view);

        // Create constant buffers
        buffer = new ConstantBuffer<Constants>(device);
        context.ComputeShader.SetConstantBuffer(0, buffer);

        // Load data into buffers
        context.UpdateSubresource(new Triangle[]
        {
            new() { A = new Vector3(0, 0, 0), B = new Vector3(0, 0, 0), C = new Vector3(0, 0, 0) }
        }, input);

        Init();
    }

    private void Init()
    {
        Matrix camera = Matrix.LookAtLH(new Vector3(0, 0, -5), Vector3.Zero, Vector3.Up);
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
