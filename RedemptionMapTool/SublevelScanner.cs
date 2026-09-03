using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan_ExtraContent.Redemption.Levels.MapPack;

namespace RedemptionMapTool
{
    /// <summary>
    /// Extracts change-manifest data for a single sublevel package (a level referenced by a
    /// BioP_MP*.pcc master's streaming level list).
    /// </summary>
    internal static class SublevelScanner
    {
        public static List<TriggerVolumeEntry> ScanTriggerVolumes(IMEPackage pcc)
        {
            var results = new List<TriggerVolumeEntry>();
            foreach (var exp in pcc.Exports.Where(x => x.ClassName == "BioTriggerVolume"))
            {
                var strrefProp = exp.GetProperty<StringRefProperty>("LocationNameStrref");
                if (strrefProp is null || strrefProp.Value == 0)
                {
                    continue; // only include instances with LocationNameStrref actually set
                }

                results.Add(new TriggerVolumeEntry
                {
                    Tag = exp.GetProperty<NameProperty>("Tag")?.ToString() ?? "",
                    LocationNameStrref = strrefProp.Value,
                    Location = ToVectorDto(CommonStructs.GetVector3(exp, "location", Vector3.Zero)),
                    Rotation = ToRotatorDto(GetRotator(exp, "Rotation")),
                    DrawScale3D = ToVectorDto(CommonStructs.GetVector3(exp, "DrawScale3D", Vector3.One))
                });
            }

            return results;
        }

        public static List<ObjectiveSpawnPointEntry> ScanObjectiveSpawnPoints(IMEPackage pcc)
        {
            var results = new List<ObjectiveSpawnPointEntry>();
            foreach (var exp in pcc.Exports.Where(x => x.ClassName == "SFXOperation_ObjectiveSpawnPoint"))
            {
                var supportedSpawnTags = exp.GetProperty<ArrayProperty<StrProperty>>("SupportedSpawnTags")
                    ?.Select(s => s.Value).ToList() ?? [];

                results.Add(new ObjectiveSpawnPointEntry
                {
                    Tag = exp.GetProperty<NameProperty>("Tag")?.ToString() ?? "",
                    SupportedSpawnTags = supportedSpawnTags,
                    SpawnLocation = exp.GetProperty<EnumProperty>("SpawnLocation")?.Value.ToString() ?? "",
                    Location = ToVectorDto(CommonStructs.GetVector3(exp, "location", Vector3.Zero)),
                    Rotation = ToRotatorDto(GetRotator(exp, "Rotation"))
                });
            }

            return results;
        }

        /// <summary>
        /// Inventories SFXEnemySpawnPoint actors. Some of these were converted from other pre-existing level
        /// nodes and had per-instance edits (cylinder size, extra reach specs, etc.); some are brand new. No
        /// cross-game (OT vs LE) matching is attempted here - that needs a location-based heuristic that isn't
        /// built yet - this is just a raw inventory of what exists in the original file.
        /// </summary>
        public static List<EnemySpawnPointEntry> ScanEnemySpawnPoints(IMEPackage pcc)
        {
            var results = new List<EnemySpawnPointEntry>();
            foreach (var exp in pcc.Exports.Where(x => x.ClassName == "SFXEnemySpawnPoint"))
            {
                var properties = new Dictionary<string, object?>();
                foreach (var prop in exp.GetProperties())
                {
                    var key = prop.Name.Instanced;
                    if (key.Equals("location", StringComparison.OrdinalIgnoreCase) || key.Equals("Rotation", StringComparison.OrdinalIgnoreCase))
                    {
                        continue; // surfaced as first-class fields below
                    }

                    properties[key] = ConvertPropertyValue(prop, pcc, exp, depth: 0);
                }

                results.Add(new EnemySpawnPointEntry
                {
                    ObjectName = exp.InstancedFullPath,
                    Location = ToVectorDto(CommonStructs.GetVector3(exp, "location", Vector3.Zero)),
                    Rotation = ToRotatorDto(GetRotator(exp, "Rotation")),
                    Properties = properties
                });
            }

            return results;
        }

        /// <summary>
        /// Generically converts a property to a JSON-friendly value. An ObjectProperty pointing at a sub-object
        /// this actor owns (e.g. its CylinderComponent) is inlined as a nested object one level deep, since that's
        /// where per-instance overrides like a resized collision cylinder actually live; any other object
        /// reference is recorded as its instanced path string.
        /// </summary>
        private static object? ConvertPropertyValue(Property prop, IMEPackage pcc, ExportEntry owner, int depth)
        {
            switch (prop)
            {
                case IntProperty ip: return ip.Value;
                case FloatProperty fp: return fp.Value;
                case BoolProperty bp: return bp.Value;
                case ByteProperty byp: return byp.Value;
                case EnumProperty ep: return ep.Value.ToString();
                case NameProperty np: return np.ToString();
                case StrProperty sp: return sp.Value;
                case StringRefProperty srp: return srp.Value;
                case ObjectProperty op:
                    var entry = op.ResolveToEntry(pcc);
                    if (entry is ExportEntry subExp && depth < 2 && Equals(subExp.Parent, owner))
                    {
                        var nested = new Dictionary<string, object?> { ["ClassName"] = subExp.ClassName };
                        foreach (var subProp in subExp.GetProperties())
                        {
                            nested[subProp.Name.Instanced] = ConvertPropertyValue(subProp, pcc, subExp, depth + 1);
                        }

                        return nested;
                    }

                    return entry?.InstancedFullPath;
                case StructProperty stp:
                    var structDict = new Dictionary<string, object?>();
                    foreach (var subProp in stp.Properties)
                    {
                        structDict[subProp.Name.Instanced] = ConvertPropertyValue(subProp, pcc, owner, depth);
                    }

                    return structDict;
                case ArrayPropertyBase apb:
                    var list = new List<object?>();
                    foreach (Property item in apb)
                    {
                        list.Add(ConvertPropertyValue(item, pcc, owner, depth));
                    }

                    return list;
                case NoneProperty:
                    return null;
                default:
                    return prop.ToString();
            }
        }

        private static Rotator? GetRotator(ExportEntry exp, string propName)
        {
            var rotProp = exp.GetProperty<StructProperty>(propName);
            return rotProp is null ? null : CommonStructs.GetRotator(rotProp);
        }

        private static VectorDto ToVectorDto(Vector3 v) => new() { X = v.X, Y = v.Y, Z = v.Z };

        private static RotatorDto ToRotatorDto(Rotator? r) =>
            r is null ? new RotatorDto() : new RotatorDto { Pitch = r.Value.Pitch, Yaw = r.Value.Yaw, Roll = r.Value.Roll };
    }
}
