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
    // JFileAhead - buffered JFile with the specialized ahead logic
    // ============================================================
    public abstract class JFileAhead : JFile
    {
        private enum EBufOpr { Append, Reset, Scrollback }

        // eBufDne is encoded as return codes; use named constants.
        private const int Added = 0;
        private const int EndOfFile = JDefs.EOF;   // -1
        private const int EndOfBuffer = JDefs.EOB; // -2
        private const int SeekErr = JDefs.EXI_SEK; // -6
        private const int ReadErr = JDefs.EXI_RED; // -8

        private readonly long mlBufSze;
        private int miBlkSze;

        private long miBufUsd;
        private readonly byte[] mpBuf;
        private readonly int mpMax;   // == mlBufSze (index one-past-end)
        private int mpInp;            // current input offset in mpBuf
        private long mzPosBse;

        protected JFileAhead(string asJid, long alBufSze = 256 * 1024,
                             int aiBlkSze = 8192, bool abSeq = false)
            : base(asJid, abSeq)
        {
            mlBufSze = alBufSze == 0 ? 1024 : alBufSze;
            miBlkSze = aiBlkSze;

            if (miBlkSze == 0)
            {
                Console.Error.WriteLine("Warning: Block size cannot be zero: set to 1.");
                miBlkSze = 1;
            }
            if (mlBufSze % miBlkSze != 0)
            {
                mlBufSze -= mlBufSze % miBlkSze;
                Console.Error.WriteLine($"Warning: Buffer size misaligned with block size: set to {mlBufSze}.");
            }
            if (mlBufSze == 0)
            {
                mlBufSze = miBlkSze;
                Console.Error.WriteLine($"Warning: Buffer size cannot be zero: set to {mlBufSze}.");
            }

            mpBuf = new byte[mlBufSze];
            mpMax = (int)mlBufSze;
            mpInp = 0;

            mpRedBuf = mpBuf;
            mpRedOff = mpInp;

            miBufUsd = 0;
            mzPosInp = 0;
            mzPosEof = JDefs.MAX_OFF_T;
            mzPosRed = 0;
            mzPosBse = 0;
            miRedSze = 0;
        }

        public override long GetBufPos() => mzPosInp - miBufUsd;
        public override long GetBufSze() => mlBufSze;
        public override long SeekCount() => mlFabSek;
        public override void SetLookaheadBase(long azBse) => mzPosBse = azBse;

        protected override int GetFromBuffer(long azPos, EAhead aiSft)
        {
            ReadOnlySpan<byte> span = GetSpanInternal(azPos, out long lzLen, out int loOff, aiSft);
            if (span.IsEmpty)
            {
                mzPosRed = -1;
                mpRedBuf = null;
                mpRedOff = 0;
                miRedSze = 0;
                return (int)lzLen; // EOF, EOB or error code
            }

            // prepare next reading position (do not advance the returned byte)
            mzPosRed = azPos + 1;
            miRedSze = lzLen - 1;
            int nextOff = loOff + 1;
            if (nextOff == mpMax) nextOff = 0;
            mpRedBuf = mpBuf;
            mpRedOff = nextOff;

            return mpBuf[loOff];
        }

        public override ReadOnlySpan<byte> GetSpan(long azPos, out long azLen, EAhead aiSft = EAhead.Read)
            => GetSpanInternal(azPos, out azLen, out _, aiSft);

        /// <inheritdoc/>
        public override void PrimeReadAt(long azPos)
        {
            ReadOnlySpan<byte> span = GetSpanInternal(azPos, out long lzLen, out int loOff, EAhead.Read);
            if (span.IsEmpty)
            {
                mzPosRed = -1;
                mpRedBuf = null;
                mpRedOff = 0;
                miRedSze = 0;
            }
            else
            {
                mzPosRed = azPos;
                mpRedBuf = mpBuf;
                mpRedOff = loOff;
                miRedSze = lzLen;
            }
        }

        private ReadOnlySpan<byte> GetSpanInternal(long azPos, out long azLen, out int aoOff, EAhead aiSft)
        {
            aoOff = 0;

            if (azPos >= mzPosEof)
            {
                azLen = JDefs.EOF;
                return ReadOnlySpan<byte>.Empty;
            }
            else if (azPos < mzPosInp && azPos >= mzPosInp - miBufUsd)
            {
                // already in buffer
            }
            else
            {
                switch (GetFromFile(azPos, aiSft))
                {
                    case EndOfBuffer: azLen = JDefs.EOB; return ReadOnlySpan<byte>.Empty;
                    case EndOfFile: azLen = JDefs.EOF; return ReadOnlySpan<byte>.Empty;
                    case SeekErr: azLen = JDefs.EXI_SEK; return ReadOnlySpan<byte>.Empty;
                    case ReadErr: azLen = JDefs.EXI_RED; return ReadOnlySpan<byte>.Empty;
                    case Added: break;
                }
            }

            // Calculate position of azPos within the ring buffer
            long len = mzPosInp - azPos;
            int off;
            if (len <= mpInp) // mpInp - mpBuf, since mpBuf base index == 0
            {
                off = (int)(mpInp - len);
            }
            else
            {
                off = (int)(mpInp + mlBufSze - len);
                len = mpMax - off;
            }

            azLen = len;
            aoOff = off;
            return new ReadOnlySpan<byte>(mpBuf, off, (int)len);
        }

        private int GetFromFile(long azPos, EAhead aiSft)
        {
            EBufOpr liSek;

            if (azPos < mzPosInp - miBufUsd)
            {
                if (aiSft == EAhead.SoftAhead)
                    return EndOfBuffer;
                else if (mbSeq)
                {
                    if (aiSft == EAhead.HardAhead) return EndOfBuffer;
                    else return SeekErr;
                }
                else if (azPos + mlBufSze - miBlkSze > mzPosInp - miBufUsd)
                    liSek = EBufOpr.Scrollback;
                else
                    liSek = EBufOpr.Reset;
            }
            else if (azPos >= mzPosInp + mlBufSze)
            {
                if (aiSft == EAhead.SoftAhead) return EndOfBuffer;
                else liSek = EBufOpr.Reset;
            }
            else
            {
                if (aiSft == EAhead.SoftAhead && azPos > mzPosBse + mlBufSze - miBlkSze)
                    return EndOfBuffer;
                else
                    liSek = EBufOpr.Append;
            }

            int liDne;
            switch (liSek)
            {
                case EBufOpr.Reset:
                    if (!mbSeq)
                        mzPosInp = (azPos / miBlkSze) * miBlkSze;
                    else
                        mzPosInp = ((azPos - mlBufSze + miBlkSze) / miBlkSze) * miBlkSze;

                    mpInp = 0;
                    mzPosBse = mzPosInp;
                    miBufUsd = 0;

                    if (JSeek(mzPosInp) != JDefs.EXI_OK) return SeekErr;
                    mlFabSek++;

                    liDne = ReadBlocks(ref mpInp, ref mzPosInp, azPos);
                    if (liDne == JDefs.EOF) return EndOfFile;
                    break;

                case EBufOpr.Append:
                    liDne = ReadBlocks(ref mpInp, ref mzPosInp, azPos);
                    if (liDne == JDefs.EOF) return EndOfFile;
                    break;

                case EBufOpr.Scrollback:
                    {
                        long lzPos = (azPos / miBlkSze) * miBlkSze;
                        long lzLen = mzPosInp - lzPos;
                        int lpInp = (int)(mpInp - lzLen);
                        if (lzLen > mpInp) lpInp += (int)mlBufSze;

                        if (lzLen > mlBufSze)
                        {
                            lzLen = lzLen - mlBufSze;
                            miBufUsd = miBufUsd - lzLen;
                            mzPosInp = lzPos + mlBufSze;
                            if (lzLen > mpInp) lpInp += (int)mlBufSze;
                            mpInp = lpInp;
                        }

                        if (JSeek(lzPos) != JDefs.EXI_OK) return SeekErr;
                        mlFabSek++;

                        long tmpInpPos = lzPos;
                        liDne = ReadBlocks(ref lpInp, ref tmpInpPos, mzPosInp - miBufUsd - 1);
                        if (liDne == JDefs.EOF)
                        {
                            mpInp = lpInp;
                            mzPosInp = lzPos;
                            miBufUsd = liDne;
                            return ReadErr;
                        }

                        if (JSeek(mzPosInp) != JDefs.EXI_OK) return SeekErr;
                        mlFabSek++;
                    }
                    break;
            }

            return Added;
        }

        private int ReadBlocks(ref int apInp, ref long azInp, long azEnd)
        {
            int liTdo;
            int liDne = 0;

            while (azInp <= azEnd)
            {
                liTdo = miBlkSze;
                if (apInp == mpMax) apInp = 0;
                else if (mpMax - apInp < liTdo) liTdo = mpMax - apInp;

                liDne = JRead(mpBuf, apInp, liTdo);

                apInp += liDne;
                azInp += liDne;
                miBufUsd += liDne;

                if (liDne < liTdo)
                {
                    mzPosEof = azInp;
                    if (miBufUsd > mlBufSze) miBufUsd = mlBufSze;
                    if (azEnd >= mzPosEof) return JDefs.EOF;
                    else return liDne;
                }
            }

            if (miBufUsd > mlBufSze) miBufUsd = mlBufSze;
            return liDne;
        }

        protected abstract int JSeek(long azPos);
        protected abstract override long JEofPos();
        protected abstract int JRead(byte[] buffer, int offset, int count);
    }
}
