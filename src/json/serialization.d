module json.serialization;

private{
    import json.parser : parseJson;
    import json.value;

    import std.meta;
    import std.string;
    import std.traits;
    import std.typecons;
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

    enum members = Filter!( not!isImmutable, Filter!( shouldInclude, FieldNameTuple!This ) );
}

private enum isNullable( T ) =
    is( typeof( { T _ = null; } ) ) ||
    is( typeof( {
        import std.algorithm.searching : startsWith;

        enum name = fullyQualifiedName!( Unqual!T );
        static assert( name.startsWith( "std.typecons.Nullable" ) );
    } ) );

private enum typeIsJsonObject( T ) = is( typeof( {
        T.fromJson( JsonValue.init );
        //JsonValue _ = T.init.toJson();
    } ) );

private enum isRef( T ) = is( typeof( {
        import std.algorithm.searching : startsWith;

        enum name = fullyQualifiedName!( Unqual!T );
        static assert( name.startsWith( "std.typecons.NullableRef" ) );
    } ) );

mixin template JsonObject()
{
    static assert(
        is( typeof( this ) == class ) || is( typeof( this ) == struct ),
        "JsonObject template can only be mixed in to a class or struct"
    );

version( none )
{
    T toJsonString( T = string )( bool indented = false ) if( traits.isSomeString!T )
    {
        return this.toJson().toJsonString( indented );
    }

    JsonValue toJson()
    {
        alias This = typeof( this );
        alias reflector = Reflector!This;

        auto json = JsonValue.newObject();

        foreach( i, name; reflector.members )
        {
            enum field = reflector.fieldName!name;
            alias type = typeof( __traits( getMember, this, name ) );
        }

        return json;
    }
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
                static if( isNullable!type )
                {
                    static if( is( typeof( { type _ = null; } ) ) && !typeIsJsonObject!type )
                        mixin( "instance.%s = value.isNull ? null : value.to!type;".format( name ) );
                    else static if( typeIsJsonObject!type )
                        mixin( "instance.%s = value.isNull ? null : type.fromJson( value );".format( name ) );
                    else // field is Nullable!T or NullableRef!T
                    {
                        alias dest = Unqual!( typeof( __traits( getMember, mixin( "instance." ~ name ), "get" ) ) );

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

                    static if( typeIsJsonObject!type )
                        mixin( "instanse.%s = type.fromJson( value );".format( name ) );
                    else
                        mixin( "instance.%s = value.to!type;".format( name ) );
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

        return instance;
    }
}

version( unittest )
{
    @JsonSerialization( SerializationMode.optOut )
    private struct Person
    {
        private {
            @JsonProperty( "first_name" )
            string _first;

            @JsonProperty( "last_name", Required.allowNull )
            string _last;

            @JsonProperty( "age", Required.allowNull )
            Nullable!ubyte _age;

            //@JsonIgnore
            int _optedOut = 5;
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
    import std.stdio;

    writeln( john );
}
