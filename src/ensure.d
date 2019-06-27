/**
Provides some convenience functionality for parsing command-line arguments by piggy-backing off std.getopt.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
*/
module ensure;

import std.traits;
import std.range : isInputRange, hasLength;
import std.format : format;

private enum isValidRangeSpecifier( string spec ) =
    spec !is null &&
    spec.length == 2 &&
    ( spec[0] == '(' || spec[0] == '[' ) &&
    ( spec[1] == ')' || spec[1] == ']' );

private enum supportsOperation( T, string op ) =
    is( typeof( { bool _ = mixin( "T.init " ~ op ~ " T.init" ); } ) );

/++
A convenience wrapper for __traits( identifier, ... ).

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
enum nameof( alias symbol ) = __traits( identifier, symbol );

@system unittest
{
    struct Foo
    {
        int x;
    }

    int a;
    Foo b;

    // test locals
    assert( nameof!a == "a" );

    // test members
    assert( nameof!( b.x ) == "x" );

    // test types
    assert( nameof!Foo == "Foo" );

    // test modules
    assert( nameof!ensure == "ensure" );
}

/++
Tests if a type can null. Not related to std.typecons.Nullable!T.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
enum isNullable( T ) = is( typeof( { Unqual!T _ = null; } ) );

@system unittest
{
    assert( isNullable!string );
    assert( !isNullable!int );
}

/++
Thrown for any validation errors.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
final class EnsureException : Exception
{
    private string _paramName;

    string paramName() const pure nothrow @trusted @property
    {
        return this._paramName;
    }

    this( string paramName, string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        this._paramName = paramName;
        auto newMsg = paramName is null || paramName.length == 0 ? msg : "%s: %s".format( paramName, msg );
        super( newMsg, file, line, next );
    }
}

/++
Represents a single function parameter, including name and value, upon which all validation is performed.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
struct Arg( T )
{
    private {
        string _paramName;
        T _value;
    }

    string paramName() const pure nothrow @trusted @property
    {
        return this._paramName;
    }

    T value() const pure nothrow @trusted @property
    {
        return this._value;
    }

    /// Default construction is not allowed.
    this() @disable;

    private this( string paramName, T value )
    {
        this._paramName = paramName;
        this._value = value;
    }

    /++
    Throws an EnsureException for the current parameter with the given message.

    Params:
        msg = The message to pass to the exception's constructor.
        file = Used for passing the appropriate file name to the exception's constructor.
        line = Used for passing the appropriate line number to the exception's constructor.

    Throws: EnsureException whenever it's called.
    Authors: Tony J. Hudgins
    Copyright: Copyright © 2019, Tony J. Hudgins
    License: MIT
    +/
    void throwWith( string msg, string file = __FILE__, size_t line = __LINE__ ) const @trusted
    {
        throw new EnsureException( this._paramName, msg, file, line );
    }
}

/++
Wrap a function argument to perform validation.

Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
Arg!( typeof( what ) ) ensure( alias what )()
{
    return Arg!( typeof( what ) )( nameof!what, what );
}

/++
Ensures that the argument is not null.

Params:
    arg = A wrapped argument, obtained with ensure.

See_Also: ensure
Throws: EnsureException when validation fails.
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
Arg!T isNotNull( T )( Arg!T arg ) //if( isNullable!T )
{
    if( arg.value is null )
        arg.throwWith( "argument cannot be null" );

    return arg;
}

/++
Ensures that an array is not empty.

Params:
    arg = A wrapped argument, obtained with ensure.

See_Also: ensure
Throws: EnsureException when validation fails.
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
Arg!T isNotEmpty( T )( Arg!T arg ) if( isArray!T )
{
    static if( isSomeString!T )
        enum kind = "string";
    else static if( isAssociativeArray!T )
        enum kind = "associative array";
    else
        enum kind = "array";

    if( arg.value.length == 0 )
        arg.throwWith( kind ~ " cannot be empty" );

    return arg;
}

/++
Ensures that a range is not empty.

Params:
    arg = A wrapped argument, obtained with ensure.

See_Also: ensure
Throws: EnsureException when validation fails.
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
Arg!T isNotEmpty( T )( Arg!T arg ) if( !isArray!T && isInputRange!T )
{
    if( arg.value.empty )
        arg.throwWith( "range cannot be empty" );

    return arg;
}

/++
Ensures that a string does not contain only whitespace characters.

Params:
    arg = A wrapped argument, obtained with ensure.

See_Also: ensure
Throws: EnsureException when validation fails.
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
Arg!S isNotWhitespace( S )( Arg!S arg ) if( isSomeString!S )
{
    import std.algorithm : all;
    import std.uni : isWhite;

    if( arg.isNotNull.value.all!isWhite )
        arg.throwWith( "string cannot consist of only whitespace characters" );

    return arg;
}

/++
Ensures that a number is between an upper bound and a lower bound.

By default, this function's bounds are **inclusive**, inclusivity/exclusivity can be changed
on a per-bound basis by passing in a string template argument similar to std.random.uniform.

The string template parameter expects a 2-character long string consisting of an
opening parenthesis or opening square bracket, followed by a closing parenthesis or closing square bracket.
The opening bracket is for the lower bound, while the closing bracket is for the upper bound.
Parenteses indicate that the boundary is inclusive, and square brackets indicate the boundary is exclusive.

All possible combinations:

- **()** - Both lower bound and upper bound are inclusive.
- **(]** - Lower bound is inclusive and upper bound is exclusive.
- **[)** - Lower bound is exclusive and upper bound is inclusive.
- **[]** - Both lower bound and upper bound are exclusive.

Params:
    arg = A wrapped argument, obtained with ensure.

Examples:
---------
const zero = 0;
const five = 5;

ensure!(zero).between!"[)"( 0, 5 ); // exception, lower bound is exclusive
---------

See_Also: ensure
Throws: EnsureException when validation fails.
Authors: Tony J. Hudgins
Copyright: Copyright © 2019, Tony J. Hudgins
License: MIT
+/
Arg!N between( string how = "()", N )( Arg!N arg, N lowerBound, N upperBound )
    if( isNumeric!N && isValidRangeSpecifier!how )
{
    enum lowerOp = how[0] == '(' ? "<" : "<=";
    enum upperOp = how[1] == ')' ? ">" : ">=";

    static enum Bound { lower, upper }

    string err( Bound bound, bool inclusive, N value )
    {
        import std.array : appender;

        auto msg = appender!string;
        msg.put( "argument (%s) is ".format( arg.value ) );

        with( Bound )
        final switch( bound )
        {
            case lower:
                msg.put( "less than " );
                break;

            case upper:
                msg.put( "greater than " );
                break;
        }

        if( !inclusive )
            msg.put( "or equal to " );

        msg.put( "the " );

        with( Bound )
        final switch( bound )
        {
            case lower:
                msg.put( "lower " );
                break;

            case upper:
                msg.put( "upper " );
                break;
        }

        msg.put( "bound (%s)".format( value ) );

        return msg.data;
    }

    if( mixin( "arg.value" ~ lowerOp ~ "lowerBound" ) )
        arg.throwWith( err( Bound.lower, how[0] == '(', lowerBound ) );

    if( mixin( "arg.value" ~ upperOp ~ "upperBound" ) )
        arg.throwWith( err( Bound.upper, how[1] == ')', upperBound ) );

    return arg;
}

// auto-generate some functions for common boolean operations.
private static immutable ops = [
    ">": [ "greaterThan", "gt" ],
    ">=": [ "greaterThanOrEqualTo", "gte" ],

    "<": [ "lessThan", "lt" ],
    "<=": [ "lessThanOrEqualTo", "lte" ],

    "==": [ "equalTo", "eq" ],
    "!=": [ "notEqualTo", "ne", "neq" ],
];

static foreach( op, names; ops )
static foreach( name; names )
{
    mixin( `
        Arg!T %01$s( T )( Arg!T arg, T value ) if( supportsOperation!( T, "%02$s" ) )
        {
            if( !( arg.value %02$s value ) )
                arg.throwWith(
                    "argument (%%01$s) does not match expression (%%01$s %02$s %%02$s)"
                    .format( arg.value, value )
                );

            return arg;
        }
    `.format( name, op ) );
}
