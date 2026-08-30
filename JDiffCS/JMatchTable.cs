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

namespace JDiffCS
{
    // ============================================================
    // JMatchTable - the matching table logic
    // ============================================================
    internal sealed class JMatchTable
    {
        private const int EQLSZE = 8;
        private const int EQLMIN = 4;
        private const int EQLMAX = 256;

        private const int MAXDST = 2 * 1024 * 1024;
        private const int MINDST = 1024;

        private const int FZY = 0;

        private const int CMPINV = -1;
        private const int CMPSKP = -2;
        private const int CMPEOB = -3;

        private static int Min(int a, int b) => a < b ? a : b;
        private static long Min(long a, long b) => a < b ? a : b;
        private static long Abs(long a) => a < 0 ? -a : a;

        private sealed class RMch
        {
            public RMch ipNxt;
            public RMch ipCol;
            public RMch ipGld;

            public int iiCnt;
            public int iiGld;
            public long izBeg;
            public long izNew;
            public long izOrg;
            public long izDlt;
            public long izTst;
            public int iiCmp;
        }

        public enum EMatchReturn { Error, Full, Enlarged, Invalid, Good, Best, Valid }

        private readonly JHashPos mpHsh;
        private readonly int miMchSze;
        private int miMchFre;

        private readonly int miMchPme;
        private readonly RMch[] msMch;
        private readonly RMch[] mpCol;
        private readonly RMch[] mpGld;
        private RMch mpOld;
        private RMch mpNew;
        private RMch mpLst;
        private RMch mpBst;
        private long mzBstOrg;
        private long mzBstNew;
        private int miBstCmp;
        private long mzOld;

        private readonly JFile mpFilOrg;
        private readonly JFile mpFilNew;
        private readonly bool mbCmpAll;
        private readonly int miAhdMax;
        private int miRlb;

        private int miHshRpr;

        public JMatchTable(JHashPos apHsh, JFile apFilOrg, JFile apFilNew,
                           int aiMchSze, bool abCmpAll, int aiAhdMax)
        {
            mpHsh = apHsh;
            miMchSze = aiMchSze < 13 ? 13 : aiMchSze;
            miMchFre = miMchSze;
            mpFilOrg = apFilOrg;
            mpFilNew = apFilNew;
            mbCmpAll = abCmpAll;
            miAhdMax = aiAhdMax;

            msMch = new RMch[miMchSze];
            for (int i = 0; i < miMchSze; i++) msMch[i] = new RMch();

            miMchPme = JDefs.GetLowerPrime(aiMchSze * 2);
            mpCol = new RMch[miMchPme];
            mpGld = new RMch[miMchPme];
        }

        public bool GetBest(long azRedOrg, long azRedNew, out long azBstOrg, out long azBstNew)
        {
            azBstOrg = 0;
            azBstNew = 0;

            if (!mbCmpAll)
            {
                if (mpNew != null)
                {
                    mpLst.ipNxt = mpOld;
                    mpOld = mpNew;
                    mpNew = null;
                    mpLst = null;
                }

                bool lbBstEob = false;
                for (RMch lpCur = mpOld; lpCur != null; lpCur = lpCur.ipNxt)
                {
                    if (lpCur != mpBst
                        && lpCur.iiCmp <= CMPEOB
                        && lpCur.izNew > lpCur.izTst
                        && IsBest(lpCur, azRedNew, 0, lpCur.izTst, lpCur.iiCmp))
                        lbBstEob = true;
                }

                if (lbBstEob && mzBstOrg == 0)
                    CalcPosOrg(mpBst, ref mzBstOrg, ref mzBstNew);
            }

            if (mpBst != null)
            {
                azBstOrg = mzBstOrg;
                azBstNew = mzBstNew;
            }

            return mpBst != null;
        }

        public EMatchReturn Add(long azFndOrgAdd, long azFndNewAdd, long azRedNew)
        {
            RMch lpCur;

            long lzDlt = azFndOrgAdd - azFndNewAdd;
            int liIdxDlt = (int)(Abs(lzDlt) % miMchPme);
            for (lpCur = mpCol[liIdxDlt]; lpCur != null; lpCur = lpCur.ipCol)
            {
                if (lpCur.izDlt == lzDlt)
                {
                    if (lpCur.iiCnt == 1) DelGld(lpCur);
                    lpCur.iiCnt++;
                    lpCur.izNew = azFndNewAdd;
                    break;
                }
            }

            int liIdxGld = 0;
            if (lpCur == null)
            {
                liIdxGld = (int)(azFndOrgAdd % miMchPme);
                for (lpCur = mpGld[liIdxGld]; lpCur != null; lpCur = lpCur.ipGld)
                {
                    if (lpCur.izOrg == azFndOrgAdd)
                    {
                        if (lpCur.iiCnt == 1) DelCol(lpCur);
                        lpCur.iiCnt++;
                        lpCur.izNew = azFndNewAdd;
                        if (lpCur.iiGld == 0)
                        {
                            if (azFndNewAdd <= lpCur.izBeg + JDefs.SMPSZE)
                                lpCur.iiGld = (int)(azFndNewAdd - lpCur.izBeg);
                            else
                                lpCur.iiGld = JDefs.SMPSZE;
                        }
                        break;
                    }
                }
            }

            if (lpCur != null && mpOld == lpCur)
            {
                mpOld = mpOld.ipNxt;
                NextOld(azRedNew);
                AddNew(lpCur);
            }

            if (lpCur == null)
            {
                if (miMchFre > 0)
                {
                    miMchFre--;
                    lpCur = msMch[miMchFre];
                }
                else if (mpOld != null)
                {
                    lpCur = mpOld;
                    mpOld = mpOld.ipNxt;
                    NextOld(azRedNew);

                    if (lpCur.iiCnt == 1 || lpCur.iiGld == 0) DelCol(lpCur);
                    if (lpCur.iiCnt == 1 || lpCur.iiGld != 0) DelGld(lpCur);
                }
                else
                {
                    return EMatchReturn.Error;
                }

                lpCur.izOrg = azFndOrgAdd;
                lpCur.izNew = azFndNewAdd;
                lpCur.izBeg = azFndNewAdd;
                lpCur.izDlt = lzDlt;
                lpCur.iiCnt = 1;
                lpCur.iiGld = 0;
                lpCur.iiCmp = 0;
                lpCur.izTst = -1;

                lpCur.ipCol = mpCol[liIdxDlt];
                mpCol[liIdxDlt] = lpCur;

                lpCur.ipGld = mpGld[liIdxGld];
                mpGld[liIdxGld] = lpCur;
            }

            EMatchReturn liRet = EMatchReturn.Enlarged;
            if (lpCur.iiCnt == 1 || lpCur.iiCmp == CMPSKP)
            {
                if (lpCur.iiCmp == CMPSKP) lpCur.iiCmp = 0;

                liRet = IsGoodOrBest(azRedNew, lpCur);
                switch (liRet)
                {
                    case EMatchReturn.Invalid:
                        if (lpCur.izTst >= lpCur.izNew)
                        {
                            miHshRpr++;
                            lpCur.iiCmp = CMPINV;
                            if (lpCur.iiCnt == 1)
                            {
                                if (mpNew == null) mpLst = lpCur;
                                lpCur.ipNxt = mpNew;
                                mpNew = lpCur;
                            }
                            break;
                        }
                        goto case EMatchReturn.Valid;
                    case EMatchReturn.Valid:
                    case EMatchReturn.Good:
                    case EMatchReturn.Best:
                        if (lpCur.iiCnt == 1) AddNew(lpCur);
                        break;
                    case EMatchReturn.Enlarged:
                    case EMatchReturn.Error:
                    case EMatchReturn.Full:
                        break;
                }
            }

            if (miMchFre == 0 && mpOld == null)
                return EMatchReturn.Full;
            return liRet;
        }

        public EMatchReturn Cleanup(long azBseOrg, long azRedNew)
        {
            RMch lpCur;

            miRlb = mpHsh.GetReliability();

            if (mpNew != null)
            {
                mpLst.ipNxt = mpOld;
                mpOld = mpNew;
                mpNew = null;
                mpLst = null;
            }

            mpBst = null;
            mzOld = azRedNew;

            for (lpCur = mpOld; lpCur != null; lpCur = lpCur.ipNxt)
            {
                if (IsOld2Skip(lpCur, azRedNew))
                    lpCur.iiCmp = CMPSKP;
                else
                    IsGoodOrBest(azRedNew, lpCur);
            }

            NextOld(azRedNew);

            if (mpOld == null && miMchFre == 0)
                return EMatchReturn.Full;
            else if (mpBst == null)
                return EMatchReturn.Invalid;
            else if (mzBstNew != azRedNew)
                return EMatchReturn.Valid;
            else if (miBstCmp >= EQLMAX)
                return EMatchReturn.Best;
            else if (miBstCmp >= EQLSZE)
                return EMatchReturn.Good;
            else
                return EMatchReturn.Valid;
        }

        private EMatchReturn IsGoodOrBest(long azRedNew, RMch lpCur)
        {
            int liCurCmp = 0;
            bool lbGld;

            long lzTstNew = azRedNew;
            long lzTstOrg = 0;

            lbGld = CalcPosOrg(lpCur, ref lzTstOrg, ref lzTstNew);

            long lzDst = -1;
            if (lzTstNew <= lpCur.izTst)
            {
                liCurCmp = lpCur.iiCmp;
                if (liCurCmp == CMPSKP || liCurCmp == CMPINV) liCurCmp = 0;
                if (lbGld)
                {
                    lzTstNew = lpCur.izTst;
                    lzTstOrg = lpCur.izOrg;
                }
                else
                {
                    lzTstOrg = lzTstOrg + (lpCur.izTst - lzTstNew);
                    lzTstNew = lpCur.izTst;
                }
            }
            else if (!lbGld && lpCur.iiCmp > 0 && (lpCur.izTst - lzTstNew + lpCur.iiCmp > EQLMIN))
            {
                liCurCmp = (int)(lpCur.izTst - lzTstNew + lpCur.iiCmp);
            }
            else
            {
                lzDst = lpCur.izBeg - lzTstNew;
                if (lzDst < MINDST) lzDst = MINDST;
                else if (lzDst > MAXDST) lzDst = MAXDST;

                liCurCmp = Check(ref lzTstOrg, ref lzTstNew, (int)lzDst,
                                 lbGld ? lpCur.iiGld : 0,
                                 mbCmpAll ? JFile.EAhead.HardAhead : JFile.EAhead.SoftAhead);

                lpCur.izTst = lzTstNew;
                if (lpCur.iiCmp == CMPINV && liCurCmp <= 0)
                {
                    // don't erase an invalid marker
                }
                else
                {
                    lpCur.iiCmp = liCurCmp;
                }
            }

            if (lpCur.iiCmp >= EQLMAX && lpCur.izNew > lzTstNew + liCurCmp)
            {
                liCurCmp += (int)(lpCur.izNew - lzTstNew);
            }

            IsBest(lpCur, azRedNew, lzTstOrg, lzTstNew, liCurCmp);

            if (liCurCmp == 0) return EMatchReturn.Invalid;
            else if (lzTstNew != azRedNew) return EMatchReturn.Valid;
            else if (liCurCmp >= EQLMAX) return EMatchReturn.Best;
            else if (liCurCmp >= EQLSZE) return EMatchReturn.Good;
            else return EMatchReturn.Valid;
        }

        private bool IsBest(RMch lpCur, long azRedNew, long lzTstOrg, long lzTstNew, int liCurCmp)
        {
            int liCurCnt = -1;

            if (liCurCmp <= CMPEOB)
            {
                if (liCurCnt < 0)
                    liCurCnt = (lpCur.iiGld > 0) ? 1 + lpCur.iiCnt / 2 : lpCur.iiCnt;

                if (lzTstNew <= lpCur.izBeg)
                {
                    liCurCmp = liCurCnt;
                    lzTstNew = lpCur.izBeg;
                    lzTstOrg = lpCur.izOrg;
                }
                else if (lzTstNew <= lpCur.izNew + miRlb)
                {
                    liCurCmp = liCurCnt;
                    long lzDst = 1 + miRlb - Min(miRlb, lpCur.iiCnt);
                    lzTstNew += lzDst;
                    lzTstOrg += lzDst;
                }
                else
                {
                    liCurCmp = liCurCnt - 1 - (int)((lzTstNew - lpCur.izNew) / (miRlb / 8 == 0 ? 1 : miRlb / 8));
                    long lzDst = liCurCnt - liCurCmp;
                    lzTstNew += lzDst;
                    lzTstOrg += lzDst;
                }
                if (liCurCmp < 1)
                    liCurCmp = 1;
                else
                    liCurCmp = 1 + Min(EQLMAX, liCurCmp) / 2;

                if (liCurCmp > 3)
                    lpCur.iiCmp = -liCurCmp;
            }

            if (liCurCmp > 0)
            {
                if (mpBst == null)
                    mpBst = lpCur;
                else if (liCurCmp < 2 && miBstCmp > 4)
                { /* do nothing */ }
                else if (miBstCmp < 2 && liCurCmp > 4)
                    mpBst = lpCur;
                else if (lzTstNew + FZY < mzBstNew)
                    mpBst = lpCur;
                else if (lzTstNew <= mzBstNew + FZY)
                {
                    if (lzTstNew - liCurCmp < mzBstNew - miBstCmp)
                    {
                        mpBst = lpCur;
                    }
                    else if (lzTstNew - liCurCmp == mzBstNew - miBstCmp)
                    {
                        if (liCurCnt < 0)
                            liCurCnt = (lpCur.iiGld > 0) ? lpCur.iiCnt / 2 : lpCur.iiCnt;
                        int liBstCnt = (mpBst.iiGld > 0) ? mpBst.iiCnt / 2 : mpBst.iiCnt;
                        if (liCurCnt > liBstCnt)
                            mpBst = lpCur;
                    }
                }

                if (mpBst == lpCur)
                {
                    mzBstNew = lzTstNew;
                    mzBstOrg = lzTstOrg;
                    miBstCmp = liCurCmp;

                    mzOld = mpBst.izTst + Min(0, mpBst.iiCmp) - miRlb;
                    if (mzOld < azRedNew) mzOld = azRedNew;
                }
            }

            return mpBst == lpCur;
        }

        private bool NextOld(long azRedNew)
        {
            RMch lpCur;

            while (mpOld != null)
            {
                if (IsOld2Reuse(mpOld, azRedNew))
                    break;
                else
                {
                    lpCur = mpOld;
                    mpOld = mpOld.ipNxt;
                    AddNew(lpCur);
                }
            }

            if (mpOld == null && mpNew != null)
            {
                mpLst.ipNxt = null;
                for (lpCur = mpNew; lpCur != null && lpCur.iiCmp == CMPINV; lpCur = lpCur.ipNxt)
                {
                    mpNew = lpCur.ipNxt;

                    if (lpCur.iiCnt > 1 && lpCur.izNew > lpCur.izTst)
                    {
                        lpCur.iiCmp = 0;
                        AddNew(lpCur);
                    }
                    else
                    {
                        lpCur.ipNxt = mpOld;
                        mpOld = lpCur;
                        break;
                    }
                }
            }

            return mpOld != null;
        }

        private bool IsOld2Skip(RMch lpCur, long azRedNew)
        {
            switch (lpCur.iiCmp)
            {
                case CMPSKP: return true;
                case CMPINV:
                case 0:
                    return lpCur.izNew + MAXDST <= azRedNew;
                case CMPEOB:
                default:
                    return (lpCur.izNew + MAXDST <= azRedNew) && (lpCur.izTst + Abs(lpCur.iiCmp) < azRedNew);
            }
        }

        private bool IsOld2Reuse(RMch lpCur, long azRedNew)
        {
            switch (lpCur.iiCmp)
            {
                case CMPSKP: return true;
                case CMPINV: return true;
                case CMPEOB:
                    return (lpCur != mpBst) && (lpCur.izNew < mzOld);
                case 0:
                    return (lpCur.izNew < lpCur.izTst) || (lpCur.izNew < mzOld);
                default:
                    return (lpCur != mpBst) && (lpCur.izNew < mzOld)
                        && (lpCur.izTst + Abs(lpCur.iiCmp) < mzOld);
            }
        }

        private bool CalcPosOrg(RMch lpCur, ref long azTstOrg, ref long azTstNew)
        {
            if (lpCur.iiGld > 0 && azTstNew >= lpCur.izBeg)
            {
                azTstOrg = lpCur.izOrg;
                return true;
            }
            else
            {
                if (azTstNew + lpCur.izDlt >= 0)
                {
                    azTstOrg = azTstNew + lpCur.izDlt;
                }
                else
                {
                    azTstNew = -lpCur.izDlt;
                    azTstOrg = 0;
                }
                return false;
            }
        }

        private int Check(ref long azPosOrg, ref long azPosNew, int aiLen, int aiGld, JFile.EAhead aiSft)
        {
            int lcOrg = 0;
            int lcNew = 0;
            int liEql = 0;

            for (; liEql < EQLMAX; aiLen--)
            {
                if ((lcOrg = mpFilOrg.Get(azPosOrg, aiSft)) < 0) break;
                else if ((lcNew = mpFilNew.Get(azPosNew, aiSft)) < 0) break;
                else if (lcOrg == lcNew)
                {
                    azPosOrg++;
                    azPosNew++;
                    liEql++;

                    // Bulk-extend the equal run with a vectorized span compare.
                    // We already matched one byte; count the common prefix of the
                    // contiguous buffered regions that follow in one shot. This is
                    // the innermost loop of the algorithm, so accelerating long
                    // equal runs matters most. Results are identical to byte-wise.
                    ReadOnlySpan<byte> spOrg = mpFilOrg.GetSpan(azPosOrg, out _, aiSft);
                    if (!spOrg.IsEmpty)
                    {
                        ReadOnlySpan<byte> spNew = mpFilNew.GetSpan(azPosNew, out _, aiSft);
                        if (!spNew.IsEmpty)
                        {
                            int cap = EQLMAX - liEql;
                            if (spOrg.Length < cap) cap = spOrg.Length;
                            if (spNew.Length < cap) cap = spNew.Length;
                            if (cap > 0)
                            {
                                int run = spOrg.Slice(0, cap).CommonPrefixLength(spNew.Slice(0, cap));
                                if (run > 0)
                                {
                                    azPosOrg += run;
                                    azPosNew += run;
                                    liEql += run;
                                    aiLen -= run; // these count against the loop budget too
                                }
                            }
                        }
                    }
                }
                else if (liEql >= EQLSZE) break;
                else if (aiLen <= 0) break;
                else
                {
                    azPosNew++;
                    if (aiGld != 0) azPosOrg -= liEql;
                    else azPosOrg++;
                    liEql = 0;
                }
            }

            if (liEql > EQLMIN)
            {
                azPosOrg -= liEql;
                azPosNew -= liEql;
                return liEql;
            }
            else if (lcOrg == JDefs.EOB || lcNew == JDefs.EOB)
            {
                return CMPEOB;
            }
            else
            {
                return 0;
            }
        }

        private void AddNew(RMch lpCur)
        {
            if (mpNew == null) mpNew = lpCur;
            else mpLst.ipNxt = lpCur;
            mpLst = lpCur;
        }

        private void DelGld(RMch apGld)
        {
            int liIdx = (int)(apGld.izOrg % miMchPme);
            RMch lpGld = mpGld[liIdx];
            if (lpGld == apGld)
                mpGld[liIdx] = apGld.ipGld;
            else
                while (lpGld != null)
                {
                    if (lpGld.ipGld == apGld)
                    {
                        lpGld.ipGld = apGld.ipGld;
                        break;
                    }
                    lpGld = lpGld.ipGld;
                }
        }

        private void DelCol(RMch apCol)
        {
            int liIdx = (int)(Abs(apCol.izDlt) % miMchPme);
            RMch lpCol = mpCol[liIdx];
            if (lpCol == apCol)
                mpCol[liIdx] = apCol.ipCol;
            else
                while (lpCol != null)
                {
                    if (lpCol.ipCol == apCol)
                    {
                        lpCol.ipCol = apCol.ipCol;
                        break;
                    }
                    lpCol = lpCol.ipCol;
                }
        }

        public int GetHshRpr() => miHshRpr;
    }
}
