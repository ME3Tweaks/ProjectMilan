using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace MilanShaderResearchTool;

/// <summary>
/// Preprocesses HLSL (.usf) shader files by resolving conditional compilation directives
/// (#if, #ifdef, #ifndef, #elif, #else, #endif), processing #include directives, and
/// tracking #define/#undef state. Each processed file is written to a specified output
/// directory with conditionals resolved based on the provided macro definitions.
/// </summary>
public partial class HlslPreprocessor
{
    private readonly string _includeDirectory;
    private readonly string _materialUsfContent;
    private readonly string _vertexFactoryUsfContent;
    private readonly Dictionary<string, string> _macros;
    private readonly string _outputDirectory;
    private readonly HashSet<string> _processedFiles = new(StringComparer.OrdinalIgnoreCase);
    private int _resolveDepth;

    // ── Regex patterns for preprocessor directives ──────────────────────────

    [GeneratedRegex(@"^\s*#\s*include\s+""([^""]+)""")]
    private static partial Regex IncludeDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*define\s+(\w+)(?:\s+(.*))?$")]
    private static partial Regex DefineDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*undef\s+(\w+)")]
    private static partial Regex UndefDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*if\b\s*(.+)")]
    private static partial Regex IfDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*ifdef\s+(\w+)")]
    private static partial Regex IfdefDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*ifndef\s+(\w+)")]
    private static partial Regex IfndefDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*elif\b\s*(.+)")]
    private static partial Regex ElifDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*else\b")]
    private static partial Regex ElseDirectiveRegex();

    [GeneratedRegex(@"^\s*#\s*endif\b")]
    private static partial Regex EndifDirectiveRegex();

    // ── Conditional block tracking ──────────────────────────────────────────

    private struct ConditionalState
    {
        /// <summary>Whether the enclosing scope is active.</summary>
        public bool ParentActive;

        /// <summary>Whether any branch in this if/elif/else chain has already been taken.</summary>
        public bool BranchTaken;

        /// <summary>Whether the current branch is active.</summary>
        public bool CurrentActive;

        public readonly bool IsActive => ParentActive && CurrentActive;
    }

    /// <summary>
    /// Preprocesses HLSL shader files starting from <paramref name="entryPointFile"/>,
    /// resolving conditional directives using the provided <paramref name="macros"/>,
    /// and writes the results to <paramref name="outputDirectory"/>.
    /// </summary>
    /// <param name="entryPointFile">Path to the root .usf file to begin processing.</param>
    /// <param name="includeDirectory">Directory where included .usf files are resolved from.</param>
    /// <param name="materialUsfContent">Virtual content returned when Material.usf is included.</param>
    /// <param name="vertexFactoryUsfContent">Virtual content returned when VertexFactory.usf is included.</param>
    /// <param name="macros">Initial preprocessor macro definitions (name → value).</param>
    /// <param name="outputDirectory">Directory to write preprocessed files into.</param>
    public HlslPreprocessor(
        string entryPointFile,
        string includeDirectory,
        string materialUsfContent,
        string vertexFactoryUsfContent,
        Dictionary<string, string> macros,
        string outputDirectory)
    {
        _includeDirectory = includeDirectory;
        _materialUsfContent = materialUsfContent;
        _vertexFactoryUsfContent = vertexFactoryUsfContent;
        _macros = new Dictionary<string, string>(macros);
        _outputDirectory = outputDirectory;

        Directory.CreateDirectory(outputDirectory);
        ProcessFile(entryPointFile);
    }

    // ── Conditional macro discovery ─────────────────────────────────────────

    /// <summary>
    /// Scans the full include tree starting from <paramref name="entryPointFile"/> and
    /// collects every preprocessor macro identifier referenced in conditional directives
    /// (<c>#if</c>, <c>#ifdef</c>, <c>#ifndef</c>, <c>#elif</c>).
    /// All branches and all <c>#include</c> paths are followed regardless of conditional
    /// state so that every possible macro that could influence compilation is discovered.
    /// </summary>
    /// <param name="entryPointFile">Path to the root .usf file to begin scanning.</param>
    /// <param name="entryPointMethodName">Name of the shader entry-point function.</param>
    /// <param name="includeDirectory">Directory where included .usf files are resolved from.</param>
    /// <param name="materialUsfContent">Virtual content returned when Material.usf is included.</param>
    /// <param name="vertexFactoryUsfContent">Virtual content returned when VertexFactory.usf is included.</param>
    /// <returns>A set of all macro identifiers found in conditional preprocessor directives.</returns>
    public static HashSet<string> FindConditionalMacros(
        string entryPointFileName,
        string entryPointMethodName,
        string includeDirectory,
        string materialUsfContent,
        string vertexFactoryUsfFileName)
    {
        var entryPointFile = Path.Combine(includeDirectory, $"{entryPointFileName}.usf");


        // Read the vertex factory file
        var vertexFactoryUsfContent = "";

        if (vertexFactoryUsfFileName != null)
        {
            var vertexFactoryPath = Path.Combine(includeDirectory, $"{vertexFactoryUsfFileName.Substring(1)}.usf");
            if (File.Exists(vertexFactoryPath))
            {
                vertexFactoryUsfContent = File.ReadAllText(vertexFactoryPath);
            }
        }

        var macros = new HashSet<string>(StringComparer.Ordinal);
        var definedMacros = new HashSet<string>(StringComparer.Ordinal);
        var processedFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var filesToProcess = new Queue<(string path, bool isVirtual, string? content)>();

        filesToProcess.Enqueue((entryPointFile, false, null));

        while (filesToProcess.Count > 0)
        {
            var (path, isVirtual, virtualContent) = filesToProcess.Dequeue();

            var normalizedKey = isVirtual ? path.ToLowerInvariant() : Path.GetFullPath(path);
            if (!processedFiles.Add(normalizedKey))
                continue;

            string content;
            if (isVirtual)
            {
                content = virtualContent!;
            }
            else
            {
                if (!File.Exists(path))
                    continue;
                content = File.ReadAllText(path);
            }

            ScanContentForConditionalMacros(
                content, macros, definedMacros, filesToProcess,
                includeDirectory, materialUsfContent, vertexFactoryUsfContent);
        }

        macros.ExceptWith(definedMacros);
        return macros;
    }

    private static void ScanContentForConditionalMacros(
        string content,
        HashSet<string> macros,
        HashSet<string> definedMacros,
        Queue<(string path, bool isVirtual, string? content)> filesToProcess,
        string includeDirectory,
        string materialUsfContent,
        string vertexFactoryUsfContent)
    {
        using var reader = new StringReader(content);
        string? line;
        while ((line = reader.ReadLine()) != null)
        {
            if (line.Contains("ENABLE_DISTANCE_SHADOW_FADING"))
            {
                //Debugger.Break();
            }
            var strippedLine = StripLineComment(line);
            Match match;

            // #ifdef

            match = IfdefDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                macros.Add(match.Groups[1].Value);
                continue;
            }

            // #ifndef
            match = IfndefDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                macros.Add(match.Groups[1].Value);
                continue;
            }

            // #if (checked after #ifdef/#ifndef)
            match = IfDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                CollectIdentifiersFromExpression(match.Groups[1].Value.Trim(), macros);
                continue;
            }

            // #elif
            match = ElifDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                CollectIdentifiersFromExpression(match.Groups[1].Value.Trim(), macros);
                continue;
            }

            // #define — track macros defined within the files
            match = DefineDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                definedMacros.Add(match.Groups[1].Value);
                continue;
            }

            // #include — follow all includes regardless of conditional state
            match = IncludeDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                var includeName = match.Groups[1].Value;
                if (string.Equals(includeName, "Material.usf", StringComparison.OrdinalIgnoreCase))
                    filesToProcess.Enqueue(("Material.usf", true, materialUsfContent));
                else if (string.Equals(includeName, "VertexFactory.usf", StringComparison.OrdinalIgnoreCase))
                    filesToProcess.Enqueue(("VertexFactory.usf", true, vertexFactoryUsfContent));
                else
                    filesToProcess.Enqueue((Path.Combine(includeDirectory, includeName), false, null));
            }
        }
    }

    /// <summary>
    /// Extracts all identifier names from a preprocessor conditional expression,
    /// excluding the <c>defined</c> keyword and numeric literals.
    /// </summary>
    private static void CollectIdentifiersFromExpression(string expression, HashSet<string> identifiers)
    {
        int commentIdx = expression.IndexOf("//");
        if (commentIdx >= 0)
            expression = expression[..commentIdx];

        var tokens = Tokenize(expression.Trim());
        foreach (var token in tokens)
        {
            if (token == "defined")
                continue;

            if (token.Length == 0 || (!char.IsLetter(token[0]) && token[0] != '_'))
                continue;

            identifiers.Add(token);
        }
    }

    // ── File processing ─────────────────────────────────────────────────────

    private void ProcessFile(string filePath)
    {
        var normalizedPath = Path.GetFullPath(filePath);
        if (!_processedFiles.Add(normalizedPath))
            return;

        if (!File.Exists(filePath))
            return;

        var content = File.ReadAllText(filePath);
        var fileName = Path.GetFileName(filePath);
        var output = ProcessContent(content);
        File.WriteAllText(Path.Combine(_outputDirectory, fileName), output);
    }

    private void ProcessVirtualFile(string virtualName, string content)
    {
        if (!_processedFiles.Add(virtualName.ToLowerInvariant()))
            return;

        var output = ProcessContent(content);
        File.WriteAllText(Path.Combine(_outputDirectory, virtualName), output);
    }

    private string ProcessContent(string content)
    {
        var sb = new StringBuilder();
        var condStack = new Stack<ConditionalState>();

        using var reader = new StringReader(content);
        string? line;
        while ((line = reader.ReadLine()) != null)
        {
            var strippedLine = StripLineComment(line);
            Match match;

            // ── #endif ──────────────────────────────────────────────────
            match = EndifDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                if (condStack.Count > 0)
                    condStack.Pop();
                continue;
            }

            // ── #else ───────────────────────────────────────────────────
            match = ElseDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                if (condStack.Count > 0)
                {
                    var state = condStack.Pop();
                    state.CurrentActive = state.ParentActive && !state.BranchTaken;
                    if (state.CurrentActive)
                        state.BranchTaken = true;
                    condStack.Push(state);
                }
                continue;
            }

            // ── #elif ───────────────────────────────────────────────────
            match = ElifDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                if (condStack.Count > 0)
                {
                    var state = condStack.Pop();
                    if (!state.ParentActive || state.BranchTaken)
                    {
                        state.CurrentActive = false;
                    }
                    else
                    {
                        var result = EvaluateExpression(match.Groups[1].Value.Trim());
                        state.CurrentActive = result;
                        if (result)
                            state.BranchTaken = true;
                    }
                    condStack.Push(state);
                }
                continue;
            }

            // ── #ifdef ──────────────────────────────────────────────────
            match = IfdefDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                var parentActive = condStack.Count == 0 || condStack.Peek().IsActive;
                var isDefined = parentActive && _macros.ContainsKey(match.Groups[1].Value);
                condStack.Push(new ConditionalState
                {
                    ParentActive = parentActive,
                    CurrentActive = isDefined,
                    BranchTaken = isDefined,
                });
                continue;
            }

            // ── #ifndef ─────────────────────────────────────────────────
            match = IfndefDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                var parentActive = condStack.Count == 0 || condStack.Peek().IsActive;
                var isNotDefined = parentActive && !_macros.ContainsKey(match.Groups[1].Value);
                condStack.Push(new ConditionalState
                {
                    ParentActive = parentActive,
                    CurrentActive = isNotDefined,
                    BranchTaken = isNotDefined,
                });
                continue;
            }

            // ── #if (checked after #ifdef/#ifndef so \b correctly rejects them) ─
            match = IfDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                var parentActive = condStack.Count == 0 || condStack.Peek().IsActive;
                bool result = false;
                if (parentActive)
                    result = EvaluateExpression(match.Groups[1].Value.Trim());
                condStack.Push(new ConditionalState
                {
                    ParentActive = parentActive,
                    CurrentActive = result,
                    BranchTaken = result,
                });
                continue;
            }

            // ── Non-conditional directives are only processed in active blocks ──
            bool isActive = condStack.Count == 0 || condStack.Peek().IsActive;

            // ── #define ──────────────────────────────────────────────────
            match = DefineDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                if (isActive)
                {
                    var name = match.Groups[1].Value;

                    // Detect function-like macros: name immediately followed by '('
                    int nameEnd = match.Groups[1].Index + match.Groups[1].Length;
                    bool isFunctionLike = nameEnd < strippedLine.Length && strippedLine[nameEnd] == '(';

                    if (!isFunctionLike)
                    {
                        var value = match.Groups[2].Success ? match.Groups[2].Value.Trim() : "";
                        if (string.IsNullOrEmpty(value))
                            value = "1";
                        _macros[name] = value;
                    }

                    sb.AppendLine(line);
                }
                continue;
            }

            // ── #undef ──────────────────────────────────────────────────
            match = UndefDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                if (isActive)
                {
                    _macros.Remove(match.Groups[1].Value);
                    sb.AppendLine(line);
                }
                continue;
            }

            // ── #include ────────────────────────────────────────────────
            match = IncludeDirectiveRegex().Match(strippedLine);
            if (match.Success)
            {
                if (isActive)
                {
                    ResolveAndProcessInclude(match.Groups[1].Value);
                    sb.AppendLine(line);
                }
                continue;
            }

            // ── Regular line ────────────────────────────────────────────
            if (isActive)
            {
                sb.AppendLine(line);
            }
        }

        return sb.ToString();
    }

    // ── Include resolution ──────────────────────────────────────────────────

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

        var fullPath = Path.Combine(_includeDirectory, includeName);
        if (File.Exists(fullPath))
        {
            ProcessFile(fullPath);
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private static string StripLineComment(string line)
    {
        int idx = line.IndexOf("//");
        return idx >= 0 ? line[..idx] : line;
    }

    // ── Expression evaluation ───────────────────────────────────────────────
    //
    // Recursive descent parser for C-style preprocessor expressions.
    // Precedence (low to high):
    //   ||  →  &&  →  |  →  &  →  == !=  →  > < >= <=  →  ! (unary)  →  primary
    // Primary: integer literal, identifier (macro lookup), defined(SYMBOL), ( expr )

    private bool EvaluateExpression(string expression)
    {
        int commentIdx = expression.IndexOf("//");
        if (commentIdx >= 0)
            expression = expression[..commentIdx];

        var tokens = Tokenize(expression.Trim());
        int pos = 0;
        var result = ParseLogicalOr(tokens, ref pos);
        return result != 0;
    }

    private long ParseLogicalOr(List<string> tokens, ref int pos)
    {
        var left = ParseLogicalAnd(tokens, ref pos);
        while (pos < tokens.Count && tokens[pos] == "||")
        {
            pos++;
            var right = ParseLogicalAnd(tokens, ref pos);
            left = (left != 0 || right != 0) ? 1 : 0;
        }
        return left;
    }

    private long ParseLogicalAnd(List<string> tokens, ref int pos)
    {
        var left = ParseBitwiseOr(tokens, ref pos);
        while (pos < tokens.Count && tokens[pos] == "&&")
        {
            pos++;
            var right = ParseBitwiseOr(tokens, ref pos);
            left = (left != 0 && right != 0) ? 1 : 0;
        }
        return left;
    }

    private long ParseBitwiseOr(List<string> tokens, ref int pos)
    {
        var left = ParseBitwiseAnd(tokens, ref pos);
        while (pos < tokens.Count && tokens[pos] == "|")
        {
            pos++;
            var right = ParseBitwiseAnd(tokens, ref pos);
            left |= right;
        }
        return left;
    }

    private long ParseBitwiseAnd(List<string> tokens, ref int pos)
    {
        var left = ParseEquality(tokens, ref pos);
        while (pos < tokens.Count && tokens[pos] == "&")
        {
            pos++;
            var right = ParseEquality(tokens, ref pos);
            left &= right;
        }
        return left;
    }

    private long ParseEquality(List<string> tokens, ref int pos)
    {
        var left = ParseComparison(tokens, ref pos);
        while (pos < tokens.Count && tokens[pos] is "==" or "!=")
        {
            var op = tokens[pos++];
            var right = ParseComparison(tokens, ref pos);
            left = op == "==" ? (left == right ? 1 : 0) : (left != right ? 1 : 0);
        }
        return left;
    }

    private long ParseComparison(List<string> tokens, ref int pos)
    {
        var left = ParseUnary(tokens, ref pos);
        while (pos < tokens.Count && tokens[pos] is ">" or "<" or ">=" or "<=")
        {
            var op = tokens[pos++];
            var right = ParseUnary(tokens, ref pos);
            left = op switch
            {
                ">" => left > right ? 1 : 0,
                "<" => left < right ? 1 : 0,
                ">=" => left >= right ? 1 : 0,
                "<=" => left <= right ? 1 : 0,
                _ => left,
            };
        }
        return left;
    }

    private long ParseUnary(List<string> tokens, ref int pos)
    {
        if (pos < tokens.Count && tokens[pos] == "!")
        {
            pos++;
            var val = ParseUnary(tokens, ref pos);
            return val == 0 ? 1 : 0;
        }

        if (pos < tokens.Count && tokens[pos] == "~")
        {
            pos++;
            var val = ParseUnary(tokens, ref pos);
            return ~val;
        }

        return ParsePrimary(tokens, ref pos);
    }

    private long ParsePrimary(List<string> tokens, ref int pos)
    {
        if (pos >= tokens.Count)
            return 0;

        var token = tokens[pos];

        // Parenthesized expression
        if (token == "(")
        {
            pos++;
            var val = ParseLogicalOr(tokens, ref pos);
            if (pos < tokens.Count && tokens[pos] == ")")
                pos++;
            return val;
        }

        // defined(SYMBOL) or defined SYMBOL
        if (token == "defined")
        {
            pos++;
            bool hasParen = pos < tokens.Count && tokens[pos] == "(";
            if (hasParen) pos++;
            string symbol = pos < tokens.Count ? tokens[pos++] : "";
            if (hasParen && pos < tokens.Count && tokens[pos] == ")")
                pos++;
            return _macros.ContainsKey(symbol) ? 1 : 0;
        }

        // Integer literal
        if (TryParseNumber(token, out long number))
        {
            pos++;
            return number;
        }

        // Identifier → macro lookup
        pos++;
        return ResolveMacroValue(token);
    }

    /// <summary>
    /// Resolves a macro identifier to its integer value, recursively evaluating
    /// expression-valued macros up to a maximum depth.
    /// </summary>
    private long ResolveMacroValue(string name)
    {
        if (_resolveDepth > 16)
            return 0;

        if (!_macros.TryGetValue(name, out var value))
            return 0; // Undefined macros evaluate to 0

        value = value.Trim();

        if (TryParseNumber(value, out long number))
            return number;

        // The value may be an expression (e.g. "(TEXTURE_LIGHTMAP || SIMPLE_TEXTURE_LIGHTMAP)")
        _resolveDepth++;
        try
        {
            var tokens = Tokenize(value);
            int pos = 0;
            return ParseLogicalOr(tokens, ref pos);
        }
        catch
        {
            return 0;
        }
        finally
        {
            _resolveDepth--;
        }
    }

    private static bool TryParseNumber(string token, out long value)
    {
        if (token.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
            return long.TryParse(token.AsSpan(2), System.Globalization.NumberStyles.HexNumber, null, out value);

        return long.TryParse(token, out value);
    }

    // ── Tokenizer ───────────────────────────────────────────────────────────

    private static List<string> Tokenize(string expression)
    {
        var tokens = new List<string>();
        int i = 0;

        while (i < expression.Length)
        {
            char c = expression[i];

            if (char.IsWhiteSpace(c))
            {
                i++;
                continue;
            }

            // Two-character operators
            if (i + 1 < expression.Length)
            {
                var twoChar = expression.Substring(i, 2);
                if (twoChar is "||" or "&&" or "==" or "!=" or ">=" or "<=")
                {
                    tokens.Add(twoChar);
                    i += 2;
                    continue;
                }
            }

            // Single-character operators / punctuation
            if (c is '(' or ')' or '!' or '>' or '<' or '|' or '&' or '+' or '-' or '*' or '/' or '~')
            {
                tokens.Add(c.ToString());
                i++;
                continue;
            }

            // Numeric literal (decimal or hex, skip trailing type suffix)
            if (char.IsDigit(c))
            {
                int start = i;
                if (c == '0' && i + 1 < expression.Length && expression[i + 1] is 'x' or 'X')
                {
                    i += 2;
                    while (i < expression.Length && IsHexDigit(expression[i]))
                        i++;
                }
                else
                {
                    while (i < expression.Length && char.IsDigit(expression[i]))
                        i++;
                }

                // Skip optional type suffix (e.g. 1u, 0L)
                while (i < expression.Length && char.IsLetter(expression[i]))
                    i++;

                tokens.Add(expression[start..i]);
                continue;
            }

            // Identifier
            if (char.IsLetter(c) || c == '_')
            {
                int start = i;
                while (i < expression.Length && (char.IsLetterOrDigit(expression[i]) || expression[i] == '_'))
                    i++;
                tokens.Add(expression[start..i]);
                continue;
            }

            // Unknown character — skip
            i++;
        }

        return tokens;
    }

    private static bool IsHexDigit(char c) =>
        char.IsDigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}
