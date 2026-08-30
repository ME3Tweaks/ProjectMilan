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
    // JOutRgn - grouped human readable output (-r)
    // ============================================================
    internal sealed class JOutRgn : JOut
    {
        private readonly TextWriter mpFilOut;
        private int siOprCur = JDefs.ESC;
        private long szOprCnt;
        private const int MINEQL = 2;

        public JOutRgn(TextWriter apFilOut) { mpFilOut = apFilOut; }

        private static int UfPutLen(long azLen)
        {
            if (azLen <= 252) return 1;
            if (azLen <= 508) return 2;
            if (azLen <= 0xffff) return 3;
            if (azLen <= 0xffffffffL) return 4;
            return 8;
        }

        public override bool Put(int aiOpr, long azLen, int aiOrg, int aiNew,
                                 long azPosOrg, long azPosNew)
        {
            if (aiOpr != siOprCur)
            {
                switch (siOprCur)
                {
                    case JDefs.MOD:
                        if (siOprCur == JDefs.INS) GzOutBytCtl += 2;
                        GzOutBytDta += szOprCnt;
                        mpFilOut.WriteLine($"{azPosOrg - szOprCnt,10} {azPosNew - szOprCnt,10} MOD {szOprCnt}");
                        break;
                    case JDefs.INS:
                        GzOutBytCtl += 2;
                        GzOutBytDta += szOprCnt;
                        mpFilOut.WriteLine($"{azPosOrg,10} {azPosNew - szOprCnt,10} INS {szOprCnt}");
                        break;
                    case JDefs.DEL:
                        GzOutBytCtl += 2 + UfPutLen(szOprCnt);
                        GzOutBytDel += szOprCnt;
                        mpFilOut.WriteLine($"{azPosOrg - szOprCnt,10} {azPosNew,10} DEL {szOprCnt}");
                        break;
                    case JDefs.BKT:
                        GzOutBytCtl += 2 + UfPutLen(szOprCnt);
                        GzOutBytBkt += szOprCnt;
                        mpFilOut.WriteLine($"{azPosOrg + szOprCnt,10} {azPosNew,10} BKT {szOprCnt}");
                        break;
                    case JDefs.EQL:
                        if (szOprCnt <= MINEQL)
                            GzOutBytDta += szOprCnt;
                        else
                        {
                            GzOutBytCtl += 2 + UfPutLen(szOprCnt);
                            GzOutBytEql += szOprCnt;
                        }
                        mpFilOut.WriteLine($"{azPosOrg - szOprCnt,10} {azPosNew - szOprCnt,10} EQL {szOprCnt}");
                        break;
                }
                siOprCur = aiOpr;
                szOprCnt = 0;
            }

            switch (aiOpr)
            {
                case JDefs.INS:
                case JDefs.MOD:
                    if (aiNew == JDefs.ESC) GzOutBytEsc++;
                    szOprCnt += azLen;
                    break;
                case JDefs.DEL:
                case JDefs.BKT:
                case JDefs.EQL:
                    szOprCnt += azLen;
                    break;
            }
            return true;
        }
    }
}
