module json.jsonexception;

public class JsonException : Exception
{
    package this( string msg, Throwable inner = null, string file = __FILE__, size_t line = __LINE__ )
    {
        super( msg, file, line, inner );
    }
}

final public class JsonParserException : JsonException
{
    private int _line;
    private int _column;
    private string _fileName;

    public int line() @property
    {
        return this._line;
    }

    public int column() @property
    {
        return this._column;
    }

    public string fileName() @property
    {
        return this._fileName;
    }

    package this( string msg, int line, int column, string file, Throwable inner = null, string dfile = __FILE__, size_t dline = __LINE__ )
    {
        super( msg, inner, dfile, dline );
    }
}