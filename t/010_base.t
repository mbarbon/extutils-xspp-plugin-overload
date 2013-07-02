#!/usr/bin/perl -w

use strict;
use warnings;
use t::lib::XSP::Test tests => 3;

run_diff xsp_stdout => 'expected';

__DATA__

=== Type ordering
--- xsp_stdout
%module{Foo};

%loadplugin{Overload};

class Foo %catch{nothing}
{
    int foo(char *test) %Overload;
    int foo() %Overload;
    int foo(int i) %Overload;
};
--- expected
#include <exception>


MODULE=Foo

MODULE=Foo PACKAGE=Foo

int
Foo::foo2( char* test )
  CODE:
    try {
      RETVAL = THIS->foo( test );
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

int
Foo::foo0()
  CODE:
    try {
      RETVAL = THIS->foo();
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

int
Foo::foo1( int i )
  CODE:
    try {
      RETVAL = THIS->foo( i );
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

#if 1
void
Foo::foo(...)
  PPCODE:
    static Xsp::Plugin::Overload::Prototype void_proto(NULL, 0);
    static const char *foo1_types[] = { XspPluginOverloadNumber };
    static Xsp::Plugin::Overload::Prototype foo1_proto(foo1_types, sizeof(foo1_types) / sizeof(foo1_types[0]));
    static const char *foo2_types[] = { XspPluginOverloadString };
    static Xsp::Plugin::Overload::Prototype foo2_proto(foo2_types, sizeof(foo2_types) / sizeof(foo2_types[0]));
    static Xsp::Plugin::Overload::Prototype *all_prototypes[] = {
        &void_proto,
        &foo1_proto,
        &foo2_proto,
        NULL };
    XSP_PLUGIN_OVERLOAD_BEGIN()
        XSP_PLUGIN_OVERLOAD_MATCH_VOID(foo0)
        XSP_PLUGIN_OVERLOAD_MATCH_EXACT(foo1_proto, foo1, 1)
        XSP_PLUGIN_OVERLOAD_MATCH_EXACT(foo2_proto, foo2, 1)
    XSP_PLUGIN_OVERLOAD_MESSAGE(Foo::foo, all_prototypes)



#endif // 1

=== Parameter count ordering
--- xsp_stdout
%module{Foo};

%loadplugin{Overload};

class Foo %catch{nothing}
{
    int foo(int i, double j) %Overload;
    int foo() %Overload;
    int foo(int i) %Overload;
};
--- expected
#include <exception>


MODULE=Foo

MODULE=Foo PACKAGE=Foo

int
Foo::foo2( int i, double j )
  CODE:
    try {
      RETVAL = THIS->foo( i, j );
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

int
Foo::foo0()
  CODE:
    try {
      RETVAL = THIS->foo();
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

int
Foo::foo1( int i )
  CODE:
    try {
      RETVAL = THIS->foo( i );
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

#if 1
void
Foo::foo(...)
  PPCODE:
    static Xsp::Plugin::Overload::Prototype void_proto(NULL, 0);
    static const char *foo1_types[] = { XspPluginOverloadNumber };
    static Xsp::Plugin::Overload::Prototype foo1_proto(foo1_types, sizeof(foo1_types) / sizeof(foo1_types[0]));
    static const char *foo2_types[] = { XspPluginOverloadNumber, XspPluginOverloadNumber };
    static Xsp::Plugin::Overload::Prototype foo2_proto(foo2_types, sizeof(foo2_types) / sizeof(foo2_types[0]));
    static Xsp::Plugin::Overload::Prototype *all_prototypes[] = {
        &void_proto,
        &foo1_proto,
        &foo2_proto,
        NULL };
    XSP_PLUGIN_OVERLOAD_BEGIN()
        XSP_PLUGIN_OVERLOAD_MATCH_VOID(foo0)
        XSP_PLUGIN_OVERLOAD_MATCH_EXACT(foo1_proto, foo1, 1)
        XSP_PLUGIN_OVERLOAD_MATCH_EXACT(foo2_proto, foo2, 2)
    XSP_PLUGIN_OVERLOAD_MESSAGE(Foo::foo, all_prototypes)



#endif // 1

=== Devault parameters
--- xsp_stdout
%module{Foo};

%loadplugin{Overload};

class Foo %catch{nothing}
{
    int foo() %Overload;
    int foo(int i, bool j = false) %Overload;
};
--- expected
#include <exception>


MODULE=Foo

MODULE=Foo PACKAGE=Foo

int
Foo::foo0()
  CODE:
    try {
      RETVAL = THIS->foo();
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

int
Foo::foo1( int i, bool j = false )
  CODE:
    try {
      RETVAL = THIS->foo( i, j );
    }
    catch (...) {
      croak("Caught C++ exception of unknown type");
    }
  OUTPUT: RETVAL

#if 1
void
Foo::foo(...)
  PPCODE:
    static Xsp::Plugin::Overload::Prototype void_proto(NULL, 0);
    static const char *foo1_types[] = { XspPluginOverloadNumber, XspPluginOverloadBool };
    static Xsp::Plugin::Overload::Prototype foo1_proto(foo1_types, sizeof(foo1_types) / sizeof(foo1_types[0]));
    static Xsp::Plugin::Overload::Prototype *all_prototypes[] = {
        &void_proto,
        &foo1_proto,
        NULL };
    XSP_PLUGIN_OVERLOAD_BEGIN()
        XSP_PLUGIN_OVERLOAD_MATCH_VOID(foo0)
        XSP_PLUGIN_OVERLOAD_MATCH_MORE(foo1_proto, foo1, 1)
    XSP_PLUGIN_OVERLOAD_MESSAGE(Foo::foo, all_prototypes)



#endif // 1
