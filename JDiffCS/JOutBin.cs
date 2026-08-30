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
    // JOutBin - binary patch output (default)
    // ============================================================
    internal sealed class JOutBin : JOut
    {
        private const int MINEQL = 2;

        private readonly Stream mpFilOut;
        private int miOprCur;
        private long mzEqlCnt;
        private readonly int[] miEqlBuf = new int[MINEQL];
        private bool mbOutEsc;

        public JOutBin(Stream apFilOut)
        {
            mpFilOut = apFilOut;
            miOprCur = JDefs.MOD;
            mzEqlCnt = 0;
            mbOutEsc = false;
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        private void PutByteRaw(int b) => mpFilOut.WriteByte((byte)b);

        private void UfPutLen(long azLen)
        {
            if (azLen <= 252)
            {
                PutByteRaw((int)(azLen - 1));
                GzOutBytCtl += 1;
            }
            else if (azLen <= 508)
            {
                PutByteRaw(252);
                PutByteRaw((int)(azLen - 253));
                GzOutBytCtl += 2;
            }
            else if (azLen <= 0xffff)
            {
                PutByteRaw(253);
                PutByteRaw((int)(azLen >> 8));
                PutByteRaw((int)(azLen & 0xff));
                GzOutBytCtl += 3;
            }
            else if (azLen <= 0xffffffffL)
            {
                PutByteRaw(254);
                PutByteRaw((int)(azLen >> 24));
                PutByteRaw((int)((azLen >> 16) & 0xff));
                PutByteRaw((int)((azLen >> 8) & 0xff));
                PutByteRaw((int)(azLen & 0xff));
                GzOutBytCtl += 5;
            }
            else
            {
                PutByteRaw(255);
                PutByteRaw((int)(azLen >> 56));
                PutByteRaw((int)((azLen >> 48) & 0xff));
                PutByteRaw((int)((azLen >> 40) & 0xff));
                PutByteRaw((int)((azLen >> 32) & 0xff));
                PutByteRaw((int)((azLen >> 24) & 0xff));
                PutByteRaw((int)((azLen >> 16) & 0xff));
                PutByteRaw((int)((azLen >> 8) & 0xff));
                PutByteRaw((int)(azLen & 0xff));
                GzOutBytCtl += 9;
            }
        }

        private void UfPutOpr(int aiOpr)
        {
            if (mbOutEsc)
            {
                PutByteRaw(JDefs.ESC);
                PutByteRaw(JDefs.ESC);
                mbOutEsc = false;
                GzOutBytEsc++;
                GzOutBytDta++;
            }

            if (aiOpr != JDefs.ESC)
            {
                if (aiOpr != JDefs.MOD || miOprCur == JDefs.INS)
                {
                    PutByteRaw(JDefs.ESC);
                    PutByteRaw(aiOpr);
                    GzOutBytCtl += 2;
                }
            }
            miOprCur = aiOpr;
        }

        private void UfPutByt(int aiByt)
        {
            if (mbOutEsc)
            {
                mbOutEsc = false;
                if (aiByt >= JDefs.BKT && aiByt <= JDefs.ESC)
                {
                    PutByteRaw(JDefs.ESC);
                    GzOutBytEsc++;
                }
                PutByteRaw(JDefs.ESC);
                GzOutBytDta++;
            }
            if (aiByt == JDefs.ESC)
            {
                mbOutEsc = true;
            }
            else
            {
                PutByteRaw(aiByt);
                GzOutBytDta++;
            }
        }

        public override bool Put(int aiOpr, long azLen, int aiOrg, int aiNew,
                                 long azPosOrg, long azPosNew)
        {
            if (aiOpr != JDefs.EQL && mzEqlCnt > 0)
            {
                if (mzEqlCnt > MINEQL || (miOprCur != JDefs.MOD && aiOpr != JDefs.MOD))
                {
                    UfPutOpr(JDefs.EQL);
                    UfPutLen(mzEqlCnt);
                    GzOutBytEql += mzEqlCnt;
                }
                else
                {
                    if (miOprCur != JDefs.MOD) UfPutOpr(JDefs.MOD);
                    for (int i = 0; i < mzEqlCnt; i++) UfPutByt(miEqlBuf[i]);
                }
                mzEqlCnt = 0;
            }

            switch (aiOpr)
            {
                case JDefs.ESC:
                    UfPutOpr(JDefs.ESC);
                    break;
                case JDefs.MOD:
                case JDefs.INS:
                    if (miOprCur != aiOpr) UfPutOpr(aiOpr);
                    UfPutByt(aiNew);
                    break;
                case JDefs.DEL:
                    UfPutOpr(JDefs.DEL);
                    UfPutLen(azLen);
                    GzOutBytDel += azLen;
                    break;
                case JDefs.BKT:
                    UfPutOpr(JDefs.BKT);
                    UfPutLen(azLen);
                    GzOutBytBkt += azLen;
                    break;
                case JDefs.EQL:
                    if (mzEqlCnt < MINEQL)
                    {
                        miEqlBuf[mzEqlCnt++] = aiOrg;
                        return mzEqlCnt >= MINEQL;
                    }
                    else
                    {
                        mzEqlCnt += azLen;
                        return true;
                    }
            }
            return false;
        }
    }
}
