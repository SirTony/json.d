module json.parser;

package {
    import json.parser.lexer;
    import json.parser.parser;
}

private {
    import json.value;
    import std.traits;
}

JsonValue parseJson( T )( T json ) if( isSomeString!T )
{
    auto lexer = new Lexer( json );
    auto parser = new Parser( lexer );

    return parser.parse();
}
