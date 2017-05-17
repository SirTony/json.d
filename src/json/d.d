module json.d;

public {
    import json.parser : parseJson;
    import json.value;
}

unittest
{
    import std.algorithm;

    auto text = q{{
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
    }};

    auto json = text.parseJson();
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
