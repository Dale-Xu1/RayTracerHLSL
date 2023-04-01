using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace RayTracer;

public partial class MainWindow : Window
{

    private RayTracerRenderer renderer = null!;

    private readonly int width = 800;
    private readonly int height = 450;

    public MainWindow()
    {
        Width = width + 2 * SystemParameters.ResizeFrameVerticalBorderWidth;
        Height = height + SystemParameters.CaptionHeight +
            2 * SystemParameters.ResizeFrameHorizontalBorderHeight;

        InitializeComponent();
    }


    private void Start(object sender, RoutedEventArgs e)
    {
        renderer = new RayTracerRenderer(this, width, height);
        CompositionTarget.Rendering += (object? sender, EventArgs e) => renderer.Render();
    }

    private void Resize(object sender, SizeChangedEventArgs e)
    {
        if (renderer is null) return; 
        
        int width = (int) content.ActualWidth, height = (int) content.ActualHeight;
        renderer.Resize(width, height);
    }

}
