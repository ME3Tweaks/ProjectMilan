using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class ShaderImportCacheTests
{
    [TestMethod]
    public void PlanningReusesCurrentPackageAndImportResultsThenReleasesThem()
    {
        string root = Path.Combine(Path.GetTempPath(), "MilanImportCache_" + Guid.NewGuid().ToString("N"));
        string output = Path.Combine(root, "Output"), game = Path.Combine(root, "Game");
        Directory.CreateDirectory(output);
        Directory.CreateDirectory(Path.Combine(game, "Engine", "Shaders"));
        try
        {
            string donorPath = Path.Combine(output, "Donor.pcc");
            using (var donor = MEPackageHandler.CreateAndOpenPackage(donorPath, MEGame.LE3))
            {
                var group = donor.CreateExport("Donor", "Package", indexed: false);
                Fixtures.Texture(donor, "Texture").idxLink = group.UIndex;
                donor.Save();
            }
            using var importer = Fixtures.Package("Importer");
            var groupImport = new ImportEntry(importer, 0, "Donor") { ClassName = "Package", PackageFile = "Core" };
            importer.AddImport(groupImport);
            var textureImport = new ImportEntry(importer, groupImport.UIndex, "Texture") { ClassName = "Texture2D", PackageFile = "Engine" };
            importer.AddImport(textureImport);
            using var context = new OfflineShaderInstallContext(output, game, null, null);
            var messages = new List<string>();
            ExportEntry? first = null;
            bool checkedDuringScan = false;
            context.Plan(diagnostics: message =>
            {
                messages.Add(message);
                if (checkedDuringScan || !message.Contains(" / local shader cache", StringComparison.Ordinal)) return;
                checkedDuringScan = true;
                first = context.ResolveImport(textureImport);
                Assert.IsNotNull(first);
                Assert.AreSame(first, context.ResolveImport(textureImport));
            });
            Assert.IsTrue(checkedDuringScan);
            Assert.IsTrue(messages.Any(m => m.Contains("import-result-cache-hits=1", StringComparison.Ordinal)));
            Assert.IsFalse(messages.Any(m => m.Contains("resolver-package-open=", StringComparison.Ordinal)),
                "The package being scanned must not be reopened for import resolution.");
            Assert.IsNull(context.Cache.GetCachedPackage(donorPath, openIfNotInCache: false));
            // The per-scan result must be gone; a fresh read after planning must see new package contents.
            using (var changed = MEPackageHandler.OpenMEPackage(donorPath, forceLoadFromDisk: true))
            {
                changed.FindExport("Donor.Texture").ObjectName = "Changed";
                changed.Save();
            }
            Assert.IsNull(context.ResolveImport(textureImport));
        }
        finally { Directory.Delete(root, recursive: true); }
    }
}
