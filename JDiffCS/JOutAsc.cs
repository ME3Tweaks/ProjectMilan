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
    // JOutAsc - human readable per-byte output (-l)
    // ============================================================
    internal sealed class JOutAsc : JOut
    {
        private readonly TextWriter mpFilOut;
        private int liOprCur = JDefs.ESC;

        public JOutAsc(TextWriter apFilOut) { mpFilOut = apFilOut; }

        private static char Vis(int c) => (c >= 32 && c <= 127) ? (char)c : ' ';

        private static int UfPutSze(long azLen)
        {
            if (azLen <= 252) return 1;
            if (azLen <= 508) return 2;
            if (azLen <= 0xffff) return 3;
            if (azLen <= 0xffffffffL) return 5;
            return 9;
        }

        public override bool Put(int aiOpr, long azLen, int aiOrg, int aiNew,
                                 long azPosOrg, long azPosNew)
        {
            if (aiOpr == JDefs.ESC) return false;

            mpFilOut.Write($"{azPosOrg,10} {azPosNew,10} ");

            switch (aiOpr)
            {
                case JDefs.MOD:
                    mpFilOut.WriteLine($"MOD {aiOrg:x2} {aiNew:x2} {Vis(aiOrg)}-{Vis(aiNew)}");
                    if (liOprCur != aiOpr) { liOprCur = aiOpr; GzOutBytCtl += 2; }
                    if (aiNew == JDefs.ESC) GzOutBytEsc++;
                    GzOutBytDta++;
                    break;
                case JDefs.INS:
                    mpFilOut.WriteLine($"INS     {aiNew:x2}  -{Vis(aiNew)}");
                    if (liOprCur != aiOpr) { liOprCur = aiOpr; GzOutBytCtl += 2; }
                    if (aiNew == JDefs.ESC) GzOutBytEsc++;
                    GzOutBytDta++;
                    break;
                case JDefs.DEL:
                    mpFilOut.WriteLine($"DEL {azLen}");
                    liOprCur = JDefs.DEL;
                    GzOutBytCtl += 2 + UfPutSze(azLen);
                    GzOutBytDel += azLen;
                    break;
                case JDefs.BKT:
                    mpFilOut.WriteLine($"BKT {azLen}");
                    liOprCur = JDefs.BKT;
                    GzOutBytCtl += 2 + UfPutSze(azLen);
                    GzOutBytBkt += azLen;
                    break;
                case JDefs.EQL:
                    mpFilOut.WriteLine($"EQL {aiOrg:x2} {aiNew:x2} {Vis(aiOrg)}-{Vis(aiNew)}");
                    if (liOprCur != aiOpr) { liOprCur = aiOpr; GzOutBytCtl += 2 + 4; }
                    GzOutBytEql++;
                    break;
            }
            return false;
        }
    }

}
