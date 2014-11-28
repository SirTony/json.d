module json;

public {
    import json.jsonexception;
    import json.jsonparseroptions;
}

private {
    import std.file;
    import std.path;
    import std.range;
    import std.traits;
    import std.variant;
    import json.parser;
}

public Variant loadString( TChar )( inout TChar[] s ) if( isSomeChar!TChar )
{
    return loadString( s, JsonParserOptions.default_ );
}

public Variant loadString( TChar )( inout TChar[] s, JsonParserOptions options ) if( isSomeChar!TChar )
{
    return loadImpl( s, options, null );
}

public Variant loadFile( in char[] fileName )
{
    return loadFile( fileName, JsonParserOptions.default_ );
}

public Variant loadFile( in char[] fileName, JsonParserOptions options )
{
    auto base = fileName.baseName();
    auto text = fileName.readText();
    return loadImpl( text, options, cast( string )base );
}

private Variant loadImpl( TChar )( inout TChar[] s, JsonParserOptions options, string fileName )
{
    auto lexer = new Lexer( s, options.allowComments, fileName );
    auto parser = new Parser( lexer, options.allowUnquotedObjectKeys, options.allowTrailingCommas );
    return parser.parse();
}