using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Numerics;

namespace MilanShaderHost.LEX
{
    internal class LevelBuildTools
    {
        public static ExportEntry CreateTextMesh(IMEPackage targetPackage, string text)
        {
            var meshName = "TextMesh_" + text;
            var existingMesh = targetPackage.FindExport(meshName);
            if (existingMesh != null)
            {
                return existingMesh;
            }

            // Does not sanitize text!
            var staticMesh = ExportCreator.CreateExport(targetPackage, meshName, "StaticMesh", indexed: false);
            PropertyCollection props = new PropertyCollection();
            props.AddOrReplaceProp(new IntProperty(1, "LightMapCoordinateIndex"));
            props.AddOrReplaceProp(new BoolProperty(true, "UseSimpleBoxCollision"));

            var smBin = StaticMesh.Create();

            // Initial implementation (no shared vertexes): each letter uses 4 vertices which creates 2 adjacent tris. 0 1 2 and 2 3 0.
            // 1 - - 2
            // |   / |
            // | /   |
            // 0 - - 3
            // Unsure if above implementation is same as bioware's order, not sure if it matters.

            var smrd = new StaticMeshRenderData();
            var TextSizeScale = 512; // Scales UV times this for each letter size

            // Build vertices and tris
            float xOffset = 0;
            var vertices = new List<Vector3>();
            float rowHeight = 0;
            List<kDOPCollisionTriangle> tris = new List<kDOPCollisionTriangle>(text.Length * 2);
            for (int charIdx = 0; charIdx < text.Length; charIdx++)
            {
                if (text[charIdx] == ' ')
                {
                    xOffset += (0.1f * TextSizeScale);
                    continue;
                }
                if (TextMap.TryGetValue(text[charIdx], out var info))
                {
                    var localScale = 1f;
                    var width = (info.UV2X - info.UV1X) * TextSizeScale;
                    var height = Math.Abs(info.UV2Y - info.UV1Y) * TextSizeScale;
                    if (rowHeight != 0)
                    {
                        // Match row size
                        if (Math.Abs(height - rowHeight) > 2)
                        {
                            localScale = Math.Abs(rowHeight - height) / ((rowHeight + height) / 2);
                            if (height > rowHeight)
                            {
                                // Scale down
                                localScale = 1 - localScale;
                            }
                            else
                            {
                                // Scale up
                                localScale = 1 + localScale;
                            }
                        }
                        height = rowHeight;
                    }
                    else
                    {
                        // Set height
                        rowHeight = height;
                    }

                    var vertexStart = (ushort)vertices.Count;
                    vertices.Add(new Vector3(xOffset, height, 0));
                    vertices.Add(new Vector3(xOffset, 0, 0));
                    vertices.Add(new Vector3(xOffset + (width * localScale), 0, 0));
                    vertices.Add(new Vector3(xOffset + (width * localScale), height, 0));

                    tris.Add(new kDOPCollisionTriangle(vertexStart, (ushort)(vertexStart + 1u), (ushort)(vertexStart + 2), 0));
                    tris.Add(new kDOPCollisionTriangle((ushort)(vertexStart + 2), (ushort)(vertexStart + 3), vertexStart, 0));
                    xOffset += width * localScale; // No clue what
                }
            }

            smBin.Bounds.SphereRadius = xOffset / 2;

            // KDOP tree
            smBin.kDOPTreeME3UDKLE = new kDOPTreeCompact();
            smBin.kDOPTreeME3UDKLE.RootBound = new kDOP(); // Not sure how to compute this.
            smBin.kDOPTreeME3UDKLE.Nodes = [new kDOPCompact()];
            smBin.kDOPTreeME3UDKLE.Triangles = tris.ToArray();


            // ELEMENT ===============================
            var smrd_element = new StaticMeshElement();
            // smrd_element.Material = 0; // Todo: Ensure is in file for preview
            if (targetPackage.Game == MEGame.LE3)
            {
                var fontPackagePath = $"EntryMenu/font_{Program.Game}.pcc"; // copied to output path by compile step.
                var fontPackage = MEPackageHandler.OpenMEPackage(fontPackagePath);
                var fontMaterial = fontPackage.FindExport("BioS_Citadel_Ext.Emb.FontBlueGlow_01");
                EntryExporter.ExportExportToPackage(fontMaterial, targetPackage, out var ported);
                smrd_element.Material = ported?.UIndex ?? 0;
            }

            smrd_element.NumTriangles = (uint)tris.Count;
            smrd_element.MaxVertexIndex = (uint)vertices.Count - 1;
            smrd_element.bEnableShadowCasting = true;
            smrd_element.Fragments = [new FragmentRange(0, 2)]; // No clue what numPrimitives means

            // POSITION VERTEX BUFFER ===================
            smrd.PositionVertexBuffer = new PositionVertexBuffer();
            smrd.PositionVertexBuffer.NumVertices = (uint)vertices.Count;
            smrd.PositionVertexBuffer.VertexData = vertices.ToArray();
            smrd.PositionVertexBuffer.Stride = 12; // No idea what this is for.
            smrd.unk1 = 1;

            // VERTEX BUFFER ============================
            smrd.VertexBuffer = new StaticMeshVertexBuffer();
            smrd.VertexBuffer.NumTexCoords = 4;
            smrd.VertexBuffer.Stride = 24; // Needs verification
            smrd.VertexBuffer.bUseFullPrecisionUVs = true;
            smrd.VertexBuffer.NumVertices = (uint)vertices.Count;
            var UVMap = new List<StaticMeshVertexBuffer.StaticMeshFullVertex>();
            foreach (var letter in text)
            {
                if (TextMap.TryGetValue(letter, out var info))
                {
                    UVMap.AddRange(info.GenerateUV());
                }
            }

            smrd.VertexBuffer.VertexData = UVMap.ToArray();


            // COLOR VERTEX BUFFER ======================
            // Unknown, empty, just has to be defined
            smrd.ColorVertexBuffer = new ColorVertexBuffer();


            // SHADOW EXTRUSION VERTEX BUFFER ===========
            smrd.ShadowExtrusionVertexBuffer = new ExtrusionVertexBuffer();
            smrd.ShadowExtrusionVertexBuffer.NumVertices = (uint)vertices.Count;
            smrd.ShadowExtrusionVertexBuffer.Stride = 4;
            smrd.ShadowExtrusionVertexBuffer.VertexData = [];

            // INDEX BUFFER =============================
            // Order of vertices. I think this matches the tris list.
            var indexBuffer = new List<ushort>(); // will be optimized later, maybe
            for (int i = 0; i < tris.Count / 2; i++)
            {
                var startIdx = i * 4; // 0 1 2 3 -> 4 5 6 7 -> 8 9 10 11 ...

                // Tri 1
                indexBuffer.Add((ushort)startIdx);
                indexBuffer.Add((ushort)(startIdx + 1));
                indexBuffer.Add((ushort)(startIdx + 2));

                // Tri 2
                indexBuffer.Add((ushort)(startIdx + 2));
                indexBuffer.Add((ushort)(startIdx + 3));
                indexBuffer.Add((ushort)startIdx);

            }
            smrd.IndexBuffer = indexBuffer.ToArray();

            // MISC =====================================
            smrd.NumVertices = (uint)vertices.Count;

            // COMPOSE THE BINARY
            smrd.Elements = [smrd_element];
            smBin.LODModels = [smrd];
            staticMesh.WritePropertiesAndBinary(props, smBin);
            return staticMesh;
        }


        private static TextTextureLetter.EGUIMasterLayer GetLayer(float f)
        {
            if (f == 0.515625f)
                return TextTextureLetter.EGUIMasterLayer.Red;
            if (f == 0.608867f)
                return TextTextureLetter.EGUIMasterLayer.Blue;

            // Todo: Green
            return TextTextureLetter.EGUIMasterLayer.Green;
        }

        private static Dictionary<char, TextTextureLetter> TextMap = new()
        {
            // Have to find the other letters.

            { 'A', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0f, UV1Y = 0f, UV2X = 0.2479248f, UV2Y = 0.16101074f }
            },
            { 'B', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.2479248f, UV1Y = 0f, UV2X = 0.48535156f, UV2Y = 0.16101074f }
            },
            { 'C', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.48706055f, UV1Y = 0f, UV2X = 0.7138672f, UV2Y = 0.16101074f }
            },
            { 'D', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.71533203f, UV1Y = 0f, UV2X = 0.95654297f, UV2Y = 0.16101074f }
            },
            { 'E', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0f, UV1Y = 0.8251953f, UV2X = 0.21875f, UV2Y = 0.98583984f }
            },
            { 'F', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0f, UV1Y = 0.16491699f, UV2X = 0.21777344f, UV2Y = 0.32617188f }
            },
            { 'G', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.21960449f, UV1Y = 0.16491699f, UV2X = 0.4501953f, UV2Y = 0.32617188f }
            },
            { 'H', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.45117188f, UV1Y = 0.16491699f, UV2X = 0.6796875f, UV2Y = 0.32617188f }
            },
            { 'I', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.6821289f, UV1Y = 0.16491699f, UV2X = 0.734375f, UV2Y = 0.32617188f }
            },
            { 'J', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.67089844f, UV1Y = 0.8251953f, UV2X = 0.8886719f, UV2Y = 0.98583984f }
            },
            { 'K', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.22167969f, UV1Y = 0.8251953f, UV2X = 0.44726562f, UV2Y = 0.98583984f }
            },
            { 'L', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0f, UV1Y = 0.33007812f, UV2X = 0.21777344f, UV2Y = 0.4909668f }
            },
            { 'M', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.21960449f, UV1Y = 0.33007812f, UV2X = 0.49487305f, UV2Y = 0.4909668f }
            },
            { 'N', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.4970703f, UV1Y = 0.33007812f, UV2X = 0.72021484f, UV2Y = 0.4909668f }
            },
            { 'O', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0f, UV1Y = 0, UV2X = 0.31835938f, UV2Y = 0.22265625f }
            },
            { 'P', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.78808594f, UV1Y = 0.66015625f, UV2X = 1f, UV2Y = 0.82128906f }
            },
            { 'Q', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0f, UV1Y = 0.49487305f, UV2X = 0.25585938f, UV2Y = 0.6557617f }
            },
            { 'R', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.25756836f, UV1Y = 0.49487305f, UV2X = 0.4970703f, UV2Y = 0.6557617f }
            },
            { 'S', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.5f, UV1Y = 0.49487305f, UV2X = 0.72314453f, UV2Y = 0.6557617f }
            },
            { 'T', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.72314453f, UV1Y = 0.49487305f, UV2X = 0.9433594f, UV2Y = 0.6557617f }
            },
            { 'U', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.73535156f, UV1Y = 0.16491699f, UV2X = 0.9667969f, UV2Y = 0.32617188f }
            },
            { 'V', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0f, UV1Y = 0.66015625f, UV2X = 0.234375f, UV2Y = 0.82128906f }
            },
            { 'W', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.23535156f, UV1Y = 0.66015625f, UV2X = 0.5390625f, UV2Y = 0.82128906f }
            },
            { 'X', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.5419922f, UV1Y = 0.66015625f, UV2X = 0.78808594f, UV2Y = 0.82128906f }
            },
            { 'Y', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.7368164f, UV1Y = 0.33007812f, UV2X = 0.94384766f, UV2Y = 0.4909668f }
            },
            { 'Z', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Red, UV1X = 0.44799805f, UV1Y = 0.8251953f, UV2X = 0.6694336f, UV2Y = 0.98583984f }
            },

            // Lowercase
            { 'a', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0f, UV1Y = 0f, UV2X = 0.16589355f, UV2Y = 0.21472168f }
            },
            { 'b', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.16589355f, UV1Y = 0f, UV2X = 0.34057617f, UV2Y = 0.21472168f }
            },
            { 'c', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.5239258f, UV1Y = 0.39135742f, UV2X = 0.6772461f, UV2Y = 0.60595703f }
            },
            { 'd', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.43139648f, UV1Y = 0f, UV2X = 0.60595703f, UV2Y = 0.21472168f }
            },
            { 'e', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.6899414f, UV1Y = 0.7817383f, UV2X = 0.85546875f, UV2Y = 0.9970703f }
            },

            { 'i', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.8598633f, UV1Y = 0f, UV2X = 0.92285156f, UV2Y = 0.21472168f }
            },
            { 'l', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.7919922f, UV1Y = 0f, UV2X = 0.8466797f, UV2Y = 0.21472168f }
            },

            { 'm', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.61865234f, UV1Y = 0.21472168f, UV2X = 0.8442383f, UV2Y = 0.4296875f }
            },
            { 'n', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.5f, UV1Y = 0.60595703f, UV2X = 0.6743164f, UV2Y = 0.82128906f }
            },
            { 'o', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.3786621f, UV1Y = 0.7817383f, UV2X = 0.55322266f, UV2Y = 0.9970703f }
            },

            { 'r', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.17370605f, UV1Y = 0.21472168f, UV2X = 0.28979492f, UV2Y = 0.4296875f }
            },
            { 'u', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.6899414f, UV1Y = 0.7817383f, UV2X = 0.85546875f, UV2Y = 0.9970703f }
            },
            { 'y', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.6772461f, UV1Y = 0.39135742f, UV2X = 0.8520508f, UV2Y = 0.60595703f }
            },


            // NUMBERS 
            // 0 is same as O (as in 'Oh')
            { '0', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0f, UV1Y = 0, UV2X = 0.31835938f, UV2Y = 0.22265625f }
            },
            { '1', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0f, UV1Y = 0.66796875f, UV2X = 0.15039062f, UV2Y = 0.8901367f }
            },
            { '2', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0.31835938f, UV1Y = 0, UV2X = 0.62109375f, UV2Y = 0.22265625f }
            },
            { '3', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0.62109375f, UV1Y = 0f, UV2X = 0.9067383f, UV2Y = 0.22265625f }
            },
            { '4', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0f, UV1Y = 0.22265625f, UV2X = 0.32788086f, UV2Y = 0.44506836f }
            },
            { '5', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0.32788086f, UV1Y = 0.22265625f, UV2X = 0.62841797f, UV2Y = 0.44506836f }
            },
            { '6', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0.62841797f, UV1Y = 0.22265625f, UV2X = 0.9477539f, UV2Y = 0.44506836f }
            },
            { '7', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0f, UV1Y = 0.44506836f, UV2X = 0.28979492f, UV2Y = 0.66796875f }
            },
            { '8', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0.28979492f, UV1Y = 0.44506836f, UV2X = 0.5864258f, UV2Y = 0.66796875f }
            },
            { '9', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Blue, UV1X = 0.58496094f, UV1Y = 0.44506836f, UV2X = 0.9067383f, UV2Y = 0.66796875f }
            },

            // SYMBOLS
            { '-', new TextTextureLetter() { LayerIndex = TextTextureLetter.EGUIMasterLayer.Green, UV1X = 0.7895508f, UV1Y = 0.66796875f, UV2X = 0.86083984f, UV2Y = 0.8198242f }
            },

        };

        class TextTextureLetter
        {
            internal enum EGUIMasterLayer
            {
                Red,
                Green,
                Blue
            }

            /// <summary>
            /// Letter this represents
            /// </summary>
            public char Letter { get; set; }

            /// <summary>
            /// Top left X position
            /// </summary>
            public float UV1X { get; set; }

            /// <summary>
            /// Top left Y position
            /// </summary>
            public float UV1Y { get; set; }

            /// <summary>
            /// Bottom right X position
            /// </summary>
            public float UV2X { get; set; }

            /// <summary>
            /// Bottom right Y position
            /// </summary>
            public float UV2Y { get; set; }

            /// <summary>
            /// Top left X position - Overlay
            /// </summary>
            public float OL1X { get; set; }

            /// <summary>
            /// Top left Y position - Overlay
            /// </summary>
            public float OL1Y { get; set; }

            /// <summary>
            /// Bottom right X position - Overlay
            /// </summary>
            public float OL2X { get; set; }

            /// <summary>
            /// Bottom right Y position - Overlay
            /// </summary>
            public float OL2Y { get; set; }

            /// <summary>
            /// 0 = R / 1 = G / 2 = B
            /// </summary>
            public EGUIMasterLayer LayerIndex { get; set; }

            private Vector2 GetLayerUV()
            {
                if (LayerIndex == EGUIMasterLayer.Red)
                    return new Vector2(0.97558594f, 0.515625f); // R
                if (LayerIndex == EGUIMasterLayer.Green)
                    return new Vector2(); // G

                // Blue
                return new Vector2(0.97558594f, 0.608867f); // B
            }

            public StaticMeshVertexBuffer.StaticMeshFullVertex[] GenerateUV()
            {
                // 1 - - 2
                // |   / |
                // | /   |
                // 0 - - 3
                return
                [
                    // Vertex 0
                    new StaticMeshVertexBuffer.StaticMeshFullVertex()
                    {
                        TangentX = new PackedNormal(0x80, 0x00, 0x80, 0x7F), // If this is an INT it needs to be done in reverse order
                        TangentZ = new PackedNormal(0x80, 0x80, 0xFF, 0xFF), // If this is an INT it needs to be done in reverse order
                        FullPrecisionUVs =
                        [
                            new Vector2(UV1X, UV2Y), // UV
                            new Vector2(OL1X, OL1Y), // Overlay
                            GetLayerUV(),
                            new Vector2(1, 0), // Unused
                        ]
                    },
                    // Vertex 1 
                    new StaticMeshVertexBuffer.StaticMeshFullVertex()
                    {
                        TangentX = new PackedNormal(0x80, 0x00, 0x80, 0x7F), // If this is an INT it needs to be done in reverse order
                        TangentZ = new PackedNormal(0x80, 0x80, 0xFF, 0xFF), // If this is an INT it needs to be done in reverse order
                        FullPrecisionUVs =
                        [
                            new Vector2(UV1X, UV1Y), // UV
                            new Vector2(OL1X, OL1Y), // Overlay
                            GetLayerUV(), // Layer
                            new Vector2(1, 0), // Unused
                        ]
                    }, 
                    // Vertex 2
                    new StaticMeshVertexBuffer.StaticMeshFullVertex()
                    {
                        TangentX = new PackedNormal(0x80, 0x00, 0x80, 0x7F), // If this is an INT it needs to be done in reverse order
                        TangentZ = new PackedNormal(0x80, 0x80, 0xFF, 0xFF), // If this is an INT it needs to be done in reverse order
                        FullPrecisionUVs =
                        [
                            new Vector2(UV2X, UV1Y), // UV
                            new Vector2(OL1X, OL1Y), // Overlay
                            GetLayerUV(), // Layer
                            new Vector2(1,0), // Unused@
                        ]
                    },
                    // Vertex 3
                    new StaticMeshVertexBuffer.StaticMeshFullVertex()
                    {
                        TangentX = new PackedNormal(0x80, 0x00, 0x80, 0x7F), // If this is an INT it needs to be done in reverse order
                        TangentZ = new PackedNormal(0x80, 0x80, 0xFF, 0xFF), // If this is an INT it needs to be done in reverse order
                        FullPrecisionUVs =
                        [
                            new Vector2(UV2X, UV2Y), // UV
                            new Vector2(OL2X, OL2Y), // Overlay
                            GetLayerUV(), // Layer
                            new Vector2(1, 0), // Unused
                        ]
                    }

                ];
            }
        }
    }
}
