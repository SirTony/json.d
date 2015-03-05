module json.parser.parser;

private {
    import std.conv;
    import std.array;
    import std.string;
    import std.traits;
    import std.variant;
    import std.algorithm;
    import json.parser.lexer;
    import json.parser.token;
    import json.jsonexception;
}

final package class Parser( C ) if( isSomeChar!C )
{
    private Token!( C )[] tokens;
    private bool allowIdentifierKeys;
    private bool allowTrailingCommas;

    public this( Lexer!( C ) lexer )
    {
        this.tokens = lexer.lex();
    }

    public Variant parse()
    {
        Variant root = null;

        if( this.match( TokenType.eof ) )
            return root;

        root = this.parseValue();
        this.take( TokenType.eof );

        return root;
    }

    private Variant parseValue()
    {
        auto token = this.take();
        Variant value;

        switch( token.type )
        {
            case TokenType.number:
                value = token.contents.to!real;
                break;

            case TokenType.string:
                value = token.contents;
                break;

            case TokenType.leftBrace:
                value = this.parseObject();
                break;

            case TokenType.leftSquare:
                value = this.parseArray();
                break;

            case TokenType.null_:
                value = null;
                break;

            case TokenType.boolean:
                value = token.contents.to!bool;
                break;

            default:
                throw new JsonParserException( "Unexpected %s".format( token.type.identify() ), token.line, token.column, token.fileName );
        }

        return value;
    }

    private Variant parseObject()
    {
        Variant[Variant] object;
        Variant result;

        if( this.matchAndTake( TokenType.rightBrace ) )
        {
            result = object;
            return result;
        }

        while( true )
        {
            auto keyToken = this.takeFirstOf( TokenType.identifier, TokenType.string );

            if( keyToken.type == TokenType.identifier && !this.allowIdentifierKeys )
                throw new JsonParserException( "Unexpected %s, expecting %s.".format( keyToken.type.identify(), TokenType.string.identify() ), keyToken.line, keyToken.column, keyToken.fileName );

            this.take( TokenType.colon );

            Variant key = keyToken.contents;
            Variant value = this.parseValue();

            object[key] = value;

            if( this.match( TokenType.comma ) && this.match( TokenType.rightBrace, 1 ) )
            {
                Token comma = this.peek();
                throw new JsonParserException( "Unexpected %s, expecting %s.".format( comma.type.identify(), TokenType.rightBrace.identify() ), comma.line, comma.column, comma.fileName );
            }

            this.matchAndTake( TokenType.comma );
            if( this.match( TokenType.rightBrace ) )
                break;
        }

        this.take( TokenType.rightBrace );

        result = object;
        return result;
    }

    private Variant parseArray()
    {
        Variant[] array;
        Variant result;

        if( this.matchAndTake( TokenType.rightSquare ) )
        {
            result = array;
            return result;
        }

        while( true )
        {
            array ~= this.parseValue();

            if( this.match( TokenType.comma ) && this.match( TokenType.rightSquare, 1 ) )
            {
                auto comma = this.peek();
                throw new JsonParserException( "Unexpected %s, expecting %s.".format( comma.type.identify(), TokenType.rightSquare.identify() ), comma.line, comma.column, comma.fileName );
            }

            this.matchAndTake( TokenType.comma );
            if( this.match( TokenType.rightSquare ) )
                break;
        }

        this.take( TokenType.rightSquare );

        result = array;
        return result;
    }

    private Token!C peek( int distance = 0 )
    {
        if( distance == 0 )
            return this.tokens.front;
        else
            return this.tokens[distance];
    }

    private Token!C take()
    {
        auto value = this.peek();
        this.tokens.popFront();
        return value;
    }

    private Token!C take( TokenType type )
    {
        auto value = this.take();

        if( value.type != type )
            throw new JsonParserException( "Unexpected %s, expecting %s.".format( value.type.identify(), type.identify() ), value.line, value.column, value.fileName );

        return value;
    }

    private Token!C takeFirstOf( TokenType[] types ... )
    {
        foreach( type; types )
        {
            if( this.match( type ) )
                return this.take();
        }

        auto head = types[0 .. $ - 2].map!( x => x.identify() ).array.join( ", " );
        auto last   = types[$ - 1].identify();

        Token top = this.peek();
        throw new JsonParserException( "Unexpected %s, expecting %s or %s.".format( top.type.identify(), head, last ), top.line, top.column, top.fileName );
    }

    private bool match( TokenType type, int distance = 0 )
    {
        return this.peek( distance ).type == type;
    }

    private bool matchAndTake( TokenType type )
    {
        if( this.match( type ) )
        {
            this.take();
            return true;
        }

        return false;
    }
}