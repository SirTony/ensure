# ensure

Fluent guards to aid in ensuring the correctness of function/method arguments. Inspired by the lovely [Ensure.That](https://github.com/danielwertheim/Ensure.That) library for C#.

# Example

```d
import std.string : chop;
import std.stdio : write, writefln, stdin;

import ensure;

void greet( string name )
{
    // String cannot be null, zero-length, or consist entirely of whitespace characters.
    ensure!name.isNotNull.isNotEmpty.isNotWhitespace;

    writefln( "Hello, %s!", name );
}

void main()
{
    write( "What is your name? " );
    auto name = stdin.readln().chop();
    greet( name );
}
```

# Get it

It's on dub: https://code.dlang.org/packages/ensure

# Extending

ensure is easily extensible using UFCS and templated functions, in fact all built-in validators use this. Take the `isNotNull` validator as an example:

```d
Arg!T isNotNull( T )( Arg!T arg ) if( isNullable!T )
{
    if( arg.value is null )
        arg.throwWith( "argument cannot be null" );

    return arg;
}
```

That's really all it takes! `isNullable` is a private template used to determine if `T` can even be null, so `isNotNull` won't compile if `T` is something that can't be null, like `int`.

Writing your own validator is similarly simple:

```d
import std.traits : isIntegral;
import std.format : format;

import ensure;

// template function lets this be called on any valid type (as per the template guard)
// however it's also possible to use concrete types
// ex: Arg!int someValidator( Arg!int arg )
// {
//     ...
// }
Arg!N isTheAnswerToEverything( N )( Arg!N arg ) if( isIntegral!N ) // only for integer numbers
{
    // access the argument's value.
    // if needed, the name can also be accessed with arg.paramName
    if( arg.value != 42 )
        // throw a new EnsureException with a custom message when validation fails.
        arg.throwWith( "%s is not the answer to everything".format( arg.value ) );
    
    // return arg when we're done with it so successful calls can be chained as above in the greet example.
    return arg;
}
```