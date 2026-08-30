/*
 * JojoDiff - C# port (diff only)
 *
 * Original C++ code Copyright (C) 2002-2020 Joris Heirbaut
 * C# port maintains the original algorithm and structure. The patch (jpatch)
 * side has been removed; this produces diff/patch files only.
 *
 * This file is part of JojoDiff (ported).
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

using System.Runtime.CompilerServices;

namespace JDiffCS
{
    // ============================================================
    // JDiff - main diffing class
    // ============================================================
    internal sealed class JDiff
    {
        private const int PGSMRK = 0x100000;
        private const long PGSMSK = 0x1ffffff;

        private readonly JFile mpFilOrg;
        private readonly JFile mpFilNew;
        private readonly JOut mpOut;
        private readonly JHashPos gpHsh;
        private readonly JMatchTable gpMch;

        private readonly int miVerbse;
        private readonly bool mbSrcBkt;
        private readonly int miMchMax;
        private readonly int miMchMin;
        private readonly int miAhdMax;
        private readonly bool mbCmpAll;
        private int miSrcScn;

        private long mzAhdOrg;
        private long mzAhdNew;
        private uint mlHshOrg;
        private uint mlHshNew;
        private int miPrvOrg;
        private int miValNew;
        private int miPrvNew;
        private int miEqlOrg;
        private int miEqlNew;
        private int miRlb;

        private int miHshErr;

        private readonly Action<double> mfnProgress;
        private readonly bool mbWeighIndex;
        private readonly long mzOrgLen;
        private readonly long mzTotalWeight;
        private readonly long mzPrgStep;
        private long mzOrgIndexed;
        private long mzLastNewPos;
        private long mzNextPrgAt;

        public JDiff(JFile apFilOrg, JFile apFilNew, JOut apOut,
                     int aiHshSze = 8, int aiVerbse = 0, bool abSrcBkt = true,
                     int aiSrcScn = 1, int aiMchMax = 1024, int aiMchMin = 2,
                     int aiAhdMax = 256 * 1024, bool abCmpAll = true,
                     Action<double> afnProgress = null)
        {
            mpFilOrg = apFilOrg;
            mpFilNew = apFilNew;
            mpOut = apOut;
            miVerbse = aiVerbse;
            mbSrcBkt = abSrcBkt;
            miMchMax = aiMchMax;
            miMchMin = aiMchMin > aiMchMax ? aiMchMax - 1 : aiMchMin;
            miAhdMax = aiAhdMax < 1024 ? 1024 : aiAhdMax;
            mbCmpAll = abCmpAll;
            miSrcScn = aiSrcScn;

            gpHsh = new JHashPos(aiHshSze);
            gpMch = new JMatchTable(gpHsh, mpFilOrg, mpFilNew, aiMchMax, abCmpAll, miAhdMax);

            // Progress is reported as a fraction of (origin bytes indexed + new bytes
            // compared) over (origin length + new length) -- but the origin length only
            // enters the denominator when a one-time full-file index is actually going to
            // run (aiSrcScn == 1); with lazy/incremental indexing (aiSrcScn == 0) origin
            // hashing is interleaved into the main loop already, so new-file position alone
            // is a fair proxy. Disabled entirely if the new file's length can't be known
            // up front (e.g. a non-seekable stream), since no percentage can be computed.
            long lzNewLen = mpFilNew.GetTotalLength();
            mzOrgLen = mpFilOrg.GetTotalLength();
            mbWeighIndex = aiSrcScn == 1 && mzOrgLen != JDefs.MAX_OFF_T && mzOrgLen > 0;

            if (afnProgress != null && lzNewLen != JDefs.MAX_OFF_T && lzNewLen > 0)
            {
                mfnProgress = afnProgress;
                mzTotalWeight = (mbWeighIndex ? mzOrgLen : 0) + lzNewLen;
                mzPrgStep = mzTotalWeight / 200;
                if (mzPrgStep < 64 * 1024) mzPrgStep = 64 * 1024;
            }
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private void ReportProgress(long azOrgIndexed, long azNewPos)
        {
            if (mfnProgress == null) return;

            long lzDone = (mbWeighIndex ? azOrgIndexed : 0) + azNewPos;
            if (lzDone < mzNextPrgAt) return;

            mzNextPrgAt = lzDone + mzPrgStep;
            double ldFrac = (double)lzDone / mzTotalWeight;
            mfnProgress(ldFrac < 0.0 ? 0.0 : (ldFrac > 1.0 ? 1.0 : ldFrac));
        }

        public JHashPos GetHsh() => gpHsh;
        public JMatchTable GetMch() => gpMch;
        public int GetHshErr() => miHshErr;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private uint Hash(uint akCurHsh, ref int acOld, int acNew, ref int aiEql)
        {
            if (acOld == acNew)
            {
                if (aiEql < JDefs.SMPSZE) aiEql++;
            }
            else
            {
                acOld = acNew;
                if (aiEql != 0) aiEql = 0;
            }
            return (akCurHsh * 2) + (uint)acNew + (uint)aiEql;
        }

        /// <summary>
        /// Count equal bytes on both files starting just after (posOrg, posNew),
        /// stopping before newLimit on the new file. Vectorized span compare over
        /// contiguous buffered regions; returns 0 at buffer boundaries so the
        /// caller advances one byte and retries. Positions are NOT modified.
        /// </summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private long BulkEqual(long posOrg, long posNew, long newLimit)
        {
            ReadOnlySpan<byte> spOrg = mpFilOrg.GetSpan(posOrg + 1, out _, JFile.EAhead.Read);
            if (spOrg.IsEmpty) return 0;
            ReadOnlySpan<byte> spNew = mpFilNew.GetSpan(posNew + 1, out _, JFile.EAhead.Read);
            if (spNew.IsEmpty) return 0;

            int cap = spOrg.Length;
            if (spNew.Length < cap) cap = spNew.Length;

            long room = newLimit - (posNew + 1);
            if (room <= 0) return 0;
            if (room < cap) cap = (int)room;
            if (cap <= 0) return 0;

            long adv = spOrg.Slice(0, cap).CommonPrefixLength(spNew.Slice(0, cap));

            // Prime the sequential fast-path state for both files at the position
            // the caller will read next.  Without this, the Get() call that immediately
            // follows a bulk skip always misses the inline fast path and falls through
            // to the slower ring-buffer lookup, even though the data is already loaded.
            mpFilOrg.PrimeReadAt(posOrg + adv + 1);
            mpFilNew.PrimeReadAt(posNew + adv + 1);

            return adv;
        }

        private void FlushEql(long lzPosOrg, long lzPosNew, ref long lzEql, ref bool lbEql)
        {
            if (lzEql > 0)
            {
                mpOut.Put(JDefs.EQL, lzEql, 0, 0, lzPosOrg - lzEql, lzPosNew - lzEql);
                lzEql = 0;
            }
            lbEql = false;
        }

        public int Jdiff()
        {
            int lcOrg;
            int lcNew;
            long lzPosOrg = 0;
            long lzPosNew = 0;

            bool lbEql = false;
            long lzEql = 0;
            long lzCnt;

            int liFnd = 0;
            long lzAhd = 0;
            long lzSkpOrg = 0;
            long lzSkpNew = 0;
            long lzLapSml = JDefs.MAX_OFF_T;

            var stddbg = JDebug.StdDbg;

            if (miVerbse > 0)
            {
                stddbg.Write("Comparing : ...           ");
                if (miVerbse > 1) lzLapSml = PGSMRK;
            }

            lcOrg = mpFilOrg.Get(lzPosOrg, JFile.EAhead.Read);
            lcNew = mpFilNew.Get(lzPosNew, JFile.EAhead.Read);

            while (lcNew >= 0)
            {
                if (miSrcScn == 0 && lzPosOrg == mzAhdOrg)
                {
                    mlHshOrg = Hash(mlHshOrg, ref miPrvOrg, lcOrg, ref miEqlOrg);
                    gpHsh.Add(mlHshOrg, mzAhdOrg, miEqlOrg);
                    mzAhdOrg++;
                }

                if (lcOrg == lcNew)
                {
                    if (!lbEql)
                    {
                        lbEql = mpOut.Put(JDefs.EQL, 1, lcOrg, lcNew, lzPosOrg, lzPosNew);
                        lzAhd--;
                        lcOrg = mpFilOrg.Get(++lzPosOrg, JFile.EAhead.Read);
                        lcNew = mpFilNew.Get(++lzPosNew, JFile.EAhead.Read);
                    }
                    else if (miSrcScn == 0)
                    {
                        // Incremental indexing interleaves a hash update per byte,
                        // so this branch stays strictly byte-by-byte.
                        lzCnt = 0;
                        while (lcOrg == lcNew && lcNew >= 0 && lzPosNew < lzLapSml)
                        {
                            lzCnt++;
                            if (lzPosOrg == mzAhdOrg)
                            {
                                mlHshOrg = Hash(mlHshOrg, ref miPrvOrg, lcOrg, ref miEqlOrg);
                                gpHsh.Add(mlHshOrg, mzAhdOrg, miEqlOrg);
                                mzAhdOrg++;
                            }
                            lcOrg = mpFilOrg.Get(++lzPosOrg, JFile.EAhead.Read);
                            lcNew = mpFilNew.Get(++lzPosNew, JFile.EAhead.Read);
                        }
                        lzEql += lzCnt;
                        lzAhd -= lzCnt;
                    }
                    else
                    {
                        lzCnt = 0;
                        while (lcOrg == lcNew && lcNew >= 0 && lzPosNew < lzLapSml)
                        {
                            lzCnt++;
                            // Bulk-advance across the aligned equal region.
                            long adv = BulkEqual(lzPosOrg, lzPosNew, lzLapSml);
                            if (adv > 0)
                            {
                                lzCnt += adv;
                                lzPosOrg += adv;
                                lzPosNew += adv;
                            }
                            lcOrg = mpFilOrg.Get(++lzPosOrg, JFile.EAhead.Read);
                            lcNew = mpFilNew.Get(++lzPosNew, JFile.EAhead.Read);
                        }
                        lzEql += lzCnt;
                        lzAhd -= lzCnt;
                    }
                }
                else if (lzAhd > 0)
                {
                    FlushEql(lzPosOrg, lzPosNew, ref lzEql, ref lbEql);

                    if (lcOrg < 0)
                    {
                        mpOut.Put(JDefs.INS, 1, lcOrg, lcNew, lzPosOrg, lzPosNew);
                        lzAhd--;
                        lcNew = mpFilNew.Get(++lzPosNew, JFile.EAhead.Read);
                    }
                    else
                    {
                        while (lcOrg != lcNew && lcOrg >= 0 && lcNew >= 0 && lzAhd > 0)
                        {
                            mpOut.Put(JDefs.MOD, 1, lcOrg, lcNew, lzPosOrg, lzPosNew);
                            lzAhd--;
                            lcOrg = mpFilOrg.Get(++lzPosOrg, JFile.EAhead.Read);
                            lcNew = mpFilNew.Get(++lzPosNew, JFile.EAhead.Read);
                        }
                    }
                }
                else if (liFnd == 1 && lzAhd == 0)
                {
                    liFnd = 0;
                    miHshErr++;
                    if (miVerbse > 2 && mbCmpAll)
                    {
                        stddbg.WriteLine();
                        stddbg.WriteLine($"Inaccurate solution at positions {lzPosOrg}/{lzPosNew}!");
                        stddbg.Write("Comparing : ...           ");
                    }
                    lzAhd = gpHsh.GetReliability() / 2;
                }
                else
                {
                    FlushEql(lzPosOrg, lzPosNew, ref lzEql, ref lbEql);

                    liFnd = Search(lzPosOrg, lzPosNew, ref lzSkpOrg, ref lzSkpNew, ref lzAhd);
                    if (liFnd < 0) return liFnd;

                    if (lzSkpOrg > 0)
                    {
                        mpOut.Put(JDefs.DEL, lzSkpOrg, 0, 0, lzPosOrg, lzPosNew);
                        lzPosOrg += lzSkpOrg;
                        lcOrg = mpFilOrg.Get(lzPosOrg, JFile.EAhead.Read);
                    }
                    else if (lzSkpOrg < 0)
                    {
                        mpOut.Put(JDefs.BKT, -lzSkpOrg, 0, 0, lzPosOrg, lzPosNew);
                        lzPosOrg += lzSkpOrg;
                        lcOrg = mpFilOrg.Get(lzPosOrg, JFile.EAhead.Read);
                    }
                    if (lzSkpNew > 0)
                    {
                        while (lzSkpNew > 0 && lcNew > JDefs.EOF)
                        {
                            mpOut.Put(JDefs.INS, 1, 0, lcNew, lzPosOrg, lzPosNew);
                            lzSkpNew--;
                            lcNew = mpFilNew.Get(++lzPosNew, JFile.EAhead.Read);
                        }
                    }
                }

                if (miVerbse > 1 && lzLapSml <= lzPosNew)
                {
                    stddbg.Write($"\rComparing : {lzPosNew / PGSMRK,12}Mb");
                    lzLapSml = lzPosNew + PGSMRK;
                }

                mzLastNewPos = lzPosNew;
                ReportProgress(mzOrgIndexed, lzPosNew);
            }

            FlushEql(lzPosOrg, lzPosNew, ref lzEql, ref lbEql);
            mpOut.Put(JDefs.ESC, 0, 0, 0, lzPosOrg, lzPosNew);

            if (mfnProgress != null) mfnProgress(1.0);

            if (miVerbse > 0)
                stddbg.Write($"\rComparing : {(lzPosNew + PGSMRK / 2) / PGSMRK,12}Mb");

            if (miVerbse > 2 && miSrcScn == 0)
                gpHsh.Dist(lzPosOrg, 10);

            if (lcNew < JDefs.EOB || lcOrg < JDefs.EOB)
                return (lcNew < lcOrg) ? lcNew : lcOrg;

            return JDefs.EXI_OK;
        }

        private int Search(long azRedOrg, long azRedNew,
                           ref long azSkpOrg, ref long azSkpNew, ref long azAhd)
        {
            long lzFndOrg = 0;
            long lzFndNew = 0;
            long lzBseOrg;
            long lzLap = 0;

            int liMax;
            int liBck;

            if (miVerbse > 1) lzLap = azRedNew + PGSMRK;

            switch (miSrcScn)
            {
                case 1:
                    {
                        int liRet = BuildFullIndex();
                        if (liRet < 0) return liRet;
                        miSrcScn = 2;
                        miRlb = gpHsh.GetReliability();
                    }
                    break;

                case 0:
                    {
                        mpFilOrg.SetLookaheadBase(azRedOrg);
                        if (mbSrcBkt)
                        {
                            liMax = miAhdMax;
                        }
                        else
                        {
                            if (mzAhdOrg < (miAhdMax / 2))
                                liMax = (int)(miAhdMax - mzAhdOrg);
                            else
                                liMax = (int)(miAhdMax / 2 - (mzAhdOrg - azRedOrg));
                        }

                        int lcOrgScan;
                        for (; liMax > 0; liMax--)
                        {
                            lcOrgScan = mpFilOrg.Get(mzAhdOrg, JFile.EAhead.SoftAhead);
                            if (lcOrgScan <= JDefs.EOF) break;
                            mlHshOrg = Hash(mlHshOrg, ref miPrvOrg, lcOrgScan, ref miEqlOrg);
                            gpHsh.Add(mlHshOrg, mzAhdOrg, miEqlOrg);
                            mzAhdOrg++;
                        }
                        miRlb = gpHsh.GetReliability();
                    }
                    break;
            }

            if (mzAhdNew > azRedNew)
                liMax = (int)(miAhdMax - (mzAhdNew - azRedNew));
            else
                liMax = miAhdMax;

            if (liMax < miRlb) liMax = miRlb;

            liBck = (int)(azRedNew - mzAhdNew);
            if (liBck < 0)
                liBck = 0;
            else if (liBck > miRlb + 2 * JDefs.SMPSZE - 1)
                liBck = miRlb + 2 * JDefs.SMPSZE - 1;

            lzBseOrg = mbSrcBkt ? 0 : mpFilOrg.GetBufPos();

            int liFnd = 0;
            switch (gpMch.Cleanup(lzBseOrg, azRedNew))
            {
                case JMatchTable.EMatchReturn.Error:
                case JMatchTable.EMatchReturn.Full:
                    liFnd = miMchMax;
                    break;
                case JMatchTable.EMatchReturn.Best:
                case JMatchTable.EMatchReturn.Good:
                    if (liMax > miRlb * 2) liMax = miRlb * 2;
                    break;
                default:
                    break;
            }

            if (liFnd < miMchMax)
            {
                mpFilNew.SetLookaheadBase(azRedNew);

                JFile.EAhead liSftNew = (liFnd >= miMchMin) ? JFile.EAhead.SoftAhead : JFile.EAhead.HardAhead;

                if (mzAhdNew == 0 || mzAhdNew + liBck < azRedNew)
                {
                    mzAhdNew = mpFilNew.GetBufPos();

                    if (azRedNew > mzAhdNew + liBck)
                    {
                        mzAhdNew = azRedNew - liBck;
                        if (mzAhdNew < 0) mzAhdNew = 0;
                    }

                    if (mzAhdNew == 0)
                        liBck = JDefs.SMPSZE - 1;
                    else
                        liBck = JDefs.SMPSZE * 2 - 1;

                    mzAhdNew--;
                    mlHshNew = 0;
                    miEqlNew = 0;
                    miPrvNew = JDefs.EOF;
                    for (int liIdx = 0; liIdx < liBck; liIdx++)
                    {
                        miValNew = mpFilNew.Get(++mzAhdNew, liSftNew);
                        if (miValNew <= JDefs.EOF)
                        {
                            mzAhdNew--;
                            break;
                        }
                        mlHshNew = Hash(mlHshNew, ref miPrvNew, miValNew, ref miEqlNew);

                        if (liIdx != miEqlNew && liBck > liIdx + (JDefs.SMPSZE - 1))
                            liBck = liIdx + (JDefs.SMPSZE - 1);
                    }
                }

                if (mzAhdNew < azRedNew)
                    liMax += (int)(azRedNew - mzAhdNew);

                while (liMax > 0)
                {
                    miValNew = mpFilNew.Get(++mzAhdNew, liSftNew);
                    if (miValNew <= JDefs.EOF)
                    {
                        mzAhdNew--;
                        break;
                    }
                    mlHshNew = Hash(mlHshNew, ref miPrvNew, miValNew, ref miEqlNew);
                    liMax--;

                    if (gpHsh.Get(mlHshNew, out lzFndOrg))
                    {
                        if (lzFndOrg > lzBseOrg)
                        {
                            switch (gpMch.Add(lzFndOrg, mzAhdNew, azRedNew))
                            {
                                case JMatchTable.EMatchReturn.Error:
                                    goto case JMatchTable.EMatchReturn.Full;
                                case JMatchTable.EMatchReturn.Full:
                                    liMax = 0;
                                    continue;
                                case JMatchTable.EMatchReturn.Enlarged:
                                case JMatchTable.EMatchReturn.Invalid:
                                    break;
                                case JMatchTable.EMatchReturn.Best:
                                case JMatchTable.EMatchReturn.Good:
                                    if (liMax > miRlb) liMax = miRlb;
                                    goto case JMatchTable.EMatchReturn.Valid;
                                case JMatchTable.EMatchReturn.Valid:
                                    liFnd++;
                                    if (mzAhdNew > azRedNew)
                                    {
                                        if (liFnd >= miMchMin)
                                            liSftNew = JFile.EAhead.SoftAhead;
                                        if (liFnd >= miMchMax)
                                        {
                                            liMax = 0;
                                            continue;
                                        }
                                    }
                                    break;
                            }
                        }
                    }

                    if (miVerbse > 1 && lzLap <= mzAhdNew)
                    {
                        JDebug.StdDbg.Write($"+{(mzAhdNew - azRedNew) / PGSMRK,-12}");
                        lzLap = lzLap + PGSMRK;
                    }
                }
            }

            if (miValNew < JDefs.EOB)
                return miValNew;

            bool lbFnd = gpMch.GetBest(azRedOrg, azRedNew, out lzFndOrg, out lzFndNew);

            if (!lbFnd)
            {
                azSkpOrg = 0;
                azSkpNew = 0;
                azAhd = (mzAhdNew - azRedNew);
                if (azAhd < JDefs.SMPSZE)
                    azAhd = JDefs.SMPSZE;
                return 0;
            }
            else
            {
                if (lzFndOrg >= azRedOrg)
                {
                    if (lzFndOrg - azRedOrg >= lzFndNew - azRedNew)
                    {
                        azSkpOrg = lzFndOrg - azRedOrg + azRedNew - lzFndNew;
                        azSkpNew = 0;
                        azAhd = lzFndNew - azRedNew;
                    }
                    else
                    {
                        azSkpOrg = 0;
                        azSkpNew = lzFndNew - azRedNew + azRedOrg - lzFndOrg;
                        azAhd = lzFndOrg - azRedOrg;
                    }
                }
                else
                {
                    azSkpOrg = azRedOrg - lzFndOrg + lzFndNew - azRedNew;
                    if (azSkpOrg <= (azRedOrg - lzBseOrg))
                    {
                        azSkpNew = 0;
                        azSkpOrg = -azSkpOrg;
                        azAhd = lzFndNew - azRedNew;
                    }
                    else
                    {
                        azSkpNew = azSkpOrg - (azRedOrg - lzBseOrg);
                        azSkpOrg = lzBseOrg - azRedOrg;
                        azAhd = (lzFndNew - azRedNew) - azSkpNew;
                    }
                }
                return 1;
            }
        }

        private int BuildFullIndex()
        {
            uint lkHshOrg = 0;
            int liEqlOrg = 0;
            int lcValOrg = 0;
            int lcValPrv = JDefs.EOF;
            long lzPosOrg = -1;

            int liIdx;
            var stddbg = JDebug.StdDbg;

            if (miVerbse > 0)
            {
                stddbg.WriteLine();
                stddbg.Write("Indexing  : ...           ");
            }

            for (liIdx = 0; liIdx < JDefs.SMPSZE - 1; liIdx++)
            {
                lcValOrg = mpFilOrg.Get(++lzPosOrg, JFile.EAhead.HardAhead);
                if (lcValOrg <= JDefs.EOF) break;
                lkHshOrg = Hash(lkHshOrg, ref lcValPrv, lcValOrg, ref liEqlOrg);
            }

            if (miVerbse > 1)
            {
                while (lcValOrg > JDefs.EOF)
                {
                    lcValOrg = mpFilOrg.Get(++lzPosOrg, JFile.EAhead.HardAhead);
                    if (lcValOrg <= JDefs.EOF) break;
                    lkHshOrg = Hash(lkHshOrg, ref lcValPrv, lcValOrg, ref liEqlOrg);
                    gpHsh.Add(lkHshOrg, lzPosOrg, liEqlOrg);

                    if ((lzPosOrg & PGSMSK) == 0)
                    {
                        stddbg.Write($"\b\b\b\b\b\b\b\b\b\b\b\b\b\b{lzPosOrg / PGSMRK,12}Mb");
                        ReportProgress(lzPosOrg, mzLastNewPos);
                    }
                }
            }
            else
            {
                while (true)
                {
                    ReadOnlySpan<byte> seg = mpFilOrg.GetSpan(lzPosOrg + 1, out long segLen, JFile.EAhead.HardAhead);
                    if (seg.IsEmpty) { lcValOrg = (int)segLen; break; }
                    foreach (byte b in seg)
                    {
                        lzPosOrg++;
                        lkHshOrg = Hash(lkHshOrg, ref lcValPrv, b, ref liEqlOrg);
                        gpHsh.Add(lkHshOrg, lzPosOrg, liEqlOrg);
                    }
                    ReportProgress(lzPosOrg, mzLastNewPos);
                }
            }

            mzOrgIndexed = lzPosOrg;

            if (miVerbse > 0)
            {
                stddbg.WriteLine($"\b\b\b\b\b\b\b\b\b\b\b\b\b\b{lzPosOrg / PGSMRK,12}Mb");
                stddbg.Write("Comparing : ...           ");
            }
            if (miVerbse > 2)
                gpHsh.Dist(lzPosOrg, 10);

            if (lcValOrg < JDefs.EOB)
                return lcValOrg;
            return 0;
        }
    }

}
