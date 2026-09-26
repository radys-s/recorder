# Builds the graphite-and-gold icon sources from the smoke-ring mark without
# changing its shape. Run once on the blue original mark (git history before
# M46), then run generate_icon.ps1 to expand the sources into every size:
#
#   powershell -File tool/recolor_icon.ps1 -Mark old-mark.png
#
# 1. The mark is recoloured per pixel in HSV: every hue becomes gold. Bright,
#    saturated pixels (the dot and its glow) keep most of their saturation and
#    read as gold light; the rings are almost fully desaturated to warm silver.
#    Alpha is preserved.
# 2. The full icon is composed fresh — a graphite radial background, a soft
#    gold glow behind the dot, then the recoloured mark — rather than recoloured
#    from the old full icon, whose background had a transparent patch in one
#    corner that iOS flattened to a pale blotch.
param(
    [Parameter(Mandatory)] [string]$Mark,
    [string]$OutMark = 'assets/icon/source/aftermind-mark.png',
    [string]$OutIcon = 'assets/icon/source/aftermind-icon.png',
    [double]$Hue = 40,
    [double]$Warmth = 0.10
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class IconRecolor {
    static double Smooth(double a, double b, double x) {
        double t = Math.Max(0, Math.Min(1, (x - a) / (b - a)));
        return t * t * (3 - 2 * t);
    }

    static Bitmap Load(string path) {
        byte[] bytes = System.IO.File.ReadAllBytes(path);
        using (var ms = new System.IO.MemoryStream(bytes))
        using (var src = new Bitmap(ms)) {
            var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) g.DrawImage(src, 0, 0, src.Width, src.Height);
            return bmp;
        }
    }

    static void Save(Bitmap bmp, string path) {
        if (System.IO.File.Exists(path)) System.IO.File.Delete(path);
        bmp.Save(path, ImageFormat.Png);
    }

    public static Bitmap Recolor(string input, double hue, double warmth) {
        var bmp = Load(input);
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int n = data.Stride * data.Height;
        var px = new byte[n];
        Marshal.Copy(data.Scan0, px, 0, n);
        for (int i = 0; i < n; i += 4) {
            double b = px[i] / 255.0, gr = px[i + 1] / 255.0, r = px[i + 2] / 255.0;
            double max = Math.Max(r, Math.Max(gr, b)), min = Math.Min(r, Math.Min(gr, b));
            double v = max, s = max == 0 ? 0 : (max - min) / max;
            double glow = Smooth(0.18, 0.42, s) * Smooth(0.30, 0.60, v);
            double s2 = warmth * s + glow * (Math.Min(1, s * 1.1) - warmth * s);
            double h = hue / 60.0;
            int sector = (int)Math.Floor(h) % 6;
            double f = h - Math.Floor(h);
            double p = v * (1 - s2), q = v * (1 - s2 * f), t = v * (1 - s2 * (1 - f));
            double nr, ng, nb;
            switch (sector) {
                case 0: nr = v; ng = t; nb = p; break;
                case 1: nr = q; ng = v; nb = p; break;
                case 2: nr = p; ng = v; nb = t; break;
                case 3: nr = p; ng = q; nb = v; break;
                case 4: nr = t; ng = p; nb = v; break;
                default: nr = v; ng = p; nb = q; break;
            }
            px[i] = (byte)Math.Round(nb * 255);
            px[i + 1] = (byte)Math.Round(ng * 255);
            px[i + 2] = (byte)Math.Round(nr * 255);
        }
        Marshal.Copy(px, 0, data.Scan0, n);
        bmp.UnlockBits(data);
        return bmp;
    }

    // Brightest strongly saturated pixel = the dot's centre.
    static PointF FindDot(Bitmap mark) {
        double best = -1; int bx = 0, by = 0;
        for (int y = 0; y < mark.Height; y += 2)
            for (int x = 0; x < mark.Width; x += 2) {
                var c = mark.GetPixel(x, y);
                if (c.A < 200) continue;
                double score = (c.R - c.B) + c.G * 0.2;
                if (score > best) { best = score; bx = x; by = y; }
            }
        return new PointF(bx, by);
    }

    static void Radial(Graphics g, PointF c, float radius, Color inner, Color outer) {
        using (var path = new GraphicsPath()) {
            path.AddEllipse(c.X - radius, c.Y - radius, radius * 2, radius * 2);
            using (var brush = new PathGradientBrush(path)) {
                brush.CenterPoint = c;
                brush.CenterColor = inner;
                brush.SurroundColors = new[] { outer };
                var blend = new Blend(4);
                blend.Factors = new float[] { 0f, 0.35f, 0.75f, 1f };
                blend.Positions = new float[] { 0f, 0.4f, 0.75f, 1f };
                brush.Blend = blend;
                g.FillEllipse(brush, c.X - radius, c.Y - radius, radius * 2, radius * 2);
            }
        }
    }

    public static void Build(string markIn, string markOut, string iconOut, double hue, double warmth) {
        using (var mark = Recolor(markIn, hue, warmth)) {
            Save(mark, markOut);
            int w = mark.Width, h = mark.Height;
            var dot = FindDot(mark);
            using (var icon = new Bitmap(w, h, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(icon)) {
                g.SmoothingMode = SmoothingMode.HighQuality;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                using (var bg = new LinearGradientBrush(new Rectangle(0, 0, w, h),
                    Color.FromArgb(40, 41, 46), Color.FromArgb(14, 15, 17), 55f)) {
                    g.FillRectangle(bg, 0, 0, w, h);
                }
                // A faint lift behind the rings, so they sit in light, not in a void.
                Radial(g, new PointF(w * 0.46f, h * 0.46f), w * 0.62f,
                    Color.FromArgb(38, 255, 244, 225), Color.FromArgb(0, 255, 244, 225));
                // The gold glow the dot throws.
                Radial(g, dot, w * 0.24f,
                    Color.FromArgb(110, 212, 169, 79), Color.FromArgb(0, 212, 169, 79));
                g.DrawImage(mark, 0, 0, w, h);
                Save(icon, iconOut);
            }
        }
    }
}
'@

[IconRecolor]::Build((Resolve-Path $Mark).Path, [System.IO.Path]::GetFullPath($OutMark),
    [System.IO.Path]::GetFullPath($OutIcon), $Hue, $Warmth)
Write-Output "Built $OutMark and $OutIcon from $Mark"
