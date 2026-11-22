using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.MPLobby
{
    internal class MPLobbySpecific : LevelSpecificFixesBase
    {
        public override void PreCorrect(LevelSpecificPipeline pipeline)
        {
            var biop = pipeline.ME3BioP;
            var bin = biop.GetLevelBinary();

            for (int i = 0; i < bin.Actors.Count; i++)
            {
                if (biop.TryGetUExport(bin.Actors[i], out var actor))
                {
                    if (actor.ClassName == "PrefabInstance")
                        bin.Actors[i] = 0; // Do not port PrefabInstance currently
                }
            }

            biop.GetLevel().WriteBinary(bin);

            // 10/17/2026 - Force weapon bench weapons to always update their light enviornment so it doesn't spawn black on race conditions.
            // Likely makes worse perf but it's only for one weapon on the bench.
            // There is only one copy of the weapon bench in LMP so this is fine to edit directly without renames.
            biop.FindExport("GUI_SF_WeaponBench.Prefab.WeaponBench.WeaponBench_Arc11.BioLightEnv0").WriteProperty(new BoolProperty(true, "bRequiresNonLatentUpdates"));
        }

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            // Add classes to MPLobby - we don't put into MPCommon as they just waste memory outside of the lobby level
            CompileLobbyClasses(pipeline);
        }

        /// <summary>
        /// Compiles the classes in the Classes folder next to this file into the lobby package, similar to MPCommon.cs
        /// </summary>
        private static void CompileLobbyClasses(LevelSpecificPipeline pipeline)
        {
            var classFolder = Path.Combine(MilanShared.PipelineRoot, "Levels", "MPLobby", "Classes");
            if (!Directory.Exists(classFolder))
            {
                return;
            }

            var sources = Directory.GetFiles(classFolder, "*.uc", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase).ToList();
            if (sources.Count == 0)
            {
                return;
            }

            // Copied from MPCommon
            var package = pipeline.LE3BioP;
            var options = new UnrealScriptOptionsPackage
            {
                Cache = pipeline.Cache,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(package),
            };
            using var lib = new FileLib(package);
            if (!lib.Initialize(options))
            {
                MilanShared.LogFailedFileLibInit(lib);
                throw new InvalidDataException($"Unable to initialize the FileLib for {package.FileNameNoExtension}");
            }

            var parent = package.CreatePackageExport(MilanPackages.SFXGameContentMilan);
            var compiledClasses = new List<ExportEntry>();
            foreach (var source in sources)
            {
                var className = Path.GetFileNameWithoutExtension(source);
                var existing = package.FindExport($"{MilanPackages.SFXGameContentMilan}.{className}");
                var (_, log) = UnrealScriptCompiler.CompileClass(package, File.ReadAllText(source), lib, options, export: existing, parent: parent, intendedClassName: className);
                if (log.HasErrors)
                {
                    throw new InvalidDataException($"Could not compile lobby class {className}: {string.Join(Environment.NewLine, log.AllErrors)}");
                }

                var classExport = package.FindExport($"{MilanPackages.SFXGameContentMilan}.{className}");
                if (classExport == null)
                {
                    throw new InvalidDataException($"Compiled class not found: {MilanPackages.SFXGameContentMilan}.{className}");
                }
                compiledClasses.Add(classExport);
                MilanLog.Information($"Compiled lobby class {classExport.InstancedFullPath}", customPrefix: pipeline.LogCategory);
            }

            // Ensure they stay referenced or GC will kill them
            KeepClassesLoaded(package, compiledClasses);
        }

        /// <summary>
        /// Keeps listed exports rooted - lobby can't use ObjectReferencer
        /// </summary>
        private static void KeepClassesLoaded(IMEPackage package, List<ExportEntry> classes)
        {
            var world = package.FindExport("TheWorld");
            ObjectBinary.EditBinary<World>(world, bin =>
            {
                var list = bin.ExtraReferencedObjects.ToList();
                foreach (var classExport in classes)
                {
                    if (!list.Contains(classExport.UIndex))
                    {
                        list.Add(classExport.UIndex);
                    }
                }
                bin.ExtraReferencedObjects = list.ToArray();
            });
        }
    }
}
