module json.parser.lexer;

private {
    import std.uni;
    import std.conv;
    import std.array;
    import std.traits;
    import std.string;
    import std.algorithm;
    import json.parser.token;
    import json.jsonexception;
}

private template Chars( C ) if( isSomeChar!C )
{
    private enum C[] hexChars = [
        'a', 'b', 'c', 'd', 'e', 'f',
        'A', 'B', 'C', 'D', 'E', 'F',
    ];

    private enum TokenType[C] punctuation = [
        ':': TokenType.colon,
        ',': TokenType.comma,
        '[': TokenType.leftSquare,
        ']': TokenType.rightSquare,
        '{': TokenType.leftBrace,
        '}': TokenType.rightBrace
    ];

    private enum TokenType[immutable( C )[]] keywords = [
        "true":  TokenType.boolean,
        "false": TokenType.boolean,
        "null":  TokenType.null_
    ];
}

final package class Lexer( C ) if( isSomeChar!C )
{
    mixin Chars!C;

    private alias immutable( C )[] jstring;

    private jstring source;
    private int column;
    private int line;
    private string file;

    private bool eof() @property
    {
        return this.source.length == 0;
    }

    public this( const( C )[] source, string file = null )
    {
        this.source = source;
        this.line = 1;
        this.column = 1;
        this.file = file;
    }

    public Token[] lex()
    {
        Token!( C )[] tokens;

        outer: while( !this.eof )
        {
            this.takeWhile( ( c ) {
                if( c == '\n' )
                {
                    ++this.line;
                    this.column = 0;
                }

                return c.isWhite;
            } );

            if( this.eof )
                break;

            if( this.peek() == '"' || this.peek() == '\'' )
            {
                int currentLine = this.line;
                int currentColumn = this.column;
                C terminator = this.take();
                jstring contents;

                str: while( !this.eof && this.peek() != terminator )
                {
                    if( this.peek() == '\\' )
                    {
                        int currentLine2 = this.line;
                        int currentColumn2 = this.column;

                        this.take();
                        C esc = this.take();

                        switch( esc )
                        {
                            case '\'':
                            case '"':
                                contents ~= esc;
                                break;

                            case 'n':
                                contents ~= '\n';
                                break;

                            case 't':
                                contents ~= '\t';
                                break;

                            case 'v':
                                contents ~= '\v';
                                break;

                            case 'f':
                                contents ~= '\f';
                                break;

                            case 'r':
                                contents ~= '\r';
                                break;

                            case 'x':
                            case 'u':
                                int currentLine3 = this.line;
                                int currentColumn3 = this.column;

                                jstring number = this.takeWhile( c => c.isNumber || hexChars.canFind( c ) );
                                uint code;

                                try
                                {
                                    code = number.to!( uint )( 16 ); //base-16 (hexadecimal)
                                }
                                catch( Throwable th )
                                {
                                    throw new JsonParserException( "'\\u%s' is not a valid character.".format( number ), currentLine3, currentColumn3, this.file, th );
                                }

                                C ch = cast( C )code;

                                if( !ch.isValidDchar || ch == 0xFFFE || ch == 0xFFFF )
                                    throw new JsonParserException( "'\\u%s' is not a valid character.".format( number ), currentLine3, currentColumn3, this.file );

                                contents ~= ch;
                                break;

                            default:
                                throw new JsonParserException( "Unrecognized escape sequence '\\%s'".format( esc ), currentLine2, currentColumn2, this.file );
                        }

                        continue str;
                    }

                    contents ~= this.take();
                }

                if( this.eof )
                    throw new JsonParserException( "Unexpected end-of-input.", currentLine, currentColumn, this.file );

                this.take();
                tokens ~= Token!( C )( TokenType.string, contents, currentLine, currentColumn, this.file );
                continue outer;
            }

            if( this.peek().isNumber || this.peek() == '-' || this.peek() == '+' )
            {
                int currentLine = this.line;
                int currentColumn = this.column;

                jstring number = this.takeWhile(
                    c =>
                        c.isNumber ||
                        c == 'e'   ||
                        c == 'E'   ||
                        c == '-'   ||
                        c == '+'   ||
                        c == '.'
                );

                try
                {
                    real value = number.to!real;
                    tokens ~= Token!( c )( TokenType.number, number, currentLine, currentColumn, this.file );
                    continue outer;
                }
                catch( Throwable th )
                {
                    throw new JsonParserException( "'%s' is not a valid number.".format( number ), currentLine, currentColumn, this.file, th );
                }
            }

            words: foreach( kw, type; keywords )
            {
                if( this.takeIfNext( kw ) )
                {
                    tokens ~= Token!( C )( type, kw, this.line, this.column - kw.length, this.file );
                    continue outer;
                }
            }

            if( this.peek().isAlpha || this.peek() == '_' )
            {
                jstring contents;
                contents ~= this.take();
                contents ~= this.takeWhile( c => c.isAlpha || c.isNumber || c == '_' );

                tokens ~= Token!( C )( TokenType.identifier, contents, this.line, this.column - contents.length, this.file );
                continue outer;
            }

            auto op = this.peek() in punctuation;
            if( op !is null )
            {
                tokens ~= Token!( C )( *op, [ this.take() ], this.line, this.column - 1, this.file );
                continue outer;
            }

            throw new JsonParserException( "Unexpected character '%s'.".format( this.peek() ), this.line, this.column, this.file );
        }

        tokens ~= Token!( C )( TokenType.eof, null, this.line, this.column, this.file );
        return tokens;
    }

    private C peek( int distance = 0 )
    {
        if( distance == 0 )
            return this.source.front;
        else
            return this.source[distance];
    }

    private C take()
    {
        if( this.eof )
            throw new JsonParserException( "Unexpected end-of-input.", this.line, this.column, this.file );

        C value = this.peek();
        this.source.popFront();
        ++this.column;
        return value;
    }

    private jstring takeWhile( bool delegate( C ) pred )
    {
        jstring result;

        while( !this.eof && pred( this.peek() ) )
            result ~= this.take();

        return result;
    }

    private bool takeIfNext( jstring s )
    {
        if( this.source.length < s.length )
            return false;

        foreach( i; 0 .. s.length )
        {
            if( s[i] != this.peek( i ) )
                return false;
        }

        foreach( _; 0 .. s.length )
            this.take();

        return true;
    }
}