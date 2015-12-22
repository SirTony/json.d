What is it?
===========

JSON.d is an alternative to phobos' (D's standard library) built-in JSON module that contains its own value type and its own parser that adheres to the JSON standard as specified at http://www.json.org/.

Why?
====

Phobos' JSON module leaves much to be desired; it can sometimes be tedious to work with and can overcomplicate the manipulation of even simple JSON objects. This is partly due to the inherent challenges associated with mapping an implicitly typed structure to a statically typed language, and partly due to phobos' implementation being more simplistic and not leveraging the full capabilities of the language.

JSON.d aims to provide an implementation that's as easy as possible to work with, making it feel as natural as possible to read and manipulate JSON documents.

Features
========

JSON.d is still young, and as such **it is prerelease software**, so please keep in mind functionality is limited for now and it is not bug-free.

- [x] Parsing JSON string to object structure.
- [x] Writing object structure back to JSON.

### Planned Features

- [ ] Validating JSON documents against schemas
- [ ] Validating JSON documents against a custom, [TypeScript](http://www.typescriptlang.org/) inspired [DSL](https://en.wikipedia.org/wiki/Domain-specific_language).
  - [ ] Generating valid schemas from the DSL.
- [ ] Deserializing JSON to objects (similar to [Json.NET](http://www.newtonsoft.com/json))

Getting started
===============

### With dub

JSON.d is available in the [dub package repository](http://code.dlang.org/packages/json).

### Building from source

Since JSON.d uses dub, building from source on any platform is dead-simple.

First clone the repository:

    $ git clone https://github.com/SirTony/json.d.git ./json.d

Then compile the library:

    $ cd json.d
    $ dub build --build=release

Compiled binaries will be located in the `bin` directory.

### Example

``` javascript
// store.json
{
    "products": [
        {
            "id":    1,
            "name":  "Door hinge",
            "price": 0.75,
            "tags":  [ "home improvement", "hardware" ]
        },
        {
            "id":    2,
            "name":  "Box of screws",
            "price": 3.50,
            "tags":  [ "hardware", "tools" ]
        }
    ]
}
```

``` d
// store.d

import std.file;
import std.stdio;

import json.d;

void main()
{
    auto json = readText( "store.json" );
    auto store = json.parseJson();

    foreach( product; store["products"] )
        writefln( "%s: $%g", product["name"], product["price"] );
}
```

Things to note
==============

JSON.d is tested on Windows with the DMD compiler, version 2.068. Other D compilers such as LDC, SDC, and GDC are not officially supported, but should still work.

License
=======

```
The MIT License (MIT)

Copyright © 2015 Tony Hudgins

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
