module json.value;

private {
    import std.algorithm;
    import std.array;
    import std.ascii;
    import std.conv;
    import std.format;
    import std.range;
    import std.string;
    import traits = std.traits;
    import std.typecons;
    import std.utf;

    enum isJsonValue( T ) = is( Unqual!T == JsonValue );
}

class JsonException : Exception
{
    import std.exception : basicExceptionCtors;
    mixin basicExceptionCtors;
}

JsonValue toJson( T )( T value )
{
    return JsonValue( value );
}

auto jtrue() pure nothrow @property @system
{
    static immutable value = JsonValue( true );
    return value;
}

auto jfalse() pure nothrow @property @system
{
    static immutable value = JsonValue( false );
    return value;
}

auto jnull() pure nothrow @property @system
{
    static immutable value = JsonValue( null );
    return value;
}

alias asJson = toJson;

struct JsonValue
{
    enum Type
    {
        Null,

        String,
        Number,
        True,
        False,
        Array,
        Object,
    }

    private enum NumberType
    {
        signed,
        unsigned,
        floating,
    }

    private {
        Type _type;
        NumberType _numType = void;

        union {
            dstring stringValue            = void;
            long signed                    = void;
            ulong unsigned                 = void;
            real floating                  = void;
            JsonValue[] arrayValue         = void;
            JsonValue[dstring] objectValue = void;
        }
    }

    Type type() const pure nothrow @safe @property
    {
        return this._type;
    }

    // convenience is* properties
    bool isObject() const pure nothrow @safe @property
    {
        return this.type == Type.Object;
    }

    bool isArray() const pure nothrow @safe @property
    {
        return this.type == Type.Array;
    }

    bool isBool() const pure nothrow @safe @property
    {
        return this.type == Type.True || this.type == Type.False;
    }

    bool isString() const pure nothrow @safe @property
    {
        return this.type == Type.String;
    }

    bool isNumber() const pure nothrow @safe @property
    {
        return this.type == Type.Number;
    }

    bool isSigned() const pure nothrow @safe @property
    {
        return this.isNumber && this._numType == NumberType.signed;
    }

    bool isUnsigned() const pure nothrow @safe @property
    {
        return this.isNumber && this._numType == NumberType.unsigned;
    }

    bool isInteger() const pure nothrow @safe @property
    {
        return this.isSigned || this.isUnsigned;
    }

    bool isFloat() const pure nothrow @safe @property
    {
        return this.isNumber && this._numType == NumberType.floating;
    }

    bool isNull() const pure nothrow @safe @property
    {
        return this.type == Type.Null;
    }

    size_t length() const pure @property
    {
        this.enforceType!( Type.Array );
        return this.arrayValue.length;
    }

    bool empty() const pure @system @property
    {
        return this.length == 0;
    }

    JsonValue front() const pure @property
    {
        this.enforceType!( Type.Array );
        return this.arrayValue.front;
    }

    JsonValue back() const pure @property
    {
        this.enforceType!( Type.Array );
        return this.arrayValue.back;
    }

    this( T )( T value ) if( traits.isSomeString!T )
    {
        this.stringValue = value.toUTF32();
        this( Type.String );
    }

    this( T )( T value ) if( traits.isSigned!T && traits.isIntegral!T )
    {
        this.signed = value;
        this._numType = NumberType.signed;
        this( Type.Number );
    }

    this( T )( T value ) if( traits.isUnsigned!T )
    {
        this.unsigned = value;
        this._numType = NumberType.unsigned;
        this( Type.Number );
    }

    this( T )( T value ) if( traits.isFloatingPoint!T )
    {
        this.floating = value;
        this._numType = NumberType.floating;
        this( Type.Number );
    }

    this( bool value )
    {
        this( value ? Type.True : Type.False );
    }

    this( R )( R r ) if( isForwardRange!R && !traits.isSomeString!R )
    {
        foreach( item; r.save() )
        {
            static if( isJsonValue!( ElementType!R ) )
                arrayValue ~= item;
            else
                arrayValue ~= JsonValue( item );
        }
        this( Type.Array );
    }

    this( TKey, TValue )( TValue[TKey] assoc ) if( traits.isSomeString!TKey )
    {
        foreach( key, value; assoc )
        {
            static if( isJsonValue!TValue )
                objectValue[key.toUTF32()] = value;
            else
                objectValue[key.toUTF32()] = JsonValue( value );
        }
        this( Type.Object );
    }

    this( typeof( null ) )
    {
        this( Type.Null );
    }

    private this( Type type )
    {
        this._type = type;
    }

    static auto newArray()
    {
        return JsonValue( typeof( JsonValue.arrayValue ).init );
    }

    static auto newObject()
    {
        return JsonValue( typeof( JsonValue.objectValue ).init );
    }

    bool hasKey( T )( T key ) if( traits.isSomeString!T )
    {
        return this.type == Type.Object
             ? ( key.toUTF32() in this.objectValue ) !is null
             : false;
    }

    T get( T, S )( S key, lazy T defaultvalue = T.init ) if( traits.isSomeString!T )
    {
        return this.hasKey( key ) ? this.objectValue[key.toUTF32()].as!T : defaultvalue;
    }

    alias to = this.opCast;
    alias as = this.opCast;

    string toString()
    {
        with( Type )
        final switch( this.type )
        {
            case True: return "true";
            case False: return "false";

            case Number:
            {
                with( NumberType )
                final switch( this._numType )
                {
                    case signed:   return this.signed.to!string;
                    case unsigned: return this.unsigned.to!string;
                    case floating: return this.floating.to!string;
                }
            }

            case String: return this.stringValue.toUTF8();

            case Null:
            case Array:
            case Object:
                return this.typename;
        }
    }

    T toJsonString( T = string )( bool indented = false ) if( traits.isSomeString!T )
    {
        return ( indented ? this.toPrettyJsonImpl( 1 ) : this.toPlainJsonImpl() ).to!T;
    }

    void popFront()
    {
        this.enforceType!( Type.Array );
        this.arrayValue.popFront();
    }

    void popBack()
    {
        this.enforceType!( Type.Array );
        this.arrayValue.popBack();
    }

    JsonValue save()
    {
        this.enforceType!( Type.Array );
        return JsonValue( this.arrayValue );
    }

    size_t opDollar()
    {
        return this.length;
    }

    JsonValue opSlice( size_t begin, size_t end )
    {
        this.enforceType!( Type.Array );
        return JsonValue( this.arrayValue[begin .. end] );
    }

    JsonValue opSliceAssign( R )( size_t begin, size_t end, R r ) if( isForwardRange!R )
    {
        this.enforceType!( Type.Array );
        this.arrayValue[begin .. end] = r.save().array;
        return this;
    }

    JsonValue opIndex( size_t i )
    {
        this.enforceType!( Type.Array );
        return this.arrayValue[i];
    }

    JsonValue opIndexAssign( T )( size_t i, T value )
    {
        this.enforceType!( Type.Array );

        static if( isJsonValue!T )
            return this.arrayValue[i] = value;
        else
            return this.arrayValue[i] = JsonValue( value );
    }

    JsonValue opIndex( T )( T key ) if( traits.isSomeString!T )
    {
        this.enforceType!( Type.Object );
        return this.objectValue[key.toUTF32()];
    }

    JsonValue opIndexAssign( T, U )( T key, U value ) if( traits.isSomeString!T )
    {
        this.enforceType!( Type.Object );

        static if( isJsonValue!U )
            return this.objectValue[key.toUTF32()] = value;
        else
            return this.objectValue[key.toUTF32()] = JsonValue( value );
    }

    JsonValue opAssign( T )( T value )
    {
        static if( !isJsonValue!T )
            this = JsonValue( value );
        else
            this = value;

        return this;
    }

    JsonValue opOpAssign( string op, T )( T value )
    {
        return this = mixin( "this" ~ op ~ "value" );
    }

    bool opEquals( T )( auto ref const T value ) const
    {
        static if( isJsonValue!T )
            return this.type == value.type && this.opCmp( value ) == 0;
        else
            return this.opCmp( value ) == 0;
    }

    T opCast( T : bool )()
    {
        return this.type == Type.True;
    }

    T opCast( T )() if( traits.isSigned!T && traits.isIntegral!T )
    {
        this.enforceNumType!( NumberType.signed );

        return cast(T)this.signed;
    }

    T opCast( T )() if( traits.isUnsigned!T )
    {
        this.enforceNumType!( NumberType.unsigned );

        return cast(T)this.unsigned;
    }

    T opCast( T )() if( traits.isFloatingPoint!T )
    {
        this.enforceNumType!( NumberType.floating );

        return cast(T)this.floating;
    }

    T opCast( T )() if( traits.isSomeString!T )
    {
        this.enforceType!( Type.String );
        return this.stringValue.to!T;
    }

    T opCast( T )() if( traits.isDynamicArray!T && !traits.isSomeString!T )
    {
        alias TElem = ElementType!T;

        this.enforceType!( Type.Array );
        return this.arrayValue
                   .map!( x => x.opCast!TElem )
                   .array;
    }

    T opCast( T )() if( traits.isAssociativeArray!T )
    {
        alias TKey   = KeyType!T;
        alias TValue = ValueType!T;

        this.enforceType!( Type.Object );

        T result;
        foreach( k, v; this.objectValue )
            result[k.to!TKey] = v.opCast!TValue;

        return result;
    }

    // array foreach
    int opApply( int delegate( ref JsonValue ) apply )
    {
        this.enforceType!( Type.Array );

        int result;
        foreach( ref item; this.arrayValue )
        {
            result = apply( item );
            if( result != 0 )
                break;
        }

        return result;
    }

    // object foreach
    int opApply( int delegate( const ref dstring, ref JsonValue ) apply )
    {
        this.enforceType!( Type.Object );

        int result;
        foreach( dstring k, ref v; this.objectValue )
        {
            result = apply( k, v );
            if( result != 0 )
                break;
        }

        return result;
    }

    private string typename() const @property
    {
        return this.type.to!( string ).toLower();
    }

    private void enforceType( Type type )() const pure @safe
    {
        enum name    = type.to!( string ).toLower();
        enum article = type == Type.Object || type == Type.Array ? "an" : "a";
        enum message = "Value is not %s %s".format( article, name );

        if( this.type != type )
            throw new JsonException( message );
    }

    private void enforceNumType( NumberType type )() const pure @safe
    {
        this.enforceType!( Type.Number );
        enum name = type.to!string ~ ( type == NumberType.floating ? " point" : "" );
        enum article = type == NumberType.unsigned ? "an" : "a";
        enum message = "Value is not %s %s number".format( article, name );

        if( this.type != Type.Number || this._numType != type )
            throw new JsonException( message );
    }

    private dstring toPlainJsonImpl()
    {
        auto writer = appender!dstring;

        with( Type )
        final switch( this.type )
        {
            case Object:
            {
                writer.put( '{' );

                bool first = true;
                foreach( k, v; this.objectValue )
                {
                    if( !first ) writer.put( ',' );
                    writer.formattedWrite( `"%s":%s`, k, v.toPlainJsonImpl() );
                    if( first ) first = false;
                }

                writer.put( '}' );
                break;
            }

            case Array:
            {
                writer.put( '[' );

                bool first = true;
                foreach( item; this.arrayValue )
                {
                    if( !first ) writer.put( ',' );
                    writer.put( item.toPlainJsonImpl() );
                    if( first ) first = false;
                }

                writer.put( ']' );
                break;
            }

            case String:
                writer.formattedWrite( `"%s"`, this.stringValue );
                break;

            case Number:
            {
                with( NumberType )
                final switch( this._numType )
                {
                    case signed:
                        writer.formattedWrite( "%d", this.signed );
                        break;

                    case unsigned:
                        writer.formattedWrite( "%d", this.unsigned );
                        break;

                    case floating:
                        writer.formattedWrite( "%g", this.floating );
                        break;
                }

                break;
            }

            case True, False:
                writer.put( this.type == True ? "true" : "false" );
                break;

            case Null:
                writer.put( "null" );
                break;
        }

        return writer.data;
    }

    private dstring toPrettyJsonImpl( size_t indentLevel )
    {
        auto writer = appender!dstring;

        dstring indent() @property
        {
            return ""d.rightJustify( indentLevel * 4 );
        }

        with( Type )
        final switch( this.type )
        {
            case Object:
            {
                writer.formattedWrite( "{%s%s", newline, indent );

                bool first = true;
                foreach( k, v; this.objectValue )
                {
                    if( !first ) writer.formattedWrite( ",%s%s", newline, indent );
                    writer.formattedWrite( `"%s": %s`, k, v.toPrettyJsonImpl( indentLevel + 1 ) );
                    if( first ) first = false;
                }

                --indentLevel;
                writer.formattedWrite( "%s%s}", newline, indent );
                break;
            }

            case Array:
            {
                writer.formattedWrite( "[%s%s", newline, indent );

                bool first = true;
                foreach( item; this.arrayValue )
                {
                    if( !first ) writer.formattedWrite( ",%s%s", newline, indent );
                    writer.put( item.toPrettyJsonImpl( indentLevel + 1 ) );
                    if( first ) first = false;
                }

                --indentLevel;
                writer.formattedWrite( "%s%s]", newline, indent );
                break;
            }

            case String:
                writer.formattedWrite( `"%s"`, this.stringValue );
                break;

            case Number:
            {
                with( NumberType )
                final switch( this._numType )
                {
                    case signed:
                        writer.formattedWrite( "%d", this.signed );
                        break;

                    case unsigned:
                        writer.formattedWrite( "%d", this.unsigned );
                        break;

                    case floating:
                        writer.formattedWrite( "%g", this.floating );
                        break;
                }

                break;
            }

            case True, False:
                writer.put( this.type == True ? "true" : "false" );
                break;

            case Null:
                writer.put( "null" );
                break;
        }

        return writer.data;
    }
}
