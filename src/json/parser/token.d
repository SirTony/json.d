module json.parser.token;

package struct TextSpan
{
    immutable size_t line;
    immutable size_t column;
    immutable size_t index;
    immutable size_t length;

    this() @disable;
    this( size_t line, size_t column, size_t index, size_t length = size_t.init )
    {
        this.line = line;
        this.column = column;
        this.index = index;
        this.length = length;
    }

    TextSpan withLength( size_t newLength )
    {
        return TextSpan( this.line, this.column, this.index, newLength );
    }
}

final package class JsonToken
{
    enum Type
    {
        String,
        Number,

        True,
        False,
        Null,

        LeftSquare,
        RightSquare,
        LeftBrace,
        RightBrace,

        Comma,
        Colon,

        EndOfInput,
    }

    private wstring _text;
    private TextSpan _span;

    immutable Type type;

    wstring text() const @property
    {
        return this._text;
    }

    TextSpan span() const @property
    {
        return this._span;
    }

    this( Type type, wstring text, TextSpan span )
    {
        this.type = type;
        this._text = text;
        this._span = span;
    }

    string identify()
    {
        import std.utf;
        import std.conv;
        import std.string;

        with( Type )
        switch( this.type )
        {
            case Number:
            case String:
            case True:
            case False:
            case Null:
                return to!( string )( this.type ).toLower();

            case EndOfInput:
                return "end-of-input";

            default:
                return this.text.toUTF8();
        }
    }
}
