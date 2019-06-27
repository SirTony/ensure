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