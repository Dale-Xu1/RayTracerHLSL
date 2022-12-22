using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using SharpDX.DXGI;

namespace SharpDX.WIC;

using SharpDX.Direct3D11;

public class TextureLoader
{

    public static BitmapSource LoadBitmap(ImagingFactory factory, string file)
    {
        BitmapDecoder decoder = new(factory, file, DecodeOptions.CacheOnDemand);
        FormatConverter converter = new(factory);

        converter.Initialize(decoder.GetFrame(0), PixelFormat.Format32bppPRGBA,
            BitmapDitherType.None, null, 0, BitmapPaletteType.Custom);

        return converter;
    }

    public static Texture2D CreateTexture2DFromBitmap(Device device, BitmapSource source)
    {
        // Allocate DataStream to receive the WIC image pixels
        int stride = source.Size.Width * 4;
        using DataStream buffer = new(source.Size.Height * stride, true, true);

        // Copy the content of the WIC to the buffer
        source.CopyPixels(stride, buffer);
        return new Texture2D(device, new Texture2DDescription
        {
            Width = source.Size.Width, Height = source.Size.Height,
            ArraySize = 1, MipLevels = 1,
            Format = Format.R8G8B8A8_UNorm,
            BindFlags = BindFlags.ShaderResource,
            SampleDescription = new SampleDescription(1, 0)
        }, new DataRectangle(buffer.DataPointer, stride));
    }

    public static Texture2D LoadFromFile(Device device, string file)
    {
        using ImagingFactory factory = new();
        return CreateTexture2DFromBitmap(device, LoadBitmap(factory, file));
    }

}
