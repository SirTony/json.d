What is it?
===========

JSON.d is an alternative to the JSON parser in D's standard library, containing its own parser and using the Variant type from the standard library to store values instead of shipping its own types. JSON.d is implemented entirely in the D programming language.

Why?
====

JSON.d was born of a desire to have a small, lightweight JSON parser with a more simplistic API in order to make using it feel more streamlined.

Getting started
===============

Even though it isn't in the package registry yet, JSON.d uses the [DUB package manager](http://code.dlang.org/download) for building. If you don't already have it, head over to the provided link and install it.

The first step is to get the source code, in order to do that, clone the repository by running the following command:

    $ git clone https://github.com/Syke94/json.d.git ./json.d

Once the repository has finished cloning, run the following command to build the library:

    $ dub build --build=release

That will build the library in release mode, and the resulting binary will be located in `json.d/bin/`.

Things to note
==============

JSON.d is tested on Windows with the DMD compiler, version 2.066. Other D compilers such as LDC, SDC, and GDC are not officially supported, but should still work as long as the compiler supports [DIP37](http://wiki.dlang.org/DIP37) (importing `package.d` files). JSON.d is also not officially supported on Linux or OS X, but should still work as intended.