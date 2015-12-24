module json.value;

private {
    import std.utf;
    import std.conv;
    import std.ascii;
    import std.array;
    import std.range;
    import std.format;
    import std.string;
    import std.traits;
    import std.typecons;
    import std.algorithm;

    import json.exception;

    enum isJsonValue( T ) = is( Unqual!T == JsonValue );
}

JsonValue toJson( T )( T value )
{
    return JsonValue( value );
}

alias asJson = toJson;

struct JsonValue
{
    enum Type
    {
        String,
        Number,
        Boolean,
        Array,
        Object,
        Null,
    }

    private static Nullable!JsonValue _null;
    private static Nullable!JsonValue _false;
    private static Nullable!JsonValue _true;

    static JsonValue Null() @property
    {
        if( _null.isNull )
            _null = JsonValue( Type.Null );

        return _null.get();
    }

    static JsonValue False() @property
    {
        if( _false.isNull )
            _false = JsonValue( false );

        return _false.get();
    }

    static JsonValue True() @property
    {
        if( _true.isNull )
            _true = JsonValue( true );

        return _true.get();
    }

    private {
        Type _type;

        wstring stringValue            = void;
        real numberValue               = void;
        bool booleanValue              = void;
        JsonValue[] arrayValue         = void;
        JsonValue[wstring] objectValue = void;
    }

    Type type() const @property
    {
        return this._type;
    }

    size_t length() const @property
    {
        this.enforceType!( Type.Array );
        return this.arrayValue.length;
    }

    bool empty() @property
    {
        return this.length == 0;
    }

    JsonValue front() @property
    {
        this.enforceType!( Type.Array );
        return this.arrayValue.front;
    }

    JsonValue back() @property
    {
        this.enforceType!( Type.Array );
        return this.arrayValue.back;
    }

    this() @disable;

    this( T )( T value ) if( isSomeString!T )
    {
        this.stringValue = value.toUTF16();
        this( Type.String );
    }

    this( T )( T value ) if( isNumeric!T )
    {
        this.numberValue = cast(real)value;
        this( Type.Number );
    }

    this( bool value )
    {
        this.booleanValue = value;
        this( Type.Boolean );
    }

    this( R )( R r ) if( isForwardRange!R && !isSomeString!R )
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

    this( TKey, TValue )( TValue[TKey] assoc ) if( isSomeString!TKey )
    {
        foreach( key, value; assoc )
        {
            static if( isJsonValue!TValue )
                objectValue[key.toUTF16()] = value;
            else
                objectValue[key.toUTF16()] = JsonValue( value );
        }
        this( Type.Object );
    }

    private this( Type type )
    {
        this._type = type;
    }

    bool hasKey( T )( T key ) if( isSomeString!T )
    {
        return this.type == Type.Object
             ? ( key.toUTF16() in this.objectValue ) !is null
             : false;
    }

    bool istype( T )()
    {
        with( Type )
        {
            static if( is( T == bool ) )
                return this.type == Boolean;
            else static if( isNumeric!T )
                return this.type == Number;
            else static if( isSomeString!T )
                return this.type == String;
            else static if( isDynamicArray!T )
                return this.type == Array;
            else static if( isAssociativeArray!T )
                return this.type == Object;
            else
                return false;
        }
    }

    alias to = this.opCast;
    alias as = this.opCast;

    string toString()
    {
        with( Type )
        final switch( this.type )
        {
            case Boolean:
                return this.booleanValue.to!string;

            case Number:
                return this.numberValue.to!string;

            case String:
                return this.stringValue.toUTF8();

            case Null:
            case Array:
            case Object:
                return this.typename;
        }
    }

    T toJsonString( T = wstring )( bool indented = false ) if( isSomeString!T )
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

    JsonValue opIndex( T )( T key ) if( isSomeString!T )
    {
        this.enforceType!( Type.Object );
        return this.objectValue[key.toUTF16()];
    }

    JsonValue opIndexAssign( T, U )( T key, U value ) if( isSomeString!T )
    {
        this.enforceType!( Type.Object );

        static if( isJsonValue!U )
            return this.objectValue[key.toUTF16()] = value;
        else
            return this.objectValue[key.toUTF16()] = JsonValue( value );
    }

    JsonValue opAssign( T )( T value )
    {
        static if( !isJsonValue!T )
            this = JsonValue( value );
        else
        {
            this._type = value.type;

            with( Type )
            final switch( value.type )
            {
                case String:
                    this.stringValue = value.stringValue;
                    break;

                case Number:
                    this.numberValue = value.numberValue;
                    break;

                case Boolean:
                    this.booleanValue = value.booleanValue;
                    break;

                case Array:
                    this.arrayValue = value.arrayValue;
                    break;

                case Object:
                    this.objectValue = value.objectValue;
                    break;

                case Null: break;
            }
        }

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

    int opCmp( T )( ref const T value ) const if( isNumeric!T )
    {
        return this.type == Type.Number
            ? cast(int)( this.numberValue - value )
            : int.min;
    }

    int opCmp( ref const JsonValue value ) const
    {
        return this.type == value.type && this.type == Type.Number
             ? cast(int)( this.numberValue - value.numberValue )
             : int.min;
    }

    JsonValue opBinary( string op, T )( T value ) if( isNumeric!T && ( op == "+" || op == "-" || op == "*" || op == "/" || op == "^^" ) )
    {
        if( this.type != Type.Number )
            throw new JsonException( "Cannot apply operator '%s' to types %s and number".format( op, this.typename ) );

        return JsonValue( this.numberValue + value );
    }

    JsonValue opBinary( string op, T )( T value ) if( isIntegral!T && ( op == ">>" || op == ">>>" || op == "<<" || op == "&" || op == "|" || op == "^" ) )
    {
        if( this.type != Type.Number )
            throw new JsonException( "Cannot apply operator '%s' to types %s and integer".format( op, this.typename ) );

        static if( op == ">>>" )
        {
            ulong num = this.numberValue.to!ulong;
            return num >>> value;
        }
        else
        {
            long num = this.numberValue.to!long;
            return mixin( "num" ~ op ~ "value" );
        }
    }

    JsonValue opBinary( string op, R )( R r ) if( op == "~" && isForwardRange!R )
    {
        if( this.type != Type.Array )
            throw new JsonException( "Cannot concatenate type %s and range".format( this.typename ) );

        return JsonValue( this.arrayValue ~ r.save().array );
    }

    JsonValue opBinary( string op, T )( T value ) if( op == "~" && isSomeString!T )
    {
        if( this.type != Type.String )
            throw new JsonException( "Cannot concatenate typ %s and string".format( this.typename ) );

        return JsonValue( this.stringValue ~ value.toUTF16() );
    }

    JsonValue* opBinaryRight( string op, T )( T key ) if( op == "in" && isSomeString!T )
    {
        if( this.type != Type.Object )
            throw new JsonException( "Cannot apply operator '%s' to types %s and string".format( this.typename ) );

        return key.toUTF16() in this.objectValue;
    }

    bool opBinaryRight( string op, T )( T key ) if( op == "!in" && isSomeString!T )
    {
        return this.opBinaryRight!( "in", T )( key ) is null;
    }

    T opCast( T : bool )()
    {
        return this.type == Type.Boolean ? this.booleanValue : true;
    }

    T opCast( T )() if( isNumeric!T )
    {
        this.enforceType!( Type.Number );
        return this.numberValue.to!T;
    }

    T opCast( T )() if( isSomeString!T )
    {
        this.enforceType!( Type.String );
        return this.stringValue.to!T;
    }

    T opCast( T )() if( isDynamicArray!T && !isSomeString!T )
    {
        alias TElem = ElementType!T;

        this.enforceType!( Type.Array );
        return this.arrayValue
                   .map!( x => x.opCast!TElem )
                   .array;
    }

    T opCast( T )() if( isAssociativeArray!T )
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
    int opApply( int delegate( const ref wstring, ref JsonValue ) apply )
    {
        this.enforceType!( Type.Object );

        int result;
        foreach( wstring k, ref v; this.objectValue )
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

    private void enforceType( Type type )() const
    {
        enum name    = type.to!( string ).toLower();
        enum article = type == Type.Object || type == Type.Array ? "an" : "a";
        enum message = "Value is not %s %s".format( article, name );

        if( this.type != type )
            throw new JsonException( message );
    }

    private wstring toPlainJsonImpl()
    {
        auto writer = appender!wstring;

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
                writer.formattedWrite( "%g", this.numberValue );
                break;

            case Boolean:
                writer.put( this.booleanValue ? "true" : "false" );
                break;

            case Null:
                writer.put( "null" );
                break;
        }

        return writer.data;
    }

    private wstring toPrettyJsonImpl( size_t indentLevel )
    {
        auto writer = appender!wstring;

        wstring indent() @property
        {
            return ""w.rightJustify( indentLevel * 4 );
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
                writer.formattedWrite( "%g", this.numberValue );
                break;

            case Boolean:
                writer.put( this.booleanValue ? "true" : "false" );
                break;

            case Null:
                writer.put( "null" );
                break;
        }

        return writer.data;
    }
}
