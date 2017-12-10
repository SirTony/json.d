module json.parser;

package {
    import json.parser.lexer  : Lexer;
    import json.parser.parser : Parser;
}

private {
    import json.value   : JsonValue;
    import std.traits   : isSomeString;
    import std.typecons : Flag;
}

public import json.parser.lexer : StandardCompliant;

JsonValue parseJson( T )( T json, StandardCompliant standardcompliant = StandardCompliant.yes ) if( isSomeString!T )
{
    auto lexer = new Lexer( json, standardcompliant );
    auto parser = new Parser( lexer, standardcompliant );

    return parser.parse();
}
