using LegendaryExplorerCore.Helpers;
using System.Diagnostics;

namespace MilanShaderHost.Test
{
    [TestClass]
    public sealed class MilanShaderHostTests
    {
        [TestMethod]
        public void TestReserialization()
        {
            var inputDir = @"..\..\..\TestData\JobDir\";
            var inputFile = @"WorkerInputOnly.in";
            ShaderCompilerJobList scjl = new ShaderCompilerJobList();
            var sci = new ShaderCompilerJobList();
            sci.WorkingDirectory = inputDir;
            sci.InputFilename = inputFile;
            sci.ReadInput();

            var ms = new MemoryStream();
            sci.Serialize(ms);
            ms.WriteToFile(@"S:\Milan\UDK\MilanShaderComp\Reserialized.in");
            ms.Position = 0;
            var originalData = File.ReadAllBytes(Path.Combine(inputDir, inputFile));
            var newData = ms.ToArray();
            var dataIsSame = originalData.SequenceEqual(newData);
            if (!dataIsSame)
            {
                // Not the same.
                LegendaryExplorerCore.DebugTools.DebugUtilities.CompareByteArrays(originalData, newData);
            }
            Assert.IsTrue(dataIsSame, "Reserialization of ShaderCompilerJobList produced a different end result than the input.");
        }

        /// <summary>
        /// Tests the encryption cipher
        /// </summary>
        [TestMethod]
        public void TestCipher()
        {
            Random rand = new Random();

            // Generate a random input
            byte[] original = new byte[500];
            byte[] ciphered = new byte[500];
            for (int i = 0; i < original.Length; i++)
            {
                original[i] = ciphered[i] = (byte) rand.Next();
            }

            // XOR one of them
            ShaderEncryption.ApplyXorCipher(ciphered);
            Assert.IsFalse(original.SequenceEqual(ciphered), "Cipher did not apply!");

            // And XOR it back
            ShaderEncryption.ApplyXorCipher(ciphered);
            Assert.IsTrue(original.SequenceEqual(ciphered), "Cipher did not translate back and forth the same!");
        

            // Todo: Ensure we can decrypt something that was encrypted by UDK at shipping time.
        }
    }
}
