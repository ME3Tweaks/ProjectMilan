using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Schema;

namespace ME3TweaksModManager.modmanager.objects.mod.merge
{
    internal class JsonSchemaValidator
    {
        public static IList<string> ValidateSchema(string inputString, string inputSchemaText)
        {
            JSchema schema = JSchema.Parse(inputSchemaText);
            JObject inputText = JObject.Parse(inputString);

            bool valid = inputText.IsValid(schema, out IList<string> messages);
            if (!valid)
            {
                return messages;
            }

            return null;
        }
    }
}
