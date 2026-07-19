using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Assets.Exports.StaticMesh;
using CUE4Parse_Conversion;
using CUE4Parse_Conversion.Meshes;

public static class MeshDump {
    public static bool Export(DefaultFileProvider provider, string objectPath, string outDir) {
        try {
            UStaticMesh mesh = null;
            foreach (var o in provider.LoadPackageObjects(objectPath)) {
                if (o is UStaticMesh sm) { mesh = sm; break; }
            }
            if (mesh == null) { Console.WriteLine($"  nao carregou: {objectPath}"); return false; }
            var opts = new ExporterOptions { MeshFormat = EMeshFormat.Gltf2, ExportMaterials = true };
            var exporter = new MeshExporter(mesh, opts);
            Directory.CreateDirectory(outDir);
            if (exporter.TryWriteToDir(new DirectoryInfo(outDir), out _, out var saved)) {
                Console.WriteLine($"  OK  {objectPath}  ->  {saved}");
                return true;
            }
            Console.WriteLine($"  falhou ao escrever: {objectPath}");
            return false;
        } catch (Exception e) {
            Console.WriteLine($"  ERRO {objectPath}: {e.Message}");
            return false;
        }
    }
}
