module json.d;

public {
    import json.value;
    import json.exception;
}

private {
    import std.utf;
    import std.traits;

    import json.parser.parser;
}

JsonValue parseJson( T )( T json ) if( isSomeString!T )
{
    auto lexer = new Lexer( json.toUTF16() );
    auto parser = new Parser( lexer );

    return parser.parse();
}
