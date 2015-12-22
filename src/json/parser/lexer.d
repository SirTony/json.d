module json.parser.lexer;

package import json.parser.token;

private {
    import std.utf;
    import std.uni;
    import std.conv;
    import std.range;
    import std.string;
    import std.traits;
    import std.algorithm;
    import std.functional;

    import json.exception;

    alias Tokenizer = bool delegate( wchar, out JsonToken );
    alias Predicate = bool delegate( wchar );
}

package {
    enum JsonToken.Type[wstring] keywords = [
        "null":  JsonToken.Type.Null,
        "true":  JsonToken.Type.True,
        "false": JsonToken.Type.False,
    ];

    enum JsonToken.Type[wchar] punctuation = [
        '{': JsonToken.Type.LeftBrace,
        '}': JsonToken.Type.RightBrace,
        '[': JsonToken.Type.LeftSquare,
        ']': JsonToken.Type.RightSquare,
        ',': JsonToken.Type.Comma,
        ':': JsonToken.Type.Colon,
    ];
}

final package class Lexer
{
private:
    wstring source;
    immutable size_t length;
    size_t index;
    size_t line;
    size_t column;
    TextSpan[] spans;
    Tokenizer[] tokenizers;

    bool eof() const @property
    {
        return this.index >= this.length;
    }

    public this( wstring source )
    {
        this.source = source;
        this.length = source.length;
        this.tokenizers = [
            &this.tryLexString,
            &this.tryLexNumber,
            &this.tryLexWord,
            &this.tryLexPunctuation,
        ];
    }

    public JsonToken[] tokenize()
    {
        JsonToken[] tokens;
        while( !this.eof )
        {
            this.skipWhile( c => c.isWhite );

            if( this.eof )
                break;

            JsonToken token;
            if( this.tokenizers.any!( fn => fn( this.peek(), token ) ) )
                tokens ~= token;
            else
            {
                this.markStart();
                auto c = this.take();
                throw new JsonParserException( this.markEnd(), "Unexpected character '%s' (0x%04X)".format( c, c ) );
            }
        }

        this.markStart();
        tokens ~= this.makeToken( JsonToken.Type.EndOfInput, null );
        return tokens;
    }

    bool tryLexString( wchar c, out JsonToken token )
    {
        if( c != '"' )
            return false;

        this.markStart();
        auto terminator = this.take();

        wstring text;
        wchar   next;
        while( !this.eof && ( next = this.peek() ) != terminator )
        {
            if( next.isControl && !next.isSpace )
                throw new JsonParserException( this.markEnd(), "Control characters are not allowed in strings" );

            if( next == '\\' )
            {
                text ~= this.handleEscapeSequence( this.take() );
                continue;
            }

            text ~= this.take();
        }

        if( this.eof )
            throw new JsonParserException( this.markEnd(), "Unexpected end-of-input (unterminated string)" );

        assert( this.take() == terminator );

        token = this.makeToken( JsonToken.Type.String, text );
        return true;
    }

    bool tryLexNumber( wchar c, out JsonToken token )
    {
        if( !c.isNumber )
            return false;

        bool hasDecimal;
        bool hasExponent;
        bool forceTake;

        bool pred( wchar ch )
        {
            if( forceTake )
            {
                forceTake = false;
                return true;
            }

            if( ch == '.' )
            {
                if( hasDecimal )
                    throw new JsonParserException( this.markEnd(), "Duplicate decimal point in number" );

                hasDecimal = true;
                return this.peek( 1 ).isNumber;
            }

            if( ch == 'e' || ch == 'E' )
            {
                if( hasExponent )
                    throw new JsonParserException( this.markEnd(), "Duplicate exponent in number" );

                hasExponent = true;
                auto next = this.peek( 1 );
                if( next == '+' || next == '-' )
                {
                    forceTake = true;
                    return this.peek( 2 ).isNumber;
                }

                return next.isNumber;
            }

            return ch.isNumber;
        }

        this.markStart();
        auto text = this.takeWhile( &pred );
        token = this.makeToken( JsonToken.Type.Number, text );
        return true;
    }

    bool tryLexWord( wchar c, out JsonToken token )
    {
        if( !c.isAlpha && c != '_' )
            return false;

        this.markStart();
        auto text = this.takeWhile( ch => ch.isAlpha || ch.isNumber || ch == '_' );
        if( auto type = text in keywords )
        {
            token = this.makeToken( *type, text );
            return true;
        }

        throw new JsonParserException( this.markEnd(), "Unexpected '%s' (did you forget to quote an object key?)".format( text ) );
    }

    bool tryLexPunctuation( wchar c, out JsonToken token )
    {
        foreach( ch, type; punctuation )
        {
            if( c == ch )
            {
                this.markStart();
                token = this.makeToken( type, [ this.take() ] );
                return true;
            }
        }

        return false;
    }

    wchar handleEscapeSequence( wchar escape )
    {
        if( this.eof )
            throw new JsonParserException( this.markEnd(), "Unexpected end-of-input following escape sequence in string" );

        switch( escape )
        {
            case '"':
            case '\\':
            case '/':
                return escape;

            case 'b': return '\b';
            case 'f': return '\f';
            case 'n': return '\n';
            case 'r': return '\r';
            case 't': return '\t';

            case 'u':
            {
                int i = -1;
                auto code = this.takeWhile( _ => ++i < 4 );

                if( code.length < 4 )
                    throw new JsonParserException( this.markEnd(), "Unexpected end-of-input following escape sequence in string" );

                try
                {
                    return code.to!( ushort )( 16 ).to!wchar;
                }
                catch( Throwable th )
                {
                    throw new JsonParserException( this.markEnd(), th.msg, __FILE__, __LINE__, th );
                }
            }

            default:
                throw new JsonParserException( this.markEnd(), "Unrecognized escape sequence '\\%s'".format( escape ) );
        }
    }

    void markStart()
    {
        this.spans ~= TextSpan( this.line, this.column, this.index );
    }

    TextSpan markEnd()
    {
        auto span = this.spans.back;
        this.spans.popBack();

        return span.withLength( this.index - span.index );
    }

    JsonToken makeToken( JsonToken.Type type, wstring text )
    {
        return new JsonToken( type, text, this.markEnd() );
    }

    wchar peek( int distance = 0 )
    {
        auto newIndex = this.index + distance;
        if( newIndex < 0 || newIndex >= this.length )
            return wchar.init;

        return this.source[newIndex];
    }

    wchar take()
    {
        auto current = this.peek();
        auto next    = this.peek( 1 );

        if( current == '\r' )
        {
            if( next == '\n' )
            {
                ++this.index;
                current = next;
            }
        }

        if( next == '\n' )
        {
            ++this.line;
            this.column = 0;
        }

        ++this.index;
        ++this.column;

        return current;
    }

    bool isNext( wstring search )
    {
        auto len = search.length;
        if( this.index + len >= this.length )
            return false;

        return this.source[this.index .. this.index + len] == search;
    }

    bool takeIfNext( wstring search )
    {
        if( this.isNext( search ) )
        {
            foreach( _; 0 .. search.length )
                this.take();
        }

        return false;
    }

    wstring takeWhile( Predicate pred )
    {
        wstring result;
        while( !this.eof && pred( this.peek() ) )
            result ~= this.take();

        return result;
    }

    void skipWhile( Predicate pred )
    {
        while( !this.eof && pred( this.peek() ) )
            this.take();
    }
}
