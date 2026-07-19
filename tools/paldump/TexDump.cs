using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Assets.Exports.Texture;
using CUE4Parse_Conversion.Textures;
using SkiaSharp;

public static class TexDump {
    public static bool Export(DefaultFileProvider provider, string objectPath, string outDir) {
        try {
            UTexture2D tex = null;
            foreach (var o in provider.LoadPackageObjects(objectPath))
                if (o is UTexture2D t) { tex = t; break; }
            if (tex == null) { Console.WriteLine($"  nao e textura: {objectPath}"); return false; }
            var ct = tex.Decode();
            var bmp = ct?.ToSkBitmap();
            if (bmp == null) { Console.WriteLine($"  decode falhou: {objectPath}"); return false; }
            Directory.CreateDirectory(outDir);
            var nome = objectPath.Split('/').Last() + ".png";
            using var img = SKImage.FromBitmap(bmp);
            using var data = img.Encode(SKEncodedImageFormat.Png, 100);
            using var fs = File.OpenWrite(Path.Combine(outDir, nome));
            data.SaveTo(fs);
            Console.WriteLine($"  OK  {nome}  ({bmp.Width}x{bmp.Height})");
            return true;
        } catch (Exception e) { Console.WriteLine($"  ERRO {objectPath}: {e.Message}"); return false; }
    }
}
