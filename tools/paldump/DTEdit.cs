using UAssetAPI;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;
using UAssetAPI.ExportTypes;
using UAssetAPI.PropertyTypes.Structs;
using UAssetAPI.PropertyTypes.Objects;

public static class DTEdit {
    const string USMAP = @"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64\ue4ss\Pal-5.1.1-0+++UE5+Release-5.1-c2ac246.usmap";

    public static void Inspect(string path) {
        var asset = new UAsset(path, EngineVersion.VER_UE5_1, new Usmap(USMAP));
        Console.WriteLine($"exports: {asset.Exports.Count}");
        foreach (var e in asset.Exports) {
            Console.WriteLine($"  export: {e.ObjectName} ({e.GetType().Name})");
            if (e is DataTableExport dt) {
                Console.WriteLine($"    rows: {dt.Table.Data.Count}");
                foreach (var row in dt.Table.Data) Console.WriteLine($"      {row.Name}");
                var berries = dt.Table.Data.FirstOrDefault(r => r.Name.ToString() == (Environment.GetEnvironmentVariable("DTROW") ?? "Berries"));
                if (berries != null) {
                    Console.WriteLine("    --- campos da row " + (Environment.GetEnvironmentVariable("DTROW") ?? "Berries") + " ---");
                    foreach (var p in berries.Value)
                        Console.WriteLine($"      {p.Name,-26} {p.GetType().Name,-24} = {p.RawValue}");
                }
            }
        }
    }
}

public static class DTWrite {
    const string USMAP = @"C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64\ue4ss\Pal-5.1.1-0+++UE5+Release-5.1-c2ac246.usmap";

    public static void AddRainbowRow(string inPath, string outPath) {
        var asset = new UAsset(inPath, EngineVersion.VER_UE5_1, new Usmap(USMAP));
        var dt = asset.Exports.OfType<DataTableExport>().First();

        var berries = dt.Table.Data.First(r => r.Name.ToString() == (Environment.GetEnvironmentVariable("DTROW") ?? "Berries"));
        // clone profundo pela serializacao interna da UAssetAPI
        var novo = (StructPropertyData)berries.Clone();
        novo.Name = new FName(asset, "RainbowStar");

        foreach (var p in novo.Value) {
            switch (p.Name.ToString()) {
                case "CropClassPath": {
                    var sp = (SoftObjectPropertyData)p;
                    sp.Value = new FSoftObjectPath(
                        new FTopLevelAssetPath(
                            new FName(asset, Environment.GetEnvironmentVariable("CROPPKG") ?? "/Game/Mods/RainbowStar/BP_PalMapObjectFarmCrop_RainbowStar"),
                            new FName(asset, Environment.GetEnvironmentVariable("CROPCLS") ?? "BP_PalMapObjectFarmCrop_RainbowStar_C")),
                        new FString(""));
                    break;
                }
                case "CropBlueprintClassName":
                    ((NamePropertyData)p).Value = new FName(asset, "BP_PalMapObjectFarmCrop_RainbowStar");
                    break;
                case "GrowupTime":   ((FloatPropertyData)p).Value = 180f; break;
                case "CropItemNum":  ((IntPropertyData)p).Value = 10;     break;
            }
        }

        // TESTE DE CARGA DO PAK _P: mexe numa row VANILLA de forma visivel.
        // Se as bagas passarem a crescer em 10s no jogo, o pak _P esta sendo lido.
        foreach (var p in berries.Value)
            if (p.Name.ToString() == "GrowupTime") ((FloatPropertyData)p).Value = 180f;
        Console.WriteLine("Berries.GrowupTime restaurado para 180");

        dt.Table.Data.Add(novo);
        Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
        asset.Write(outPath);
        Console.WriteLine($"row RainbowStar adicionada. rows agora: {dt.Table.Data.Count}");
        Console.WriteLine($"escrito: {outPath}");
    }
}
