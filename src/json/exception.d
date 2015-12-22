module json.exception;

private import json.parser.token;

class JsonException : Exception
{
    package this( string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super( msg, file, line, next );
    }
}

final class JsonParserException : JsonException
{
    private TextSpan _span;
    TextSpan span() const @property
    {
        return this._span;
    }

package:
    this( TextSpan span, string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        this._span = span;
        super( msg, file, line, next );
    }

    this( JsonToken token, string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        this._span = token.span;
        super( msg, file, line, next );
    }
}
