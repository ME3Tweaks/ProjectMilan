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
    // JOut - abstract output
    // ============================================================
    public abstract class JOut
    {
        public long GzOutBytDta;
        public long GzOutBytCtl;
        public long GzOutBytDel;
        public long GzOutBytBkt;
        public long GzOutBytEsc;
        public long GzOutBytEql;

        protected JOut() { }

        /// <summary>
        /// Output one operation. Returns true when the caller may switch to
        /// batched EQL length output (faster path).
        /// </summary>
        public abstract bool Put(int aiOpr, long azLen, int aiOrg, int aiNew,
                                 long azPosOrg, long azPosNew);
    }
}
