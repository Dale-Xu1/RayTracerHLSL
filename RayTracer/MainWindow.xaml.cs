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

    private readonly int width = 1000;
    private readonly int height = 600;

    public MainWindow()
    {
        double dpi = 1.5;

        Width = width / dpi + 2 * SystemParameters.ResizeFrameVerticalBorderWidth;
        Height = height / dpi + SystemParameters.CaptionHeight +
            2 * SystemParameters.ResizeFrameHorizontalBorderHeight;

        InitializeComponent();
    }


    private void Start(object sender, RoutedEventArgs e)
    {
        RayTracerRenderer renderer = new(this, width, height);
        CompositionTarget.Rendering += (object? sender, EventArgs e) => renderer.Render();
    }

}
