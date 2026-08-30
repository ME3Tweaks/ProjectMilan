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
    // JFileAheadStream - JFileAhead backed by a System.IO.Stream
    // ============================================================
    internal sealed class JFileAheadStream : JFileAhead
    {
        private readonly Stream mpFil;

        public JFileAheadStream(Stream apFil, string asFid,
                                long alBufSze = 256 * 1024, int aiBlkSze = 4096,
                                bool abSeq = false)
            : base(asFid, alBufSze, aiBlkSze, abSeq)
        {
            mpFil = apFil;
            ChkSeq();
        }

        protected override int JSeek(long azPos)
        {
            try
            {
                if (!mpFil.CanSeek) return JDefs.EXI_SEK;
                mpFil.Seek(azPos, SeekOrigin.Begin);
                return JDefs.EXI_OK;
            }
            catch
            {
                return JDefs.EXI_SEK;
            }
        }

        protected override long JEofPos()
        {
            try
            {
                if (!mpFil.CanSeek) return JDefs.EXI_SEK;
                long len = mpFil.Length;
                mpFil.Seek(0, SeekOrigin.Begin);
                return len;
            }
            catch
            {
                return JDefs.EXI_SEK;
            }
        }

        protected override int JRead(byte[] buffer, int offset, int count)
        {
            // ReadAtLeast fills the requested span unless EOF is hit first,
            // handling the "stream returns fewer bytes than asked" case for us.
            return mpFil.ReadAtLeast(buffer.AsSpan(offset, count), count, throwOnEndOfStream: false);
        }
    }
}
