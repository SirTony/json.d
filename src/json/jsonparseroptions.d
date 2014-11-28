module json.jsonparseroptions;

public struct JsonParserOptions
{
    public static JsonParserOptions default_() @property
    {
        JsonParserOptions options =
        {
            allowComments:           true,
            allowUnquotedObjectKeys: true,
            allowTrailingCommas:     true
        };

        return options;
    }

    public static JsonParserOptions strict() @property
    {
        JsonParserOptions options = 
        {
            allowComments:           false,
            allowUnquotedObjectKeys: false,
            allowTrailingCommas:     false
        };

        return options;
    }

    public bool allowComments;
    public bool allowUnquotedObjectKeys;
    public bool allowTrailingCommas;
}