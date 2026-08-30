/*
 * JojoDiff - C# port (diff only)
 *
 * Original C++ code Copyright (C) 2002-2020 Joris Heirbaut
 * C# port maintains the original algorithm and structure. The patch (jpatch)
 * side has been removed; this produces diff/patch files only.
 *
 * This file is a conversion of the entrypoint of JojoDiff for use as a C# library.
 *
 * JojoDiff is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace JDiffCS
{

    public enum OutputFormat
    {
        Binary = 0,   // JOutBin  (matches CLI default, -j / no flag)
        Listing = 1,  // JOutAsc  (matches --listing / -l)
        Regions = 2,  // JOutRgn  (matches --regions / -r)
    }

    /// <summary>
    /// A diff input/output that can be either a file path or an already-open
    /// Stream. Implicit conversions let callers freely mix the two, e.g.:
    ///   JDiffLib.Run("old.bin", someStream, "out.jdf");
    /// Streams passed in are never disposed by JDiffLib — the caller owns them.
    /// Paths are opened and disposed internally.
    /// </summary>
    public readonly struct JDiffSource
    {
        public string Path { get; }
        public Stream Stream { get; }
        public bool IsPath => Path != null;

        public JDiffSource(string path)
        {
            Path = path ?? throw new ArgumentNullException(nameof(path));
            Stream = null;
        }

        public JDiffSource(Stream stream)
        {
            Stream = stream ?? throw new ArgumentNullException(nameof(stream));
            Path = null;
        }

        public static implicit operator JDiffSource(string path) => new JDiffSource(path);
        public static implicit operator JDiffSource(Stream stream) => new JDiffSource(stream);
    }

    /// <summary>
    /// Mirrors the tunables Program.Main derives from argv, with the same
    /// defaults. Values here are in the same "pre-scaling" units Main uses
    /// internally (e.g. buffer sizes in MB, not bytes) — Run() applies the
    /// exact same scaling/rounding Main does.
    /// </summary>
    public sealed class JDiffOptions
    {
        public OutputFormat OutputFormat = OutputFormat.Binary;
        public int Verbosity = 0;

        public bool CompareAllBlocks = true;   // lbCmpAll
        public bool BucketSource = true;       // lbSrcBkt
        public int SourceScanMode = 1;         // liSrcScn

        public int MatchMin = 2;               // liMchMin
        public int MatchMax = 128;             // liMchMax
        public int HashTableMb = 32;           // liHshMbt

        public long SourceBufferMb = 0;        // llBufOrg, pre-scaling (0 = auto)
        public long DestBufferMb = 0;          // llBufNew, pre-scaling (0 = auto)
        public int BlockSize = 32 * 1024;      // liBlkSze
        public int SearchAheadBytes = 0;       // liAhdMax (0 = auto: DestBuffer - BlockSize)

        public bool SequentialSource = false;  // lbSeqOrg / -p
        public bool SequentialDest = false;    // lbSeqNew / -q

        public string SourceLabel = "Org";
        public string DestLabel = "New";

        /// <summary>
        /// Optional callback invoked with progress in [0.0, 1.0] as the diff proceeds.
        /// Called synchronously on the calling thread from inside Run() -- keep it cheap
        /// (e.g. posting to a UI progress bar), it is not throttled to any wall-clock rate,
        /// only to roughly every ~0.5% of total work. Never invoked if the destination
        /// file's length can't be determined up front (e.g. a non-seekable stream), since
        /// no percentage can be computed in that case.
        /// </summary>
        public Action<double> ProgressChanged = null;

        public static JDiffOptions Default => new JDiffOptions();

        /// <summary>
        /// Equivalent of the CLI's --better / -b flag. Returns a modified
        /// clone so it can be chained: JDiffOptions.Default.Better().
        /// With the stock defaults this resolves to:
        ///   MatchMin=4, MatchMax=512, HashTableMb=128, SourceBufferMb=4 (=> 4MB),
        ///   DestBufferMb still 0 => inherits SourceBufferMb => also 4MB,
        ///   BucketSource=true, CompareAllBlocks=true, SourceScanMode=1.
        /// </summary>
        public JDiffOptions Better()
        {
            var o = Clone();
            o.CompareAllBlocks = true;
            o.BucketSource = true;
            o.SourceScanMode = 1;
            o.MatchMin *= 2;
            o.MatchMax *= 4;
            o.HashTableMb *= 4;
            o.SourceBufferMb = (o.SourceBufferMb <= 0 ? 1 : o.SourceBufferMb) * 4;
            return o;
        }

        /// <summary>Equivalent of the CLI's --lazy / -f flag.</summary>
        public JDiffOptions Faster()
        {
            var o = Clone();
            if (o.CompareAllBlocks)
            {
                o.CompareAllBlocks = false;
                o.BucketSource = true;
                o.SourceScanMode = 1;
                o.MatchMin *= 2;
                o.MatchMax /= 2;
                o.SourceBufferMb = (o.SourceBufferMb <= 0 ? 1 : o.SourceBufferMb) * 16;
            }
            else
            {
                o.SourceScanMode = 0;
                o.MatchMin /= 2;
                o.MatchMax /= 2;
            }
            o.HashTableMb /= 2;
            return o;
        }

        internal JDiffOptions Clone() => (JDiffOptions)MemberwiseClone();
    }

    /// <summary>
    /// The result of a Jdiff operation
    /// </summary>

    public sealed class JDiffResult
    {
        public int ExitCode;
        public bool FilesAreDifferent;
        public long EqualBytes;
        public long DataBytes;
        public long ControlBytes;
    }

    /// <summary>
    /// Exception for when Jdiff hits an error
    /// </summary>
    public sealed class JDiffException : Exception
    {
        public int ExitCode { get; }
        public JDiffException(int exitCode, string message) : base(message) => ExitCode = exitCode;
    }


    /// <summary>
    /// Entrypoint for using JdiffCS
    /// </summary>
    public static class JDiffLib
    {
        /// <summary>
        /// Runs a diff. org/dest/output each accept a file path (string) or an
        /// open Stream (implicitly, via JDiffSource) — any mix is fine:
        ///   JDiffLib.Run("old.bin", "new.bin", "out.jdf");
        ///   JDiffLib.Run(orgStream, "new.bin", outStream);
        ///   JDiffLib.Run("old.bin", newStream, "out.jdf", JDiffOptions.Default.Better());
        /// </summary>
        public static JDiffResult Run(JDiffSource org, JDiffSource dest, JDiffSource output, JDiffOptions options = null)
        {
            options ??= JDiffOptions.Default;

            bool lbSrcBkt = options.BucketSource;
            bool lbCmpAll = options.CompareAllBlocks;
            int liSrcScn = options.SourceScanMode;
            int liMchMax = options.MatchMax;
            int liMchMin = options.MatchMin;
            int liHshMbt = options.HashTableMb;
            long llBufOrg = options.SourceBufferMb;
            long llBufNew = options.DestBufferMb;
            int liBlkSze = options.BlockSize;
            int liAhdMax = options.SearchAheadBytes;
            bool lbSeqOrg = options.SequentialSource;
            bool lbSeqNew = options.SequentialDest;

            // ---- exact buffer-sizing math from Program.Main ----
            llBufOrg = (llBufOrg > 0 ? llBufOrg : (lbSeqOrg ? 32 : 1));
            llBufNew = (llBufNew > 0 ? llBufNew : (lbSeqNew ? 16 : llBufOrg)) * 1024 * 1024;
            llBufOrg = llBufOrg * 1024 * 1024;
            liBlkSze = liBlkSze < 4096 ? 4096 : liBlkSze;

            if (llBufOrg % liBlkSze != 0)
            {
                llBufOrg -= llBufOrg % liBlkSze;
                if (llBufOrg <= 0) llBufOrg = liBlkSze;
            }
            if (llBufNew % liBlkSze != 0)
            {
                llBufNew -= llBufNew % liBlkSze;
                if (llBufNew <= 0) llBufNew = liBlkSze;
            }

            if (liAhdMax == 0)
            {
                liAhdMax = (int)(llBufNew - liBlkSze);
                if (liAhdMax < 4096) liAhdMax = 4096;
            }

            Stream strmOrg = null, strmNew = null, strmOut = null;
            bool ownsOrg = false, ownsNew = false, ownsOut = false;
            JFile jflOrg = null, jflNew = null;

            try
            {
                (strmOrg, ownsOrg) = OpenRead(org);
                jflOrg = TryCreateDirect(strmOrg, options.SourceLabel)
                         ?? (JFile)new JFileAheadStream(strmOrg, options.SourceLabel, llBufOrg, liBlkSze, lbSeqOrg);

                (strmNew, ownsNew) = OpenRead(dest);
                jflNew = TryCreateDirect(strmNew, options.DestLabel)
                         ?? (JFile)new JFileAheadStream(strmNew, options.DestLabel, llBufNew, liBlkSze, lbSeqNew);

                (strmOut, ownsOut) = OpenWrite(output);

                // Auto-detected sequential sources (e.g. non-seekable streams)
                // downgrade the same way the CLI does when it detects stdin.
                if (!lbSeqOrg && jflOrg.IsSequential())
                {
                    lbSeqOrg = true; lbCmpAll = false; lbSrcBkt = false; liSrcScn = 0;
                }
                if (!lbSeqNew && jflNew.IsSequential())
                {
                    lbSeqNew = true; liMchMin = 0;
                }

                JOut lpOut = options.OutputFormat switch
                {
                    OutputFormat.Listing => new JOutAsc(new StreamWriter(strmOut) { AutoFlush = false }),
                    OutputFormat.Regions => new JOutRgn(new StreamWriter(strmOut) { AutoFlush = false }),
                    _ => new JOutBin(strmOut),
                };

                var jd = new JDiff(jflOrg, jflNew, lpOut,
                                    liHshMbt, options.Verbosity, lbSrcBkt, liSrcScn,
                                    liMchMax, liMchMin, liAhdMax, lbCmpAll,
                                    options.ProgressChanged);

                int liRet;
                try
                {
                    liRet = jd.Jdiff();
                }
                catch (OutOfMemoryException)
                {
                    throw new JDiffException(JDefs.EXI_MEM, "Error allocating memory.");
                }

                if (liRet == JDefs.EXI_OK)
                    liRet = lpOut.GzOutBytDta > 0 ? JDefs.EXI_DIF : JDefs.EXI_EQL;

                ThrowIfError(liRet);

                strmOut.Flush();

                return new JDiffResult
                {
                    ExitCode = liRet,
                    FilesAreDifferent = liRet == JDefs.EXI_DIF,
                    EqualBytes = lpOut.GzOutBytEql,
                    DataBytes = lpOut.GzOutBytDta,
                    ControlBytes = lpOut.GzOutBytCtl + lpOut.GzOutBytEsc,
                };
            }
            finally
            {
                if (ownsOrg) strmOrg?.Dispose();
                if (ownsNew) strmNew?.Dispose();
                if (ownsOut) strmOut?.Dispose();
            }
        }

        private static void ThrowIfError(int liRet)
        {
            switch (liRet)
            {
                case JDefs.EXI_OK:
                case JDefs.EXI_EQL:
                case JDefs.EXI_DIF:
                    return;
                case JDefs.EXI_SEK: throw new JDiffException(liRet, "Seek error.");
                case JDefs.EXI_LRG: throw new JDiffException(liRet, "64-bit offsets not supported.");
                case JDefs.EXI_RED: throw new JDiffException(liRet, "Error reading file.");
                case JDefs.EXI_WRI: throw new JDiffException(liRet, "Error writing file.");
                case JDefs.EXI_MEM: throw new JDiffException(liRet, "Error allocating memory.");
                case JDefs.EXI_ARG: throw new JDiffException(liRet, "Error in arguments.");
                case JDefs.EXI_ERR: throw new JDiffException(liRet, "An error occurred during diff.");
                default: throw new JDiffException(liRet, $"Unknown jdiff exit code {liRet}.");
            }
        }

        private static (Stream stream, bool owns) OpenRead(JDiffSource src)
        {
            if (!src.IsPath) return (src.Stream, false);
            var fs = new FileStream(src.Path, FileMode.Open, FileAccess.Read, FileShare.Read);
            return (fs, true);
        }

        /// <summary>
        /// If <paramref name="stream"/> is (or wraps) an array-backed <see cref="MemoryStream"/>,
        /// return a <see cref="JFileDirect"/> that indexes the array directly, bypassing the
        /// ring-buffer machinery.  Returns <see langword="null"/> for all other stream types.
        /// </summary>
        private static JFile TryCreateDirect(Stream stream, string label)
        {
            if (stream is MemoryStream ms && ms.TryGetBuffer(out ArraySegment<byte> buf))
                return new JFileDirect(buf.Array, buf.Offset, (int)ms.Length, label);
            return null;
        }

        private static (Stream stream, bool owns) OpenWrite(JDiffSource src)
        {
            if (!src.IsPath) return (src.Stream, false);
            var fs = new FileStream(src.Path, FileMode.Create, FileAccess.Write, FileShare.None);
            // JOutBin writes a byte at a time; buffer to avoid a syscall per byte.
            return (new BufferedStream(fs, 64 * 1024), true);
        }
    }
}
