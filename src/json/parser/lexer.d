module json.parser.lexer;

private {
    import json.value : JsonException;

    import std.algorithm;
    import std.conv;
    import std.functional;
    import std.range;
    import std.string;
    import std.traits;
    import std.uni;
    import std.utf;

    alias Tokenizer = bool delegate( dchar, out JsonToken );
    alias Predicate = bool delegate( dchar );
}

package {
    enum JsonToken.Type[dstring] Keywords = [
        "null":  JsonToken.Type.Null,
        "true":  JsonToken.Type.True,
        "false": JsonToken.Type.False,
    ];

    enum JsonToken.Type[dchar] Punctuation = [
        '{': JsonToken.Type.LeftBrace,
        '}': JsonToken.Type.RightBrace,
        '[': JsonToken.Type.LeftSquare,
        ']': JsonToken.Type.RightSquare,
        ',': JsonToken.Type.Comma,
        ':': JsonToken.Type.Colon,
    ];
}

final class JsonParserException : JsonException
{
    private TextSpan _span;
    TextSpan span() const pure nothrow @safe @property
    {
        return this._span;
    }

package:
    this( TextSpan span, string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        this._span = span;
        super( msg, file, line, next );
    }

    this( JsonToken token, string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        this._span = token.span;
        super( msg, file, line, next );
    }
}

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
        Identifier,

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

    enum NumberType
    {
        signed,
        unsigned,
        floating,
    }

    private dstring _text;
    private TextSpan _span;

    immutable Type type;
    immutable NumberType numberType = void;

    dstring text() const @property
    {
        return this._text;
    }

    TextSpan span() const @property
    {
        return this._span;
    }

    this( Type type, dstring text, TextSpan span )
    {
        this.type = type;
        this._text = text;
        this._span = span;
    }

    this( NumberType numType, dstring text, TextSpan span )
    {
        this.numberType = numType;
        this( Type.Number, text, span );
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

alias StandardCompliant = Flag!"JsonStandardCompliantParsing";

final package class Lexer
{
private:
    dstring source;
    immutable size_t length;
    size_t index;
    size_t line;
    size_t column;
    TextSpan[] spans;
    Tokenizer[] tokenizers;
    immutable StandardCompliant standard;

    bool eof() const pure nothrow @safe @property
    {
        return this.index >= this.length;
    }

    public this( S )( S source, StandardCompliant standardCompliant ) if( isSomeString!S )
    {
        this.source = source.toUTF32();
        this.length = this.source.length;
        this.standard = standardCompliant;
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

            if( !this.standard && ( this.trySkipSingleLineComment() || this.trySkipMultiLineComment() ) )
                continue;

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

    bool trySkipSingleLineComment()
    {
        if( !this.isNext( "//" ) )
            return false;

        this.skipWhile( c => c != '\n' );
        return true;
    }

    bool trySkipMultiLineComment()
    {
        if( !this.isNext( "/*" ) )
            return false;

        this.markStart();
        int level = 1;

        this.takeIfNext( "/*" );
        while( !this.eof && level > 0 )
        {
            if( this.isNext( "*/" ) )
            {
                level -= 1;
                this.takeIfNext( "*/" );
                this.markEnd();
                continue;
            }

            if( this.isNext( "/*" ) )
            {
                level += 1;
                this.markStart();
                this.takeIfNext( "/*" );
                continue;
            }

            if( this.eof )
                break;

            this.take();
        }

        // if this is true then we've reached EOF and there's an unterminated comment somewhere
        if( level > 0 )
            throw new JsonParserException(
                this.markEnd(),
                "unexpected end-of-input (unclosed multi-line comment)"
            );

        return true;
    }

    bool tryLexString( dchar c, out JsonToken token )
    {
        if( c != '"' && c != '\'' )
            return false;

        if( c == '\'' && this.standard )
            return false;

        this.markStart();
        immutable terminator = this.take();


        if( c == '\'' && this.standard )
            throw new JsonParserException(
                this.markEnd(),
                "cannot use single-quoted strings in standard-compliant mode"
            );

        dstring text;
        dchar   next;
        while( !this.eof && ( next = this.peek() ) != terminator )
        {
            if( this.standard && next.isControl && !next.isSpace )
                throw new JsonParserException(
                    this.markEnd(),
                    "Control characters (0x%04X) are not allowed in strings".format( next )
                );

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

    bool tryLexNumber( dchar c, out JsonToken token )
    {
        if( !c.isNumber && c != '-' )
            return false;

        bool hasDecimal;
        bool hasExponent;
        bool forceTake = c == '-';
        bool signed = c == '-';

        bool pred( dchar ch )
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
        auto type = hasDecimal || hasExponent
                  ? JsonToken.NumberType.floating
                  : ( signed ? JsonToken.NumberType.signed
                             : JsonToken.NumberType.unsigned );
        token = this.makeToken( type, text );
        return true;
    }

    bool tryLexWord( dchar c, out JsonToken token )
    {
        if( !c.isAlpha && c != '_' )
            return false;

        this.markStart();
        auto text = this.takeWhile( ch => ch.isAlpha || ch.isNumber || ch == '_' );
        if( auto type = text in Keywords )
        {
            token = this.makeToken( *type, text );
            return true;
        }

        if( !this.standard )
        {
            token = this.makeToken( JsonToken.Type.Identifier, text );
            return true;
        }

        throw new JsonParserException(
            this.markEnd(),
            "Unexpected '%s' (did you forget to quote an object key?)".format( text )
        );
    }

    bool tryLexPunctuation( dchar c, out JsonToken token )
    {
        foreach( ch, type; Punctuation )
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

    dchar handleEscapeSequence( dchar escape )
    {
        if( this.eof )
            throw new JsonParserException(
                this.markEnd(),
                "Unexpected end-of-input following escape sequence in string"
            );

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
                    return code.to!( ushort )( 16 ).to!dchar;
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

    JsonToken makeToken( JsonToken.Type type, dstring text )
    {
        return new JsonToken( type, text, this.markEnd() );
    }

    JsonToken makeToken( JsonToken.NumberType numType, dstring text )
    {
        return new JsonToken( numType, text, this.markEnd() );
    }

    dchar peek( int distance = 0 )
    {
        auto newIndex = this.index + distance;
        if( newIndex < 0 || newIndex >= this.length )
            return dchar.init;

        return this.source[newIndex];
    }

    dchar take()
    {
        auto current   = this.peek();
        immutable next = this.peek( 1 );

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

    bool isNext( dstring search )
    {
        auto len = search.length;
        if( this.index + len >= this.length )
            return false;

        return this.source[this.index .. this.index + len] == search;
    }

    bool takeIfNext( dstring search )
    {
        if( this.isNext( search ) )
        {
            foreach( _; 0 .. search.length )
                this.take();
        }

        return false;
    }

    dstring takeWhile( Predicate pred )
    {
        dstring result;
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
