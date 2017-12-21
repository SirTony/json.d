module json.serialization;

// this module is not ready for use just yet
version( none ):

private{
    import json.parser : parseJson;
    import json.value;

    import std.meta;
    import std.string;
    import std.traits;
    import std.typecons;

    void ensureNotNull( T )( JsonValue value )
    {
        if( value.isNull )
            throw new JsonException( "cannot convert null to %s".format( T.stringof ) );
    }

    void ensureDeserializable( T, string name )()
    {
        enum canConvert = is( typeof( {
            auto _ = &JsonValue.opCast!T;
        } ) );

        static assert(
            canConvert,
            "cannot convert to type %s for field %s".format( T.stringof, name )
        );
    }

    template isNullable( T, bool typeconsNullable )
    {
        static if( !typeconsNullable )
            enum isNullable = is( typeof( { T _ = null; } ) );
        else
        {
            enum isNullable = is( typeof( {
                import std.algorithm.searching : startsWith;

                enum name = fullyQualifiedName!( Unqual!T );
                static assert( name.startsWith( "std.typecons.Nullable" ) );
            } ) );
        }
    }

    enum typeIsJsonObject( T, bool hasDeserializer = true, bool hasSerializer = true ) = is( typeof( {
        static if( hasDeserializer )
            T.fromJson( JsonValue.init );

        static if( hasSerializer )
            JsonValue _ = T.init.toJson();
    } ) );

    enum typeIsJsonValue( T ) = is( typeof( {
        auto _ = JsonValue( T.init );
    } ) );

    enum isRefNullable( T ) = is( typeof( {
        import std.algorithm.searching : startsWith;

        enum name = fullyQualifiedName!( Unqual!T );
        static assert( name.startsWith( "std.typecons.NullableRef" ) );
    } ) );

    void deserialize( string name, T )( JsonValue value, T* member )
        if( isNullable!( T, false ) && !typeIsJsonObject!( T, true, false ) )
    {
        ensureDeserializable!( T, name );
        *member = value.isNull ? null : value.to!T;
    }

    void deserialize( string name, T )( JsonValue value, T* member )
        if( typeIsJsonObject!( T, true, false ) )
    {
        *member = value.isNull ? null : T.fromJson( value );
    }

    void deserialize( string name, T )( JsonValue value, T* member )
        if( isNullable!( T, true ) && !isRefNullable!T )
    {
        alias TDest = Unqual!( ReturnType!( &(*member).get ) );
        ensureDeserializable!( TDest, name );

        *member = value.isNull ? T.init : T( value.to!TDest );
    }

    void deserialize( string name, T )( JsonValue value, T* member )
        if( isNullable!( T, true ) && isRefNullable!T )
    {
        alias TDest = Unqual!( ReturnType!( &(*member).get ) );
        ensureDeserializable!( TDest, name );

        TDest* ptr = void;

        if( value.isNull )
        {
            *member = T.init;
            return;
        }

        *ptr = value.to!TDest;
        *member = T( ptr );
    }

    void deserialize( string name, T )( JsonValue value, T* member )
        if( ( !isNullable!( T, true ) && !isNullable!( T, false ) ) && typeIsJsonObject!( T, true, false ) )
    {
        value.ensureNotNull!T;
        *member = T.fromJson( value );
    }

    void deserialize( string name, T )( JsonValue value, T* member )
        if( ( !isNullable!( T, true ) && !isNullable!( T, false ) ) && !typeIsJsonObject!( T, true, false ) )
    {
        ensureDeserializable!( T, name );
        value.ensureNotNull!T;
        *member = value.to!T;
    }
}

enum Required
{
    no,
    allowNull,
    disallowNull,
    always,
}

enum SerializationMode
{
    optIn,
    optOut,
}

struct JsonSerialization
{
    immutable SerializationMode mode;

    this() @disable;

    this( SerializationMode mode )
    {
        this.mode = mode;
    }
}

struct JsonIgnore { }

struct JsonProperty
{
    private string _name;
    auto name() const @property { return this._name; }

    immutable Required required;

    this( string name, Required required = Required.no )
    {
        this._name = name;
        this.required = required;
    }
}

private template Reflector( This ) if( is( This == class ) || is( This == struct ) )
{
    SerializationMode serializationMode()
    {
        static if( hasUDA!( This, JsonSerialization ) )
            return getUDAs!( This, JsonSerialization )[0].mode;
        else
            return SerializationMode.optOut;
    }

    enum isJsonIgnored( T... ) = hasUDA!( __traits( getMember, This, T[0] ), JsonIgnore );
    enum isJsonProperty( T... ) = hasUDA!( __traits( getMember, This, T[0] ), JsonProperty );

    template shouldInclude( T... )
    {
        static if( serializationMode == SerializationMode.optIn )
            enum shouldInclude = isJsonProperty!T;
        else static if( serializationMode == SerializationMode.optOut )
            enum shouldInclude = !isJsonIgnored!T;
        else
            static assert( false, "programmer forgot to implement something" );
    }

    enum isImmutable( T... ) = is( typeof( __traits( getMember, This, T[0] ) ) == immutable )
                            || is( typeof( __traits( getMember, This, T[0] ) ) == const );

    template not( alias x )
    {
        enum not( T... ) = !x!T;
    }

    JsonProperty getProperty( alias name )()
    {
        static if( isJsonProperty!name )
            return getUDAs!( __traits( getMember, This, name ), JsonProperty )[0];
        else
            static assert( false, "'%s' is not a json property".formaT( name ) );
    }

    string fieldName( alias name )()
    {
        static if( isJsonProperty!name )
        {
            enum prop = getProperty!name;
            return prop.name !is null && prop.name.length ? prop.name : name;
        }
        else return name;
    }

    Required getRequirement( alias name )()
    {
        static if( isJsonProperty!name )
            return getProperty!( name ).required;
        else
            return Required.no;
    }

    static if( ( FieldNameTuple!This ).length )
        enum members = Filter!( not!isImmutable, Filter!( shouldInclude, FieldNameTuple!This ) );
    else
        enum members = AliasSeq!();
}

mixin template JsonObject()
{
    static assert(
        is( typeof( this ) == class ) || is( typeof( this ) == struct ),
        "JsonObject template can only be mixed in to a class or struct"
    );

    T toJsonString( T = string )( bool indented = false ) if( isSomeString!T )
    {
        return this.toJson().toJsonString( indented );
    }

    JsonValue toJson()
    {
        alias This = typeof( this );
        alias reflector = Reflector!This;

        void ensureConversion( T, string name )()
        {
            enum canConvert = is( typeof( {
                auto _ = JsonValue( T.init );
            } ) );

            static assert(
                canConvert,
                "cannot convert from type %s for field %s".format( T.stringof, name )
            );
        }

        auto json = JsonValue.newObject();

        foreach( i, name; reflector.members )
        {
            enum field = reflector.fieldName!name;
            alias type = typeof( __traits( getMember, this, name ) );

            try
            {
                static if( isNullable!type )
                {
                    static if( is( typeof( { type _ = null; } ) ) && !typeIsJsonObject!type )
                    {
                        ensureConversion!( type, name );
                        mixin( "json[\"%s\"] = this.%s.isNull ? jnull : JsonValue( this );".format( field, name ) );
                    }
                    else static if( typeIsJsonObject!( type, true ) )
                        mixin( "json[\"%s\"] = this.%2$s.isNull ? jnull : this.%2$s.toJson();".format( field, name ) );
                    else // field is Nullable!T or NullableRef!T
                    {
                        alias dest = Unqual!( typeof( __traits( getMember, mixin( "instance." ~ name ), "get" ) ) );
                        ensureConversion!( dest, name );

                        static if( !isRef!type )
                            mixin( "instance.%s = value.isNull ? type.init : type( value.to!dest );".format( name ) );
                        else
                        {
                            dest* ptr = value.isNull ? null : new dest( value.to!dest );
                            mixin( "instance.%s = value.isNull ? type.init : type( ptr );".format( name ) );
                        }
                    }
                }
                else // field is not nullable
                {
                    if( value.isNull )
                        throw new JsonException( "cannot convert null to %s".format( type.stringof ) );

                    static if( typeIsJsonObject!( type, true ) )
                        mixin( "instanse.%s = type.fromJson( value );".format( name ) );
                    else
                    {
                        ensureConversion!( type, name );
                        mixin( "instance.%s = value.to!type;".format( name ) );
                    }
                }
            }
            catch( JsonException ex )
            {
                throw new JsonException(
                    "error deserializing field '%s': %s".format( field, ex.msg ),
                    __FILE__,
                    __LINE__,
                    ex
                );
            }
        }

        return json;
    }

    static typeof( this ) fromJson( S )( S str ) if( isSomeString!S )
    {
        auto json = str.parseJson();
        return fromJson( json );
    }

    static typeof( this ) fromJson( JsonValue json )
    {
        if( !json.isObject )
            throw new JsonException( "JSON value is not an object" );

        alias This = typeof( this );
        alias reflector = Reflector!This;

        auto instance = {
            static if( is( This == struct ) )
                return This();
            else static if( is( This == class ) )
                return new This();
            else
                static assert( false, "programmer messed up template constraints" );
        }();

        foreach( i, name; reflector.members )
        {
            enum field = reflector.fieldName!name;
            enum required = reflector.getRequirement!name;
            alias type = typeof( __traits( getMember, instance, name ) );

            immutable exists = json.hasKey( field );

            if( !exists && ( required == Required.always || required == Required.allowNull ) )
                throw new JsonException( "missing required field '%s'".format( field ) );

            if( !exists ) continue;

            auto value = json[field];
            if( value.isNull && ( required == Required.always || required == Required.disallowNull ) )
                throw new JsonException( "value for '%s' cannot be null".format( field ) );

            try
            {
                type* member = &__traits( getMember, instance, name );
                value.deserialize!( field )( member );
            }
            catch( JsonException ex )
            {
                throw new JsonException(
                    "error deserializing field '%s': %s".format( field, ex.msg ),
                    __FILE__,
                    __LINE__,
                    ex
                );
            }
        }

        return instance;
    }
}

version( unittest )
{
    private class Invalid { }

    @JsonSerialization( SerializationMode.optIn )
    private struct Person
    {
        private {
            @JsonProperty( "first_name", Required.always )
            string _first;

            @JsonProperty( "last_name", Required.always )
            string _last;

            @JsonProperty( "age", Required.always )
            ubyte _age;

            @JsonIgnore
            Invalid _invalid;
        }

        string firstName() @property { return _first; }
        string lastName() @property { return _last; }
        ubyte age() @property { return _age; }

        mixin JsonObject;
    }
}

unittest
{
    auto text = q{{
        "first_name": "John",
        "last_name": "Doe",
        "age": 35
    }};

    auto john = Person.fromJson( text );

    assert( john.firstName == "John" );
    assert( john.lastName == "Doe" );
    assert( john.age == 35 );
}
