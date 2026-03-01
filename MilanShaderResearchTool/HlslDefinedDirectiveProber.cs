using System.IO;
using System.Text.RegularExpressions;

namespace MilanShaderResearchTool
{
    /// <summary>
    /// Probes HLSL (.usf) files for preprocessor directives that test whether a symbol is defined
    /// (#ifdef, #ifndef, defined(...)). Recursively follows #include directives.
    /// </summary>
    public partial class HlslDefinedDirectiveProber
    {
        // Matches: #ifdef SYMBOL or #ifndef SYMBOL
        [GeneratedRegex(@"^\s*#\s*ifn?def\s+(\w+)", RegexOptions.Compiled)]
        private static partial Regex IfdefRegex();

        // Matches: defined(SYMBOL) or defined ( SYMBOL ) inside #if / #elif
        [GeneratedRegex(@"defined\s*\(\s*(\w+)\s*\)", RegexOptions.Compiled)]
        private static partial Regex DefinedRegex();

        // Matches: #include "filename"
        [GeneratedRegex(@"^\s*#\s*include\s+""([^""]+)""", RegexOptions.Compiled)]
        private static partial Regex IncludeRegex();

        // Matches: #if or #elif line (not #ifdef/#ifndef which are handled separately)
        [GeneratedRegex(@"^\s*#\s*(if|elif)\b", RegexOptions.Compiled)]
        private static partial Regex IfElifRegex();

        /// <summary>
        /// The unique set of symbols tested by defined-checking preprocessor directives.
        /// </summary>
        public HashSet<string> DefinedDirectives { get; } = new();

        private readonly string _includesDirectory;
        private readonly string _materialUsfContent;
        private readonly string _vertexFactoryUsfContent;
        private readonly HashSet<string> _processedFiles = new(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Probes the given HLSL file and all of its includes for preprocessor directives that
        /// test whether a symbol is defined (#ifdef, #ifndef, defined(...)).
        /// </summary>
        /// <param name="startingFilePath">Path to the root .usf file to begin scanning.</param>
        /// <param name="includesDirectory">Directory where included .usf files are located.</param>
        /// <param name="materialUsfContent">String content for the virtual Material.usf file.</param>
        /// <param name="vertexFactoryUsfContent">String content for the virtual VertexFactory.usf file.</param>
        public HlslDefinedDirectiveProber(string startingFilePath, string includesDirectory,
            string materialUsfContent, string vertexFactoryUsfContent)
        {
            _includesDirectory = includesDirectory;
            _materialUsfContent = materialUsfContent;
            _vertexFactoryUsfContent = vertexFactoryUsfContent;

            ProcessFile(startingFilePath);
        }

        private void ProcessFile(string filePath)
        {
            var normalizedPath = Path.GetFullPath(filePath);
            if (!_processedFiles.Add(normalizedPath))
                return;

            if (!File.Exists(filePath))
                return;

            var content = File.ReadAllText(filePath);
            ProcessContent(content);
        }

        private void ProcessVirtualFile(string virtualName, string content)
        {
            if (!_processedFiles.Add(virtualName))
                return;

            ProcessContent(content);
        }

        private void ProcessContent(string content)
        {
            using var reader = new StringReader(content);
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                // Check for #include
                var includeMatch = IncludeRegex().Match(line);
                if (includeMatch.Success)
                {
                    ResolveAndProcessInclude(includeMatch.Groups[1].Value);
                    continue;
                }

                // Check for #ifdef / #ifndef
                var ifdefMatch = IfdefRegex().Match(line);
                if (ifdefMatch.Success)
                {
                    DefinedDirectives.Add(ifdefMatch.Groups[1].Value);
                    continue;
                }

                // Check for defined(...) in #if / #elif expressions
                if (IfElifRegex().IsMatch(line))
                {
                    foreach (Match m in DefinedRegex().Matches(line))
                    {
                        DefinedDirectives.Add(m.Groups[1].Value);
                    }
                }
            }
        }

        private void ResolveAndProcessInclude(string includeName)
        {
            if (string.Equals(includeName, "Material.usf", StringComparison.OrdinalIgnoreCase))
            {
                ProcessVirtualFile("Material.usf", _materialUsfContent);
                return;
            }

            if (string.Equals(includeName, "VertexFactory.usf", StringComparison.OrdinalIgnoreCase))
            {
                ProcessVirtualFile("VertexFactory.usf", _vertexFactoryUsfContent);
                return;
            }

            var fullPath = Path.Combine(_includesDirectory, includeName);
            if (File.Exists(fullPath))
            {
                ProcessFile(fullPath);
            }
        }
    }
}
