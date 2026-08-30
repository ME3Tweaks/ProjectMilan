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
    // JHashPos - hash table of (sample-key, position)
    // ============================================================
    internal sealed class JHashPos
    {
        private const int COLLISION_THRESHOLD = 4;
        private const int COLLISION_HIGH = 4;
        private const int COLLISION_LOW = 1;

        private readonly long[] mzHshTblPos;
        private readonly uint[] mkHshTblHsh;

        private readonly int miHshPme;
        private readonly int miHshSze;

        private int miHshColMax;
        private int miHshColCnt;
        private int miHshRlb;
        private int miLodCnt;

        private int miHshHit;

        public JHashPos(int aiSze)
        {
            miHshColMax = COLLISION_THRESHOLD;
            miHshColCnt = COLLISION_THRESHOLD;
            miHshRlb = JDefs.SMPSZE + JDefs.SMPSZE / 2;
            miHshHit = 0;

            int liSzeIdx = aiSze < 1 ? 1 : aiSze;
            long elems = (long)liSzeIdx * 1024L * 1024L / (sizeof(uint) + sizeof(long));
            if (elems > int.MaxValue) elems = int.MaxValue;
            liSzeIdx = JDefs.GetLowerPrime((int)elems);

            miHshPme = liSzeIdx;
            miHshSze = miHshPme * (sizeof(long) + sizeof(uint));
            mzHshTblPos = new long[miHshPme];
            mkHshTblHsh = new uint[miHshPme];
            miLodCnt = miHshPme;
        }

        public void Add(uint akCurHsh, long azPos, int aiEqlCnt)
        {
            if (miLodCnt > 0)
            {
                miLodCnt--;
            }
            else
            {
                miLodCnt = miHshPme;
                miHshColMax += COLLISION_THRESHOLD;
                miHshRlb += 4;
            }

            if (aiEqlCnt <= JDefs.SMPSZE * 2)
                miHshColCnt -= COLLISION_HIGH;
            else
                miHshColCnt -= COLLISION_LOW;

            if (miHshColCnt <= 0)
            {
                int liIdx = (int)(akCurHsh % (uint)miHshPme);
                mkHshTblHsh[liIdx] = akCurHsh;
                mzHshTblPos[liIdx] = azPos;
                miHshColCnt = miHshColMax;
            }
        }

        public void Reset()
        {
            miLodCnt = miHshPme;
            miHshColMax = COLLISION_THRESHOLD;
            miHshColCnt = COLLISION_THRESHOLD;
            miHshRlb = JDefs.SMPSZE + JDefs.SMPSZE / 2;
        }

        public bool Get(uint akCurHsh, out long azPos)
        {
            int liIdx = (int)(akCurHsh % (uint)miHshPme);
            if (mkHshTblHsh[liIdx] == akCurHsh)
            {
                miHshHit++;
                azPos = mzHshTblPos[liIdx];
                return true;
            }
            azPos = 0;
            return false;
        }

        public int GetReliability() => miHshRlb;

        public int GetHashPrime() => miHshPme;
        public int GetHashSize() => miHshSze;
        public int GetHashColMax() => miHshColMax;
        public int GetHashHits() => miHshHit;

        public void Dist(long azMax, int aiBck)
        {
            var stddbg = JDebug.StdDbg;
            stddbg.WriteLine($"Hash Dist Overload    = {miHshColMax / COLLISION_THRESHOLD - 1}");
            stddbg.WriteLine($"Hash Dist Reliability = {miHshRlb}");

            if (aiBck <= 0) return;
            int[] bck = new int[aiBck];
            long liHshDiv = azMax / aiBck;
            if (liHshDiv <= 0) liHshDiv = 1;

            for (int i = 0; i < miHshPme; i++)
            {
                if (mzHshTblPos[i] > 0 && mzHshTblPos[i] <= azMax)
                {
                    long li = mzHshTblPos[i] / liHshDiv;
                    if (li >= aiBck) li = 0;
                    bck[li]++;
                }
            }

            int liCnt = 0, liMin = int.MaxValue, liMax = 0;
            for (int i = 0; i < aiBck; i++)
            {
                liCnt += bck[i];
                if (bck[i] < liMin) liMin = bck[i];
                if (bck[i] > liMax) liMax = bck[i];
                stddbg.WriteLine($"Hash Dist {i,8} Pos={(long)i * liHshDiv,10}:{(long)(i + 1) * liHshDiv,10} Cnt={bck[i],8} Rlb={(bck[i] == 0 ? -1 : liHshDiv / bck[i])}");
            }
            stddbg.WriteLine($"Hash Dist Avg/Min/Max/% = {liCnt / aiBck}/{liMin}/{liMax}/{(liMax > 0 ? (100 - (liMin / (liMax / 100 == 0 ? 1 : liMax / 100))) : -1)}%");
            stddbg.WriteLine($"Hash Dist Load          = {liCnt}/{miHshPme}={(miHshPme > 0 ? (liCnt / (miHshPme / 100 == 0 ? 1 : miHshPme / 100)) : -1)}%");
        }
    }
}
