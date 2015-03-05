module json.functions;

private {
    import std.file;
    import std.path;
    import std.range;
    import std.traits;
    import std.variant;
    import json.parser;
}

public Variant loadString( C )( const( C )[] s ) if( isSomeChar!C )
{
    return loadImpl( s, null );
}

public Variant loadFile( S = string )( string fileName ) if( isSomeString!S )
{
    auto base = fileName.baseName();
    auto text = fileName.readText!( S );
    return loadImpl( text, base );
}

private Variant loadImpl( C )( const( C )[] s, string fileName ) if( isSomeChar!C )
{
    auto lexer = new Lexer!( C )( s, fileName );
    auto parser = new Parser!( C )( lexer );
    return parser.parse();
}