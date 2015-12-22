module json.parser.parser;

package import json.parser.lexer;

private {
    import std.utf;
    import std.conv;
    import std.string;

    import json.value;
    import json.exception;

    immutable wstring[JsonToken.Type] keywords;
    immutable wchar[JsonToken.Type] punctuation;
}

shared static this()
{
    wstring[JsonToken.Type] _kwTemp;
    foreach( k, v; json.parser.lexer.keywords )
        _kwTemp[v] = k;

    wchar[JsonToken.Type] _punctTemp;
    foreach( k, v; json.parser.lexer.punctuation )
        _punctTemp[v] = k;

    keywords    = cast(immutable)_kwTemp;
    punctuation = cast(immutable)_punctTemp;
}

final package class Parser
{
private:
    JsonToken[] tokens;
    immutable size_t length;
    size_t index;

    public this( Lexer lexer )
    {
        this.tokens = lexer.tokenize();
        this.length = this.tokens.length;
    }

    public JsonValue parse()
    {
        this.index = 0;
        auto value = this.parseValue();
        this.take( JsonToken.Type.EndOfInput );

        return value;
    }

    JsonValue parseValue()
    {
        auto token = this.take();
        with( JsonToken.Type )
        switch( token.type )
        {
            case String:     return JsonValue( token.text );
            case Number:     return JsonValue( token.text.to!real );
            case True:       return JsonValue.True;
            case False:      return JsonValue.False;
            case Null:       return JsonValue.Null;
            case LeftBrace:  return this.parseObject();
            case LeftSquare: return this.parseArray();

            default:
                throw new JsonParserException( token, "Unexpected '%s', expecting value".format( token.identify() ) );
        }
    }

    JsonValue parseObject()
    {
        with( JsonToken.Type )
        {
            JsonValue[wstring] object;
            while( !this.match( RightBrace ) )
            {
                auto key = this.take( String );
                this.take( Colon );

                object[key.text] = this.parseValue();

                if( !this.matchAndTake( Comma ) )
                    break;
            }

            this.take( RightBrace );
            return JsonValue( object );
        }
    }

    JsonValue parseArray()
    {
        with( JsonToken.Type )
        {
            JsonValue[] array;
            while( !this.match( RightSquare ) )
            {
                array ~= this.parseValue();

                if( !this.matchAndTake( Comma ) )
                    break;
            }

            this.take( RightSquare );
            return JsonValue( array );
        }
    }

    JsonToken take()
    {
        debug assert( this.index < this.length );
        return this.tokens[this.index++];
    }

    JsonToken take( JsonToken.Type type )
    {
        auto token = this.take();
        if( token.type != type )
            throw new JsonParserException( token, "Unexpected '%s', expecting '%s'".format( token.identify(), this.identify( type ) ) );

        return token;
    }

    bool match( JsonToken.Type type )
    {
        return this.tokens[this.index].type == type;
    }

    bool matchAndTake( JsonToken.Type type )
    {
        if( this.match( type ) )
        {
            this.take( type );
            return true;
        }

        return false;
    }

    string identify( JsonToken.Type type )
    {
        if( auto word = type in keywords )
            return ( *word ).toUTF8();

        if( auto mark = type in punctuation )
            return [ *mark ].toUTF8();

        with( JsonToken.Type )
        switch( type )
        {
            case EndOfInput:
                return "end-of-input";

            case String:
            case Number:
                return to!( string )( type ).toLower();

            default:
                assert( false, "unhandled type '%s'".format( type ) );
        }
    }
}
