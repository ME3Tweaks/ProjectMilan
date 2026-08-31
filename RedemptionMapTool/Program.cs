using ProjectMilan.Utility;

namespace RedemptionMapTool
{
    internal class Program
    {

        static void Main(string[] args)
        {
            var libraryPath = Utilities.GetModManagerLibraryPath();
            var redemptionPath = Path.Combine(libraryPath, "ME3", "Redemption MP Map Pack");
            if (!Directory.Exists(redemptionPath))
            {
                Console.WriteLine("Redemption MP Map Pack not found in the Mod Manager library. Import the mod and run this tool again.");
                Environment.Exit(1);
            }
        


        }
    }
}
