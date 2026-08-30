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
    // JFile - abstract input file with absolute addressing
    // ============================================================
    public abstract class JFile
    {
        public enum EAhead { Read, HardAhead, SoftAhead }

        protected readonly string msJid;
        protected bool mbSeq;
        protected long miRedSze;   // remaining bytes in the current fast-read run
        protected long mzPosInp;
        protected long mzPosRed;
        protected long mzPosEof;
        protected long mlFabSek;

        // Fast-path buffer references (for the inlined Get()). In the C++ code
        // these are raw pointers; here we use a byte[] plus an integer offset.
        protected byte[] mpRedBuf;
        protected int mpRedOff;

        protected JFile(string asJid, bool abSeq = false)
        {
            msJid = asJid;
            mbSeq = abSeq;
            mzPosEof = JDefs.MAX_OFF_T;
            miRedSze = 0;
            mpRedBuf = null;
            mpRedOff = 0;
        }

        /// <summary>Get one byte at specified address and increment the address.</summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public int Get(long azPos, EAhead aiSft = EAhead.Read)
        {
            if (azPos == mzPosRed && miRedSze > 0)
            {
                mzPosRed++;
                miRedSze--;
                return mpRedBuf[mpRedOff++];
            }
            return GetFromBuffer(azPos, aiSft);
        }

        /// <summary>Get next byte at the current read position.</summary>
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public int Get(EAhead aiSft = EAhead.Read) => Get(mzPosRed, aiSft);

        public abstract void SetLookaheadBase(long azBse);

        /// <summary>
        /// Prime the sequential fast-path state so the next <see cref="Get(long, EAhead)"/>
        /// call at <paramref name="azPos"/> takes the inline fast path instead of falling
        /// through to the slower buffer-lookup path. Called by <c>BulkEqual</c> after a
        /// bulk skip so the immediately following single-byte <c>Get</c> is not a cold miss.
        /// </summary>
        public virtual void PrimeReadAt(long azPos) { }

        public bool IsSequential() => mbSeq;

        public virtual long SeekCount() => mlFabSek;

        public virtual long GetBufPos() => -1;

        public virtual long GetBufSze() => -1;

        /// <summary>
        /// Total length of the file in bytes, or <see cref="JDefs.MAX_OFF_T"/> if unknown
        /// (e.g. a non-seekable/sequential source). Known as soon as the file is seekable,
        /// since <see cref="ChkSeq"/> resolves it eagerly at construction time.
        /// </summary>
        public long GetTotalLength() => mzPosEof;

        /// <summary>
        /// Get a read-only span of the contiguous buffered bytes starting at azPos.
        /// Returns an empty span (with azLen holding the EOF/EOB/error code) when
        /// data is not available. The span is only valid until the next call that
        /// mutates the buffer.
        /// </summary>
        public virtual ReadOnlySpan<byte> GetSpan(long azPos, out long azLen, EAhead aiSft = EAhead.Read)
        {
            azLen = 0;
            return ReadOnlySpan<byte>.Empty;
        }

        protected void ChkSeq()
        {
            if (!mbSeq)
            {
                mzPosEof = JEofPos();
                if (mzPosEof < 0)
                {
                    mbSeq = true;
                    mzPosEof = JDefs.MAX_OFF_T;
                }
            }
        }

        protected abstract long JEofPos();

        protected abstract int GetFromBuffer(long azPos, EAhead aiSft);
    }

}
