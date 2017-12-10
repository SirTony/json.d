module json.parser.parser;

private {
    import json.parser.lexer;
    import json.value;

    import std.conv;
    import std.string;
    import std.utf;

    static immutable dstring[JsonToken.Type] keywords;
    static immutable dchar[JsonToken.Type] punctuation;
}

shared static this()
{
    dstring[JsonToken.Type] _kwTemp;
    foreach( k, v; json.parser.lexer.Keywords )
        _kwTemp[v] = k;

    dchar[JsonToken.Type] _punctTemp;
    foreach( k, v; json.parser.lexer.Punctuation )
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
    StandardCompliant standard;

    public this( Lexer lexer, StandardCompliant standardCompliant )
    {
        this.tokens = lexer.tokenize();
        this.length = this.tokens.length;
        this.standard = standardCompliant;
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

            case Number:
            {
                with( JsonToken.NumberType )
                final switch( token.numberType )
                {
                    case signed:   return JsonValue( token.text.to!long );
                    case unsigned: return JsonValue( token.text.to!ulong );
                    case floating: return JsonValue( token.text.to!real );
                }
            }

            case True:       return jtrue;
            case False:      return jfalse;
            case Null:       return jnull;
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
            JsonValue[dstring] object;
            while( !this.match( RightBrace ) )
            {
                auto key = this.standard ? this.take( String ) : this.takeFirstOf( String, Identifier );
                this.take( Colon );

                object[key.text] = this.parseValue();

                if( !this.match( Comma ) )
                    break;

                this.take( Comma );

                // allow trailing comma in non-standard mode
                if( !this.standard && this.match( RightBrace ) )
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

                if( !this.match( Comma ) )
                    break;

                this.take( Comma );

                // allow trailing comma in non-standard mode
                if( !this.standard && this.match( RightSquare ) )
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
            throw new JsonParserException(
                token,
                "Unexpected '%s', expecting '%s'".format(
                    token.identify(),
                    this.identify( type )
                )
            );

        return token;
    }

    JsonToken takeFirstOf( JsonToken.Type[] types... )
    {
        import std.array : join;
        import std.algorithm.iteration : map;
        import std.algorithm.searching : canFind;

        auto token = this.take();

        if( !types.canFind( token.type ) )
            throw new JsonParserException(
                token,
                "Unexpected '%s', expecting one of: %s".format(
                    token.identify(),
                    types.map!( t => this.identify( t ) ).join( ", " )
                )
            );

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
