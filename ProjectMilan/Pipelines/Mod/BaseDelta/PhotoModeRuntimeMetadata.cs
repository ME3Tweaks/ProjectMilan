using System;
using System.IO;
using System.Linq;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Mod.BaseDelta;

/// <summary>
/// Cooked instancing traits are not fully expressible in decompiled UnrealScript. Restore them
/// after class compilation so camera/effect references are duplicated for each owning instance.
/// </summary>
internal static class PhotoModeRuntimeMetadata
{
    internal static readonly string[] Classes = ["BioPlayerController", "SFXGameModeSpectator", "SFXGameModePhoto"];
    internal const UnrealFlags.EClassFlags ClassTraits = UnrealFlags.EClassFlags.HasInstancedProps | UnrealFlags.EClassFlags.HasComponents;
    internal const UnrealFlags.EPropertyFlags PropertyTraits = UnrealFlags.EPropertyFlags.Component | UnrealFlags.EPropertyFlags.NeedCtorLink;

    internal static void Apply(IMEPackage package, IMEPackage vanilla)
    {
        foreach (var name in Classes)
        {
            var target = package.FindExport(name) ?? throw new InvalidDataException($"Missing patched {name}");
            var original = vanilla.FindExport(name) ?? throw new InvalidDataException($"Missing vanilla {name}");
            var targetClass = target.GetBinaryData<UClass>();
            targetClass.ClassFlags |= original.GetBinaryData<UClass>().ClassFlags & ClassTraits;
            target.WriteBinary(targetClass);

            foreach (var originalField in vanilla.Exports.Where(e => e.idxLink == original.UIndex && e.ClassName.EndsWith("Property", StringComparison.Ordinal)))
            {
                var field = package.FindExport(originalField.InstancedFullPath) ?? throw new InvalidDataException($"Missing patched {originalField.InstancedFullPath}");
                if (field.ClassName != originalField.ClassName)
                    throw new InvalidDataException($"Property type changed for {field.InstancedFullPath}");
                var originalProperty = (UProperty)ObjectBinary.From(originalField);
                var targetProperty = (UProperty)ObjectBinary.From(field);
                targetProperty.PropertyFlags |= originalProperty.PropertyFlags & PropertyTraits;
                field.WriteBinary(targetProperty);
            }
        }
    }
}
