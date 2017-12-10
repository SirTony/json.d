module json.d;

public {
    import json.parser : parseJson;
    import json.parser.lexer : StandardCompliant;
    import json.value;
}

// test standard-compliant JSON parsing
@system unittest
{
    import std.algorithm;

    immutable text = `{
        "firstName": "John",
        "lastName": "Doe",
        "age": 35,

        "phoneNumbers": [
            "605-555-1234"
        ],

        "transactions": [
            123.4,
            -500,
            -1e5,
            2e+5,
            2E-5,
            2.5E2,
            75
        ]
    }`;

    immutable json = text.parseJson();
    assert( json.isObject );
    assert( json["firstName"].isString && json["lastName"].isString );
    assert( json["age"].isUnsigned );
    assert( json["phoneNumbers"].isArray );
    assert( json["transactions"].all!( x => x.isNumber ) );

    JsonValue default_;
    assert( default_.isNull );

    JsonValue true_ = true;
    JsonValue false_ = false;

    assert( true_ );
    assert( !false_ );
}

// test non-standard parsing
@system unittest
{
    immutable text = `{
        unquoted: 'single-quoted string', // trailling comma

        /* multi-line comment
            /* with another one nested inside */
        */}`;

    immutable json = text.parseJson( StandardCompliant.no );

    assert( json.isObject );
    assert( json["unquoted"].isString && json["unquoted"] == "single-quoted string" );
}
