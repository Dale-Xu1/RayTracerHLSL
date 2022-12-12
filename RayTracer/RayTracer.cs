using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

namespace RayTracer;

using SharpDX;
using SharpDX.Direct3D11;

internal struct Constants
{

    public int Width { get; init; }
    public int Height { get; init; }

    public uint Sample { get; init; }

}

internal struct Triangle
{

    public Vector3 A { get; init; }
    public Vector3 B { get; init; }
    public Vector3 C { get; init; }

}

internal class RayTracerRenderer : Renderer
{

    private readonly Buffer constantBuffer;

    public RayTracerRenderer(Window window) : base(window)
    {
        using ShaderBuffer<Triangle> input = new(device, 1);
        context.ComputeShader.SetShaderResource(0, input.View);

        context.UpdateSubresource(new Triangle[]
        {
            new() { A = new Vector3(0, 0, 0), B = new Vector3(0, 0, 0), C = new Vector3(0, 0, 0) }
        }, input);

        // Create constant buffer
        constantBuffer = new Buffer(device, new BufferDescription
        {
            SizeInBytes = 16,
            BindFlags = BindFlags.ConstantBuffer
        });
        context.ComputeShader.SetConstantBuffer(0, constantBuffer);
    }

    protected override void OnResize() => sample = 0;


    private uint sample = 0;
    public override void Render()
    {
        Constants constants = new()
        {
            Width = width, Height = height,
            Sample = sample++
        };
        context.UpdateSubresource(ref constants, constantBuffer);

        base.Render();
    }

}
