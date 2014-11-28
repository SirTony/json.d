module json.parser.token;

private import std.string;

package enum TokenType
{
    string,
    identifier,
    null_,
    boolean,
    number,
    colon,
    comma,
    leftSquare,
    rightSquare,
    leftBrace,
    rightBrace,
    eof
}

package string identify( TokenType type )
{
    string name;

    final switch( type )
    {
        case TokenType.string:
            name = "string";
            break;

        case TokenType.identifier:
            name = "identifier";
            break;

        case TokenType.null_:
            name = "null";
            break;

        case TokenType.number:
            name = "number";
            break;

        case TokenType.colon:
            name = "colon";
            break;

        case TokenType.comma:
            name = "comma";
            break;

        case TokenType.leftSquare:
            name = "lsquare";
            break;

        case TokenType.rightSquare:
            name = "rsquare";
            break;

        case TokenType.leftBrace:
            name = "lbrace";
            break;

        case TokenType.rightBrace:
            name = "rbrace";
            break;

        case TokenType.boolean:
            name = "boolean";
            break;

        case TokenType.eof:
            return "EOF";
    }

    return "T_" ~ name.toUpper();
}

final package struct Token
{
    private dstring _contents;
    private string _fileName;
    private int _line;
    private int _column;
    private TokenType _type;

    public dstring contents() @property
    {
        return this._contents;
    }

    public string fileName() @property
    {
        return this._fileName;
    }

    public int line() @property
    {
        return this._line;
    }

    public int column() @property
    {
        return this._column;
    }

    public TokenType type() @property
    {
        return this._type;
    }

    public this() @disable;

    public this( TokenType type, dstring contents, int line, int column, string fileName = null )
    {
        this._type = type;
        this._contents = contents;
        this._fileName = fileName;
        this._line = line;
        this._column = column;
    }
}