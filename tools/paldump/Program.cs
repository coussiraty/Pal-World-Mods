using CUE4Parse.Encryption.Aes;
using CUE4Parse.UE4.Objects.Core.Misc;
using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Versions;
using CUE4Parse.MappingsProvider;
using CUE4Parse.MappingsProvider.Usmap;
using Newtonsoft.Json;

class Program {
    static int Main(string[] args) {
        var paks = @"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Content\Paks";
        var usmap = @"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64\ue4ss\Pal-5.1.1-0+++UE5+Release-5.1-c2ac246.usmap";
        var outDir = @"C:\PMK\paldump\out";
        Directory.CreateDirectory(outDir);

        var provider = new DefaultFileProvider(paks, SearchOption.AllDirectories,
            new VersionContainer(EGame.GAME_UE5_1));
        provider.Initialize();
        provider.SubmitKey(new FGuid(), new FAesKey(new byte[32]));
        provider.MappingsContainer = new FileUsmapTypeMappingsProvider(usmap);
        Console.WriteLine($"arquivos no provider: {provider.Files.Count}");

        if (args.Length > 2 && args[0] == "--dt-write") { DTWrite.AddRainbowRow(args[1], args[2]); return 0; }
        if (args.Length > 1 && args[0] == "--dt-inspect") { DTEdit.Inspect(args[1]); return 0; }
        if (args.Length > 1 && args[0] == "--tex") {
            var tDir = "C:/PMK/paldump/tex";
            int okc = 0;
            foreach (var t in args.Skip(1)) if (TexDump.Export(provider, t, tDir)) okc++;
            Console.WriteLine($"texturas: {okc}/{args.Length-1}");
            return 0;
        }
        var meshMode = args.Length > 0 && args[0] == "--mesh";
        var targets = meshMode ? args.Skip(1) : args;
        if (meshMode) {
            var mDir = @"C:\PMK\paldump\meshes";
            int ok = 0;
            foreach (var t in targets) if (MeshDump.Export(provider, t, mDir)) ok++;
            Console.WriteLine($"exportados: {ok}/{targets.Count()}");
            return 0;
        }
        foreach (var target in targets) {
            try {
                var pkg = provider.LoadPackage(target);
                var json = JsonConvert.SerializeObject(pkg.GetExports(), Formatting.Indented);
                var name = target.Split('/').Last().Replace(".uasset","");
                var path = Path.Combine(outDir, name + ".json");
                File.WriteAllText(path, json);
                Console.WriteLine($"OK  {name}  ->  {json.Length} chars  ->  {path}");
            } catch (Exception e) {
                Console.WriteLine($"ERRO {target}: {e.Message}");
            }
        }
        return 0;
    }
}
