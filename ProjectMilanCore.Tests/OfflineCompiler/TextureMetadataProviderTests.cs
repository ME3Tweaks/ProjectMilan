using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class TextureMetadataProviderTests
{
    private static string tempRoot = "";

    [ClassInitialize]
    public static void CreateTempRoot(TestContext _)
    {
        tempRoot = Path.Combine(Path.GetTempPath(), "MilanMetadataTests_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);
    }

    [ClassCleanup]
    public static void DeleteTempRoot()
    {
        try { Directory.Delete(tempRoot, true); } catch (IOException) { }
    }

    /// <summary>Saves a donor package holding Donor.Textures.Norm, whose binary is junk.</summary>
    private static string SaveDonor(string folder, string compression)
    {
        Directory.CreateDirectory(folder);
        string path = Path.Combine(folder, "Donor.pcc");
        using var donor = MEPackageHandler.CreateAndOpenPackage(path, MEGame.LE3);
        // Seekfree layout: the original package is a root export, so the path matches the import's.
        var root = donor.CreateExport("Donor", "Package", indexed: false);
        var group = donor.CreateExport("Textures", "Package", root, indexed: false);
        var texture = Fixtures.Texture(donor, "Norm", compression);
        texture.idxLink = group.UIndex;
        donor.Save();
        return path;
    }

    private static ImportEntry ImportDonorTexture(IMEPackage package)
    {
        var root = new ImportEntry(package, 0, "Donor") { ClassName = "Package", PackageFile = "Core" };
        package.AddImport(root);
        var group = new ImportEntry(package, root.UIndex, "Textures") { ClassName = "Package", PackageFile = "Core" };
        package.AddImport(group);
        var texture = new ImportEntry(package, group.UIndex, "Norm") { ClassName = "Texture2D", PackageFile = "Engine" };
        package.AddImport(texture);
        return texture;
    }

    [TestMethod]
    public void ExportReadsPropertiesOnlyAndCachesPerReference()
    {
        using var package = Fixtures.Package("ExportMetadata");
        var texture = Fixtures.Texture(package, "Tex", "TC_NormalmapBC5", unpackMin: -1f);
        using var provider = new PackageTextureMetadataProvider();

        var metadata = provider.GetMetadata(texture);
        var again = provider.GetMetadata(texture);

        Assert.IsNotNull(metadata);
        Assert.AreSame(metadata, again);
        Assert.AreEqual("TC_NormalmapBC5", metadata.CompressionSettings);
        Assert.AreEqual(-1f, metadata.UnpackMin.X);
        Assert.AreEqual(1, provider.Resolutions.Count, "Cached lookups are not recorded twice.");
    }

    [TestMethod]
    public void NonTextureExportFailsWithAReason()
    {
        using var package = Fixtures.Package("NotATexture");
        var material = Fixtures.Material(package, "Mat");
        using var provider = new PackageTextureMetadataProvider();

        Assert.IsNull(provider.GetMetadata(material));
        StringAssert.Contains(provider.Resolutions.Single().Failure, "not a Texture2D");
    }

    [TestMethod]
    public void ImportIsReadFromTheFirstDonorThatHasIt()
    {
        string missing = Path.Combine(tempRoot, "Missing", "Donor.pcc");
        string empty = Path.Combine(tempRoot, "Empty", "Donor.pcc");
        Directory.CreateDirectory(Path.GetDirectoryName(empty)!);
        using (var emptyPackage = MEPackageHandler.CreateAndOpenPackage(empty, MEGame.LE3))
            emptyPackage.Save();
        string donor = SaveDonor(Path.Combine(tempRoot, "Output"), "TC_NormalmapBC7");
        using var package = Fixtures.Package("ImportMetadata");
        var import = ImportDonorTexture(package);
        using var provider = new PackageTextureMetadataProvider(_ => [missing, empty, donor]);

        var metadata = provider.GetMetadata(import);

        Assert.IsNotNull(metadata, provider.Resolutions.Single().Failure);
        Assert.AreEqual("TC_NormalmapBC7", metadata.CompressionSettings);
        Assert.AreEqual(donor, provider.Resolutions.Single().SourcePackage);
    }

    [TestMethod]
    public void DecookedExportTexturesReadWhatTheGameLoads()
    {
        // The decooked graph's default is the pre-conversion texture; the converted copy in the output decides the decode.
        string donor = SaveDonor(Path.Combine(tempRoot, "Converted"), "TC_NormalmapBC7");
        string decookedPath = Path.Combine(tempRoot, "Decooked", "Donor.pcc");
        Directory.CreateDirectory(Path.GetDirectoryName(decookedPath)!);
        using (var decooked = MEPackageHandler.CreateAndOpenPackage(decookedPath, MEGame.LE3))
        {
            var root = decooked.CreateExport("Donor", "Package", indexed: false);
            var group = decooked.CreateExport("Textures", "Package", root, indexed: false);
            Fixtures.Texture(decooked, "Norm", "TC_Normalmap").idxLink = group.UIndex;
            decooked.Save();
        }
        using var decookedPackage = MEPackageHandler.OpenMEPackage(decookedPath, forceLoadFromDisk: true);
        var texture = decookedPackage.FindExport("Donor.Textures.Norm")!;

        using var byPath = new PackageTextureMetadataProvider(_ => [donor], _ => true);
        Assert.AreEqual("TC_NormalmapBC7", byPath.GetMetadata(texture)!.CompressionSettings);

        using var noDonor = new PackageTextureMetadataProvider(_ => [], _ => true);
        Assert.AreEqual("TC_Normalmap", noDonor.GetMetadata(texture)!.CompressionSettings, "falls back to the export itself");

        using var plain = new PackageTextureMetadataProvider(_ => [donor]);
        Assert.AreEqual("TC_Normalmap", plain.GetMetadata(texture)!.CompressionSettings, "other exports read themselves");
    }

    [TestMethod]
    public void ImportWithoutADonorFailsInsteadOfGuessing()
    {
        using var package = Fixtures.Package("NoDonor");
        var import = ImportDonorTexture(package);
        using var noLocator = new PackageTextureMetadataProvider();
        using var nothingFound = new PackageTextureMetadataProvider(_ => [Path.Combine(tempRoot, "Nowhere", "Donor.pcc")]);

        Assert.IsNull(noLocator.GetMetadata(import));
        StringAssert.Contains(noLocator.Resolutions.Single().Failure, "no donor locator");
        Assert.IsNull(nothingFound.GetMetadata(import));
        StringAssert.Contains(nothingFound.Resolutions.Single().Failure, "file missing");
    }

    [TestMethod]
    public void ObjectDatabaseLocatorPrefersOutputPackages()
    {
        string vanilla = SaveDonor(Path.Combine(tempRoot, "Game", "BioGame", "CookedPCConsole"), "TC_NormalmapBC5");
        string output = SaveDonor(Path.Combine(tempRoot, "Game", "BioGame", "DLC", "DLC_MOD_Milan", "CookedPCConsole"), "TC_NormalmapBC7");
        var database = ObjectInstanceDB.CreateEmpty(MEGame.LE3);
        foreach (var path in new[] { output, vanilla })
        {
            using var donorPackage = MEPackageHandler.OpenMEPackage(path);
            database.AddFileToDB(donorPackage, path, gamePathOverride: Path.Combine(tempRoot, "Game"));
        }
        using var package = Fixtures.Package("LocatorTest");
        var import = ImportDonorTexture(package);

        var plain = TextureDonorLocators.FromObjectDatabase(database, Path.Combine(tempRoot, "Game"))(import).ToArray();
        var preferred = TextureDonorLocators.FromObjectDatabase(database, Path.Combine(tempRoot, "Game"),
            [Path.Combine(tempRoot, "Game", "BioGame", "DLC", "DLC_MOD_Milan")])(import).ToArray();

        CollectionAssert.AreEquivalent(new[] { vanilla, output }, plain);
        Assert.AreEqual(output, preferred[0]);
        using var provider = new PackageTextureMetadataProvider(TextureDonorLocators.Concat(_ => [],
            TextureDonorLocators.FromObjectDatabase(database, Path.Combine(tempRoot, "Game"),
                [Path.Combine(tempRoot, "Game", "BioGame", "DLC", "DLC_MOD_Milan")])));
        Assert.AreEqual("TC_NormalmapBC7", provider.GetMetadata(import)!.CompressionSettings);
    }
}
