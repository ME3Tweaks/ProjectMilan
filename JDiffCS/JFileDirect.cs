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
    // JFileDirect - JFile backed directly by a byte[].
    //
    // No ring buffer, no block reads, no seeks.  Get() and GetSpan()
    // are O(1) index operations into the caller-owned array.
    // Used automatically by JDiffLib when an input is (or wraps) an
    // in-memory byte array (e.g. MemoryStream created from ReadAllBytes).
    // ============================================================
    internal sealed class JFileDirect : JFile
    {
        private readonly byte[] _data;
        private readonly int _dataOffset;
        private readonly int _length;

        /// <param name="data">Backing array.  Ownership is not transferred; the
        /// caller must keep it alive for the lifetime of this object.</param>
        /// <param name="dataOffset">Index of the first byte within <paramref name="data"/>.</param>
        /// <param name="length">Number of bytes available from <paramref name="dataOffset"/>.</param>
        /// <param name="label">Diagnostic label (passed to <see cref="JFile"/>).</param>
        public JFileDirect(byte[] data, int dataOffset, int length, string label)
            : base(label, abSeq: false)
        {
            _data = data ?? throw new ArgumentNullException(nameof(data));
            _dataOffset = dataOffset;
            _length = length;
            // The entire file is available immediately; set EOF so the base-class
            // fast-path check (azPos >= mzPosEof) works correctly.
            mzPosEof = length;
        }

        // SetLookaheadBase controls SoftAhead windowing in JFileAhead.
        // JFileDirect has no I/O cost so the hint is irrelevant.
        public override void SetLookaheadBase(long azBse) { }

        // JFileAhead uses GetBufPos/GetBufSze for lookahead-window decisions.
        // For an in-memory file everything is buffered from position 0.
        public override long GetBufPos() => 0;
        public override long GetBufSze() => _length;

        protected override long JEofPos() => _length;

        /// <summary>
        /// Return the byte at <paramref name="azPos"/> and prime the sequential
        /// fast-path state for the run of bytes that follows it.
        /// </summary>
        protected override int GetFromBuffer(long azPos, EAhead aiSft)
        {
            if (azPos < 0 || azPos >= _length)
            {
                mzPosRed = -1;
                mpRedBuf = null;
                mpRedOff = 0;
                miRedSze = 0;
                return JDefs.EOF;
            }

            int absOff = _dataOffset + (int)azPos;
            long remaining = _length - (int)azPos;

            // Prime for the next sequential position so subsequent Get(azPos+1),
            // Get(azPos+2) ... all take the inline fast path in JFile.Get().
            mzPosRed = azPos + 1;
            mpRedBuf = _data;
            mpRedOff = absOff + 1;
            miRedSze = remaining - 1;

            return _data[absOff];
        }

        /// <summary>
        /// Return a span of every byte from <paramref name="azPos"/> to end-of-file.
        /// The span is valid for the lifetime of this object.
        /// </summary>
        public override ReadOnlySpan<byte> GetSpan(long azPos, out long azLen, EAhead aiSft = EAhead.Read)
        {
            if (azPos < 0 || azPos >= _length)
            {
                azLen = JDefs.EOF;
                return ReadOnlySpan<byte>.Empty;
            }

            int absOff = _dataOffset + (int)azPos;
            int len = _length - (int)azPos;
            azLen = len;
            return new ReadOnlySpan<byte>(_data, absOff, len);
        }

        /// <inheritdoc/>
        public override void PrimeReadAt(long azPos)
        {
            if (azPos < 0 || azPos >= _length)
            {
                mzPosRed = -1;
                mpRedBuf = null;
                mpRedOff = 0;
                miRedSze = 0;
                return;
            }

            int absOff = _dataOffset + (int)azPos;
            mzPosRed = azPos;
            mpRedBuf = _data;
            mpRedOff = absOff;
            miRedSze = _length - (int)azPos;
        }
    }
}
