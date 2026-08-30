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

using System;
using System.Collections.Generic;
using System.Text;

namespace JDiffCS
{
    // ============================================================
    // JDefs - global definitions
    // ============================================================
    internal static class JDefs
    {
        public const string JDIFF_VERSION = "0.8.5 (beta) 2020 (C# port)";
        public const string JDIFF_COPYRIGHT = "Copyright (C) 2002-2020 Joris Heirbaut";

        // Sample size in bytes = number of bits in a hash key.
        // Default C++ build uses 32-bit hash keys (unsigned long on Windows/LLP64),
        // giving SMPSZE = 4*8 = 32. We match that.
        public const int SMPSZE = sizeof(uint) * 8;  // 32

        public const long MAX_OFF_T = long.MaxValue;

        // Special stream return codes. EOF is -1 (as in C stdio), EOB is one less.
        public const int EOF = -1;
        public const int EOB = EOF - 1;   // -2

        // Exit codes
        public const int EXI_OK = 0;
        public const int EXI_DIF = 1;
        public const int EXI_EQL = 2;
        public const int EXI_ARG = -2;
        public const int EXI_FRT = -3;
        public const int EXI_SCD = -4;
        public const int EXI_OUT = -5;
        public const int EXI_SEK = -6;
        public const int EXI_LRG = -7;
        public const int EXI_RED = -8;
        public const int EXI_WRI = -9;
        public const int EXI_MEM = -10;
        public const int EXI_ERR = -20;

        // Output routine op-codes
        public const int ESC = 0xA7; // 167
        public const int MOD = 0xA6; // 166
        public const int INS = 0xA5; // 165
        public const int DEL = 0xA4; // 164
        public const int EQL = 0xA3; // 163
        public const int BKT = 0xA2; // 162

        /// <summary>Check if number is a prime number.</summary>
        public static bool IsPrime(int number)
        {
            if (number < 2) return false;
            if (number == 2) return true;
            if (number % 2 == 0) return false;
            for (int i = 3; number / i >= i; i += 2)
                if (number % i == 0) return false;
            return true;
        }

        /// <summary>Get highest lower prime.</summary>
        public static int GetLowerPrime(int aiNum)
        {
            switch (aiNum)
            {
                case 1024: return 1021;
                case 32 * 1024 * 1024: return 33554393;
                case 16 * 1024 * 1024: return 16777213;
                case 8 * 1024 * 1024: return 8388593;
                case 128 * 1024 * 1024: return 134217689;
                case 512 * 1024 * 1024: return 536870909;
                default:
                    for (; aiNum > 0; aiNum--)
                        if (IsPrime(aiNum)) return aiNum;
                    break;
            }
            return aiNum;
        }
    }
}
