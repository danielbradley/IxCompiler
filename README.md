
## Introduction

Here is documented the implementation of the Ix Compiler,
which translates between the Ix programming language and target languages.
Initialy, the first language to be targeted will be C,
but later the intention is to target C++, C#, Java, and Swift.

Ix is an object oriented programming language meaning the language supports:

*   classes, which can be instantiated into objects
*   single inheritance of parent classes
*   multiple implementation of interfaces
*   dynamic dispatch similar to Java

Philosophically, Ix can be considered an evolution of Stroustrup's original C with Classes concept
as the language will not include any features that cannot be implemented in C.
However, the language itself is heavily influenced by C++ and Java.

Similar to Java, source files are located within a source directory,
however,
in contrast to Java,
a namespace/package of a source file is determined by the dotted notation name
of the folder it is contained within.
Also the name of a class is determined by the name of its source file -
not specified _within_ the source file like most (?all?) other languages.
For example, the following source file is contained within the 'ix.base.' namespace,
and the class name will be 'StringBuffer'.

See: [ixlang.org](https://ixlang.org) for more details.

```
Example file path: source/ix/ix.base/StringBuffer.ix
```

```
public class extends Object implements Interface
{
    @data: char[]

    %count: int
}

public new()
{
    @data[] = new char[]
    #count++
}

public append( aString: string& )
{
    foreach( character in aString )
    {
        @data[] = character;
    }
}

public append( aString: string* )
{
    foreach( character in aString )
    {
        @data[] = character;
    }
    // aString is implicitly destroyed at end of method.
}
```

The language has the following characteristics:

*   Instance and class members are declared/defined within a class block.
*   Classes must indicate their visibility via public, private, etc.
*   Methods are defined with the same source file and below the class definition.
*   Methods must indicate their visibility via public, private, etc.
*   Similar to C++, an asterisk denotes a pointer and an ampersand denotes a reference.
*   When a pointer is passed, the caller losses access to that pointer (it is made null).
*   Memory is managed by deleting any non-null pointers.

## Design
## Implementation

```
ixc --output-dir _gen/c --target-language C [--dry-run]
```

```!c/main.c
//
//  Copyright 2021 Daniel Robert Bradley
//

#include <stdlib.h>
#include <stdio.h>

#include "ixcompiler.h"
#include "ixcompiler.Arguments.h"
#include "ixcompiler.AST.h"
#include "ixcompiler.ASTCollection.h"
#include "ixcompiler.ASTPrinter.h"
#include "ixcompiler.Generator.h"
#include "ixcompiler.IxParser.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.IxSourceUnitCollection.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.Tokenizer.h"
#include "todo.h"

int main( int argc, char** argv )
{
    int            status      = 1;
    Arguments*     args        = Arguments_new          ( argc, argv );
    bool           dry_run     = Arguments_hasFlag      ( args, ARGUMENT_DRY_RUN );
    const char*    target_lang = Arguments_getOption    ( args, ARGUMENT_TARGET_LANGUAGE );
    const char*    output_dir  = Arguments_getOption    ( args, ARGUMENT_OUTPUT_DIR );
    FilesIterator* files       = Arguments_filesIterator( args );
    Path*          output_path = Path_new               ( output_dir );
    GeneratorFn    generator   = Generator_FunctionFor  ( target_lang );


    if ( !Arguments_hasFlag( args, ARGUMENT_OUTPUT_DIR ) )
    {
        Console_Write( ABORT_NO_OUTPUT_DIR, "" );
        exit( -1 );
    }
    else
    if ( !Arguments_hasFlag( args, ARGUMENT_TARGET_LANGUAGE ) )
    {
        Console_Write( ABORT_TARGET_LANGUAGE_NOT_SPECIFIED, "" );
        exit( -1 );
    }
    else
    if ( !Path_exists( output_path ) )
    {
        Console_Write( ABORT_DIRECTORY_DOES_NOT_EXIST, output_dir );
        exit( -1 );
    }
    else
    if ( !Path_canWrite( output_path ) )
    {
        Console_Write( ABORT_DIRECTORY_IS_NOT_WRITABLE, output_dir );
        exit( -1 );
    }
    else
    if ( !generator )
    {
        Console_Write( ABORT_TARGET_LANGUAGE_NOT_SUPPORTED, target_lang );
        exit( -1 );
    }
    else
    if ( !FilesIterator_hasNext( files ) )
    {
        Console_Write( ABORT_NO_SOURCE_FILES, "" );
        exit( -1 );
    }
    else
    {
        ASTCollection*          ast_collection = ASTCollection_new();
        IxSourceUnitCollection* source_units   = IxSourceUnitCollection_new();

        while ( FilesIterator_hasNext( files ) )
        {
            File* file = FilesIterator_next( files );

            if ( !File_exists( file ) )
            {
                Console_Write( ABORT_FILE_DOES_NOT_EXIST, File_getFilePath( file ) );
                exit( -1 );
            }
            else
            if ( !File_canRead( file ) )
            {
                Console_Write( ABORT_FILE_CANNOT_BE_READ, File_getFilePath( file ) );
                exit( -1 );
            }
            else
            {
                Tokenizer* t = Tokenizer_new( &file );
                if ( FALSE )
                {
                    Tokenizer_printAll( t );
                    Tokenizer_free( &t );
                }
                else
                {
                    AST* ast = AST_new( &t );
                    ASTPrinter_Print( ast );
                    ASTCollection_add( ast_collection, &ast );
                }
            }
        }

        int n = ASTCollection_getLength( ast_collection );

        for ( int i=0; i < n; i++ )
        {
            const AST* ast = ASTCollection_get( ast_collection, i );

            IxSourceUnit* source_unit = IxSourceUnit_new( ast );

            IxSourceUnitCollection_add( source_units, &source_unit );
        }

        if ( FALSE )//!dry_run )
        {

            if ( generator )
            {
                status = generator( source_units, output_path );
            }
        }

        ASTCollection_free         ( &ast_collection );
        IxSourceUnitCollection_free( &source_units   );
    }

    Arguments_free    ( &args        );
    FilesIterator_free( &files       );
    Path_free         ( &output_path );

    return !status;
}
```

### Tokenizer

```!include/ixcompiler.Tokenizer.h
#ifndef IXCOMPILER_TOKENIZER_H
#define IXCOMPILER_TOKENIZER_H

#include "ix.h"
#include "ixcompiler.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"

Tokenizer* Tokenizer_new          ( File**      file );

Tokenizer*     Tokenizer_free          (       Tokenizer** self );
Token*         Tokenizer_nextToken     (       Tokenizer*  self );
const Token*   Tokenizer_peekToken     (       Tokenizer*  self );
EnumTokenGroup Tokenizer_peekTokenGroup(       Tokenizer*  self );
EnumTokenType  Tokenizer_peekTokenType (       Tokenizer*  self );
void           Tokenizer_printAll      (       Tokenizer*  self );
bool           Tokenizer_hasMoreTokens ( const Tokenizer*  self );
const File*    Tokenizer_getFile       ( const Tokenizer*  self );

#endif
```


```!c/ixcompiler.Tokenizer.c
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"
#include "ixcompiler.Tokenizer.h"

struct _Tokenizer
{
    EnumTokenType   lastType;
    bool            ignoreUntilNewline;
    File*           file;
    PushbackReader* reader;
    Queue*          queue;
};

static void primeQueue( Tokenizer* self );
static Token*     next( Tokenizer* self );
```

```c/ixcompiler.Tokenizer.c
Tokenizer* Tokenizer_new( File** file )
{
    Tokenizer* self = Platform_Alloc( sizeof( Tokenizer ) );

    if ( self )
    {
        self->file   = *file; *file = null;
        self->reader = PushbackReader_new( File_getFilePath( self->file ) );
        self->queue  = Queue_new( (Destructor) Token_free );

        primeQueue( self );
    }
    return self;
}
```

```c/ixcompiler.Tokenizer.c
Tokenizer* Tokenizer_free( Tokenizer** self )
{
    if ( *self )
    {
        if ( 1 )
        {
            Token* tmp;

            while ( (tmp = Queue_removeHead( (*self)->queue )) )
            {
                Token_free( &tmp );
            }
        }

        File_free          ( &(*self)->file   );
        PushbackReader_free( &(*self)->reader );
        Queue_free         ( &(*self)->queue  );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.Tokenizer.c
Token* Tokenizer_nextToken( Tokenizer* self )
{
    primeQueue( self );

    if ( Queue_getLength( self->queue ) > 0 )
    {
        return (Token*) Queue_removeHead( self->queue );
    }
    else
    {
        return null;
    }
}
```

```c/ixcompiler.Tokenizer.c
const Token* Tokenizer_peekToken( Tokenizer* self )
{
    primeQueue( self );

    if ( Queue_getLength( self->queue ) > 0 )
    {
        return (const Token*) Queue_getHead( self->queue );
    }
    else
    {
        return null;
    }
}
```

```c/ixcompiler.Tokenizer.c
EnumTokenGroup Tokenizer_peekTokenGroup( Tokenizer* self )
{
    const Token* token = Tokenizer_peekToken( self );
    if ( !token )
    {
        return GROUPEND;
    }
    else
    {
        return TokenGroup_getGroupType( Token_getTokenGroup( token ) );
    }
}
```

```c/ixcompiler.Tokenizer.c
EnumTokenType Tokenizer_peekTokenType( Tokenizer* self )
{
    const Token* token = Tokenizer_peekToken( self );
    if ( !token )
    {
        return END;
    }
    else
    {
        return Token_getTokenType( token );
    }
}
```

```c/ixcompiler.Tokenizer.c
#include <stdio.h>
void Tokenizer_printAll( Tokenizer* self )
{
    while( Tokenizer_hasMoreTokens( self ) )
    {
        Token* token = Tokenizer_nextToken( self );
        Token_print( token, stdout );
        fprintf( stdout, "\n" );
        Token_free( &token );
    }
}
```

```c/ixcompiler.Tokenizer.c
bool Tokenizer_hasMoreTokens( const Tokenizer* self )
{
    return (Queue_getLength( self->queue ) > 0);
}
```

```c/ixcompiler.Tokenizer.c
const File* Tokenizer_getFile( const Tokenizer* self )
{
    return self->file;
}
```

```c/ixcompiler.Tokenizer.c
static void addTokenToTail( Tokenizer* self, Token** token )
{
    EnumTokenGroup group = Token_getGroupType( *token );
    EnumTokenType  type  = Token_getTokenType( *token );

    switch ( group )
    {
    case WHITESPACE:
    case COMMENT:
        break;
    default:
        self->lastType = type;
    }

    //  Disable STOP prediction in primeQueue
    //  if processing a copyright or license line
    //  until a newline is encountered.
    switch ( type )
    {
    case COPYRIGHT:
    case LICENSE:
        self->ignoreUntilNewline = TRUE;
        break;
    case NEWLINE:
        self->ignoreUntilNewline = FALSE;
        break;
    }

    Queue_addTail( self->queue, (void**) token );
}

static void primeQueue( Tokenizer* self )
{
    Token* token = null;

    if ( (token = next( self )) )
    {
        if ( !self->ignoreUntilNewline )
        {
            if ( Token_ShouldInsertStop( self->lastType, Token_getTokenType( token ) ) )
            {
                addTokenToTail( self, (Token**) Give( Token_CreateStopToken( self ) ) );
            }
        }
        addTokenToTail( self, &token );
    }
}
```

```c/ixcompiler.Tokenizer.c
static Token* next( Tokenizer* self )
{
    Token* token = null;
    int    ch    = 0;
    int    ch2   = 0;

    if ( (ch = PushbackReader_read( self->reader )) )
    {
        StringBuffer*  sb         = StringBuffer_new();
        TokenGroup*    group      = TokenGroup_new( ch );
        EnumTokenType  token_type = END;
        EnumTokenGroup group_type = TokenGroup_getGroupType( group );

        sb = StringBuffer_append_char( sb, ch );

        while ( (ch2 = PushbackReader_read( self->reader )) )
        {
            if ( ESCAPE == group_type )
            {
                sb  = StringBuffer_append_char( sb, ch2 );
                ch2 = PushbackReader_read( self->reader );
                break;
            }
            else
            if ( (SYMBOLIC == group_type) && ('/' == ch) && ('/' == ch2) )
            {
                sb = StringBuffer_append_char( sb, ch2 );

                while( (ch2 = PushbackReader_read( self->reader )) )
                {
                    if ( '\n' != ch2 )
                    {
                        sb = StringBuffer_append_char( sb, ch2 );
                    }
                    else goto end;
                }
            }
            else
            if ( (SYMBOLIC == group_type) && ('#' == ch) )
            {
                sb = StringBuffer_append_char( sb, ch2 );

                while( (ch2 = PushbackReader_read( self->reader )) )
                {
                    if ( '\n' != ch2 )
                    {
                        sb = StringBuffer_append_char( sb, ch2 );
                    }
                    else goto end;
                }
            }
            else
            if ( (SYMBOLIC == group_type) && ('/' == ch) && ('*' == ch2) )
            {
                sb = StringBuffer_append_char( sb, ch2 );

                while( (ch2 = PushbackReader_read( self->reader )) )
                {
                    sb = StringBuffer_append_char( sb, ch2 );

                    if ( '*' == ch2 )
                    {
                        ch2 = PushbackReader_read( self->reader );
                        sb = StringBuffer_append_char( sb, ch2 );

                        if ( '/' == ch2 )
                        {
                            ch2 = 0;
                            goto end;
                        }
                    }
                }
            }
            else
            if ( TokenGroup_matches( group, ch2 ) )
            {
                if ( '\\' == ch2 )
                {
                    sb  = StringBuffer_append_char( sb, ch2 );
                    ch2 = PushbackReader_read( self->reader );
                    sb  = StringBuffer_append_char( sb, ch2 );
                }
                else
                {
                    sb  = StringBuffer_append_char( sb, ch2 );
                }
            }
            else
            if ( STRING == group_type )
            {
                sb = StringBuffer_append_char( sb, ch2 );
                ch2 = PushbackReader_read( self->reader );
                break;
            }
            else
            if ( CHAR == group_type )
            {
                sb = StringBuffer_append_char( sb, ch2 );
                ch2 = PushbackReader_read( self->reader );
                break;
            }
            else
            {
                break;
            }
        }
end:

        if ( ch2 )
        {
            PushbackReader_pushback( self->reader );
        }

        if ( !StringBuffer_isEmpty( sb ) )
        {
            token = Token_new( self, StringBuffer_content( sb ), group );
        }

        StringBuffer_free( &sb );
        TokenGroup_free( &group );
    }
    return token;
}
```

### Token

```!include/ixcompiler.Token.h
#ifndef IXCOMPILER_TOKEN_H
#define IXCOMPILER_TOKEN_H

#include "ix.h"
#include "ixcompiler.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"

Token*            Token_new                      ( Tokenizer* t, const char* content, TokenGroup* aGroup );
Token*            Token_free                     ( Token**      self );
const char*       Token_getContent               ( const Token* self );
const TokenGroup* Token_getTokenGroup            ( const Token* self );
EnumTokenType     Token_getTokenType             ( const Token* self );
EnumTokenGroup    Token_getGroupType             ( const Token* self );
bool              Token_isAmongTypes             ( const Token* self, const EnumTokenType types[] );
void              Token_print                    ( const Token* self, void* stream );
Token*            Token_CreateStopToken          ( Tokenizer* t );
bool              Token_ShouldInsertStop         ( EnumTokenType lastType, EnumTokenType nextType );

#endif
```

```!c/ixcompiler.Token.c
#include <stdio.h>
#include "ixcompiler.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.TokenGroup.h"

struct _Token
{
    Tokenizer*    t;
    char*         content;
    int           length;
    TokenGroup*   group;
    EnumTokenType type;
    const char*   typeName;
};

EnumTokenType   Token_DetermineTokenType       ( TokenGroup* group, const char* content );
EnumTokenType   Token_DetermineWhitespaceType  ( const char* content );
EnumTokenType   Token_DetermineSymbolicType    ( const char* content );
EnumTokenType   Token_DetermineAlphanumericType( const char* content );
EnumTokenType   Token_DetermineOpenType        ( const char* content );
EnumTokenType   Token_DetermineCloseType       ( const char* content );
```

```c/ixcompiler.Token.c
Token* Token_new( Tokenizer* t, const char* content, TokenGroup* aGroup )
{
    Token* self = Platform_Alloc( sizeof(Token) );

    if ( self )
    {
        self->t        = t;
        self->content  = String_Copy  ( content );
        self->length   = String_Length( content );
        self->group    = TokenGroup_copy( aGroup );
        self->type     = Token_DetermineTokenType( aGroup, content );
        self->typeName = EnumTokenType_asString( self->type );

        switch( self->type )
        {
        case LINECOMMENT:
        case MULTILINECOMMENT:
            TokenGroup_setGroupType( self->group, COMMENT );
            break;
        }
    }
    return self;
}
```

```c/ixcompiler.Token.c
Token* Token_free( Token **self )
{
    if ( *self )
    {
        TokenGroup_free( &(*self)->group   );
        Platform_Free  ( &(*self)->content );

        (*self)->t = null;

        Platform_Free( self );
    }

    return *self;
}
```

```c/ixcompiler.Token.c
const char* Token_getContent( const Token* self )
{
    return self->content;
}
```

```c/ixcompiler.Token.c
const TokenGroup* Token_getTokenGroup( const Token* self )
{
    return self->group;
}
```

```c/ixcompiler.Token.c
EnumTokenType Token_getTokenType( const Token* self )
{
    return self->type;
}
```

```c/ixcompiler.Token.c
EnumTokenGroup Token_getGroupType( const Token* self )
{
    return TokenGroup_getGroupType( self->group );
}
```

```c/ixcompiler.Token.c
void Token_print( const Token* self, void* stream )
{
    EnumTokenGroup group_type = TokenGroup_getGroupType( self->group );

    switch ( group_type )
    {
    case OPEN:
    case CLOSE:
        break;

    case COMMENT:
        Term_Colour( stream, COLOR_COMMENT );
        break;

    case SYMBOLIC:
        Term_Colour( stream, COLOR_BOLD );
        break;

    case STRING:
        Term_Colour( stream, COLOR_STRING );
        break;

    case CHAR:
        Term_Colour( stream, COLOR_CHAR );
        break;

    case ALPHANUMERIC:
        switch ( self->type )
        {
        case PRIMITIVE:
            Term_Colour( stream, COLOR_TYPE );
            break;

        case CLASS:
        case KEYWORD:
        case MODIFIER:
            Term_Colour( stream, COLOR_MODIFIER );
            break;

        case WORD:
            Term_Colour( stream, COLOR_NORMAL );
            break;

        default:
            Term_Colour( stream, COLOR_LIGHT );
        }
        break;

    case VALUE:
        Term_Colour( stream, COLOR_VALUE );
        break;        

    case UNKNOWN_GROUP:
        Term_Colour( stream, COLOR_UNKNOWN );
        break;        

    default:
        Term_Colour( stream, COLOR_NORMAL );
    }
    if ( WHITESPACE == group_type )
    {
        fprintf( stream, "%s (%s)", " ", self->typeName );
    }
    else
    {
        fprintf( stream, "%s (%s)", self->content, self->typeName );
    }
    Term_Colour( stream, COLOR_NORMAL );
}
```


```c/ixcompiler.Token.c
EnumTokenType Token_DetermineTokenType( TokenGroup* group, const char* content )
{
    EnumTokenType type = UNKNOWN_TYPE;

    switch ( TokenGroup_getGroupType( group ) )
    {
    case PSEUDOGROUP:
        type = PSEUDO;
        break;

    case UNKNOWN_GROUP:
        type = UNKNOWN_TYPE;
        break;

    case WHITESPACE:
        type = Token_DetermineWhitespaceType( content );
        break;

    case OPEN:
        type = Token_DetermineOpenType( content );
        break;

    case CLOSE:
        type = Token_DetermineCloseType( content );
        break;

    case SYMBOLIC:
        type = Token_DetermineSymbolicType( content );
        break;

    case ALPHANUMERIC:
        type = Token_DetermineAlphanumericType( content );
        break;

    case STRING:
        type = UNKNOWN_TYPE;
        break;

    case CHAR:
        type = FLOAT;
        break;

    case VALUE:
        type = FLOAT;
        break;

    case HEX_VALUE:
        type = HEX;
        break;

    default:
        type = UNKNOWN_TYPE;
    }

    return type;
}
```

```c/ixcompiler.Token.c
EnumTokenType Token_DetermineWhitespaceType( const char* content )
{
    switch( content[0] )
    {
    case ' ':
        return SPACE;
    case '\t':
        return TAB;
    case '\n':
        return NEWLINE;
    default:
        return UNKNOWN_WHITESPACE;
    }
}
```

```c/ixcompiler.Token.c
EnumTokenType Token_DetermineSymbolicType( const char* content )
{
    switch ( content[0] )
    {
    case ',':   return COMMA;
    case '.':   return SELECTOR;
    case ':':   return OFTYPE;
    case '':   return SYMBOL;
    case '!':
        switch ( content[1] )
        {
        case '=':  return INFIXOP;
        default:   return PREFIXOP;
        }
        break;

    case '@':   return INSTANCEMEMBER;
    case '%':   return CLASSMEMBER;
    case '#':   return LINECOMMENT;
    case '$':   return SYMBOL;
    case '^':
        switch ( content[1] )
        {
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

    case '&':
        switch ( content[1] )
        {
        case '&':  return INFIXOP;
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

    case '*':
        switch ( content[1] )
        {
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

    case '-':
        switch ( content[1] )
        {
        case '-':  return PREPOSTFIXOP;
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

    case '+':
        switch ( content[1] )
        {
        case '+':  return PREPOSTFIXOP;
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

    case '=':
        switch ( content[1] )
        {
        case '=':  return INFIXOP;
        default:   return ASSIGNMENTOP;
        }
        break;

    case '/':
        switch ( content[1] )
        {
        case '/':  return LINECOMMENT;
        case '*':  return MULTILINECOMMENT;
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

    case ';':   return STOP;
    case '<':   return INFIXOP;
    case '>':   return INFIXOP;
    default:    return SYMBOL;
    }
}
```

```c/ixcompiler.Token.c
EnumTokenType Token_DetermineAlphanumericType( const char* content )
{
         if ( String_Equals( content, "copyright"  ) ) return COPYRIGHT;
    else if ( String_Equals( content, "Copyright"  ) ) return COPYRIGHT;
    else if ( String_Equals( content, "license"    ) ) return LICENSE;
    else if ( String_Equals( content, "License"    ) ) return LICENSE;
    else if ( String_Equals( content, "licence"    ) ) return LICENSE;
    else if ( String_Equals( content, "Licence"    ) ) return LICENSE;
    else if ( String_Equals( content, "class"      ) ) return CLASS;
    else if ( String_Equals( content, "include"    ) ) return INCLUDE;
    else if ( String_Equals( content, "interface"  ) ) return INTERFACE;
    else if ( String_Equals( content, "package"    ) ) return PACKAGE;

    else if ( String_Equals( content, "public"     ) ) return MODIFIER;
    else if ( String_Equals( content, "protected"  ) ) return MODIFIER;
    else if ( String_Equals( content, "private"    ) ) return MODIFIER;
    else if ( String_Equals( content, "function"   ) ) return MODIFIER;

    else if ( String_Equals( content, "bool"       ) ) return PRIMITIVE;
    else if ( String_Equals( content, "boolean"    ) ) return PRIMITIVE;
    else if ( String_Equals( content, "byte"       ) ) return PRIMITIVE;
    else if ( String_Equals( content, "char"       ) ) return PRIMITIVE;
    else if ( String_Equals( content, "double"     ) ) return PRIMITIVE;
    else if ( String_Equals( content, "float"      ) ) return PRIMITIVE;
    else if ( String_Equals( content, "int"        ) ) return PRIMITIVE;
    else if ( String_Equals( content, "integer"    ) ) return PRIMITIVE;
    else if ( String_Equals( content, "long"       ) ) return PRIMITIVE;
    else if ( String_Equals( content, "short"      ) ) return PRIMITIVE;
    else if ( String_Equals( content, "signed"     ) ) return PRIMITIVE;
    else if ( String_Equals( content, "string"     ) ) return PRIMITIVE;
    else if ( String_Equals( content, "unsigned"   ) ) return PRIMITIVE;
    else if ( String_Equals( content, "void"       ) ) return PRIMITIVE;

    else if ( String_Equals( content, "break"      ) ) return KEYWORD;
    else if ( String_Equals( content, "case"       ) ) return KEYWORD;
    else if ( String_Equals( content, "catch"      ) ) return KEYWORD;
    else if ( String_Equals( content, "const"      ) ) return KEYWORD;
    else if ( String_Equals( content, "default"    ) ) return KEYWORD;
    else if ( String_Equals( content, "extends"    ) ) return KEYWORD;
    else if ( String_Equals( content, "implements" ) ) return KEYWORD;
    else if ( String_Equals( content, "for"        ) ) return KEYWORD;
    else if ( String_Equals( content, "foreach"    ) ) return KEYWORD;
    else if ( String_Equals( content, "let"        ) ) return KEYWORD;
    else if ( String_Equals( content, "namespace"  ) ) return KEYWORD;
    else if ( String_Equals( content, "return"     ) ) return KEYWORD;
    else if ( String_Equals( content, "switch"     ) ) return KEYWORD;
    else if ( String_Equals( content, "try"        ) ) return KEYWORD;
    else if ( String_Equals( content, "var"        ) ) return KEYWORD;
    else if ( String_Equals( content, "new"        ) ) return KEYWORD;
    else                                               return WORD;
}
```

```c/ixcompiler.Token.c
EnumTokenType Token_DetermineOpenType( const char* content )
{
    switch ( content[0] )
    {
    case '{':
        return STARTBLOCK;
    case '(':
        return STARTEXPRESSION;
    case '[':
        return STARTSUBSCRIPT;
    case '<':
        return STARTTAG;
    default:
        return UNKNOWN_OPEN;
    }
}
```

```c/ixcompiler.Token.c
EnumTokenType Token_DetermineCloseType( const char* content )
{
    switch ( content[0] )
    {
    case '}':
        return ENDBLOCK;
    case ')':
        return ENDEXPRESSION;
    case ']':
        return ENDSUBSCRIPT;
    case '>':
        return ENDTAG;
    default:
        return UNKNOWN_OPEN;
    }
}
```

```c/ixcompiler.Token.c
bool Token_isAmongTypes( const Token* self, const EnumTokenType types[] )
{
    for ( int i=0; types[i]; i++ )
    {
        if ( types[i] == Token_getTokenType( self) )
        {
            return TRUE;
        }
    }
    return FALSE;
}
```

```c/ixcompiler.Token.c
Token* Token_CreateStopToken( Tokenizer* t )
{
    Token* stopToken = null;
    {
        TokenGroup* group = TokenGroup_new( ';' );
        {
            stopToken = Token_new( t, ";", group );
        }
        TokenGroup_free( &group );
    }
    return stopToken;
}
```

```c/ixcompiler.Token.c
bool Token_ShouldInsertStop( EnumTokenType lastType, EnumTokenType nextType )
{
    bool insert = FALSE;

    switch( lastType )
    {
    case POSTFIXOP:
    case WORD:
    case PRIMITIVE:
    case FLOAT:
    case ENDEXPRESSION:
    case ENDSUBSCRIPT:
    case PREPOSTFIXOP:
        switch( nextType )
        {
        case ENDBLOCK:
        case PREFIXOP:
        case WORD:
        case INSTANCEMEMBER:
        case CLASSMEMBER:
        case KEYWORD:
            insert = TRUE;
        }
    }

    return insert;
}
```

### Token Group

```!include/ixcompiler.TokenGroup.h
#ifndef IXCOMPILER_TOKENGROUP_H
#define IXCOMPILER_TOKENGROUP_H

#include "ix.h"
#include "ixcompiler.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"

TokenGroup*    TokenGroup_new          ( char ch );
TokenGroup*    TokenGroup_free         ( TokenGroup** self );
void           TokenGroup_setGroupType ( TokenGroup*  self, EnumTokenGroup groupType );

EnumTokenGroup TokenGroup_getGroupType ( const TokenGroup* self );
bool           TokenGroup_matches      ( const TokenGroup* self, char ch );
TokenGroup*    TokenGroup_copy         ( const TokenGroup* self );
EnumTokenGroup TokenGroup_DetermineType( char ch );

#endif
```

```!c/ixcompiler.TokenGroup.c
#include "ixcompiler.TokenGroup.h"

struct _TokenGroup
{
    int            character;
    EnumTokenGroup groupType;
};
```

```c/ixcompiler.TokenGroup.c
TokenGroup* TokenGroup_new( char character )
{
    TokenGroup* self = Platform_Alloc( sizeof( TokenGroup ) );

    if ( self )
    {
        self->character = character;
        self->groupType = TokenGroup_DetermineType( character );
    }

    return self;
}
```

```c/ixcompiler.TokenGroup.c
TokenGroup* TokenGroup_free( TokenGroup** self )
{
    if ( *self )
    {
        (*self)->character = 0;
        (*self)->groupType = 0;
    }
    Platform_Free( self );

    return *self;
}
```

```c/ixcompiler.TokenGroup.c
void TokenGroup_setGroupType( TokenGroup* self, EnumTokenGroup groupType )
{
    self->groupType = groupType;
}
```

```c/ixcompiler.TokenGroup.c
EnumTokenGroup TokenGroup_getGroupType ( const TokenGroup*  self )
{
    return self->groupType;
}
```

```c/ixcompiler.TokenGroup.c
EnumTokenGroup TokenGroup_DetermineType( char ch )
{
    switch ( ch )
    {
    case '\0':
        return PSEUDOGROUP;

    case '':
    case '!':
    case '@':
    case '#':
    case '$':
    case '%':
    case '^':
    case '&':
    case '*':
    case '-':
    case '+':
    case '=':
    case '|':
    case ':':
    case ';':
    case ',':
    case '.':
    case '?':
    case '/':
        return SYMBOLIC;

    case '\\':
        return ESCAPE;

    case '(':
    case '{':
    case '[':
    case '<':
        return OPEN;

    case ')':
    case '}':
    case ']':
    case '>':
        return CLOSE;

    case '"':
        return STRING;

    case '\'':
        return CHAR;

    case '_':
        return ALPHANUMERIC;

    default:
        switch ( ch )
        {
        case  9: // TAB
        case 10: // LF
        case 11: // VT
        case 12: // FF
        case 13: // CR
        case 14: // SO
        case 15: // SI
        case 32: // SPACE
            return WHITESPACE;

        default:
            if ( (48 <= ch) && (ch <= 57) )
            {
                return VALUE;
            }
            else
            if ( (65 <= ch) && (ch <= 90) ) // uppercase
            {
                return ALPHANUMERIC;
            }
            else
            if ( (97 <= ch) && (ch <= 122) ) // lowercase
            {
                return ALPHANUMERIC;
            }
            return UNKNOWN_GROUP;
        }
    }
}
```

```c/ixcompiler.TokenGroup.c
bool TokenGroup_matches( const TokenGroup* self, char ch )
{
    if ( '\0' == ch )
    {
        return FALSE;
    }
    else
    if ( ';' == ch )
    {
        return FALSE;
    }
    else
    {
        EnumTokenGroup secondType = TokenGroup_DetermineType( ch );

        switch( self->groupType )
        {
        case SYMBOLIC:
            switch( secondType )
            {
            case SYMBOLIC:
                return TRUE;

            default:
                return FALSE;
            }
            break;

        case STRING:
            switch ( secondType )
            {
            case STRING:
                return FALSE;

            default:
                return TRUE;
            }
            break;

        case CHAR:
            switch ( secondType )
            {
            case CHAR:
                return FALSE;

            default:
                return TRUE;
            }
            break;

        case ALPHANUMERIC:
            switch ( secondType )
            {
            case ALPHANUMERIC:
            case VALUE:
                return TRUE;

            default:
                return FALSE;
            }
            break;

        case WHITESPACE:
            switch ( secondType )
            {
            case WHITESPACE:
                return TRUE;

            default:
                return FALSE;
            }
            break;

        case VALUE:
            switch ( secondType )
            {
            case VALUE:
                return TRUE;

            case ALPHANUMERIC:
                if ( (65 <= ch) && (ch <= 70) )
                {
                    return TRUE;
                }
                else
                if ( (97 <= ch) && (ch <= 102) )
                {
                    return TRUE;
                }
                else
                return ('x' == ch);

            default:
                return FALSE;
            }
            break;

        case UNKNOWN_GROUP:
            switch ( secondType )
            {
            case UNKNOWN_GROUP:
                return TRUE;

            default:
                return FALSE;
            }
            break;

        default:
            return FALSE;
        }
    }
}
```

```c/ixcompiler.TokenGroup.c
TokenGroup* TokenGroup_copy( const TokenGroup* self )
{
    TokenGroup* copy = Platform_Alloc( sizeof( TokenGroup ) );

    copy->character = self->character;
    copy->groupType = self->groupType;

    return copy;
}
```

### AST

```!include/ixcompiler.AST.h
#ifndef IXCOMPILER_AST_H
#define IXCOMPILER_AST_H

#include "ix.h"
#include "ixcompiler.h"

AST*        AST_new             ( Tokenizer** tokenizer );
AST*        AST_free            ( AST**       self );
const Tree* AST_getTree         ( const AST*  self );
const File* AST_getTokenizerFile( const AST*  self );

#endif
```

```!c/ixcompiler.AST.c
#include "ixcompiler.h"
#include "ixcompiler.AST.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxParser.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"
#include "ixcompiler.Tokenizer.h"

struct _AST
{
    Tokenizer* tokenizer;
    Tree* tree;
};

static Node* AST_Inject               ( Node* parent, const char* tag );
static void  AST_Expect               ( Node* parent, Tokenizer* tokenizer, EnumTokenType expected[] );

static void AST_Parse( AST* self );

static void AST_ParseRoot             ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseWhitespace       ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseLine             ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseComplex          ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseClass            ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseMemberUntilStop  ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseUntilStop        ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseUntilStopOrEndEx ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseClassBlock       ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseClassBlockMember ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseMemberType       ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseMethod           ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseMethodType       ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseParameters       ( Node* parent, Tokenizer* tokenizer );
static bool AST_ParseParameter        ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseParameterType    ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseBlock            ( Node* parent, Tokenizer* tokenizer );
static void AST_ParseStatement        ( Node* parent, Tokenizer* tokenizer, bool one_liner );
static void AST_ParseExpression       ( Node* parent, Tokenizer* tokenizer );
```

```c/ixcompiler.AST.c
AST* AST_new( Tokenizer** tokenizer )
{
    AST* self = Platform_Alloc( sizeof( AST ) );
    if ( self )
    {
        self->tokenizer = *tokenizer; *tokenizer = null;
        self->tree      = Tree_new();
    }

    AST_Parse( self );

    return self;
}
```

```c/ixcompiler.AST.c
AST* AST_free( AST** self )
{
    if ( *self )
    {
        Tree_free( &(*self)->tree );
    }
    Platform_Free( self );

    return *self;
}
```

```c/ixcompiler.AST.c
const Tree* AST_getTree( const AST* self )
{
    return self->tree;
}
```

```c/ixcompiler.AST.c
const File* AST_getTokenizerFile( const AST* self )
{
    return Tokenizer_getFile( self->tokenizer );
}
```

```c/ixcompiler.AST.c
static Node* AST_Inject( Node* parent, const char* tag )
{
    Node* injected = null;

    TokenGroup* group = TokenGroup_new( '\0' );
    {
        //
        //  NODE[parent]
        //     |
        //  NODE[injected][tag]  -----TOKEN[empty] --> GROUP[group]
        //     |
        //  NODE[???]            -----TOKEN[token] --> GROUP[???]

        Token* empty = Token_new( null, "\0", group );
        Node_addChild( parent, &empty );
        injected = Node_getLastChild( parent );
        if ( tag ) Node_setTag( injected, tag );
    }
    TokenGroup_free( &group );

    return injected;
}
```

```c/ixcompiler.AST.c
static void AST_Expect( Node* parent, Tokenizer* tokenizer, EnumTokenType expected[] )
{
    const Token* peek     = null;
    Token*       token    = null;
    Node*        injected = null;

    while ( (peek = Tokenizer_peekToken( tokenizer )) )
    {
        if ( Token_isAmongTypes( peek, expected ) )
        {
            break;
        }
        else
        if ( Token_getTokenType( peek ) == END )
        {
            break;
        }
        else
        {
            if( !injected )
            {
                injected = AST_Inject( parent, "unexpected" );
            }
            Node_addChild( injected, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_Parse( AST* self )
{
    Token* t    = null;
    Node*  root = Node_new( &t );
    AST_ParseRoot( root, self->tokenizer );
    Tree_setRoot( self->tree, &root );
}
```

```c/ixcompiler.AST.c
static void AST_ParseRoot( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[4] = { COPYRIGHT, LICENSE, MODIFIER, END };
    EnumTokenType  expected2[4] = {            LICENSE, MODIFIER, END };
    EnumTokenType  expected3[4] = {                     MODIFIER, END };
    EnumTokenType* expected = expected1;

    bool loop = TRUE;
    while ( loop && Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            loop = FALSE;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType ( tokenizer );

            switch ( token_type )
            {
            case COPYRIGHT:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                Node_setTag( child, "copyright" );
                AST_ParseLine( child, tokenizer );
                break;

            case LICENSE:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                Node_setTag( child, "license" );
                AST_ParseLine( child, tokenizer );
                expected = expected2;
                break;

            case MODIFIER:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseComplex( child, tokenizer );
                expected = expected3;
                break;
            }
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseWhitespace( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        if ( Tokenizer_peekTokenGroup( tokenizer ) == WHITESPACE )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            break;
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseLine( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenType type = Tokenizer_peekTokenType( tokenizer );
        Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );

        if ( NEWLINE == type )
        {
            break;
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseComplex( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[4] = { KEYWORD, CLASS, WORD, END };
    EnumTokenType  expected2[4] = {          CLASS, WORD, END };
    EnumTokenType* expected     = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type = Tokenizer_peekTokenType( tokenizer );

            switch ( token_type )
            {
            case KEYWORD:
                const Token* peek = Tokenizer_peekToken( tokenizer );
                if ( String_Equals( "new", Token_getContent( peek ) ) )
                {
                    //  new
                    Node_setTag( parent, "method" );
                    AST_ParseMethod( parent, tokenizer );
                    goto exit;
                }
                else
                {
                    //  const
                    Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                    expected = expected2;
                }
                break;

            case CLASS:
                Node_setTag( parent, "class" );
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseClass( child, tokenizer );
                goto exit;
                break;

            case WORD:
                Node_setTag( parent, "method" );
                AST_ParseMethod( parent, tokenizer );
                goto exit;
                break;
            }
        }
    }
exit:
}
```

```c/ixcompiler.AST.c
static void AST_ParseClass( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType expected1[3] = {  KEYWORD, STARTBLOCK, END };
    EnumTokenType expected2[3] = {           STARTBLOCK, END };

    EnumTokenType* expected = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType ( tokenizer );

            switch( token_type )
            {
            case KEYWORD:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseUntilStop( child, tokenizer );
                expected = expected2;
                break;

            case STARTBLOCK:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseClassBlock( child, tokenizer );
                goto exit;
            }
        }
    }
exit:
}
```

```c/ixcompiler.AST.c
static void AST_ParseMemberUntilStop( Node* parent, Tokenizer* tokenizer )
{
    bool loop = TRUE;
    while( loop && Tokenizer_hasMoreTokens( tokenizer ) )
    {
        const Token*  token = Tokenizer_peekToken( tokenizer );
        const char*   value = Token_getContent( token );
        EnumTokenType type  = Token_getTokenType( token );

        if ( STARTBLOCK == type )
        {
            loop = FALSE;
        }
        else
        if ( (INFIXOP == type) && (('*' == value[0]) || ('&' == value[0])) )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( COMMA == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( STOP == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( OFTYPE == type )
        {
            Node* child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            AST_ParseMemberUntilStop( child, tokenizer );
            break;
        }
        else
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseUntilStopOrEndEx( Node* parent, Tokenizer* tokenizer )
{
    bool loop = TRUE;
    while( loop && Tokenizer_hasMoreTokens( tokenizer ) )
    {
        const Token*  token = Tokenizer_peekToken( tokenizer );
        const char*   value = Token_getContent( token );
        EnumTokenType type  = Token_getTokenType( token );

        if ( STARTBLOCK == type )
        {
            loop = FALSE;
        }
        else
        if ( (INFIXOP == type) && (('*' == value[0]) || ('&' == value[0])) )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( COMMA == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( STOP == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( ENDEXPRESSION == type )
        {
            loop = FALSE;
        }
        else
        if ( OFTYPE == type )
        {
            Node* child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            AST_ParseMemberUntilStop( child, tokenizer );
            break;
        }
        else
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseUntilStop( Node* parent, Tokenizer* tokenizer )
{
    bool loop = TRUE;
    while( loop && Tokenizer_hasMoreTokens( tokenizer ) )
    {
        const Token*  token = Tokenizer_peekToken( tokenizer );
        const char*   value = Token_getContent( token );
        EnumTokenType type  = Token_getTokenType( token );

        if ( STARTBLOCK == type )
        {
            loop = FALSE;
        }
        else
        if ( COMMA == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( STOP == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( ENDEXPRESSION == type )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            loop = FALSE;
        }
        else
        if ( (OFTYPE == type) || (INFIXOP == type) || (ASSIGNMENTOP == type) )
        {
            Node* child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            AST_ParseUntilStop( child, tokenizer );
            loop = FALSE;
        }
        else
        if ( STARTEXPRESSION == type )
        {
            Node* child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            AST_ParseUntilStop( child, tokenizer );
        }
        else
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseClassBlock( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[4] = { INSTANCEMEMBER, CLASSMEMBER, ENDBLOCK, END };
    EnumTokenType* expected = expected1;

    bool loop = TRUE;
    while ( loop && Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            loop = FALSE;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType( tokenizer );

            switch( token_type )
            {
            case INSTANCEMEMBER:
            case CLASSMEMBER:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseClassBlockMember( child, tokenizer );
                break;

            case ENDBLOCK:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                loop = FALSE;
                break;
            }
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseClassBlockMember( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected[4] = {   WORD, END };

    bool loop = TRUE;
    while ( loop && Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            loop = FALSE;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType( tokenizer );

            switch ( token_type )
            {
            case WORD:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseMemberUntilStop( child, tokenizer );
                loop = FALSE;
                break;
            }
        }
    }
}
```

```
static void AST_ParseMemberType( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[7] = {                                      PRIMITIVE,       WORD, END };
    EnumTokenType  expected2[7] = {           STARTSUBSCRIPT, INFIXOP, COMMA, STOP,   ENDBLOCK, END };
    EnumTokenType  expected3[7] = { SELECTOR, STARTSUBSCRIPT, INFIXOP, COMMA, STOP,   ENDBLOCK, END };
    EnumTokenType  expected4[7] = {                                                       WORD, END };
    EnumTokenType  expected5[7] = {                                               ENDSUBSCRIPT, END };
    EnumTokenType  expected6[7] = {                             INFIXOP, COMMA, STOP, ENDBLOCK, END };
    EnumTokenType  expected7[7] = {                                      COMMA, STOP, ENDBLOCK, END };
    EnumTokenType* expected = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType( tokenizer );

            switch ( token_type )
            {
            case PRIMITIVE:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected2;
                break;

            case WORD:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected3;
                break;

            case SELECTOR:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected4;
                break;

            case STARTSUBSCRIPT:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected5;
                break;

            case ENDSUBSCRIPT:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected6;
                break;

            case INFIXOP:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected7;
                break;

            case COMMA:
                goto exit;
                break;

            case STOP:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                goto exit;
                break;

            case STARTBLOCK:
            case ENDBLOCK:
            case ENDEXPRESSION:
                goto exit;
                break;
            }
        }
    }
exit:
}
```

```c/ixcompiler.AST.c
static void AST_ParseMethod( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[3] = {           KEYWORD, WORD, END };
    EnumTokenType  expected2[3] = {                    WORD, END };
    EnumTokenType  expected3[3] = {         STARTEXPRESSION, END };
    EnumTokenType  expected4[3] = { OFTYPE,      STARTBLOCK, END };
    EnumTokenType  expected5[3] = {              STARTBLOCK, END };
    EnumTokenType* expected     = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );
            token_type  = Tokenizer_peekTokenType ( tokenizer );

            switch( token_type )
            {
            case KEYWORD:    // public [const] methodname 
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                if ( String_Equals( "new", Token_getContent( Node_getToken( child ) ) ) )
                {
                    expected = expected3;   // new
                }
                else
                {
                    expected = expected2;   // const
                }
                break;

            case WORD:       // public const [methodname]
                Node* child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected3;
                break;

            case STARTEXPRESSION:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseParameters( child, tokenizer );
                expected = expected4;
                break;

            case OFTYPE:    // public const [methodname]
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseUntilStop( child, tokenizer );
                expected = expected5;
                break;

            case STARTBLOCK:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseBlock( child, tokenizer );
                goto exit;
                break;
            }
        }
    }
exit:
}
```

```
static void AST_ParseMethodType( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[7] = {                                      PRIMITIVE,       WORD, END };
    EnumTokenType  expected2[7] = {           STARTSUBSCRIPT, INFIXOP, COMMA, STOP, STARTBLOCK, END };
    EnumTokenType  expected3[7] = { SELECTOR, STARTSUBSCRIPT, INFIXOP, COMMA, STOP, STARTBLOCK, END };
    EnumTokenType  expected4[7] = {                                                       WORD, END };
    EnumTokenType  expected5[7] = {                                               ENDSUBSCRIPT, END };
    EnumTokenType  expected6[7] = {                           INFIXOP, COMMA, STOP, STARTBLOCK, END };
    EnumTokenType  expected7[7] = {                                    COMMA, STOP, STARTBLOCK, END };
    EnumTokenType* expected = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType( tokenizer );

            switch ( token_type )
            {
            case PRIMITIVE:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected2;
                break;

            case WORD:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected3;
                break;

            case SELECTOR:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected4;
                break;

            case STARTSUBSCRIPT:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected5;
                break;

            case ENDSUBSCRIPT:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected6;
                break;

            case INFIXOP:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected7;
                break;

            case COMMA:
                goto exit;
                break;

            case STOP:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                goto exit;
                break;

            case STARTBLOCK:
            case ENDBLOCK:
            case ENDEXPRESSION:
                goto exit;
                break;
            }
        }
    }
exit:
}
```

```c/ixcompiler.AST.c
static void AST_ParseParameters( Node* parent, Tokenizer* tokenizer )
{
    //  name1: type, name2: type )

    EnumTokenType  expected1[3] = { WORD,  ENDEXPRESSION, END };
    EnumTokenType* expected     = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );
            token_type  = Tokenizer_peekTokenType ( tokenizer );

            switch( token_type )
            {
            case WORD:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseParameter( child, tokenizer );
                break;

            case ENDEXPRESSION:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                goto exit;
                break;
            }
        }
    }
exit:
}
```

```c/ixcompiler.AST.c
//  Returns true if last parameter and endexpression encountered
static bool AST_ParseParameter( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[3] = {               OFTYPE, END };
    EnumTokenType* expected     = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );
            token_type  = Tokenizer_peekTokenType ( tokenizer );

            switch( token_type )
            {
            case OFTYPE:
                child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                AST_ParseUntilStopOrEndEx( child, tokenizer );
                goto exit;
                break;
            }
        }
    }
exit:
}
```

```
static void AST_ParseParameterType( Node* parent, Tokenizer* tokenizer )
{
    EnumTokenType  expected1[7] = {                                         PRIMITIVE,       WORD, END };
    EnumTokenType  expected2[7] = {           STARTSUBSCRIPT, INFIXOP, COMMA, STOP, ENDEXPRESSION, END };
    EnumTokenType  expected3[7] = { SELECTOR, STARTSUBSCRIPT, INFIXOP, COMMA, STOP, ENDEXPRESSION, END };
    EnumTokenType  expected4[7] = {                                                          WORD, END };
    EnumTokenType  expected5[7] = {                                                  ENDSUBSCRIPT, END };
    EnumTokenType  expected6[7] = {                           INFIXOP, COMMA, STOP, ENDEXPRESSION, END };
    EnumTokenType  expected7[7] = {                                    COMMA, STOP, ENDEXPRESSION, END };
    EnumTokenType* expected = expected1;

    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        {
            AST_Expect( parent, tokenizer, expected );

            token_type  = Tokenizer_peekTokenType( tokenizer );

            switch ( token_type )
            {
            case PRIMITIVE:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected2;
                break;

            case WORD:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected3;
                break;

            case SELECTOR:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected4;
                break;

            case STARTSUBSCRIPT:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected5;
                break;

            case ENDSUBSCRIPT:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected6;
                break;

            case INFIXOP:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                expected = expected7;
                break;

            case COMMA:
                goto exit;
                break;

            case STOP:
                Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
                goto exit;
                break;

            case STARTBLOCK:
            case ENDBLOCK:
            case ENDEXPRESSION:
                goto exit;
                break;
            }
        }
    }
exit:
}
```


```c/ixcompiler.AST.c
static void AST_ParseBlock( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        EnumTokenGroup token_group = Tokenizer_peekTokenGroup( tokenizer );
        EnumTokenType  token_type  = Tokenizer_peekTokenType ( tokenizer );

        Node* child = null;
        if ( token_type == END )
        {
            goto exit;
        }
        else
        if ( token_group == WHITESPACE )
        {
            child = Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            Node_setTag( child, "whitespace" );
            AST_ParseWhitespace( child, tokenizer );
        }
        else
        if ( token_group == COMMENT )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
        }
        else
        if ( token_type == ENDBLOCK )
        {
            Node_addChild( parent, (Token**) Give( Tokenizer_nextToken( tokenizer ) ) );
            goto exit;
        }
        else
        {
            Node* child = AST_Inject( parent, "statement" );
            AST_ParseStatement( child, tokenizer, FALSE );
        }
    }
exit:
}
```

```c/ixcompiler.AST.c
static void AST_ParseStatement( Node* parent, Tokenizer* tokenizer, bool one_liner )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        if ( Token_getTokenType( Tokenizer_peekToken( tokenizer ) ) == ENDBLOCK )
        {
            break;
        }

        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );

        Node_addChild( parent, &token );

        if ( token_type == STOP )
        {
            break;
        }
        else
        if ( token_type == ENDBLOCK )
        {
            break;
        }
        else
        if ( one_liner && (token_type == NEWLINE) )
        {
            break;
        }
        else
        if ( token_group == WHITESPACE )
        {
            continue;
        }
        else
        if ( token_type == OFTYPE )
        {
            AST_ParseUntilStop( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        if ( (token_type == INSTANCEMEMBER) || (token_type == CLASSMEMBER) )
        {
            Node* last = Node_getLastChild( parent );
            AST_ParseStatement( last, tokenizer, FALSE );
            break;
        }
        else
        if ( (token_group == SYMBOLIC) && ((token_type == ASSIGNMENTOP) || (token_type == INSTANCEMEMBER) || (token_type == CLASSMEMBER) || (token_type == PREFIXOP) || (token_type == INFIXOP)) )
        {
            AST_ParseStatement( Node_getLastChild( parent ), tokenizer, FALSE );
            break;
        }
        else
        if ( (token_group == OPEN) && (token_type == STARTEXPRESSION) )
        {
            AST_ParseExpression( Node_getLastChild( parent ), tokenizer );
        }
        else
        if ( (token_group == OPEN) && (token_type == STARTBLOCK) )
        {
            AST_ParseBlock( Node_getLastChild( parent ), tokenizer );
            break;
        }
    }
}
```

```c/ixcompiler.AST.c
static void AST_ParseExpression( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        if ( Token_getTokenType( Tokenizer_peekToken( tokenizer ) ) == ENDBLOCK )
        {
            break;
        }

        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );
        const char*    content     = Token_getContent( token );
        int            ch          = content[0];

        Node_addChild( parent, &token );

        if ( token_type == STOP )
        {
            break;
        }
        else
        if ( token_type == ENDEXPRESSION )
        {
            break;
        }
        else
        if ( (token_group == OPEN) && (token_type == STARTEXPRESSION) )
        {
            AST_ParseExpression( Node_getLastChild( parent ), tokenizer );
        }
        else
        if ( (token_group == SYMBOLIC) && ((token_type == ASSIGNMENTOP) || (token_type == INFIXOP)) )
        {
            AST_ParseExpression( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        {
            continue;
        }
    }
}
```


### AST Collection

```!include/ixcompiler.ASTCollection.h
#ifndef IXCOMPILER_ASTCOLLECTION_H
#define IXCOMPILER_ASTCOLLECTION_H

#include "ix.h"

ASTCollection* ASTCollection_new();
ASTCollection* ASTCollection_free( ASTCollection** self            );
void           ASTCollection_add ( ASTCollection*  self, AST** ast );

int            ASTCollection_getLength( const ASTCollection* self );
const AST*     ASTCollection_get      ( const ASTCollection* self, int index );

#endif
```

```!c/ixcompiler.ASTCollection.c
#include "ixcompiler.h"
#include "ixcompiler.AST.h"

struct _ASTCollection
{
    Array* ast_collection;
};
```

```c/ixcompiler.ASTCollection.c
ASTCollection* ASTCollection_new()
{
    ASTCollection* self = Platform_Alloc( sizeof( ASTCollection ) );
    if ( self )
    {
        self->ast_collection = Array_new_destructor( (Destructor) AST_free );
    }
    return self;
}
```

```c/ixcompiler.ASTCollection.c
ASTCollection* ASTCollection_free( ASTCollection** self )
{
    if ( *self )
    {
        Array_free( &(*self)->ast_collection );
        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.ASTCollection.c
void ASTCollection_add( ASTCollection* self, AST** ast )
{
    Array_push( self->ast_collection, (void**) ast );
}
```

```c/ixcompiler.ASTCollection.c
int ASTCollection_getLength( const ASTCollection* self )
{
    return Array_getLength( self->ast_collection );
}
```

```c/ixcompiler.ASTCollection.c
const AST* ASTCollection_get( const ASTCollection* self, int index )
{
    return Array_getObject( self->ast_collection, index );
}
```
### AST Printer

```!include/ixcompiler.ASTPrinter.h
#ifndef IXCOMPILER_ASTPRINTER_H
#define IXCOMPILER_ASTPRINTER_H

#include "ix.h"

void ASTPrinter_Print( const AST* ast );

#endif
```

```!c/ixcompiler.ASTPrinter.c
#include <stdio.h>
#include "ixcompiler.h"
#include "ixcompiler.AST.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.Generator.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"

static void PrintNode( const Node* node );
static void PrintTree( const Node* node, int indent );
```

```c/ixcompiler.ASTPrinter.c
void ASTPrinter_Print( const AST* ast )
{
    const Tree* tree = AST_getTree( ast );
    const Node* root = Tree_getRoot( tree );

    PrintTree( root, -1 );
}
```

```c/ixcompiler.ASTPrinter.c
static void PrintNode( const Node* node )
{
    const Token* token = Node_getToken( node );

    if ( token )
    {
        Token_print( token, stdout );
    }

    if ( Node_hasChildren( node ) )
    {
        NodeIterator* it = Node_iterator( node );
        while ( NodeIterator_hasNext( it ) )
        {
            const Node*  child = NodeIterator_next( it );

            PrintNode( child );
        }
        NodeIterator_free( &it );
    }
}
```

```c/ixcompiler.ASTPrinter.c
static void PrintTree( const Node* node, int indent )
{
    const Token* token = Node_getToken( node );

    if ( token )
    {
        const String* tag = null;

        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        switch( token_group )
        {
        case WHITESPACE:
            break;
        default:
            for ( int i=0; i < indent; i++ )
            {
                fprintf( stdout, "\t" );
            }
            tag = Node_getTag( node );
            if ( tag ) fprintf( stdout, "[%s] ", String_content( tag ) );
            Token_print( token, stdout );
            fprintf( stdout, "\n" );
        }
    }

    if ( Node_hasChildren( node ) )
    {
        NodeIterator* it = Node_iterator( node );
        while ( NodeIterator_hasNext( it ) )
        {
            const Node*  child = NodeIterator_next( it );

            PrintTree( child, indent + 1 );
        }
        NodeIterator_free( &it );
    }
}
```

```!include/ixcompiler.IxParser.h
#ifndef IXCOMPILER_IXPARSER_H
#define IXCOMPILER_IXPARSER_H

#include "ix.h"
#include "ixcompiler.h"

IxParser*      IxParser_new           ( Tokenizer* tokenizer )                ;
IxParser*      IxParser_free          ( IxParser** self )                     ;
AST*           IxParser_parse         ( IxParser* self )                      ;

#endif
```

```!c/ixcompiler.IxParser.c
#include "ixcompiler.AST.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxParser.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"
#include "ixcompiler.Tokenizer.h"

struct _IxParser
{
    Tokenizer* tokenizer;
};

```

```c/ixcompiler.IxParser.c
IxParser* IxParser_new( Tokenizer* tokenizer )
{
    IxParser* self = Platform_Alloc( sizeof(IxParser) );
    if ( self )
    {
        self->tokenizer = tokenizer;
    }
    return self;
}
```

```c/ixcompiler.IxParser.c
IxParser* IxParser_free( IxParser** self )
{
    if ( *self )
    {
        (*self)->tokenizer = null;

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxParser.c
AST* IxParser_parse( IxParser* self )
{
}
```

### Ix Source Block

```!include/ixcompiler.IxSourceBlock.h
#ifndef IXCOMPILER_IXSOURCEBLOCK_H
#define IXCOMPILER_IXSOURCEBLOCK_H

#include "ix.h"
#include "ixcompiler.h"

IxSourceBlock* IxSourceBlock_new( const Node* startBlockNode );

IxSourceBlock* IxSourceBlock_free         (       IxSourceBlock** self );
const Array*   IxSourceBlock_getStatements( const IxSourceBlock*  self );

#endif
```

```!c/ixcompiler.IxSourceBlock.c
#include "ix.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceBlock.h"
#include "ixcompiler.IxSourceStatement.h"
#include "ixcompiler.Token.h"

struct _IxSourceBlock
{
    Array* statements;
};

void IxSourceBlock_parseStatements( IxSourceBlock* self, const Node* startBlock );
```


```c/ixcompiler.IxSourceBlock.c
IxSourceBlock* IxSourceBlock_new( const Node* startBlockNode )
{
    IxSourceBlock* self = Platform_Alloc( sizeof(IxSourceBlock) );
    if ( self )
    {
        self->statements = Array_new_destructor( (Destructor) IxSourceStatement_free );

        IxSourceBlock_parseStatements( self, startBlockNode );        
    }
    return self;
}
```

```c/ixcompiler.IxSourceBlock.c
IxSourceBlock* IxSourceBlock_free( IxSourceBlock** self )
{
    if ( *self )
    {
        Array_free( &(*self)->statements );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceBlock.c
const Array* IxSourceBlock_getStatements( const IxSourceBlock* self )
{
    return self->statements;
}
```

```c/ixcompiler.IxSourceBlock.c
void IxSourceBlock_parseStatements( IxSourceBlock* self, const Node* startBlock )
{
    NodeIterator* it = Node_iterator( startBlock );
    while ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node );

        if ( Token_getTokenType( token ) == ENDBLOCK )
        {
            break;
        }
        else
        {
            Array_push( self->statements, Give( IxSourceStatement_new( node ) ) );
        }
    }
    NodeIterator_free( &it );
}
```

### Ix Source Class

```!include/ixcompiler.IxSourceClass.h
#ifndef IXCOMPILER_IXSOURCECLASS_H
#define IXCOMPILER_IXSOURCECLASS_H

#include "ix.h"
#include "ixcompiler.h"

IxSourceClass* IxSourceClass_new( const Node* classNode );

IxSourceClass* IxSourceClass_free( IxSourceClass** self );

const Array* IxSourceClass_getMembers( const IxSourceClass* self );

#endif
```

```!c/ixcompiler.IxSourceClass.c
#include <stdio.h>
#include "ix.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceClass.h"
#include "ixcompiler.IxSourceMember.h"
#include "ixcompiler.Token.h"

struct _IxSourceClass
{
    bool                   invalid;
    String*                accessModifier;
    String*                className;
    ArrayOfString*         interfaces;
    Array*                 members;
};

static void parseModifier( IxSourceClass* self, const Node* node );
static void parseClass   ( IxSourceClass* self, const Node* node );
static void parseBlock   ( IxSourceClass* self, const Node* node );
static void parseMember  ( IxSourceClass* self, const Node* node );
```

```c/ixcompiler.IxSourceClass.c
IxSourceClass* IxSourceClass_new( const Node* classModifierNode )
{
    Console_Write( "IxSourceClass_new", null );

    IxSourceClass* self = Platform_Alloc( sizeof( IxSourceClass ) );
    if ( self )
    {
        self->accessModifier = String_new( "" );
        self->className      = String_new( "" );
        self->interfaces     = ArrayOfString_new();
        self->members        = Array_new_destructor( (Destructor) IxSourceMember_free );

        parseModifier( self, classModifierNode );
    }
    return self;
}
```

0x555555580e50

```c/ixcompiler.IxSourceClass.c
IxSourceClass* IxSourceClass_free( IxSourceClass** self )
{
    if ( *self )
    {
        String_free       ( &(*self)->accessModifier );
        String_free       ( &(*self)->className      );
        ArrayOfString_free( &(*self)->interfaces     );
        Array_free        ( &(*self)->members        );
    }
}
```

```c/ixcompiler.IxSourceClass.c
const Array* IxSourceClass_getMembers( const IxSourceClass* self )
{
    return self->members;
}
```

```c/ixcompiler.IxSourceClass.c
static void parseModifier( IxSourceClass* self, const Node* classModifierNode )
{
    String_free( &self->accessModifier );
    self->accessModifier = String_new( Token_getContent( Node_getToken( classModifierNode ) ) );

    NodeIterator* it = Node_iterator( classModifierNode );

    // CLASS
    if ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*   next  = NodeIterator_next( it );
        const Token*  token = Node_getToken( next );
        EnumTokenType type  = Token_getTokenType( token );

        if ( type = CLASS )
        {
            parseClass( self, next );
        }
        else
        {
            self->invalid = TRUE;
        }
    }
}
```


```c/ixcompiler.IxSourceClass.c
static void parseClass ( IxSourceClass* self, const Node* classNode )
{
    NodeIterator* it = Node_iterator( classNode );

    // STARTBLOCK
    if ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*   next  = NodeIterator_next( it );
        const Token*  token = Node_getToken( next );
        EnumTokenType type  = Token_getTokenType( token );

        if ( type == STARTBLOCK )
        {
            parseBlock( self, next );
        }
        else
        {
            self->invalid = TRUE;
        }
    }
}
```

```c/ixcompiler.IxSourceClass.c
static void parseBlock ( IxSourceClass* self, const Node* startBlockNode )
{
    NodeIterator* it = Node_iterator( startBlockNode );
    while ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*  next  = NodeIterator_next ( it    );
        const Token* token = Node_getToken     ( next  );
        const char*  value = Token_getContent  ( token );
        EnumTokenType type = Token_getTokenType( token );

        switch ( type )
        {
        case INSTANCEMEMBER:
            parseMember( self, next );
            break;

        case CLASSMEMBER:
            parseMember( self, next );
            break;

        case ENDBLOCK:
            break;

        default:
            self->invalid = TRUE;
        }
    }
}
```

```c/ixcompiler.IxSourceClass.c
static void parseMember( IxSourceClass* self, const Node* node )
{
    IxSourceMember* member = IxSourceMember_new( node );

    Array_push( self->members, Give( member ) );
}
```


### Ix Source Comment

```!include/ixcompiler.IxSourceComment.h
#ifndef IXCOMPILER_IXSOURCECOMMENT_H
#define IXCOMPILER_IXSOURCECOMMENT_H

#include "ix.h"
#include "ixcompiler.h"

IxSourceComment* IxSourceComment_new();
IxSourceComment* IxSourceComment_free( IxSourceComment** self );

#endif
```

```!c/ixcompiler.IxSourceComment.c
#include "ixcompiler.IxSourceComment.h"

struct _IxSourceComment
{
    String* keyword;
    String* text;
};
```

```c/ixcompiler.IxSourceComment.c
IxSourceComment* IxSourceComment_new()
{
    IxSourceComment* self = Platform_Alloc( sizeof( IxSourceComment ) );
    if ( self )
    {
    }
    return self;
}
```

```c/ixcompiler.IxSourceComment.c
IxSourceComment* IxSourceComment_free( IxSourceComment** self )
{
    if ( *self )
    {
        Platform_Free( self );
    }
    return *self;
}
```

### Ix Source Conditional

```
if ( <expression> )
```

```
while ( <expression> )
```

```
foreach ( <variable name> in <iterator name> )
```

```!include/ixcompiler.IxSourceConditional.h
#ifndef IXCOMPILER_IXSOURCECONDITIONAL_H
#define IXCOMPILER_IXSOURCECONDITIONAL_H

#include "ix.h"
#include "ixcompiler.h"

typedef enum _EnumConditionalType
{
    IF,
    ELSE,
    FOR,
    FOREACH,
    OR,
    WHILE
} EnumConditionalType;

typedef enum _EnumForeachType
{
    AS,
    IN

} EnumForeachType;

IxSourceConditional* IxSourceConditional_new( const Node* keywordNode );

IxSourceConditional* IxSourceConditional_free    (       IxSourceConditional** self );
String*              IxSourceConditional_toString( const IxSourceConditional*  self );

#endif
```

```!c/ixcompiler.IxSourceConditional.c
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceConditional.h"
#include "ixcompiler.IxSourceExpression.h"
#include "ixcompiler.Token.h"

struct _IxSourceConditional
{
    bool                invalid;
    EnumConditionalType conditionalType;
    IxSourceExpression* expression;

    EnumForeachType     foreachType;
    String*             foreachVariableName;
    String*             foreachIteratorName;
};

void IxSourceConditional_parseKeywordNode( IxSourceConditional* self, const Node* keywordNode );
void IxSourceConditional_parseForeach    ( IxSourceConditional* self, const Node* startExpressionNode );
```

```c/ixcompiler.IxSourceConditional.c
IxSourceConditional* IxSourceConditional_new( const Node* keywordNode )
{
    IxSourceConditional* self = Platform_Alloc( sizeof(IxSourceConditional) );
    if ( self )
    {
        IxSourceConditional_parseKeywordNode( self, keywordNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceConditional.c
IxSourceConditional* IxSourceConditional_free( IxSourceConditional** self )
{
    if ( *self )
    {
        IxSourceExpression_free( &(*self)->expression );
        String_free( &(*self)->foreachVariableName );
        String_free( &(*self)->foreachIteratorName );
    }
    return *self;
}
```

```
CONDITIONAL[ IF, ( expr ) ]
```

```c/ixcompiler.IxSourceConditional.c
String* IxSourceConditional_toString( const IxSourceConditional* self )
{
    StringBuffer* sb = StringBuffer_new();
    {
        switch( self->conditionalType )
        {
        case IF:
            StringBuffer_append( sb, "IF" );
            break;

        case ELSE:
            StringBuffer_append( sb, "ELSE" );
            break;

        case FOR:
            StringBuffer_append( sb, "FOR" );
            break;

        case FOREACH:
            StringBuffer_append( sb, "FOREACH" );
            break;

        case OR:
            StringBuffer_append( sb, "OR" );
            break;

        case WHILE:
            StringBuffer_append( sb, "WHILE" );
            break;
        }
    }
    return StringBuffer_ConvertToString( &sb );
}
```

```c/ixcompiler.IxSourceConditional.c
void IxSourceConditional_parseKeywordNode( IxSourceConditional* self, const Node* keywordNode )
{
    const char* keyword = Token_getContent( Node_getToken( keywordNode ) );

    if ( String_Equals( keyword, "if" ) )
    {
        self->conditionalType = IF;
    }
    else
    if ( String_Equals( keyword, "else" ) )
    {
        self->conditionalType = ELSE;
    }
    else
    if ( String_Equals( keyword, "for" ) )
    {
        self->conditionalType = FOR;
    }
    else
    if ( String_Equals( keyword, "foreach" ) )
    {
        self->conditionalType = FOREACH;
    }
    else
    if ( String_Equals( keyword, "or" ) )
    {
        self->conditionalType = OR;
    }
    else
    if ( String_Equals( keyword, "while" ) )
    {
        self->conditionalType = WHILE;
    }

    NodeIterator* it = Node_iterator( keywordNode );
    if ( NodeIterator_hasNonWhitespaceOfType( it, STARTEXPRESSION ) )
    {
        switch( self->conditionalType )
        {
        case IF:
            self->expression = IxSourceExpression_new( NodeIterator_next( it ) );
            break;

        case ELSE:
            self->expression = IxSourceExpression_new( NodeIterator_next( it ) );
            break;

        case FOR:
            self->expression = IxSourceExpression_new( NodeIterator_next( it ) );
            break;

        case FOREACH:
            IxSourceConditional_parseForeach( self, NodeIterator_next( it ) );
            break;

        case OR:
            self->expression = IxSourceExpression_new( NodeIterator_next( it ) );
            break;

        case WHILE:
            self->expression = IxSourceExpression_new( NodeIterator_next( it ) );
            break;

        default:
            self->invalid = TRUE;
        }
    }
    else
    {
        self->invalid = TRUE;
    }
    NodeIterator_free( &it );

}
```

```c/ixcompiler.IxSourceConditional.c
void IxSourceConditional_parseForeach( IxSourceConditional* self, const Node* startExpressionNode )
{
    bool invalid = TRUE;

    const char* first;
    const char* second;

    NodeIterator* it = Node_iterator( startExpressionNode );
    if ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
    {
        first = Token_getContent( Node_getToken( NodeIterator_next( it ) ) );

        if ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
        {
            const char* type = Token_getContent( Node_getToken( NodeIterator_next( it ) ) );

            if ( String_Equals( type, "as" ) )
            {
                self->foreachType = AS;
            }
            else
            if ( String_Equals( type, "in" ) )
            {
                self->foreachType = IN;
            }

            if ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
            {
                second = Token_getContent( Node_getToken( NodeIterator_next( it ) ) );

                switch ( self->foreachType )
                {
                case AS:
                    self->foreachVariableName = String_new( second );
                    self->foreachIteratorName = String_new( first  );
                    break;
                
                case IN:
                    self->foreachVariableName = String_new( first  );
                    self->foreachIteratorName = String_new( second );
                    break;
                }

                if ( NodeIterator_hasNonWhitespaceOfType( it, ENDEXPRESSION ) )
                {
                    invalid = FALSE;
                }
            }
        }
    }
    NodeIterator_free( &it );

    self->invalid = invalid;
}
```

### Ix Source Declaration

```!include/ixcompiler.IxSourceDeclaration.h
#ifndef IXCOMPILER_IXSOURCEDECLARATION_H
#define IXCOMPILER_IXSOURCEDECLARATION_H

#include "ix.h"
#include "ixcompiler.h"

IxSourceDeclaration* IxSourceDeclaration_new( const Node* varNode );

IxSourceDeclaration*      IxSourceDeclaration_free         (       IxSourceDeclaration** self );
const String*             IxSourceDeclaration_getName      ( const IxSourceDeclaration*  self );
const IxSourceType*       IxSourceDeclaration_getType      ( const IxSourceDeclaration*  self );
const IxSourceExpression* IxSourceDeclaration_getExpression( const IxSourceDeclaration*  self );
bool                      IxSourceDeclaration_hasExpression( const IxSourceDeclaration*  self );

#endif
```

```!c/ixcompiler.IxSourceDeclaration.c
#include "ixcompiler.IxSourceDeclaration.h"
#include "ixcompiler.IxSourceExpression.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.Token.h"

struct _IxSourceDeclaration
{
    bool                invalid;
    bool                hasExpression;

    String*             name;
    IxSourceType*       type;
    IxSourceExpression* expression;
};

static void IxSourceDeclaration_parse( IxSourceDeclaration* self, const Node* varNode );
```

```c/ixcompiler.IxSourceDeclaration.c
IxSourceDeclaration* IxSourceDeclaration_new( const Node* varNode )
{
    IxSourceDeclaration* self = Platform_Alloc( sizeof(IxSourceDeclaration) );
    if ( self )
    {
        IxSourceDeclaration_parse( self, varNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceDeclaration.c
IxSourceDeclaration* IxSourceDeclaration_free( IxSourceDeclaration** self )
{
    if ( *self )
    {
        String_free            ( &(*self)->name       );
        IxSourceType_free      ( &(*self)->type       );
        IxSourceExpression_free( &(*self)->expression );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceDeclaration.c
const String* IxSourceDeclaration_getName( const IxSourceDeclaration* self )
{
    return self->name;
}
```

```c/ixcompiler.IxSourceDeclaration.c
const IxSourceType* IxSourceDeclaration_getType( const IxSourceDeclaration* self )
{
    return self->type;
}
```

```c/ixcompiler.IxSourceDeclaration.c
const IxSourceExpression* IxSourceDeclaration_getExpression( const IxSourceDeclaration* self )
{
    return self->expression;
}
```

```c/ixcompiler.IxSourceDeclaration.c
bool IxSourceDeclaration_hasExpression( const IxSourceDeclaration* self )
{
    return self->hasExpression;
}
```

```c/ixcompiler.IxSourceDeclaration.c
static void IxSourceDeclaration_parse( IxSourceDeclaration* self, const Node* varNode )
{
    bool invalid = TRUE;
    {
        NodeIterator* it = Node_iterator( varNode );

        if ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
        {
            self->name = NodeIterator_nextTokenString( it );

            if ( NodeIterator_hasNonWhitespaceOfType( it, OFTYPE ) )
            {
                NodeIterator_next( it );

                if
                (
                    NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE )
                    ||
                    NodeIterator_hasNonWhitespaceOfType( it, WORD )
                )
                {
                    String* type = NodeIterator_nextTokenString( it );
                    self->type = IxSourceType_new( type );
                    String_free( &type );

                    if ( NodeIterator_hasNonWhitespaceOfType( it, ASSIGNMENTOP ) )
                    {
                        self->hasExpression = TRUE;
                        self->expression = IxSourceExpression_new( NodeIterator_next( it ) );
                    }
                    invalid = FALSE;
                }
            }
        }
    }
    self->invalid = invalid;
}
```

### Ix Source Expression

An expression evaluates to a result.
For example the expression 1 + 1 evaluates to 2.
In programming languages,
expressions can also involve the invocation of functions
and the results of the functions can be passed to functions.
For example,

```
div( max( c ) + max( d ), 2 )
```

As an ?expression tree?

```
div()
    +
    max()
        c
    max()
        c
```

```!include/ixcompiler.IxSourceExpression.h
#ifndef IXCOMPILER_IXSOURCEEXPRESSION_H
#define IXCOMPILER_IXSOURCEEXPRESSION_H

#include "ix.h"
#include "ixcompiler.h"

IxSourceExpression* IxSourceExpression_new( const Node* firstNode );

IxSourceExpression*       IxSourceExpression_free              (       IxSourceExpression** self );
bool                      IxSourceExpression_isValue           ( const IxSourceExpression*  self );
bool                      IxSourceExpression_hasPrefixOperator ( const IxSourceExpression*  self );
bool                      IxSourceExpression_hasInfixOperator  ( const IxSourceExpression*  self );
bool                      IxSourceExpression_hasPostfixOperator( const IxSourceExpression*  self );
const String*             IxSourceExpression_getValue          ( const IxSourceExpression*  self );
const String*             IxSourceExpression_getPrefixOperator ( const IxSourceExpression*  self );
const IxSourceExpression* IxSourceExpression_getLeftExpression ( const IxSourceExpression*  self );
const String*             IxSourceExpression_getInfixOperator  ( const IxSourceExpression*  self );
const IxSourceExpression* IxSourceExpression_getRightExpression( const IxSourceExpression*  self );
const String*             IxSourceExpression_getPostfixOperator( const IxSourceExpression*  self );

#endif
```

```!c/ixcompiler.IxExpression.c
#include "ixcompiler.IxSourceExpression.h"
#include "ixcompiler.Token.h"

struct _IxSourceExpression
{
    bool                     invalid;
    bool                     isValue;
    String*                  value;
    String*                  prefixOperator;
    IxSourceExpression*      leftExpression;
    String*                  infixOperator;
    IxSourceExpression*      rightExpression;
    String*                  postfixOperator;
};

void IxSourceExpression_parse( IxSourceExpression* self, const Node* firstNode );
```

```c/ixcompiler.IxExpression.c
IxSourceExpression* IxSourceExpression_new( const Node* firstNode )
{
    IxSourceExpression* self = Platform_Alloc( sizeof(IxSourceExpression) );
    {
        IxSourceExpression_parse( self, firstNode );
    }
    return self;
}
```

```c/ixcompiler.IxExpression.c
IxSourceExpression* IxSourceExpression_free( IxSourceExpression** self )
{
    if ( *self )
    {
        String_free            ( &(*self)->value           );
        String_free            ( &(*self)->prefixOperator  );
        String_free            ( &(*self)->infixOperator   );
        String_free            ( &(*self)->postfixOperator );
        IxSourceExpression_free( &(*self)->leftExpression  );
        IxSourceExpression_free( &(*self)->rightExpression );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxExpression.c
bool IxSourceExpression_isValue( const IxSourceExpression* self )
{
    return (null != self->value);
}
```

```c/ixcompiler.IxExpression.c
bool IxSourceExpression_hasPrefixOperator( const IxSourceExpression* self )
{
    return (null != self->prefixOperator);
}
```
```c/ixcompiler.IxExpression.c
bool IxSourceExpression_hasInfixOperator( const IxSourceExpression* self )
{
    return (null != self->infixOperator);
}

```c/ixcompiler.IxExpression.c
bool IxSourceExpression_hasPostfixOperator( const IxSourceExpression* self )
{
    return (null != self->postfixOperator);
}
```

```c/ixcompiler.IxExpression.c
const String* IxSourceExpression_getValue( const IxSourceExpression* self )
{
    return self->value;
}
```

```c/ixcompiler.IxExpression.c
const String* IxSourceExpression_getPrefixOperator( const IxSourceExpression* self )
{
    return self->prefixOperator;
}
```

```c/ixcompiler.IxExpression.c
const IxSourceExpression* IxSourceExpression_getLeftExpression( const IxSourceExpression* self )
{
    return self->leftExpression;
}
```

```c/ixcompiler.IxExpression.c
const String* IxSourceExpression_getInfixOperator( const IxSourceExpression* self )
{
    return self->infixOperator;
}
```

```c/ixcompiler.IxExpression.c
const IxSourceExpression* IxSourceExpression_getRightExpression( const IxSourceExpression* self )
{
    return self->rightExpression;
}
```

```c/ixcompiler.IxExpression.c
const String* IxSourceExpression_getPostfixOperator( const IxSourceExpression* self )
{
    return self->postfixOperator;
}
```

```c/ixcompiler.IxExpression.c
void IxSourceExpression_parse( IxSourceExpression* self, const Node* firstNode )
{

    
}
```

    NodeIterator* it = Node_iterator( firstNode );

    //  Parse left value
    if ( NodeIterator_hasNonWhitespace( it ) )
    {
        //  Parse prefix
        const Node*  next  = NodeIterator_next( it );
        const Token* token = Node_getToken( next );
        const char*  value = Token_getContent( first );

        switch ( Token_getTokenType( token ) )
        {
        case PREFIXOP:
            self->prefixOperator = String_new( value );
            break;

        case INSTANCEMEMBER:
        case CLASSMEMBER:
            self->prefixOperator = String_new( value );
            break;

        case INFIXOP:
            self->invalid = TRUE;
            break;

        case POSTFIXOP:
            self->invalid = TRUE;
            break;

        case WORD:
            self->value = String_new( value );
            break;

        default:
            self->invalid = TRUE;
        }

        if ( !self->invalid && !self->value && NodeIterator_hasNonWhitespace( it ) )
        {
            const Node*  secondNode = NodeIterator_next( it );
            const Token* second     = Node_getToken( secondNode );

            switch ( Token_getTokenType( second ) )
            {
            case WORD:
                self->value = String_new( value );
                break;

            default:
                self->invalid = TRUE;
            }

            if ( !self->invalid && self->value && NodeIterator_hasNonWhitespace( it ) )
            {
                const Node*  secondNode = NodeIterator_next( it );
                const Token* second     = Node_getToken( secondNode );

                switch ( Token_getTokenType( second ) )
                {
                case PREFIXOP:
                    self->invalid = TRUE;
                    break;

                case POSTFIXOP:
                    self->postfixOperator = String_new( value );
                    break;

                case INFIXOP:

                    self->infixOperator = String_new( value );
                    IxSourceExpression_parse
                    break;

                }

        //  Parse value
        if ( !self->value && NodeIterator_hasNonWhitespace( it ) )
        {
            const Node*  secondNode = NodeIterator_next( it );
            const Token* second     = Node_getToken( secondNode );

            switch ( Token_getTokenType( second ) )
            {
            case PREFIXOP:
            case POSTFIXOP:
                self->invalid = TRUE;
                break;

            case INFIXOP:
                self->infixOperator = String_new( value );
                break;

            case WORD:
                self->value = String_new( value );
                break;
            
            default:
                self->invalid = TRUE;
            }

            if ( NodeIterator_hasNonWhitespace( it ) )
            {
                const Node*  thirdNode = NodeIterator_next( it );
                const Token* third     = Node_getToken( thirdNode );

                switch ( Token_getTokenType( third ) )
                {
                case PREFIXOP:
                case INFIXOP:
                    self->invalid = TRUE;
                    break;

                case POSTFIXOP:
                    self->postfixOperator = String_new( value );
                    break;

                case WORD:
                    self->value = String_new( value );
                    break;
                
                default:
                    self->invalid = TRUE;
                }
            }
        }
    }
    NodeIterator_free( _it );
}
```




### Ix Source Method

```!include/ixcompiler.IxSourceFunction.h
#ifndef IXCOMPILER_IXSOURCEFUNCTION_H
#define IXCOMPILER_IXSOURCEFUNCTION_H

#include "ixcompiler.h"

IxSourceFunction* IxSourceFunction_new();
IxSourceFunction* IxSourceFunction_free( IxSourceFunction** self );

#endif
```

```!c/ixcompiler.IxSourceFunction.c
#include "ixcompiler.IxSourceFunction.h"

struct _IxSourceFunction
{
    String*                   modifier;     //  public
    String*                   methodName;   //  getSomething
    ArrayOfIxSourceParameter* parameters;   //  ( name: Type*, size: int )
    String*                   returnType;   //  String*
    ArrayOfIxSourceStatement* statements;   //  ...
};
```

```c/ixcompiler.IxSourceFunction.c
IxSourceFunction* IxSourceFunction_new()
{
    IxSourceFunction* self = Platform_Alloc( sizeof( IxSourceFunction ) );
    if ( self )
    {



    }
    return self;
}
```

```c/ixcompiler.IxSourceFunction.c
IxSourceFunction* IxSourceFunction_free( IxSourceFunction** self )
{
    if ( *self )
    {
        Platform_Free( self );
    }
    return *self;
}
```



### Ix Source Comment

```!include/ixcompiler.IxSourceHeader.h
#ifndef IXCOMPILER_IXSOURCEHEADER_H
#define IXCOMPILER_IXSOURCEHEADER_H

#include "ixcompiler.h"

IxSourceHeader* IxSourceHeader_new ( const char* keyword, const char* freeform_text );

IxSourceHeader* IxSourceHeader_free      (       IxSourceHeader** self );
const char*     IxSourceHeader_getKeyword( const IxSourceHeader*  self );
const char*     IxSourceHeader_getText   ( const IxSourceHeader*  self );

#endif
```

```!c/ixcompiler.IxSourceHeader.c
#include "ixcompiler.IxSourceHeader.h"

struct _IxSourceHeader
{
    String* keyword;
    String* text;
};
```

```c/ixcompiler.IxSourceHeader.c
IxSourceHeader* IxSourceHeader_new( const char* keyword, const char* freeform_text )
{
    IxSourceHeader* self = Platform_Alloc( sizeof( IxSourceHeader ) );
    if ( self )
    {
        self->keyword = String_new( keyword       );
        self->text    = String_new( freeform_text );
    }
    return self;
}
```

```c/ixcompiler.IxSourceHeader.c
IxSourceHeader* IxSourceHeader_free( IxSourceHeader** self )
{
    if ( *self )
    {
        String_free  ( &(*self)->keyword );
        String_free  ( &(*self)->text    );
        Platform_Free(    self           );
    }
    return *self;
}
```

```!include/ixcompiler.IxSourceInterface.h
#ifndef IXCOMPILER_IXSOURCEINTERFACE_H
#define IXCOMPILER_IXSOURCEINTERFACE_H

#include "ixcompiler.h"

IxSourceInterface* IxSourceInterface_new( const Node* startNode );

IxSourceInterface* IxSourceInterface_free( IxSourceInterface** self );

#endif
```

```!c/ixcompiler.IxSourceInterface.c
#include "ixcompiler.IxSourceInterface.h"

struct _IxSourceInterface
{
    String* name;
};
```

```c/ixcompiler.IxSourceInterface.c
IxSourceInterface* IxSourceInterface_new( const Node* startNode )
{
    IxSourceInterface* self = Platform_Alloc( sizeof(IxSourceInterface) );
    {
        self->name = String_new( "" );
    }
    return self;
}
```

```c/ixcompiler.IxSourceInterface.c
IxSourceInterface* IxSourceInterface_free( IxSourceInterface** self )
{
    if ( *self )
    {
        String_free( &(*self)->name );

        Platform_Free( self );
    }
    return *self;
}
```

### Ix Source Member

```!include/ixcompiler.IxSourceMember.h
#ifndef IXCOMPILER_IXSOURCEMEMBER_H
#define IXCOMPILER_IXSOURCEMEMBER_H

#include "ixcompiler.h"

IxSourceMember* IxSourceMember_new( const Node* prefixNode );

IxSourceMember*     IxSourceMember_free(                  IxSourceMember** self );
bool                IxSourceMember_isInvalid      ( const IxSourceMember*  self );
bool                IxSourceMember_isInstance     ( const IxSourceMember*  self );
const String*       IxSourceMember_getName        ( const IxSourceMember*  self );
const IxSourceType* IxSourceMember_getType        ( const IxSourceMember*  self );
const String*       IxSourceMember_getDefaultValue( const IxSourceMember*  self );

#endif
```

```!c/ixcompiler.IxSourceMember.c
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceMember.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.Token.h"

struct _IxSourceMember
{
    bool          invalid;
    bool          isInstance;
    String*       prefix;
    String*       name;
    String*       oftype;
    IxSourceType* type;
    String*       equals;
    String*       defaultValue;
};

static void IxSource_Unit_parseMember( IxSourceMember* self, const Node* prefixNode );
```

```c/ixcompiler.IxSourceMember.c
IxSourceMember* IxSourceMember_new( const Node* prefixNode )
{
    IxSourceMember* self = Platform_Alloc( sizeof( IxSourceMember ) );
    if ( self )
    {
        self->prefix = String_new( "" );
        self->name   = String_new( "" );
        self->oftype = String_new( "" );
        self->type   = IxSourceType_new( self->oftype );
        self->equals = String_new( "" );
        self->defaultValue = String_new( "" );

        IxSource_Unit_parseMember( self, prefixNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceMember.c
IxSourceMember* IxSourceMember_free( IxSourceMember** self )
{
    if ( *self )
    {
        String_free      ( &(*self)->name         );
        IxSourceType_free( &(*self)->type         );
        String_free      ( &(*self)->defaultValue );
        Platform_Free    (    self                );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceMember.c
bool IxSourceMember_isInvalid( const IxSourceMember* self )
{
    return self->invalid;
}
```

```c/ixcompiler.IxSourceMember.c
bool IxSourceMember_isInstance( const IxSourceMember* self )
{
    return self->isInstance;
}
```

```c/ixcompiler.IxSourceMember.c
const String* IxSourceMember_getName( const IxSourceMember* self )
{
    return self->name;
}
```

```c/ixcompiler.IxSourceMember.c
const IxSourceType* IxSourceMember_getType( const IxSourceMember* self )
{
    return self->type;
}
```

```c/ixcompiler.IxSourceMember.c
const String* IxSourceMember_getDefaultValue( const IxSourceMember* self )
{
    return self->defaultValue;
}
```

```c/ixcompiler.IxSourceMember.c
static void IxSource_Unit_parseMember( IxSourceMember* self, const Node* prefixNode )
{
    //  SYMBOL(prefix)
    {
        const Token*  token = Node_getToken     ( prefixNode );
        EnumTokenType type  = Token_getTokenType( token      );
        const char*   value = Token_getContent  ( token      );

        switch ( type )
        {
        case INSTANCEMEMBER:
            self->isInstance = TRUE;
        case CLASSMEMBER:
            self->prefix = String_new( value );
            break;
        
        default:
            self->invalid = TRUE;
        }
    }

    NodeIterator* it = Node_iterator( prefixNode );
    
    //  name
    if ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
    {
        String_free( &self->name );
        self->name = String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) );
    }
    else
    {
        self->invalid = TRUE;
    }

    //  operator
    if ( NodeIterator_hasNonWhitespaceOfType( it, OFTYPE ) )
    {
        String_free( &self->oftype );
        self->oftype = String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) );
    }
    else
    {
        self->invalid = TRUE;
    }

    //  type
    if
    (
        NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE )
        ||
        NodeIterator_hasNonWhitespaceOfType( it, WORD )
    )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node );

        String* type_name = String_new( Token_getContent( token ) );
        {
            IxSourceType_free( &self->type );
            self->type = IxSourceType_new( type_name );
        }
        String_free( &type_name );

        if ( NodeIterator_hasNonWhitespaceOfType( it, STARTSUBSCRIPT ) )
        {
            NodeIterator_next( it );
            IxSourceType_setAsArray( self->type, TRUE );

            if ( NodeIterator_hasNonWhitespaceOfType( it, ENDSUBSCRIPT ) )
            {
                NodeIterator_next( it );
            }
            else
            {
                self->invalid = TRUE;
            }
        }

        if ( NodeIterator_hasNonWhitespaceOfType( it, INFIXOP ) )
        {
            const Token* token   = Node_getToken( NodeIterator_next( it ) );
            const char*  content = Token_getContent( token );

            switch ( content[0] )
            {
            case '*':
                IxSourceType_setAsPointer( self->type, TRUE );
                break;
            
            case '&':
                IxSourceType_setAsReference( self->type, TRUE );
                break;
            }
        }

        if ( NodeIterator_hasNonWhitespaceOfType( it, ASSIGNMENTOP ) )
        {
            const Token* token = Node_getToken( NodeIterator_next( it ) );
            self->equals = String_new( Token_getContent( token ) );
        }

        if ( NodeIterator_hasNonWhitespace( it ) )
        {
            const Token* token = Node_getToken( NodeIterator_next( it ) );
            self->defaultValue = String_new( Token_getContent( token ) );
        }
    }
}
```

### Ix Source Method

```!include/ixcompiler.IxSourceMethod.h
#ifndef IXCOMPILER_IXSOURCEMETHOD_H
#define IXCOMPILER_IXSOURCEMETHOD_H

#include "ixcompiler.h"

IxSourceMethod* IxSourceMethod_new( const IxSourceUnit* sourceUnit, const Node* modifierNode );

IxSourceMethod*          IxSourceMethod_free             (       IxSourceMethod** self );
const IxSourceUnit*      IxSourceMethod_getSourceUnit    ( const IxSourceMethod*  self );
const IxSourceSignature* IxSourceMethod_getSignature     ( const IxSourceMethod*  self );
const char*              IxSourceMethod_getAccessModifier( const IxSourceMethod*  self );
const char*              IxSourceMethod_getConst         ( const IxSourceMethod*  self );
const char*              IxSourceMethod_getMethodName    ( const IxSourceMethod*  self );
const Array*             IxSourceMethod_getParameters    ( const IxSourceMethod*  self );
const char*              IxSourceMethod_getReturnType    ( const IxSourceMethod*  self );
const IxSourceBlock*     IxSourceMethod_getMethodBlock   ( const IxSourceMethod*  self );
const Array*             IxSourceMethod_getStatements    ( const IxSourceMethod*  self );

#endif
```

```!c/ixcompiler.IxSourceMethod.c
#include "ix.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceBlock.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceParameter.h"
#include "ixcompiler.IxSourceSignature.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.Token.h"

struct _IxSourceMethod
{
    bool                      invalid;
    const IxSourceUnit*       sourceUnit;
    IxSourceSignature*        signature;
    IxSourceBlock*            methodBlock;
};

void IxSourceMethod_parseModifier  ( IxSourceMethod* self, const Node* modifierNode   );
void IxSourceMethod_parseMethodName( IxSourceMethod* self, const Node* methodNameNode );
void IxSourceMethod_parseStatements( IxSourceMethod* self, const Node* startBlockNode );
```

```c/ixcompiler.IxSourceMethod.c
IxSourceMethod* IxSourceMethod_new( const IxSourceUnit* sourceUnit, const Node* modifierNode )
{
    IxSourceMethod* self = Platform_Alloc( sizeof( IxSourceMethod ) );
    if ( self )
    {
        self->sourceUnit = sourceUnit;
        self->signature  = IxSourceSignature_new( sourceUnit, modifierNode );

        IxSourceMethod_parseModifier( self, modifierNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceMethod.c
IxSourceMethod* IxSourceMethod_free( IxSourceMethod** self )
{
    if ( *self )
    {
        IxSourceSignature_free( &(*self)->signature   );
        IxSourceBlock_free    ( &(*self)->methodBlock );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceMethod.c
const IxSourceUnit* IxSourceMethod_getSourceUnit( const IxSourceMethod* self )
{
    return self->sourceUnit;
}
```

```c/ixcompiler.IxSourceMethod.c
const IxSourceSignature* IxSourceMethod_getSignature( const IxSourceMethod* self )
{
    return self->signature;
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getAccessModifier( const IxSourceMethod* self )
{
    return String_content( IxSourceSignature_getAccessModifier( self->signature ) );
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getConst( const IxSourceMethod* self )
{
    return String_content( IxSourceSignature_getConst( self->signature ) );
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getMethodName( const IxSourceMethod* self )
{
    return String_content( IxSourceSignature_getMethodName( self->signature ) );
}
```

```c/ixcompiler.IxSourceMethod.c
const Array* IxSourceMethod_getParameters( const IxSourceMethod* self )
{
    return IxSourceSignature_getParameters( self->signature );
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getReturnType( const IxSourceMethod* self )
{
    return String_content( IxSourceType_getName( IxSourceSignature_getReturnType( self->signature ) ) );
}
```

```c/ixcompiler.IxSourceMethod.c
const IxSourceBlock* IxSourceMethod_getMethodBlock( const IxSourceMethod* self )
{
    return self->methodBlock;
}
```

```c/ixcompiler.IxSourceMethod.c
const Array* IxSourceMethod_getStatements( const IxSourceMethod* self )
{
    return (self->methodBlock) ? IxSourceBlock_getStatements( self->methodBlock ) : null;
}
```

```c/ixcompiler.IxSourceMethod.c
void IxSourceMethod_parseModifier( IxSourceMethod* self, const Node* modifierNode )
{
    const Token* token = Node_getToken( modifierNode );
    
    if ( MODIFIER != Token_getTokenType( token ) )
    {
        self->invalid = TRUE;
    }

    NodeIterator* it = Node_iterator( modifierNode );

    //  const (optional)
    if ( NodeIterator_hasNonWhitespaceOfType( it, KEYWORD ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node );

        if ( ! String_Equals( "const", Token_getContent( token ) ) )
        {
            self->invalid = TRUE;
        }
    }

    //  name
    if ( !NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
    {
        self->invalid = TRUE;
    }
    else
    {
        const Node* next = NodeIterator_next( it );
        IxSourceMethod_parseMethodName( self, next );
    }
}
```

```c/ixcompiler.IxSourceMethod.c
void IxSourceMethod_parseMethodName( IxSourceMethod* self, const Node* methodNameNode )
{
    NodeIterator* it = Node_iterator( methodNameNode );

    //  (   (startexpression)
    if ( NodeIterator_hasNonWhitespaceOfType( it, STARTEXPRESSION ) )
    {
        NodeIterator_next( it );

        if ( NodeIterator_hasNonWhitespaceOfType( it, OFTYPE ) )
        {
            NodeIterator_next( it );

            if ( NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE ) || NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
            {
                NodeIterator_next( it );
            }
            else
            {
                self->invalid = TRUE;
            }
        }
        else
        {
            self->invalid = TRUE;
        }

        if ( NodeIterator_hasNonWhitespaceOfType( it, STARTBLOCK ) )
        {
            const Node* next = NodeIterator_next( it );

            self->methodBlock = IxSourceBlock_new( next );
        }
        else
        {
            self->invalid = TRUE;
        }
    }
    else
    {
        self->invalid = TRUE;
    }
}
```

### Ix Source Parameter

```!include/ixcompiler.IxSourceParameter.h
#ifndef IXCOMPILER_IXSOURCEPARAMETER_H
#define IXCOMPILER_IXSOURCEPARAMETER_H

#include "ixcompiler.h"

IxSourceParameter* IxSourceParameter_new( const Node* wordNode );

IxSourceParameter*  IxSourceParameter_free           (       IxSourceParameter** self );
const String*       IxSourceParameter_getName        ( const IxSourceParameter*  self );
const IxSourceType* IxSourceParameter_getType        ( const IxSourceParameter*  self );
const String*       IxSourceParameter_getDefaultValue( const IxSourceParameter*  self );

#endif
```

```!c/ixcompiler.IxSourceParameter.c
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceParameter.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.Token.h"

struct _IxSourceParameter
{
    bool          invalid;
    String*       name;
    String*       oftype;
    IxSourceType* type;
    String*       defaultValue;
};

void parseWordNode( IxSourceParameter* self, const Node* wordNode );
```

```c/ixcompiler.IxSourceParameter.c
IxSourceParameter* IxSourceParameter_new( const Node* wordNode )
{
    IxSourceParameter* self = Platform_Alloc( sizeof( IxSourceParameter ) );
    if ( self )
    {
        self->name         = String_new( "" );
        self->oftype       = String_new( "" );
        self->type         = IxSourceType_new( self->oftype );
        self->defaultValue = String_new( "" );

        parseWordNode( self, wordNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceParameter.c
IxSourceParameter* IxSourceParameter_free( IxSourceParameter** self )
{
    if ( *self )
    {
        String_free      ( &(*self)->name         );
        String_free      ( &(*self)->oftype       );
        IxSourceType_free( &(*self)->type         );
        String_free      ( &(*self)->defaultValue );
        Platform_Free    (    self                );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceParameter.c
const String* IxSourceParameter_getName( const IxSourceParameter* self )
{
    return self->name;
}
```

```c/ixcompiler.IxSourceParameter.c
const IxSourceType* IxSourceParameter_getType( const IxSourceParameter* self )
{
    return self->type;
}
```

```c/ixcompiler.IxSourceParameter.c
const String* IxSourceParameter_getDefaultValue( const IxSourceParameter* self )
{
    return self->defaultValue;
}
```

```c/ixcompiler.IxSourceParameter.c
void parseWordNode( IxSourceParameter* self, const Node* wordNode )
{
    const Token* token = Node_getToken( wordNode );

    if ( WORD == Token_getTokenType( token ) )
    {
        String_free( &self->name );
        self->name = String_new( Token_getContent( token ) );

        NodeIterator* it = Node_iterator( wordNode );
        if ( NodeIterator_hasNonWhitespaceOfType( it, OFTYPE ) )
        {
            self->oftype = String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) );

            if
            (
                NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE )
            ||  NodeIterator_hasNonWhitespaceOfType( it, WORD      )
            )
            {
                self->type = IxSourceType_new( String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) ) );
            }
            else
            {
                self->invalid = TRUE;
            }

            if ( NodeIterator_hasNonWhitespaceOfType( it, STARTSUBSCRIPT ) )
            {
                NodeIterator_next( it );
                IxSourceType_setAsArray( self->type, TRUE );

                if ( NodeIterator_hasNonWhitespaceOfType( it, ENDSUBSCRIPT ) )
                {
                    NodeIterator_next( it );
                }
                else
                {
                    self->invalid = TRUE;
                }
            }

            if ( NodeIterator_hasNonWhitespaceOfType( it, INFIXOP ) )
            {
                const Token* token   = Node_getToken( NodeIterator_next( it ) );
                const char*  content = Token_getContent( token );

                switch ( content[0] )
                {
                case '*':
                    IxSourceType_setAsPointer( self->type, TRUE );
                    break;
                
                case '&':
                    IxSourceType_setAsReference( self->type, TRUE );
                    break;
                }
            }
        }
        else
        {
            self->invalid = TRUE;
        }
    }
    else
    {
        self->invalid = TRUE;
    }
}
```

### Ix Source Signature

```!include/ixcompiler.IxSourceSignature.h
#ifndef IXCOMPILER_IXSOURCESIGNATURE_H
#define IXCOMPILER_IXSOURCESIGNATURE_H

#include "ixcompiler.h"

IxSourceSignature* IxSourceSignature_new( const IxSourceUnit* sourceUnit, const Node* accessModifierNode );

IxSourceSignature*    IxSourceSignature_free             (       IxSourceSignature** self );
//const IxSourceMethod* IxSourceSignature_getMethod        ( const IxSourceSignature*  self );
const String*         IxSourceSignature_getAccessModifier( const IxSourceSignature*  self );
const String*         IxSourceSignature_getConst         ( const IxSourceSignature*  self );
bool                  IxSourceSignature_isConst          ( const IxSourceSignature*  self );
bool                  IxSourceSignature_isClass          ( const IxSourceSignature*  self );
const String*         IxSourceSignature_getMethodName    ( const IxSourceSignature*  self );
const Array*          IxSourceSignature_getParameters    ( const IxSourceSignature*  self );
const IxSourceType*   IxSourceSignature_getReturnType    ( const IxSourceSignature*  self );
String*               IxSourceSignature_generateName     ( const IxSourceSignature*  self, const char* prefix );
const IxSourceUnit*   IxSourceSignature_getSourceUnit    ( const IxSourceSignature*  self );

#endif
```

```!c/ixcompiler.IxSourceSignature.c
#include "ix.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceParameter.h"
#include "ixcompiler.IxSourceSignature.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.Token.h"

struct _IxSourceSignature
{
    const IxSourceUnit*       sourceUnit;
    bool                      invalid;
    bool                      isConst;
    bool                      isClass;
    String*                   modifier;     //  public
    String*                   konst;        //  const
    String*                   methodName;   //  getSomething
    Array*                    parameters;   //  ( name: Type*, size: int )
    String*                   oftype;       //  :
    IxSourceType*             returnType;   //  String*
};

void IxSourceSignature_parseModifier    ( IxSourceSignature* self, const Node* modifierNode );
void IxSourceSignature_parseNameChildren( IxSourceSignature* self, const Node* nameNode     );
void IxSourceSignature_parseParameters  ( IxSourceSignature* self, const Node* startNode    );
```

```c/ixcompiler.IxSourceSignature.c
IxSourceSignature* IxSourceSignature_new( const IxSourceUnit* sourceUnit, const Node* accessModifierNode )
{
    IxSourceSignature* self = Platform_Alloc( sizeof( IxSourceSignature ) );
    if ( self )
    {
        self->sourceUnit = sourceUnit;
        self->modifier   = String_new( "" );
        self->konst      = String_new( "" );
        self->methodName = String_new( "" );
        self->parameters = Array_new_destructor( (Destructor) IxSourceSignature_free );
        self->oftype     = String_new( "" );
        self->returnType = IxSourceType_new( String_new( "" ) );

        IxSourceSignature_parseModifier( self, accessModifierNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceSignature.c
IxSourceSignature* IxSourceSignature_free( IxSourceSignature** self )
{
    if ( *self )
    {
        String_free      ( &(*self)->modifier   );
        String_free      ( &(*self)->konst      );
        String_free      ( &(*self)->methodName );
        Array_free       ( &(*self)->parameters );
        String_free      ( &(*self)->oftype     );
        IxSourceType_free( &(*self)->returnType );
        Platform_Free    (    self              );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceSignature.c
const String* IxSourceSignature_getAccessModifier( const IxSourceSignature* self )
{
    return self->modifier;
}
```

```c/ixcompiler.IxSourceSignature.c
const String* IxSourceSignature_getConst( const IxSourceSignature* self )
{
    return self->konst;
}
```

```c/ixcompiler.IxSourceSignature.c
bool IxSourceSignature_isConst( const IxSourceSignature* self )
{
    return self->isConst;
}
```

```c/ixcompiler.IxSourceSignature.c
bool IxSourceSignature_isClass( const IxSourceSignature* self )
{
    return self->isClass;
}
```

```c/ixcompiler.IxSourceSignature.c
const String* IxSourceSignature_getMethodName( const IxSourceSignature* self )
{
    return self->methodName;
}
```

```c/ixcompiler.IxSourceSignature.c
const Array* IxSourceSignature_getParameters( const IxSourceSignature* self )
{
    return self->parameters;
}
```

```c/ixcompiler.IxSourceSignature.c
const IxSourceType* IxSourceSignature_getReturnType( const IxSourceSignature* self )
{
    return self->returnType;
}
```

```c/ixcompiler.IxSourceSignature.c
String* IxSourceSignature_generateName( const IxSourceSignature* self, const char* prefix )
{
    String* name = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            StringBuffer_append( sb, prefix );
            StringBuffer_append( sb, "_" );
            StringBuffer_append( sb, String_content( IxSourceSignature_getMethodName( self ) ) );

            name = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }

    return name;
}
```

```c/ixcompiler.IxSourceSignature.c
const IxSourceUnit* IxSourceSignature_getSourceUnit( const IxSourceSignature* self )
{
    return self->sourceUnit;
}
```

```c/ixcompiler.IxSourceSignature.c
void IxSourceSignature_parseModifier( IxSourceSignature* self, const Node* modifierNode )
{
    const Token* token = Node_getToken( modifierNode );
    
    if ( MODIFIER != Token_getTokenType( token ) )
    {
        self->invalid = TRUE;
    }

    String_free( &self->modifier );
    self->modifier = String_new( Token_getContent( Node_getToken( modifierNode ) ) );

    NodeIterator* it = Node_iterator( modifierNode );

    //  const or class (optional)
    if ( NodeIterator_hasNonWhitespaceOfType( it, KEYWORD ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node );

        if ( String_Equals( "const", Token_getContent( token ) ) )
        {
            String_free( &(self->konst) );
            self->konst = String_new( Token_getContent( token ) );
            self->isConst = TRUE;
        }
        else
        if ( String_Equals( "class", Token_getContent( token ) ) )
        {
            self->isClass = TRUE;
        }
        else
        {
            self->invalid = TRUE;
        }
    }

    //  const or class (optional)
    if ( NodeIterator_hasNonWhitespaceOfType( it, KEYWORD ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node );

        if ( String_Equals( "const", Token_getContent( token ) ) )
        {
            String_free( &(self->konst) );
            self->konst = String_new( Token_getContent( token ) );
            self->isConst = TRUE;
        }
        else
        if ( String_Equals( "class", Token_getContent( token ) ) )
        {
            self->isClass = TRUE;
        }
        else
        {
            self->invalid = TRUE;
        }
    }

    //  name
    if ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node );

        String_free( &(self->methodName) );
        self->methodName = String_new( Token_getContent( token ) );

        IxSourceSignature_parseNameChildren( self, node );
    }
    else
    {
        self->invalid = TRUE;
    }
}
```

```c/ixcompiler.IxSourceSignature.c
void IxSourceSignature_parseNameChildren( IxSourceSignature* self, const Node* nameNode )
{
    NodeIterator* it = Node_iterator( nameNode );

    //  '(' START
    if ( NodeIterator_hasNonWhitespaceOfType( it, STARTEXPRESSION ) )
    {
        const Node* startNode = NodeIterator_next( it );
        IxSourceSignature_parseParameters( self, startNode );
    }
    else
    {
        self->invalid = TRUE;
    }

    if ( String_equals_chars( self->methodName, "new" ) )
    {
        self->returnType = IxSourceType_new( IxSourceUnit_getName( self->sourceUnit ) );
        IxSourceType_setAsPointer( self->returnType, TRUE );
    }
    else
    if ( NodeIterator_hasNonWhitespaceOfType( it, OFTYPE ) )
    {
        String_free( &(self->oftype) );
        self->oftype = String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) );

        if ( NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE ) || NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
        {
            IxSourceType_free( &(self->returnType) );
            self->returnType = IxSourceType_new( String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) ) );
        }
        else
        {
            self->invalid = TRUE;
        }
    }
}
```

```c/ixcompiler.IxSourceSignature.c
void IxSourceSignature_parseParameters( IxSourceSignature* self, const Node* startNode )
{
    NodeIterator* it = Node_iterator( startNode );

    while ( NodeIterator_hasNonWhitespaceOfType( it, WORD ) )
    {
        const Node* wordNode = NodeIterator_next( it );

        Array_push( self->parameters, Give( IxSourceParameter_new( wordNode ) ) );
    }
}
```

### Ix Source Statement

```!include/ixcompiler.IxSourceStatement.h
#ifndef IXCOMPILER_IXSOURCESTATEMENT_H
#define IXCOMPILER_IXSOURCESTATEMENT_H

#include "ixcompiler.h"

IxSourceStatement* IxSourceStatement_new( const Node* aNode );

IxSourceStatement*         IxSourceStatement_free          (       IxSourceStatement** self );
const IxSourceBlock*       IxSourceStatement_getBlock      ( const IxSourceStatement*  self );
const IxSourceConditional* IxSourceStatement_getConditional( const IxSourceStatement*  self );
const IxSourceDeclaration* IxSourceStatement_getDeclaration( const IxSourceStatement*  self );
const IxSourceExpression*  IxSourceStatement_getExpression ( const IxSourceStatement*  self );
bool                       IxSourceStatement_isComplex     ( const IxSourceStatement*  self );
bool                       IxSourceStatement_isDeclaration ( const IxSourceStatement*  self );
bool                       IxSourceStatement_isExpression  ( const IxSourceStatement*  self );

#endif
```

```!c/ixcompiler.IxSourceStatement.c
#include "ix.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceBlock.h"
#include "ixcompiler.IxSourceConditional.h"
#include "ixcompiler.IxSourceDeclaration.h"
#include "ixcompiler.IxSourceExpression.h"
#include "ixcompiler.IxSourceStatement.h"
#include "ixcompiler.Token.h"

struct _IxSourceStatement
{
    bool                 invalid;
    bool                 isComplex;
    bool                 isDeclaration;
    bool                 isExpression;
    String*              statementType;
    IxSourceBlock*       block;
    IxSourceConditional* conditional;
    IxSourceDeclaration* declaration;
    IxSourceExpression*  expression;
};

void IxSourceStatement_parse( IxSourceStatement* self, const Node* firstNode );
```

```c/ixcompiler.IxSourceStatement.c
IxSourceStatement* IxSourceStatement_new( const Node* firstNode )
{
    IxSourceStatement* self = Platform_Alloc( sizeof(IxSourceStatement) );
    if ( self )
    {
        IxSourceStatement_parse( self, firstNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceStatement.c
IxSourceStatement* IxSourceStatement_free( IxSourceStatement** self )
{
    if ( *self )
    {
        String_free             ( &(*self)->statementType );
        IxSourceBlock_free      ( &(*self)->block         );
        IxSourceConditional_free( &(*self)->conditional   );
        IxSourceDeclaration_free( &(*self)->declaration   );
        IxSourceExpression_free ( &(*self)->expression    );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceStatement.c
const IxSourceBlock* IxSourceStatement_getBlock( const IxSourceStatement* self )
{
    return self->block;
}
```

```c/ixcompiler.IxSourceStatement.c
const IxSourceConditional* IxSourceStatement_getConditional( const IxSourceStatement* self )
{
    return self->conditional;
}
```

```c/ixcompiler.IxSourceStatement.c
const IxSourceDeclaration* IxSourceStatement_getDeclaration( const IxSourceStatement*  self )
{
    return self->declaration;
}
```

```c/ixcompiler.IxSourceStatement.c
const IxSourceExpression*  IxSourceStatement_getExpression ( const IxSourceStatement*  self )
{
    return self->expression;
}
```

```c/ixcompiler.IxSourceStatement.c
bool IxSourceStatement_isComplex( const IxSourceStatement* self )
{
    return self->isComplex;
}
```

```c/ixcompiler.IxSourceStatement.c
bool IxSourceStatement_isDeclaration( const IxSourceStatement* self )
{
    return self->isDeclaration;
}
```

```c/ixcompiler.IxSourceStatement.c
bool IxSourceStatement_isExpression( const IxSourceStatement* self )
{
    return self->isExpression;
}
```

```c/ixcompiler.IxSourceStatement.c
void IxSourceStatement_parse( IxSourceStatement* self, const Node* firstNode )
{
    const Token* token = Node_getToken( firstNode );
    const char*  value = Token_getContent( token );

    if ( Token_getTokenType( token ) == KEYWORD )
    {
        if ( String_Equals( value, "var" ) )
        {
            self->isDeclaration = TRUE;
            self->declaration   = IxSourceDeclaration_new( firstNode );
        }
        else
        if ( String_Equals( value, "return" ) )
        {
            self->isExpression = TRUE;
            self->expression   = IxSourceExpression_new( firstNode );
        }
        else
        {
            self->isComplex     = TRUE;
            self->statementType = String_new( Token_getContent( token ) );
            self->conditional   = IxSourceConditional_new( firstNode );

            NodeIterator* it = Node_iterator( firstNode );
            if ( NodeIterator_hasNonWhitespaceOfType( it, STARTEXPRESSION ) )
            {
                NodeIterator_next( it );
            }

            if ( NodeIterator_hasNonWhitespaceOfType( it, STARTBLOCK ) )
            {
                self->block = IxSourceBlock_new( NodeIterator_next( it ) );
            }
        }
    }
    else
    {
        self->isExpression = TRUE;
        self->expression   = IxSourceExpression_new( firstNode );
    }
}
```

```!include/ixcompiler.IxSourceSubExpression.h
#ifndef IXCOMPILER_IXSOURCESUBEXPRESSION_H
#define IXCOMPILER_IXSOURCESUBEXPRESSION_H

#include "ixcompiler.h"

IxSourceSubExpression* IxSourceSubExpression_new( const Node* startExpression );

IxSourceSubExpression* IxSourceSubExpression_free         (       IxSourceSubExpression** self );
IxSourceExpression*    IxSourceSubExpression_getExpression( const IxSourceSubExpression*  self );

#endif
```

```!c/ixcompiler.IxSourceSubExpression.c
#include "ixcompiler.IxSourceExpression.h"
#include "ixcompiler.IxSourceSubExpression.h"

struct _IxSourceSubExpression
{
    IxSourceExpression* expression;
};
```

```c/ixcompiler.IxSourceSubExpression.c
IxSourceSubExpression* IxSourceSubExpression_new( const Node* startExpression )
{
    IxSourceSubExpression* self = Platform_Alloc( sizeof(IxSourceSubExpression) );
    if ( self )
    {
        self->expression = IxSourceExpression_new( startExpression );
    }
    return self;
}
```

```c/ixcompiler.IxSourceSubExpression.c
IxSourceSubExpression* IxSourceSubExpression_free( IxSourceSubExpression** self )
{
    if ( *self )
    {
        IxSourceExpression_free( &(*self)->expression );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceSubExpression.c
IxSourceExpression* IxSourceSubExpression_getExpression( const IxSourceSubExpression* self )
{
    return self->expression;
}
```

### Ix Source Type

```!include/ixcompiler.IxSourceType.h
#ifndef IXCOMPILER_IXSOURCETYPE_H
#define IXCOMPILER_IXSOURCETYPE_H

#include "ixcompiler.h"

IxSourceType* IxSourceType_new( const String* name );

IxSourceType* IxSourceType_free          ( IxSourceType** self               );
void          IxSourceType_setAsArray    ( IxSourceType*  self, bool isArray );
void          IxSourceType_setAsConst    ( IxSourceType*  self, bool isArray );
void          IxSourceType_setAsFullName ( IxSourceType*  self, bool isArray );
void          IxSourceType_setAsPointer  ( IxSourceType*  self, bool isArray );
void          IxSourceType_setAsReference( IxSourceType*  self, bool isArray );

const String* IxSourceType_getName    ( const IxSourceType*  self );
bool          IxSourceType_isArray    ( const IxSourceType*  self );
bool          IxSourceType_isConst    ( const IxSourceType*  self );
bool          IxSourceType_isFullName ( const IxSourceType*  self );
bool          IxSourceType_isPointer  ( const IxSourceType*  self );
bool          IxSourceType_isPrimitive( const IxSourceType*  self );
bool          IxSourceType_isReference( const IxSourceType*  self );

#endif
```

```!c/ixcompiler.IxSourceType.c
#include "ixcompiler.IxSourceType.h"

struct _IxSourceType
{
    bool    isArray;
    bool    isConst;
    bool    isFullName;
    bool    isPointer;
    bool    isPrimitive;
    bool    isReference;
    String* name;
};

static bool IxSourceType_IsPrimitive( const String* name );
```

```c/ixcompiler.IxSourceType.c
IxSourceType* IxSourceType_new( const String* name )
{
    IxSourceType* self = Platform_Alloc( sizeof(IxSourceType) );
    if ( self )
    {
        self->name        = String_copy( name );
        self->isFullName  = String_contains_chars( name, "." );
        self->isPrimitive = IxSourceType_IsPrimitive( name );
    }
    return self;
}
```

```c/ixcompiler.IxSourceType.c
IxSourceType* IxSourceType_free( IxSourceType** self )
{
    if ( self )
    {
        String_free( &(*self)->name );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceType.c
void IxSourceType_setAsArray( IxSourceType* self, bool isArray )
{
    self->isArray = isArray;
}
```

```c/ixcompiler.IxSourceType.c
void IxSourceType_setAsConst( IxSourceType* self, bool isConst )
{
    self->isConst = isConst;
}
```

```c/ixcompiler.IxSourceType.c
void IxSourceType_setAsPointer( IxSourceType* self, bool isPointer )
{
    self->isPointer = isPointer;
}
```

```c/ixcompiler.IxSourceType.c
void IxSourceType_setAsReference( IxSourceType* self, bool isReference )
{
    self->isReference = isReference;
}
```

```c/ixcompiler.IxSourceType.c
const String* IxSourceType_getName( const IxSourceType* self )
{
    return self->name;
}
```

```c/ixcompiler.IxSourceType.c
bool IxSourceType_isArray( const IxSourceType* self )
{
    return self->isArray;
}
```

```c/ixcompiler.IxSourceType.c
bool IxSourceType_isConst( const IxSourceType* self )
{
    return self->isConst;
}
```

```c/ixcompiler.IxSourceType.c
bool IxSourceType_isFullName( const IxSourceType* self )
{
    return self->isFullName;
}
```

```c/ixcompiler.IxSourceType.c
bool IxSourceType_isPointer( const IxSourceType* self )
{
    return self->isPointer;
}
```

```c/ixcompiler.IxSourceType.c
bool IxSourceType_isPrimitive( const IxSourceType* self )
{
    return self->isPrimitive;
}
```

```c/ixcompiler.IxSourceType.c
bool IxSourceType_isReference( const IxSourceType* self )
{
    return self->isReference;
}
```

```c/ixcompiler.IxSourceType.c
static bool IxSourceType_IsPrimitive( const String* name )
{
    int len = String_getLength( name );

    switch( len )
    {
    case 3:
        return
            String_equals_chars( name, "int" );

    case 4:
        return
            String_equals_chars( name, "bool" ) ||
            String_equals_chars( name, "byte" ) ||
            String_equals_chars( name, "char" ) ||
            String_equals_chars( name, "long" ) ||
            String_equals_chars( name, "void" );

    case 5:
        return
            String_equals_chars( name, "float" ) ||
            String_equals_chars( name, "short" );

    case 6:
        return
            String_equals_chars( name, "double" );

    default:
        return FALSE;
    }
}
```

### IxSourceUnit

```!include/ixcompiler.IxSourceUnit.h
#ifndef IXCOMPILER_IXSOURCEUNIT_H
#define IXCOMPILER_IXSOURCEUNIT_H

#include "ixcompiler.h"

IxSourceUnit* IxSourceUnit_new( const AST* ast );

IxSourceUnit*                IxSourceUnit_free             (       IxSourceUnit** self );
const String*                IxSourceUnit_getName          ( const IxSourceUnit*  self );
const String*                IxSourceUnit_getPackage       ( const IxSourceUnit*  self );
const String*                IxSourceUnit_getFullName      ( const IxSourceUnit*  self );
const char*                  IxSourceUnit_getPrefix        ( const IxSourceUnit*  self );

const IxSourceClass*         IxSourceUnit_getClass         ( const IxSourceUnit*  self );
const ArrayOfString*         IxSourceUnit_getSignatures    ( const IxSourceUnit*  self );
const ArrayOfString*         IxSourceUnit_getCopyrightLines( const IxSourceUnit*  self );
const ArrayOfString*         IxSourceUnit_getLicenseLines  ( const IxSourceUnit*  self );
const Array*                 IxSourceUnit_getMethods       ( const IxSourceUnit*  self );

#endif
```

```!c/ixcompiler.IxSourceUnit.c
#include "ixcompiler.AST.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceClass.h"
#include "ixcompiler.IxSourceInterface.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"

struct _IxSourceUnit
{
    bool                       invalid;
    String*                    package;
    String*                    filename;
    String*                    name;
    String*                    extension;
    String*                    prefix;
    String*                    fullName;
    ArrayOfString*             copyrightLines;
    ArrayOfString*             licenseLines;
    IxSourceClass*             class;
    IxSourceInterface*         interface;
    Array*                     methods;
    Array*                     functions;
};

static void    init        ( IxSourceUnit* self, const AST* ast );
static void    initChildren( IxSourceUnit* self, const AST* ast );
static void    initPrefix  ( IxSourceUnit* self                 );
static void    initFullName( IxSourceUnit* self                 );
static String* CreateLine  ( const char* prefix, const Node* node );

```

```c/ixcompiler.IxSourceUnit.c
IxSourceUnit* IxSourceUnit_new( const AST* ast )
{
    IxSourceUnit* self = Platform_Alloc( sizeof( IxSourceUnit ) );
    if ( self )
    {
        init        ( self, ast );
        initChildren( self, ast );
        initPrefix  ( self      );
        initFullName( self      );
    }
    return self;
}
```

```c/ixcompiler.IxSourceUnit.c
IxSourceUnit* IxSourceUnit_free( IxSourceUnit** self )
{
    if ( *self )
    {
        String_free           ( &(*self)->package        );
        String_free           ( &(*self)->filename       );
        String_free           ( &(*self)->name           );
        String_free           ( &(*self)->extension      );
        String_free           ( &(*self)->prefix         );
        String_free           ( &(*self)->fullName       );
        ArrayOfString_free    ( &(*self)->copyrightLines );
        ArrayOfString_free    ( &(*self)->licenseLines   );
        IxSourceClass_free    ( &(*self)->class          );
        IxSourceInterface_free( &(*self)->interface      );
        Array_free            ( &(*self)->methods        );
        Array_free            ( &(*self)->functions      );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceUnit.c
const String* IxSourceUnit_getName( const IxSourceUnit* self )
{
    return self->name;
}
```

```c/ixcompiler.IxSourceUnit.c
const String* IxSourceUnit_getPackage( const IxSourceUnit* self )
{
    return self->package;
}
```

```c/ixcompiler.IxSourceUnit.c
const char* IxSourceUnit_getPrefix( const IxSourceUnit* self )
{
    return String_content( self->prefix );
}
```

```c/ixcompiler.IxSourceUnit.c
const String* IxSourceUnit_getFullName( const IxSourceUnit* self )
{
    return self->fullName;
}
```

```c/ixcompiler.IxSourceUnit.c
const IxSourceClass* IxSourceUnit_getClass( const IxSourceUnit* self )
{
    return self->class;
}
```

```c/ixcompiler.IxSourceUnit.c
const ArrayOfString* IxSourceUnit_getCopyrightLines( const IxSourceUnit* self )
{
    return self->copyrightLines;
}
```

```c/ixcompiler.IxSourceUnit.c
const ArrayOfString* IxSourceUnit_getLicenseLines( const IxSourceUnit* self )
{
    return self->licenseLines;
}
```

```c/ixcompiler.IxSourceUnit.c
const Array* IxSourceUnit_getMethods( const IxSourceUnit* self )
{
    return self->methods;
}
```

```c/ixcompiler.IxSourceUnit.c
static void init( IxSourceUnit* self, const AST* ast )
{
    String*        source_file_path = String_new( File_getFilePath( AST_getTokenizerFile( ast ) ) );
    ArrayOfString* parts            = String_split( source_file_path, '/' );
    int            len              = ArrayOfString_getLength( parts );

    self->package  = String_copy( ArrayOfString_getObject( parts, len - 2 ) );
    self->filename = String_copy( ArrayOfString_getObject( parts, len - 1 ) );

    ArrayOfString* bits = String_split( self->filename, '.' );
    self->name          = String_copy( ArrayOfString_getObject( bits, 0 ) );
    self->extension     = String_copy( ArrayOfString_getObject( bits, 1 ) );

    String_free       ( &source_file_path );
    ArrayOfString_free( &parts            );
    ArrayOfString_free( &bits             );
}
```

```c/ixcompiler.IxSourceUnit.c
static void initChildren( IxSourceUnit* self, const AST* ast )
{
    self->copyrightLines = ArrayOfString_new();
    self->licenseLines   = ArrayOfString_new();
    self->methods        = Array_new_destructor( (Destructor) IxSourceMethod_free );

    const Tree* tree = AST_getTree ( ast  );
    const Node* root = Tree_getRoot( tree );    

    String* copyright = String_new( "copyright" );
    String* license   = String_new( "license"   );
    String* class     = String_new( "class"     );
    String* method    = String_new( "method"    );

    NodeIterator* it = Node_iterator( root );
    while ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*   node  = NodeIterator_next( it );
        const String* tag   = Node_getTag( node );
        const Token*  token = Node_getToken( node );
        EnumTokenType type  = Token_getTokenType( token );

        if ( tag && String_equals( tag, copyright ) )
        {
            String* t = CreateLine( "", node );
            ArrayOfString_push( self->copyrightLines, &t );
        }
        else
        if ( tag && String_equals( tag, license ) )
        {
            ArrayOfString_push( self->licenseLines, (String**) Give( CreateLine( "", node ) ) );
        }
        else
        if ( tag && String_equals( tag, class ) )
        {
            if ( ! self->class )
            {
                self->class = IxSourceClass_new( node );
            }
            else
            {
                self->invalid = TRUE;
            }
        }
        else
        if ( tag && String_equals( tag, method ) )
        {
            Array_push( self->methods,  Give( IxSourceMethod_new( self, node ) ) );
        }
    }

    String_free( &copyright );
    String_free( &license   );
    String_free( &class     );
}
```

```c/ixcompiler.IxSourceUnit.c
static void initPrefix( IxSourceUnit* self )
{
    StringBuffer* sb  = StringBuffer_new();
    String*       pkg = String_replace( self->package, '.', '_' );
    {
        StringBuffer_append( sb, String_content( pkg ) );
        StringBuffer_append( sb, "_"                             );
        StringBuffer_append( sb, String_content( self->name    ) );

        self->prefix = String_new( StringBuffer_content( sb ) );
    }
    String_free      ( &pkg );
    StringBuffer_free( &sb  );
}
```

```c/ixcompiler.IxSourceUnit.c
static void initFullName( IxSourceUnit* self )
{
    StringBuffer* sb  = StringBuffer_new();
    {
        StringBuffer_append( sb, String_content( self->package ) );
        StringBuffer_append( sb, "."                             );
        StringBuffer_append( sb, String_content( self->name    ) );

        self->fullName = String_new( StringBuffer_content( sb ) );
    }
    StringBuffer_free( &sb  );
}
```

```c/ixcompiler.IxSourceUnit.c
String* CreateLine( const char* prefix, const Node* node )
{
    String* line = null;
    {
        StringBuffer* sb     = StringBuffer_new();
        String*       export = Node_export( node );
        {
            StringBuffer_append( sb, prefix );
            StringBuffer_append( sb, String_content( export ) );

            line = String_new( StringBuffer_content( sb ) );
        }
        StringBuffer_free( &sb     );
        String_free      ( &export );
    }
    return line;
}
```

### IxSourceUnit Collection

```!include/ixcompiler.IxSourceUnitCollection.h
#ifndef IXCOMPILER_IXSOURCEUNITCOLLECTION_H
#define IXCOMPILER_IXSOURCEUNITCOLLECTION_H

#include "ixcompiler.h"

IxSourceUnitCollection* IxSourceUnitCollection_new();
IxSourceUnitCollection* IxSourceUnitCollection_free( IxSourceUnitCollection** self                              );
void                    IxSourceUnitCollection_add ( IxSourceUnitCollection*  self, IxSourceUnit** IxSourceUnit );

int                     IxSourceUnitCollection_getLength        ( const IxSourceUnitCollection* self );
const IxSourceUnit*     IxSourceUnitCollection_get              ( const IxSourceUnitCollection* self, int index );
ArrayOfString*          IxSourceUnitCollection_retrieveTypes    ( const IxSourceUnitCollection* self );
ArrayOfString*          IxSourceUnitCollection_retrieveFunctions( const IxSourceUnitCollection* self );

const ArrayOfString*    IxSourceUnitCollection_getCopyrightLines( const IxSourceUnitCollection* self );
const ArrayOfString*    IxSourceUnitCollection_getLicenseLines  ( const IxSourceUnitCollection* self );
const Dictionary*       IxSourceUnitCollection_getResolvedTypes ( const IxSourceUnitCollection* self );
const Dictionary*       IxSourceUnitCollection_getSignatures    ( const IxSourceUnitCollection* self );

#endif
```

```!c/ixcompiler.IxSourceUnitCollection.c
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceSignature.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.IxSourceUnitCollection.h"

struct _IxSourceUnitCollection
{
    Array*         collection;
    ArrayOfString* copyrightLines;
    ArrayOfString* licenseLines;
    Dictionary*    resolvedTypes;
    Dictionary*    signatures;
};
```

```c/ixcompiler.IxSourceUnitCollection.c
IxSourceUnitCollection* IxSourceUnitCollection_new()
{
    IxSourceUnitCollection* self = Platform_Alloc( sizeof( IxSourceUnitCollection ) );
    if ( self )
    {
        self->collection     = Array_new_destructor( (Destructor) IxSourceUnit_free );
        self->copyrightLines = ArrayOfString_new();
        self->licenseLines   = ArrayOfString_new();
        self->resolvedTypes  = Dictionary_new( FALSE, (Destructor) String_free );
        self->signatures     = Dictionary_new( FALSE, null );
    }
    return self;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
IxSourceUnitCollection* IxSourceUnitCollection_free( IxSourceUnitCollection** self )
{
    if ( *self )
    {
        if ( (*self)->collection )
        {
            IxSourceUnit* sourceFile;

            while ( (sourceFile = Array_pop( (*self)->collection )) )
            {
                IxSourceUnit_free( &sourceFile );
            }
            Array_free        ( &(*self)->collection     );
            ArrayOfString_free( &(*self)->copyrightLines );
            ArrayOfString_free( &(*self)->licenseLines   );
            Dictionary_free   ( &(*self)->resolvedTypes  );
            Dictionary_free   ( &(*self)->signatures     );

            Platform_Free( self );
        }
    }
    return *self;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
void IxSourceUnitCollection_add( IxSourceUnitCollection* self, IxSourceUnit** sourceUnit )
{
    ArrayOfString_union( self->copyrightLines, IxSourceUnit_getCopyrightLines( *sourceUnit ) );
    ArrayOfString_union( self->licenseLines,   IxSourceUnit_getLicenseLines  ( *sourceUnit ) );

    Dictionary_put
    (
        self->resolvedTypes,
        (String**) Give( String_copy( IxSourceUnit_getName    ( *sourceUnit ) ) ),
        (void**)   Give( String_copy( IxSourceUnit_getFullName( *sourceUnit ) ) )
    );

    const char*  prefix  = IxSourceUnit_getPrefix ( *sourceUnit );
    const Array* methods = IxSourceUnit_getMethods( *sourceUnit );
    int n = Array_getLength( methods );
    for ( int i=0; i < n; i++ )
    {
        const IxSourceMethod*    method    = (const IxSourceMethod*) Array_getObject( methods, i );
        const IxSourceSignature* signature = IxSourceMethod_getSignature( method );

        String* signature_name = IxSourceSignature_generateName( signature, prefix );

        Dictionary_put_reference( self->signatures, &signature_name, signature );
    }

    Array_push( self->collection, (void**) sourceUnit );
}
```

```c/ixcompiler.IxSourceUnitCollection.c
int IxSourceUnitCollection_getLength( const IxSourceUnitCollection* self )
{
    return Array_getLength( self->collection );
}
```

```c/ixcompiler.IxSourceUnitCollection.c
const IxSourceUnit*     IxSourceUnitCollection_get      ( const IxSourceUnitCollection* self, int index )
{
    return Array_getObject( self->collection, index );
}
```

```c/ixcompiler.IxSourceUnitCollection.c
ArrayOfString* IxSourceUnitCollection_retrieveTypes( const IxSourceUnitCollection* self )
{
    ArrayOfString* types = ArrayOfString_new();
    {
        int n = IxSourceUnitCollection_getLength( self );

        String* tmp;

        for ( int i=0; i < n; i++ )
        {
            const IxSourceUnit* unit     = IxSourceUnitCollection_get( self, i );
            const String*       fullName = IxSourceUnit_getFullName( unit );

            ArrayOfString_push( types, (String**) Give( String_copy( fullName ) ) );
        }
    }
    return types;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
ArrayOfString* IxSourceUnitCollection_retrieveFunctions( const IxSourceUnitCollection* self )
{
    ArrayOfString* functions = ArrayOfString_new();
    return functions;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
const ArrayOfString* IxSourceUnitCollection_getCopyrightLines( const IxSourceUnitCollection* self )
{
    return self->copyrightLines;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
const ArrayOfString* IxSourceUnitCollection_getLicenseLines( const IxSourceUnitCollection* self )
{
    return self->licenseLines;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
const Dictionary* IxSourceUnitCollection_getResolvedTypes( const IxSourceUnitCollection* self )
{
    return self->resolvedTypes;
}
```

```c/ixcompiler.IxSourceUnitCollection.c
const Dictionary* IxSourceUnitCollection_getSignatures( const IxSourceUnitCollection* self )
{
    return self->signatures;
}
```

### Generator

```!include/ixcompiler.Generator.h
#ifndef IXCOMPILER_GENERATOR_H
#define IXCOMPILER_GENERATOR_H

#include "ix.h"
#include "ixcompiler.h"

GeneratorFn Generator_FunctionFor( const char* target_language );

#endif
```

```!c/ixcompiler.Generator.c
#include <stdio.h>
#include "ixcompiler.Generator.h"
#include "ixcompiler.GeneratorForC.h"
```

```c/ixcompiler.Generator.c
GeneratorFn Generator_FunctionFor( const char* target_language )
{
    if ( String_Equals( target_language, LANG_C ) )
    {
        return Generator_FunctionForC;
    }
    else
    {
        return null;
    }
}
```

#### C Signature

```!include/ixcompiler.CSignature.h
#ifndef IXCOMPILER_GENERATORFORC_CSIGNATURE_H
#define IXCOMPILER_GENERATORFORC_CSIGNATURE_H

#include "ixcompiler.h"

CSignature* CSignature_new( const IxSourceSignature* signature, const Dictionary* resolvedTypes );

  CSignature* CSignature_free                   (       CSignature** self );
      String* CSignature_generateHeaderSignature( const CSignature*  self );

const String* CSignature_getReturnType          ( const CSignature*  self );
const String* CSignature_getFunctionName        ( const CSignature*  self );
const String* CSignature_getParameters          ( const CSignature*  self );

#endif
```

```!c/ixcompiler.CSignature.c
#include "ix.h"
#include "ixcompiler.CSignature.h"
#include "ixcompiler.IxSourceSignature.h"
#include "ixcompiler.IxSourceParameter.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.IxSourceUnit.h"

struct _CSignature
{
    const IxSourceSignature* signature;
    const Dictionary*        resolvedTypes;

    String* returnType;
    String* functionName;
    String* parameters;
};

static void    CSignature_initReturnType  ( CSignature* self );
static void    CSignature_initFunctionName( CSignature* self );
static void    CSignature_initParameters  ( CSignature* self );

static String* CSignature_ToFullCType( const IxSourceType* stype, const Dictionary* resolvedTypes );
```

```c/ixcompiler.CSignature.c
CSignature* CSignature_new( const IxSourceSignature* signature, const Dictionary* resolvedTypes )
{
    CSignature* self = Platform_Alloc( sizeof( CSignature ) );
    if ( self )
    {
        self->signature     = signature;
        self->resolvedTypes = resolvedTypes;

        CSignature_initReturnType  ( self );
        CSignature_initFunctionName( self );
        CSignature_initParameters  ( self );
    }
    return self;
}
```

```c/ixcompiler.CSignature.c
CSignature* CSignature_free( CSignature** self )
{
    if ( *self )
    {
        String_free( &(*self)->returnType   );
        String_free( &(*self)->functionName );
        String_free( &(*self)->parameters   );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.CSignature.c
const String* CSignature_getReturnType( const CSignature*  self )
{
    return self->returnType;
}
```

```c/ixcompiler.CSignature.c
const String* CSignature_getFunctionName( const CSignature* self )
{
    return self->functionName;
}
```

```c/ixcompiler.CSignature.c
const String* CSignature_getParameters( const CSignature* self )
{
    return self->parameters;
}
```

```c/ixcompiler.CSignature.c
String* CSignature_generateHeaderSignature( const CSignature*  self )
{
    const IxSourceUnit* unit = IxSourceSignature_getSourceUnit( self->signature );
    const char*       prefix = IxSourceUnit_getPrefix( unit );

    return String_new( "" );
}
```

```c/ixcompiler.CSignature.c
void CSignature_initReturnType( CSignature* self )
{
    const IxSourceType* stype = IxSourceSignature_getReturnType( self->signature );
    const String*       rtype = IxSourceType_getName( stype );
    {
        String* tmp = null;

        if ( 0 == String_getLength( rtype ) )
        {
            tmp = String_new( "void" );
        }
        else
        if ( !IxSourceType_isFullName( stype ) )
        {
            if ( Dictionary_has( self->resolvedTypes, rtype ) )
            {
                rtype = Dictionary_get( self->resolvedTypes, rtype );
                tmp = String_replace( rtype, '.', '_' );
            }
            else
            {
                tmp = String_copy( rtype );
            }
        }
        else
        {
            tmp = String_replace( rtype, '.', '_' );
        }

        if ( IxSourceType_isPointer( stype ) && IxSourceType_isArray( stype ) )
        {
            self->returnType = String_cat_chars( tmp, "?" );
        }
        else
        if ( IxSourceType_isPointer( stype ) )
        {
            self->returnType = String_cat_chars( tmp, "*" );
        }
        else
        if ( IxSourceType_isArray( stype ) )
        {
            self->returnType = String_cat_chars( tmp, "[]" );
        }
        else
        {
            self->returnType = String_copy( tmp );
        }

        String_free( &tmp );
    }
}
```

```c/ixcompiler.CSignature.c
void CSignature_initFunctionName( CSignature* self )
{
    const IxSourceUnit* unit         = IxSourceSignature_getSourceUnit( self->signature );
    const char*         prefix       = IxSourceUnit_getPrefix( unit );
    const String*       functionName = IxSourceSignature_getMethodName( self->signature );
    const Array*        parameters   = IxSourceSignature_getParameters( self->signature );

    StringBuffer* sb = StringBuffer_new();
    {
        StringBuffer_append( sb, prefix );
        StringBuffer_append( sb, "__"   );
        StringBuffer_append( sb, String_content( functionName ) );

        int n = Array_getLength( parameters );
        if ( 0 < n )
        {
            StringBuffer_append( sb, "_" );

            for ( int i=0; i < n; i++ )
            {
                const IxSourceParameter* parameter = Array_getObject( parameters, i );
                const String*            name      = IxSourceParameter_getName( parameter );
                StringBuffer_append( sb, "_"                    );
                StringBuffer_append( sb, String_content( name ) );
            }
        }
        self->functionName = StringBuffer_toString( sb );
    }
    StringBuffer_free( &sb );
}
```

```c/ixcompiler.CSignature.c
void CSignature_initParameters( CSignature* self )
{
    const Array* parameters = IxSourceSignature_getParameters( self->signature );
    {
        StringBuffer* sb = StringBuffer_new();
        StringBuffer_append( sb, "(" );
        {
            int n = Array_getLength( parameters );

            if ( !IxSourceSignature_isClass( self->signature ) )
            {
                const IxSourceUnit* unit = IxSourceSignature_getSourceUnit( self->signature );
                const String*       name = IxSourceUnit_getFullName( unit );
                {
                    String* type = String_replace( name, '.', '_' );

                    StringBuffer_append( sb, "\n" );
                    StringBuffer_append( sb, "\t" );
                    StringBuffer_append( sb, String_content( type ) );

                    if ( 0 < n )
                    {
                        StringBuffer_append( sb, "* self,\n" );
                    }
                    else
                    {
                        StringBuffer_append( sb, "* self\n" );
                    }

                    String_free( &type );
                }
            }

            for ( int i=0; i < n; i++ )
            {
                const IxSourceParameter* parameter = (const IxSourceParameter*) Array_getObject( parameters, i );
                const IxSourceType*      ixtype    = IxSourceParameter_getType( parameter );

                String* rtype = CSignature_ToFullCType( ixtype, self->resolvedTypes );
                {
                    StringBuffer_append( sb, "\t" );
                    StringBuffer_append( sb, String_content( rtype ) );
                    StringBuffer_append( sb, " " );
                    StringBuffer_append( sb, String_content( IxSourceParameter_getName( parameter ) ) );
                    StringBuffer_append( sb, "\n" );
                }
                String_free( &rtype );
            }
        }
        StringBuffer_append( sb, ")" );
        self->parameters = StringBuffer_ConvertToString( &sb );
    }
}
```

```c/ixcompiler.CSignature.c
static String* CSignature_ToFullCType( const IxSourceType* stype, const Dictionary* resolvedTypes )
{
    String* ctype = null;
    {
        const String* rtype = IxSourceType_getName( stype );
        {
            String* tmp = null;

            if ( 0 == String_getLength( rtype ) )
            {
                tmp = String_new( "void" );
            }
            else
            if ( !IxSourceType_isFullName( stype ) )
            {
                if ( Dictionary_has( resolvedTypes, rtype ) )
                {
                    rtype = Dictionary_get( resolvedTypes, rtype );
                    tmp = String_replace( rtype, '.', '_' );
                }
                else
                {
                    tmp = String_copy( rtype );
                }
            }
            else
            {
                tmp = String_replace( rtype, '.', '_' );
            }

            if ( IxSourceType_isPointer( stype ) && IxSourceType_isArray( stype ) )
            {
                ctype = String_cat_chars( tmp, "?" );
            }
            else
            if ( IxSourceType_isPointer( stype ) )
            {
                ctype = String_cat_chars( tmp, "*" );
            }
            else
            if ( IxSourceType_isReference( stype ) )
            {
                ctype = String_cat_chars( tmp, "* REF" );
            }
            else
            if ( IxSourceType_isArray( stype ) )
            {
                ctype = String_cat_chars( tmp, "[]" );
            }
            else
            {
                ctype = String_copy( tmp );
            }

            String_free( &tmp );
        }
    }
    return ctype;
}
```

### C Statement

```!include/ixcompiler.CStatement.h
#ifndef IXCOMPILER_CSTATEMENT_H
#define IXCOMPILER_CSTATEMENT_H

#include "ix.h"
#include "ixcompiler.h"

CStatement* CStatement_new ( const IxSourceUnit* unit, const IxSourceStatement* anIxStatement, const Dictionary* resolvedTypes );

CStatement* CStatement_free    (       CStatement** self );
String*     CStatement_toString( const CStatement*  self );

#endif
```

```!c/ixcompiler.CStatement.c
#include "ix.h"
#include "ixcompiler.CStatement.h"
#include "ixcompiler.IxSourceDeclaration.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceStatement.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.Token.h"

struct _CStatement
{
    const IxSourceUnit*      unit;
    const IxSourceStatement* ixStatement; 
    const Dictionary*        resolvedTypes;
          String*            prefix;
};

Array* CStatement_parseTokens( const CStatement* self, const Array* tokens );
```

```c/ixcompiler.CStatement.c
CStatement* CStatement_new( const IxSourceUnit* unit, const IxSourceStatement* anIxStatement, const Dictionary* resolvedTypes )
{
    CStatement* self = Platform_Alloc( sizeof(CStatement) );
    if ( self )
    {
        self->unit          = unit;
        self->ixStatement   = anIxStatement;
        self->resolvedTypes = resolvedTypes;
        self->prefix        = String_replace( IxSourceUnit_getFullName( unit ), '.', '_' );
    }
    return self;
};
```

```c/ixcompiler.CStatement.c
CStatement* CStatement_free( CStatement** self )
{
    if ( *self )
    {
        String_free( &(*self)->prefix );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.CStatement.c
String* CStatement_toString( const CStatement* self )
{
    StringBuffer* sb = StringBuffer_new();

    if ( IxSourceStatement_isDeclaration( self->ixStatement ) )
    {
        const IxSourceDeclaration* decl   = IxSourceStatement_getDeclaration( self->ixStatement );
        const IxSourceType*        ixtype = IxSourceDeclaration_getType( decl );
        const String*              type   = IxSourceType_getName( ixtype );

        StringBuffer_append( sb, "// Declaration" );
        StringBuffer_append( sb, String_content( type ) );
    }
    else
    if ( IxSourceStatement_isComplex( self->ixStatement ) )
    {
        StringBuffer_append( sb, "// Complex" );
    }
    else
    if ( IxSourceStatement_isExpression( self->ixStatement ) )
    {
        StringBuffer_append( sb, "// Expression" );

        const IxSourceExpression* expression = IxSourceStatement_getExpression( self->ixStatement );
        {
        }
    }
    else
    {
        StringBuffer_append( sb, "// Unknown" );
    }

    return StringBuffer_ConvertToString( &sb );
}
```

```c/ixcompiler.CStatement.c
Array* CStatement_parseTokens( const CStatement* self, const Array* tokens )
{
    Array* ret = Array_new_destructor( null );

    int n = Array_getLength( tokens );
    for ( int i=0; i < n; i++ )
    {

    }
    return ret;
}
```




        {
            StringBuffer_append( sb, "\t" );

            int n = Array_getLength( tokens );
            for ( int i=0; i < n; i++ )
            {
                const Token* token = Array_getObject( tokens, i );
                const char*  item  = Token_getContent( token );

                if ( '@' == item[0] )
                {
                    StringBuffer_append( sb, "self->" );
                }
                else
                if ( '%' == item[0] )
                {
                    StringBuffer_append( sb, String_content( self->prefix ) );
                    StringBuffer_append( sb, "_" );
                }
                else
                {
                    StringBuffer_append( sb, item );
                }
            }
        }

### Generator for C

```!include/ixcompiler.GeneratorForC.h
#ifndef IXCOMPILER_GENERATORFORC_H
#define IXCOMPILER_GENERATORFORC_H

#include "ix.h"
#include "ixcompiler.h"

int Generator_FunctionForC( const IxSourceUnitCollection* source_units, const Path* output_path );

#endif
```

```!c/ixcompiler.GeneratorForC.c
#include <stdio.h>
#include "ix.h"
#include "ixcompiler.CSignature.h"
#include "ixcompiler.CStatement.h"
#include "ixcompiler.GeneratorForC.h"
#include "ixcompiler.IxSourceClass.h"
#include "ixcompiler.IxSourceMember.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceParameter.h"
#include "ixcompiler.IxSourceSignature.h"
#include "ixcompiler.IxSourceStatement.h"
#include "ixcompiler.IxSourceType.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.IxSourceUnitCollection.h"

#define TARGET_HEADER_NAME "/include/"
#define TARGET_SOURCE_NAME "/c/"

static void    GenerateHeaderFileThenWrite ( const IxSourceUnitCollection* sourceUnits, const String* outputDir );
static String* GenerateHeaderFile          ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateHeaderFileIfDef     ( const IxSourceUnit*           sourceUnit  );
static String* GenerateHeaderFileTypeDef   ( const String*                 type,        int           longest  );
static String* GenerateHeaderFileSignatures( const IxSourceUnitCollection* sourceUnits );


static void    GenerateSourceFileThenWrite                       ( const IxSourceUnitCollection* sourceUnits, const String* outputDir );
static String* GenerateSourceFile                                ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateSourceFileIncludes                        ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateSourceFileStructs                         ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateSourceFileStructsForSourceUnit            ( const IxSourceUnit*           sourceUnit, const Dictionary* resolvedTypes );
static String* GenerateSourceFileStructsForSourceUnitMembers     ( const IxSourceUnit*           sourceUnit, const Dictionary* resolvedTypes );
static String* GenerateSourceFileStructsForSourceUnitClassMembers( const IxSourceUnit*           sourceUnit, const Dictionary* resolvedTypes );

static String* GenerateSourceFileMethods                               ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateSourceFileMethodsForSourceUnit                  ( const IxSourceUnit*           sourceUnit, const Dictionary* resolvedTypes );
static String* GenerateSourceFileMethodsForSourceUnitFunction          ( const IxSourceMethod*         method,     const Dictionary* resolvedTypes, const char* classPrefix );
static String* GenerateSourceFileMethodsForSourceUnitFunctionStatements( const IxSourceMethod*         method,     const Dictionary* resolvedTypes );

```

```c/ixcompiler.GeneratorForC.c
int Generator_FunctionForC( const IxSourceUnitCollection* sourceUnits, const Path* outputPath )
{
    int         n                 = IxSourceUnitCollection_getLength( sourceUnits );
    String*     output_dir        = String_new( Path_getFullPath( outputPath ) );
    String*     target_header     = String_new( TARGET_HEADER_NAME );
    String*     target_source     = String_new( TARGET_SOURCE_NAME );
    String*     target_header_dir = String_cat( output_dir, target_header );
    String*     target_source_dir = String_cat( output_dir, target_source );
    Path*       target_header_path = Path_new( String_content( target_header_dir ) );
    Path*       target_source_path = Path_new( String_content( target_source_dir ) );

    if ( !Platform_Path_Create( target_header_path ) )
    {
        Console_Write( "Aborting. Could not create output header dir: %s\n", String_content( target_header_dir ) );
        Platform_Exit( -1 );
    }

    if ( !Platform_Path_Create( target_source_path ) )
    {
        Console_Write( "Aborting. Could not create output source dir: %s\n", String_content( target_source_dir ) );
        Platform_Exit( -1 );
    }

    Console_Write( "Output header dir: %s\n", String_content( target_header_dir ) );
    Console_Write( "Output source dir: %s\n", String_content( target_source_dir ) );

    GenerateHeaderFileThenWrite( sourceUnits, target_header_dir );
    GenerateSourceFileThenWrite( sourceUnits, target_source_dir );

    String_free( &output_dir        );
    String_free( &target_header     );
    String_free( &target_source     );
    String_free( &target_header_dir );
    String_free( &target_source_dir );

    return SUCCESS;
}
```


#### Generate C Header

```c/ixcompiler.GeneratorForC.c
static void GenerateHeaderFileThenWrite( const IxSourceUnitCollection* sourceUnits, const String* outputDir )
{
    if ( 0 < IxSourceUnitCollection_getLength( sourceUnits ) )
    {
        String*             content     = GenerateHeaderFile( sourceUnits );
        const IxSourceUnit* first       = IxSourceUnitCollection_get( sourceUnits, 0 );
        const String*       package     = IxSourceUnit_getPackage( first );
        String*             header      = String_cat( outputDir, package );
        String*             extension   = String_new( ".h" );
        String*             header_full = String_cat( header, extension );

        if ( Platform_File_WriteContents( String_content( header_full ), String_content( content ), TRUE ) )
        {
            Console_Write( "Wrote Header: %s\n", String_content( header_full ) );
        }
        else
        {
            Console_Write( "Could not write header: %s\n", String_content( header_full ) );
        }

        String_free( &content     );
        String_free( &header      );
        String_free( &extension   );
        String_free( &header_full );
    }
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateHeaderFile( const IxSourceUnitCollection* sourceUnits )
{
    const IxSourceUnit* first   = IxSourceUnitCollection_get      ( sourceUnits, 0 );
    int                 n       = IxSourceUnitCollection_getLength( sourceUnits    );

    StringBuffer* sb      = StringBuffer_new();
    String*       content = null;
    {
        StringBuffer_appendLine_prefix_optional( sb, "#ifndef", (String**) Give( GenerateHeaderFileIfDef( first ) ) );
        StringBuffer_appendLine_prefix_optional( sb, "#define", (String**) Give( GenerateHeaderFileIfDef( first ) ) );
        StringBuffer_appendLine_prefix_optional( sb, "",        (String**) null                           );

        // Copyright lines
        {
            const ArrayOfString* lines = IxSourceUnitCollection_getCopyrightLines( sourceUnits );
            int                  num   = ArrayOfString_getLength ( lines );

            for ( int i=0; i < num; i++ )
            {
                const String* line = ArrayOfString_getObject( lines, i );
                StringBuffer_append( sb, "// Copyright" );
                StringBuffer_append( sb, String_content( line ) );
                StringBuffer_append( sb, "\n" );
            }
            StringBuffer_append( sb, "\n" );
        }

        // License lines
        {
            const ArrayOfString* lines = IxSourceUnitCollection_getLicenseLines( sourceUnits );
            int                  num   = ArrayOfString_getLength ( lines );

            for ( int i=0; i < num; i++ )
            {
                const String* line = ArrayOfString_getObject( lines, i );
                StringBuffer_append( sb, "// License" );
                StringBuffer_append( sb, String_content( line ) );
                StringBuffer_append( sb, "\n" );
            }
            StringBuffer_append( sb, "\n" );
        }

        // Defines
        {
            StringBuffer_append( sb, "#ifndef REF\n" );
            StringBuffer_append( sb, "#define REF\n" );
            StringBuffer_append( sb, "#endif\n"      );
            StringBuffer_append( sb, "\n"            );
        }

        // Types
        {
            ArrayOfString* types   = IxSourceUnitCollection_retrieveTypes( sourceUnits );
            int            num     = ArrayOfString_getLength ( types );
            int            longest = ArrayOfString_getLongest( types );

            for ( int i=0; i < num; i++ )
            {
                const String* type = ArrayOfString_getObject( types, i );
                StringBuffer_appendLine_prefix_optional( sb, "typedef struct", (String**) Give( GenerateHeaderFileTypeDef( type, longest ) ) );
            }
        }

        //  Signatures
        StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateHeaderFileSignatures( sourceUnits ) ) );

        StringBuffer_appendLine_prefix_optional( sb, "",        null );
        StringBuffer_appendLine_prefix_optional( sb, "#endif",  null );
    }
    content = String_new( StringBuffer_content( sb ) );
    StringBuffer_free( &sb );

    return content;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateHeaderFileIfDef( const IxSourceUnit* sourceUnit )
{
    String* ifdef = null;
    {
        String* suffix      = String_new( ".h" );
        String* header_name = String_cat( IxSourceUnit_getPackage( sourceUnit ), suffix );
        String* uppercase   = String_toUpperCase( header_name );

        ifdef = String_replace( uppercase, '.', '_' );

        String_free( &suffix      );
        String_free( &header_name );
        String_free( &uppercase   );
    }

    return ifdef;
}
```

```
typedef struct _<name> <name>;
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateHeaderFileTypeDef( const String* type, int longest )
{
    String* ret   = null;
    {
        String* ctype = String_replace( type, '.', '_' );
        {
            const char* _ctype = String_content( ctype );

            char pattern[99];
            char output[99];

            sprintf( pattern, "_%%-%is %%-%is;", longest, longest );
            sprintf( output, pattern, _ctype, _ctype );

            ret = String_new( output );
        }
        String_free( &ctype );
    }
    return ret;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateHeaderFileSignatures( const IxSourceUnitCollection* sourceUnits )
{
    String* st_signatures = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            const Dictionary* resolvedTypes = IxSourceUnitCollection_getResolvedTypes( sourceUnits );
            const Dictionary* signatures    = IxSourceUnitCollection_getSignatures   ( sourceUnits );
            const Array*      entries       = Dictionary_getEntries( signatures );
            {
                StringBuffer_append( sb, "\n" );
                int n = Array_getLength( entries );
                for ( int i=0; i < n; i++ )
                {
                    const Entry*             entry      = (const Entry*) Array_getObject( entries, i );
                    const String*            key        = Entry_getKey( entry );
                    const IxSourceSignature* sig        = (IxSourceSignature*) Entry_getValue( entry );
                    {
                        CSignature* csig = CSignature_new( sig, resolvedTypes );
                        {
                            StringBuffer_append( sb, String_content( CSignature_getReturnType( csig ) ) );
                            StringBuffer_append( sb, "\n" );
                            StringBuffer_append( sb, String_content( CSignature_getFunctionName( csig ) ) );
                            StringBuffer_append( sb, "\n" );
                            StringBuffer_append( sb, String_content( CSignature_getParameters( csig ) ) );
                            StringBuffer_append( sb, ";\n" );
                            StringBuffer_append( sb, "\n" );
                        }
                        CSignature_free( &csig );
                    }
                }
                st_signatures = StringBuffer_toString( sb );
            }
        }
        StringBuffer_free( &sb );
    }
    return st_signatures;
}
```

#### Generate C Source File

```c/ixcompiler.GeneratorForC.c
static void GenerateSourceFileThenWrite( const IxSourceUnitCollection* sourceUnits, const String* outputDir )
{
    if ( 0 < IxSourceUnitCollection_getLength( sourceUnits ) )
    {
        String*             content     = GenerateSourceFile( sourceUnits );
        const IxSourceUnit* first       = IxSourceUnitCollection_get( sourceUnits, 0 );
        const String*       package     = IxSourceUnit_getPackage( first );
        String*             source      = String_cat( outputDir, package );
        String*             extension   = String_new( ".c" );
        String*             source_full = String_cat( source, extension );

        if ( Platform_File_WriteContents( String_content( source_full ), String_content( content ), TRUE ) )
        {
            Console_Write( "Wrote Source: %s\n", String_content( source_full ) );
        }
        else
        {
            Console_Write( "Could not write source: %s\n", String_content( source_full ) );
        }

        String_free( &content     );
        String_free( &source      );
        String_free( &extension   );
        String_free( &source_full );
    }
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFile( const IxSourceUnitCollection* sourceUnits )
{
    String* ret = null;
    {
        StringBuffer* sb = StringBuffer_new();

        StringBuffer_appendLine_prefix_optional( sb, "#include", (String**) Give( GenerateSourceFileIncludes( sourceUnits ) ) );
        StringBuffer_appendLine_prefix_optional( sb,         "", (String**) Give( GenerateSourceFileStructs ( sourceUnits ) ) );
        StringBuffer_appendLine_prefix_optional( sb,         "", (String**) Give( GenerateSourceFileMethods ( sourceUnits ) ) );

        ret = String_new( StringBuffer_content( sb ) );
    }
    return ret;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileIncludes( const IxSourceUnitCollection* sourceUnits )
{
    String* includes = null;
    {
        const IxSourceUnit* first       = IxSourceUnitCollection_get( sourceUnits, 0 );
        const String*       package     = IxSourceUnit_getPackage( first );

        StringBuffer* sb = StringBuffer_new();
        StringBuffer_append( sb, "\"" );
        StringBuffer_append( sb, String_content( package ) );
        StringBuffer_append( sb, ".h" );
        StringBuffer_append( sb, "\"" );

        includes = StringBuffer_toString( sb );

        StringBuffer_free( &sb );
    }
    return includes;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileStructs( const IxSourceUnitCollection* sourceUnits )
{
    const Dictionary* resolvedTypes = IxSourceUnitCollection_getResolvedTypes( sourceUnits );

    String* structs = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            int n = IxSourceUnitCollection_getLength( sourceUnits );

            for ( int i=0; i < n; i++ )
            {
                const IxSourceUnit* sourceUnit = IxSourceUnitCollection_get( sourceUnits, i );

                StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateSourceFileStructsForSourceUnit            ( sourceUnit, resolvedTypes ) ) );
                StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateSourceFileStructsForSourceUnitClassMembers( sourceUnit, resolvedTypes ) ) );
            }
            structs = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return structs;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileStructsForSourceUnit( const IxSourceUnit* sourceUnit, const Dictionary* resolvedTypes )
{
    String* _struct = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            const String* package = IxSourceUnit_getPackage( sourceUnit );
            const String* name    = IxSourceUnit_getName   ( sourceUnit );
            {
                String* pkg = String_replace( package, '.', '_' );

                StringBuffer_append( sb, "\n" );
                StringBuffer_append( sb, "struct" );
                StringBuffer_append( sb, " " );
                StringBuffer_append( sb, "_" );
                StringBuffer_append( sb, String_content( pkg  ) );
                StringBuffer_append( sb, "_" );
                StringBuffer_append( sb, String_content( name ) );
                StringBuffer_append( sb, "\n" );
                StringBuffer_append( sb, "{" );
                StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateSourceFileStructsForSourceUnitMembers( sourceUnit, resolvedTypes ) ) );
                StringBuffer_append( sb, "};" );

                String_free( &pkg );
            }
            _struct = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return _struct;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileStructsForSourceUnitMembers( const IxSourceUnit* sourceUnit, const Dictionary* resolvedTypes )
{
    String* members = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            const IxSourceClass* class = IxSourceUnit_getClass( sourceUnit );
            const Array*         array = IxSourceClass_getMembers( class );
            {
                int n = Array_getLength( array );
                for ( int i=0; i < n; i++ )
                {
                    const IxSourceMember* member = (IxSourceMember*) Array_getObject( array, i );

                    if ( IxSourceMember_isInstance( member ) )
                    {
                        StringBuffer_append( sb, "\n" );
                        StringBuffer_append( sb, "\t" );

                        const IxSourceType* type = IxSourceMember_getType( member );
                        const String*       name = IxSourceType_getName( type );
                        const String*       full = null;

                        if
                        (
                            IxSourceType_isFullName( type )
                            ||
                            IxSourceType_isPrimitive( type )
                        )
                        {
                            full = name;
                        }
                        else
                        {
                            full = Dictionary_get( resolvedTypes, name );
                        }

                        String* converted = (full) ? String_replace( full, '.', '_' ) : String_new( "" );
                        {
                            StringBuffer_append( sb, String_content( converted ) );
                            if ( IxSourceType_isPointer( type ) )
                            {
                                StringBuffer_append( sb, "*"  );
                            }
                            if ( IxSourceType_isArray( type ) )
                            {
                                StringBuffer_append( sb, "*" );
                            }

                            if ( IxSourceType_isReference( type ) )
                            {
                                StringBuffer_append( sb, "* REF"  );
                            }

                            StringBuffer_append( sb, " "  );
                            StringBuffer_append( sb, String_content( IxSourceMember_getName( member ) ) );
                            StringBuffer_append( sb, ";"  );
                        }   
                        String_free( &converted );
                    }
                }
            }
            members = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return members;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileStructsForSourceUnitClassMembers ( const IxSourceUnit* sourceUnit, const Dictionary* resolvedTypes )
{
    StringBuffer* sb = StringBuffer_new();

    const String*        full    = IxSourceUnit_getFullName( sourceUnit );
    const IxSourceClass* cls     = IxSourceUnit_getClass ( sourceUnit );
    const Array*         members = IxSourceClass_getMembers( cls );
    {
        int n = Array_getLength( members );
        for ( int i=0; i < n; i++ )
        {
            const IxSourceMember* member = Array_getObject( members, i );
            
            if ( !IxSourceMember_isInstance( member ) )
            {
                const IxSourceType* type = IxSourceMember_getType( member );
                const String*       name = IxSourceType_getName( type );

                String* prefix = String_replace( full, '.', '_' );
                String* ctype = null;
                {
                    if ( name && IxSourceType_isFullName( type ) )
                    {
                        ctype = String_replace( name, '.', '_' );
                        StringBuffer_append( sb, String_content( ctype ) );
                    }
                    else
                    if ( name && IxSourceType_isPrimitive( type ) )
                    {
                        ctype = String_replace( name, '.', '_' );
                        StringBuffer_append( sb, String_content( ctype ) );
                    }
                    else
                    {
                        const String* resolved_type   = Dictionary_get( resolvedTypes, name );
                        if ( resolved_type )
                        {
                            ctype = String_replace( resolved_type, '.', '_' );
                            StringBuffer_append( sb, String_content( ctype ) );
                        }
                    }
                    StringBuffer_append( sb, " " );
                    StringBuffer_append( sb, String_content( prefix ) );
                    StringBuffer_append( sb, "_" );
                    StringBuffer_append( sb, String_content( IxSourceMember_getName( member ) ) );
                    StringBuffer_append( sb, ";\n" );
                }
                String_free( &ctype  );
                String_free( &prefix );
            }
        }
    }
    return StringBuffer_ConvertToString( &sb );
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileMethods( const IxSourceUnitCollection* sourceUnits )
{
    const Dictionary* resolvedTypes = IxSourceUnitCollection_getResolvedTypes( sourceUnits );

    String* methods = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            int n = IxSourceUnitCollection_getLength( sourceUnits );

            for ( int i=0; i < n; i++ )
            {
                const IxSourceUnit* sourceUnit = IxSourceUnitCollection_get( sourceUnits, i );
                StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateSourceFileMethodsForSourceUnit( sourceUnit, resolvedTypes ) ) );
            }
            methods = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return methods;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileMethodsForSourceUnit( const IxSourceUnit* sourceUnit, const Dictionary* resolvedTypes )
{
    const char* classPrefix = IxSourceUnit_getPrefix( sourceUnit );

    String* st_methods = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            const Array* methods = IxSourceUnit_getMethods( sourceUnit );
            {
                int n = Array_getLength( methods );
                for ( int i=0; i < n; i++ )
                {
                    const IxSourceMethod* method = (IxSourceMethod*) Array_getObject( methods, i );
                    StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateSourceFileMethodsForSourceUnitFunction( method, resolvedTypes, classPrefix ) ) );
                }
            }
            st_methods = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return st_methods;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileMethodsForSourceUnitFunction( const IxSourceMethod* method, const Dictionary* resolvedTypes, const char* classPrefix )
{
    const IxSourceSignature* ixSig = IxSourceMethod_getSignature( method );

    CSignature* csig = CSignature_new( ixSig, resolvedTypes );

    String* st_method = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            StringBuffer_append( sb, "// " );
            StringBuffer_append( sb, IxSourceMethod_getAccessModifier( method ) );
            StringBuffer_append( sb, " " );
            StringBuffer_append( sb, IxSourceMethod_getConst( method ) );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, String_content( CSignature_getReturnType( csig ) ) );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, String_content( CSignature_getFunctionName( csig ) ) );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, String_content( CSignature_getParameters( csig ) ) );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, "{" );
            StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( GenerateSourceFileMethodsForSourceUnitFunctionStatements( method, resolvedTypes ) ) );
            StringBuffer_append( sb, "}" );
            StringBuffer_append( sb, "\n" );

            st_method = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return st_method;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateSourceFileMethodsForSourceUnitFunctionStatements( const IxSourceMethod* method, const Dictionary* resolvedTypes )
{
    const IxSourceUnit* unit = IxSourceMethod_getSourceUnit( method );

    StringBuffer* sb     = StringBuffer_new();
    {
        const Array* statements = IxSourceMethod_getStatements( method );
        int n = Array_getLength( statements );
        if ( 0 < n )
        {
            StringBuffer_append( sb, "\n" );
        }

        for ( int i=0; i < n; i++ )
        {
            const IxSourceStatement* statement = (const IxSourceStatement*) Array_getObject( statements, i );
            {
                CStatement* cstatement = CStatement_new( unit, statement, resolvedTypes );

                StringBuffer_appendLine_prefix_optional( sb, "", (String**) Give( CStatement_toString( cstatement ) ) );
            }
        }
    }

    return StringBuffer_ConvertToString( &sb );
}
```

## Appendices
### Arguments

```!include/ixcompiler.Arguments.h
#ifndef IXCOMPILER_ARGUMENTS_H
#define IXCOMPILER_ARGUMENTS_H

#include "ixcompiler.h"

Arguments*     Arguments_new          ( int argc, char** argv );
Arguments*     Arguments_free         ( Arguments** self );
bool           Arguments_hasFlag      ( Arguments* self, const char* argument );
const char*    Arguments_getOption    ( Arguments* self, const char* argument );
FilesIterator* Arguments_filesIterator( Arguments* self );

#endif
```

```!c/ixcompiler.Arguments.c
#include "ixcompiler.Arguments.h"
#include "todo.h"

struct _Arguments
{
    bool         dryRun;
    const char*  executable;
    const char*  outputDir;
    const char*  targetLanguage;
    const char** files;
};
```

```c/ixcompiler.Arguments.c
Arguments* Arguments_new( int argc, char** argv )
{
    int index = 0;

    Arguments* self = Platform_Alloc( sizeof( Arguments ) );
    if ( self )
    {
        self->files      = Platform_Array( argc, sizeof( char* ) );
        self->executable = argv[0];

        for ( int i=1; i < argc; i++ )
        {
            if ( String_Equals( argv[i], ARGUMENT_DRY_RUN ) )
            {
                self->dryRun = TRUE;
            }
            else
            if ( String_Equals( argv[i], ARGUMENT_OUTPUT_DIR) )
            {
                i++;
                if ( i < argc )
                {
                    self->outputDir = argv[i];
                }
            }
            else
            if ( String_Equals( argv[i], ARGUMENT_TARGET_LANGUAGE) )
            {
                i++;
                if ( i < argc )
                {
                    self->targetLanguage = argv[i];
                }
            }
            else
            {
                self->files[index++] = argv[i];
            }
        }
    }

    return self;
}
```

```c/ixcompiler.Arguments.c
Arguments* Arguments_free( Arguments** self )
{
    Platform_Free( &(*self)->files );
    Platform_Free(   self          );

    return *self;
}
```

```c/ixcompiler.Arguments.c
bool Arguments_hasFlag( Arguments* self, const char* argument )
{
    if ( String_Equals( argument, ARGUMENT_DRY_RUN ) )
    {
        return self->dryRun;
    }
    else
    if ( String_Equals( argument, ARGUMENT_OUTPUT_DIR ) )
    {
        return (0 != self->outputDir);
    }
    else
    if ( String_Equals( argument, ARGUMENT_TARGET_LANGUAGE ) )
    {
        return (0 != self->targetLanguage);
    }
    else
    {
        return FALSE;
    }
}
```

```c/ixcompiler.Arguments.c
const char* Arguments_getOption( Arguments* self, const char* argument )
{
    if ( String_Equals( argument, ARGUMENT_OUTPUT_DIR ) )
    {
        return (0 != self->outputDir) ? self->outputDir : "";
    }
    else
    if ( String_Equals( argument, ARGUMENT_TARGET_LANGUAGE ) )
    {
        return (0 != self->targetLanguage) ? self->targetLanguage : "";
    }
    else
    {
        return null;
    }
}
```

```c/ixcompiler.Arguments.c
FilesIterator* Arguments_filesIterator( Arguments* self )
{
    return FilesIterator_new( self->files );
}
```

### TokenGroup

```!include/ixcompiler.EnumTokenGroup.h
#ifndef IXCOMPILER_ENUMTOKENGROUP_H
#define IXCOMPILER_ENUMTOKENGROUP_H

typedef enum _EnumTokenGroup
{
    GROUPEND,
    PSEUDOGROUP,
    UNKNOWN_GROUP,
    WHITESPACE,
    OPEN,
    CLOSE,
    SYMBOLIC,
    ESCAPE,
    ALPHANUMERIC,
    STRING,
    COMMENT,
    CHAR,
    VALUE,
    HEX_VALUE

} EnumTokenGroup;

#endif
```

### Enum Token Type

```!include/ixcompiler.EnumTokenType.h
#ifndef IXCOMPILER_ENUMTOKENTYPE_H
#define IXCOMPILER_ENUMTOKENTYPE_H

#include "ixcompiler.h"

typedef enum _EnumTokenType
{
	END,
	PSEUDO,
	UNKNOWN_TYPE,
    UNKNOWN_WHITESPACE,
    UNKNOWN_OPEN,
    UNKNOWN_CLOSE,

    //  Whitespace
    SPACE,
    TAB,
    NEWLINE,

    //  Open
    STARTBLOCK,
    STARTEXPRESSION,
    STARTSUBSCRIPT,
    STARTTAG,

    //  Close
    ENDBLOCK,
    ENDEXPRESSION,
    ENDSUBSCRIPT,
    ENDTAG,

    //  Symbolic
    OFTYPE,
	INSTANCEMEMBER,
	CLASSMEMBER,
    OPERATOR,
    ASSIGNMENTOP,
    PREFIXOP,
    INFIXOP,
	POSTFIXOP,
    PREINFIXOP,
    PREPOSTFIXOP,
    STOP,
	COMMA,
    LINECOMMENT,
    MULTILINECOMMENT,

    //  Words
	COPYRIGHT,
	LICENSE,

    //  Composite
	WORD,
	FILEPATH,
	PACKAGE,
	IMPORT,
	INCLUDE,
	CLASS,
	CLASSNAME,
	INTERFACE,
	ENUM,
	ENUMNAME,
	GENERIC,
	ANNOTATION,
	IMETHOD,
	METHOD,
	BLOCK,
	MEMBER,
	MEMBERNAME,
	EXPRESSION,
	CLAUSE,
    PARAMETERS,
	PARAMETER,
	ARGUMENTS,
	ARGUMENT,
	STATEMENT,
	DECLARATION,
	JAVADOC,
	BLANKLINE,
	TOKEN,
	SYMBOL,
	KEYWORD,
	MODIFIER,
	PRIMITIVE,
	TYPE,
	METHODNAME,
	VARIABLE,
	NAME,
	METHODCALL,
	CONSTRUCTOR,
	SELECTOR,
	FLOAT,
	INTEGER,
	NUMBER,
	HEX,
	OCTAL,
	DOUBLEQUOTE,
	QUOTE,
	ESCAPED,
	OTHER

} EnumTokenType;

const char* EnumTokenType_asString( EnumTokenType type );

#endif
```

```!c/ixcompiler.EnumTokenType.c
#include "ixcompiler.EnumTokenType.h"
```

```c/ixcompiler.EnumTokenType.c
const char* EnumTokenType_asString( EnumTokenType type )
{
    switch ( type )
    {
	case END:                return "END";
	case PSEUDO:             return "PSEUDO";
	case UNKNOWN_TYPE:       return "UNKNOWN_TYPE";
    case UNKNOWN_WHITESPACE: return "UNKNOWN_WHITESPACE";
    case UNKNOWN_OPEN:       return "UNKNOWN_OPEN";
    case UNKNOWN_CLOSE:      return "UNKNOWN_CLOSE";
    case SPACE:              return "SPACE";
    case TAB:                return "TAB";
    case NEWLINE:            return "NEWLINE";
    case STARTBLOCK:         return "STARTBLOCK";
    case STARTEXPRESSION:    return "STARTEXPRESSION";
    case STARTSUBSCRIPT:     return "STARTSUBSCRIPT";
    case STARTTAG:           return "STARTTAG";
    case ENDBLOCK:           return "ENDBLOCK";
    case ENDEXPRESSION:      return "ENDEXPRESSION";
    case ENDSUBSCRIPT:       return "ENDSUBSCRIPT";
    case ENDTAG:             return "ENDTAG";
    case OFTYPE:             return "OFTYPE";
    case INSTANCEMEMBER:     return "INSTANCEMEMBER";
    case CLASSMEMBER:        return "CLASSMEMBER";
    case OPERATOR:           return "OPERATOR";
    case ASSIGNMENTOP:       return "ASSIGNMENTOP";
    case PREFIXOP:           return "PREFIXOP";
    case INFIXOP:            return "INFIXOP";
    case POSTFIXOP:          return "POSTFIXOP";
    case PREINFIXOP:         return "PREINFIXOP";
    case PREPOSTFIXOP:       return "PREPOSTFIXOP";
    case STOP:               return "STOP";
    case COMMA:              return "COMMA";
    case LINECOMMENT:        return "LINECOMMENT";
    case MULTILINECOMMENT:   return "MULTILINECOMMENT";
	case COPYRIGHT:          return "COPYRIGHT";
	case LICENSE:            return "LICENSE";
	case WORD:               return "WORD";
	case FILEPATH:           return "FILEPATH";
	case PACKAGE:            return "PACKAGE";
	case IMPORT:             return "IMPORT";
	case INCLUDE:            return "INCLUDE";
	case CLASS:              return "CLASS";
	case CLASSNAME:          return "CLASSNAME";
	case INTERFACE:          return "INTERFACE";
	case ENUM:               return "ENUM";
	case ENUMNAME:           return "ENUMNAME";
	case GENERIC:            return "GENERIC";
	case ANNOTATION:         return "ANNOTATION";
	case IMETHOD:            return "IMETHOD";
	case METHOD:             return "METHOD";
	case BLOCK:              return "BLOCK";
	case MEMBER:             return "MEMBER";
	case MEMBERNAME:         return "MEMBERNAME";
	case EXPRESSION:         return "EXPRESSION";
	case CLAUSE:             return "CLAUSE";
    case PARAMETERS:         return "PARAMETERS";
	case PARAMETER:          return "PARAMETER";
	case ARGUMENTS:          return "ARGUMENTS";
	case ARGUMENT:           return "ARGUMENT";
	case STATEMENT:          return "STATEMENT";
	case DECLARATION:        return "DECLARATION";
	case JAVADOC:            return "JAVADOC";
	case BLANKLINE:          return "BLANKLINE";
	case TOKEN:              return "TOKEN";
	case SYMBOL:             return "SYMBOL";
	case KEYWORD:            return "KEYWORD";
	case MODIFIER:           return "MODIFIER";
	case PRIMITIVE:          return "PRIMITIVE";
	case TYPE:               return "TYPE";
	case METHODNAME:         return "METHODNAME";
	case VARIABLE:           return "VARIABLE";
	case NAME:               return "NAME";
	case METHODCALL:         return "METHODCALL";
	case CONSTRUCTOR:        return "CONSTRUCTOR";
	case SELECTOR:           return "SELECTOR";
	case FLOAT:              return "FLOAT";
	case INTEGER:            return "INTEGER";
	case NUMBER:             return "NUMBER";
	case HEX:                return "HEX";
	case OCTAL:              return "OCTAL";
	case DOUBLEQUOTE:        return "DOUBLEQUOTE";
	case QUOTE:              return "QUOTE";
	case ESCAPED:            return "ESCAPED";
	case OTHER:              return "OTHER";
    default:                 return "???";
    }
}
```
### Includes

```!include/ixcompiler.h
//
// Copyright 2021 Daniel Robert Bradley
//

#ifndef IXCOMPILER_H
#define IXCOMPILER_H

#include "ix.h"

#define ABORT_DIRECTORY_DOES_NOT_EXIST      "Aborting, output directory does not exist - %s\n"
#define ABORT_DIRECTORY_IS_NOT_WRITABLE     "Aborting, cannot write to output directory - %s\n"
#define ABORT_FILE_CANNOT_BE_READ           "Aborting, speciifed file cannot be read - %s\n"
#define ABORT_FILE_DOES_NOT_EXIST           "Aborting, specified file does not exist - %s\n"
#define ABORT_NO_OUTPUT_DIR                 "Aborting, no output directory specified (--output-dir)\n"
#define ABORT_NO_SOURCE_FILES               "Aborting, no source files specified\n"
#define ABORT_TARGET_LANGUAGE_NOT_SPECIFIED "Aborting, target language not specified (--target-language)\n"
#define ABORT_TARGET_LANGUAGE_NOT_SUPPORTED "Aborting, could not find generator for target language - %s\n"

#define ARGUMENT_DRY_RUN         "--dry-run"
#define ARGUMENT_OUTPUT_DIR      "--output-dir"
#define ARGUMENT_TARGET_LANGUAGE "--target-language"

#define LANG_C "C"



typedef struct _Arguments                       Arguments;
typedef struct _ArrayOfIxSourceFunction         ArrayOfIxSourceFunction;
typedef struct _ArrayOfIxSourceMember           ArrayOfIxSourceMember;
typedef struct _ArrayOfIxSourceMethod           ArrayOfIxSourceMethod;
typedef struct _ArrayOfIxSourceParameter        ArrayOfIxSourceParameter;
typedef struct _ArrayOfIxSourceStatement        ArrayOfIxSourceStatement;
typedef struct _ArrayOfString                   ArrayOfString;
typedef struct _AST                             AST;
typedef struct _ASTCollection                   ASTCollection;
typedef struct _CSignature                      CSignature;
typedef struct _CStatement                      CStatement;
typedef struct _Generator                       Generator;
typedef struct _IxParser                        IxParser;
typedef struct _IxSourceBlock                   IxSourceBlock;
typedef struct _IxSourceClass                   IxSourceClass;
typedef struct _IxSourceComment                 IxSourceComment;
typedef struct _IxSourceConditional             IxSourceConditional;
typedef struct _IxSourceDeclaration             IxSourceDeclaration;
typedef struct _IxSourceExpression              IxSourceExpression;
typedef struct _IxSourceFunction                IxSourceFunction;
typedef struct _IxSourceHeader                  IxSourceHeader;
typedef struct _IxSourceInterface               IxSourceInterface;
typedef struct _IxSourceMember                  IxSourceMember;
typedef struct _IxSourceMethod                  IxSourceMethod;
typedef struct _IxSourceParameter               IxSourceParameter;
typedef struct _IxSourceSignature               IxSourceSignature;
typedef struct _IxSourceStatement               IxSourceStatement;
typedef struct _IxSourceSubExpression           IxSourceSubExpression;
typedef struct _IxSourceType                    IxSourceType;
typedef struct _IxSourceUnit                    IxSourceUnit;
typedef struct _IxSourceUnitCollection          IxSourceUnitCollection;
typedef struct _Token                           Token;
typedef struct _TokenGroup                      TokenGroup;
typedef struct _Tokenizer                       Tokenizer;
typedef struct _Tree                            Tree;

typedef void* (*Destructor )( void**                                     );
typedef int   (*GeneratorFn)( const IxSourceUnitCollection*, const Path* );

#endif
```

## Base

```!include/ix.h
#ifndef IX_H
#define IX_H

#ifndef bool
#define bool int
#endif

#ifndef null
#define null 0
#endif

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef SUCCESS
#define SUCCESS 1
#endif

#ifndef FAILED
#define FAILED 0
#endif

#ifndef ANY
#define ANY void*
#endif

#ifndef ANY_STRING
#define ANY_STRING void*
#endif

#ifndef ANY_STRING
#define ANY_STRING void*
#endif

typedef void* (*Destructor )( void** );

typedef struct _Array           Array;
typedef struct _ArrayOfString   ArrayOfString;
typedef struct _Dictionary      Dictionary;
typedef struct _Entry           Entry;
typedef struct _File            File;
typedef struct _FilesIterator   FilesIterator;
typedef struct _Node            Node;
typedef struct _NodeIterator    NodeIterator;
typedef struct _Object          Object;
typedef struct _Path            Path;
typedef struct _PushbackReader  PushbackReader;
typedef struct _Queue           Queue;
typedef struct _String          String;
typedef struct _StringBuffer    StringBuffer;
typedef struct _Tree            Tree;

typedef struct _Token         Token;
typedef enum   _EnumTokenType EnumTokenType;

void** Give  ( void* pointer );
void*  Take  ( void* giver   );
void   Swap  ( ANY one, ANY two );

#include "ix/Array.h"
#include "ix/ArrayOfString.h"
#include "ix/Console.h"
#include "ix/Object.h"

#include "ix/Dictionary.h"
#include "ix/Entry.h"
#include "ix/File.h"
#include "ix/FilesIterator.h"
#include "ix/Node.h"
#include "ix/NodeIterator.h"
#include "ix/Path.h"
#include "ix/PushbackReader.h"
#include "ix/Platform.h"
#include "ix/Queue.h"
#include "ix/String.h"
#include "ix/StringBuffer.h"
#include "ix/Term.h"
#include "ix/Tree.h"

#endif
```

### Array

```!include/ix/Array.h
#ifndef IX_ARRAY_H
#define IX_ARRAY_H

#include "ix.h"

Array*      Array_new           ();
Array*      Array_new_destructor( Destructor destructor );
Array*      Array_init          ( Array*  self );
Array*      Array_free          ( Array** self );
Array*      Array_push          ( Array*  self, void** object );
void*       Array_pop           ( Array*  self );
void*       Array_shift         ( Array*  self );
Array*      Array_unshift       ( Array*  self, void** object );
int         Array_getLength     ( const Array* self            );
const void* Array_getObject     ( const Array* self, int index );

int Array_Sizeof();

#endif
```

```!c/ix/Array.c
#include "ix.h"

struct _Array
{
    Object        super;
    Array*(*free)(Array**);
    Destructor    destroy;
    void**        objects;
    int           length;
    int           size;
    bool          treatAsObjects;
};
```

```c/ix/Array.c
static void Array_expand( Array* self )
{
    if ( 0 == self->size )
    {
        self->objects = (void**) Platform_Array( 1, sizeof( void* ) );
        self->size    = 1;
    }
    else
    {
        int new_size = self->size * 2;

        void** tmp = (void**) Platform_Array( new_size, sizeof( void* ) );

        for ( int i=0; i < self->length; i++ )
        {
            tmp[i] = self->objects[i];
        }

        Platform_Free( &self->objects );

        self->objects = tmp;
        self->size    = new_size;
    }
}
```

```c/ix/Array.c
Array* Array_new()
{
    Array* self = Array_init( 0 );

    if ( self )
    {
        self->objects        = 0;
        self->length         = 0;
        self->size           = 0;
        self->treatAsObjects = TRUE;
    }
    return self;
}
```

```c/ix/Array.c
Array* Array_new_destructor( Destructor destructor )
{
    Array* self = Array_init( 0 );

    if ( self )
    {
        self->destroy = destructor;
        self->objects = 0;
        self->length  = 0;
        self->size    = 0;
    }
    return self;
}
```

```c/ix/Array.c
Array* Array_init( Array* self )
{
    if ( !self ) self = Platform_Alloc( Array_Sizeof() );
    if ( self )
    {
        Object_init( (Object*) self );
        self->super.free = (Object*(*)(Object**)) Array_free;
        self->free = Array_free;
    }
    return self;
}
```

```c/ix/Array.c
Array* Array_free( Array** self )
{
    if ( self && *self )
    {
        if ( Array_free != (*self)->free )
        {
            (*self)->free( self );
        }
        else
        {
            if ( (*self)->treatAsObjects )
            {
                Object* object;
                while ( (object = (Object*) Array_pop( *self ) ) )
                {
                    Object_free( &object );
                }
            }
            else
            if ( (*self)->destroy )
            {
                void* object;
                while ( (object = Array_pop( *self )) )
                {
                    (*self)->destroy( &object );
                }
            }

            Platform_Free( &(*self)->objects );
            Platform_Free( self );
        }
    }
    return 0;
}
```

```c/ix/Array.c
Array* Array_push( Array* self, void** object )
{
    if ( self->length == self->size )
    {
        Array_expand( self );
    }

    self->objects[self->length++] = *object;
    *object = 0;

    return self;
}
```

```c/ix/Array.c
void* Array_pop( Array* self )
{
    void* ret = null;

    if ( 0 < self->length )
    {
        --self->length;
        ret = self->objects[self->length]; self->objects[self->length] = null;
    }
    return ret;
}
```

```c/ix/Array.c
void* Array_shift( Array* self )
{
    if ( self->length )
    {
        void* head = self->objects[0];

        for ( int i=1; i < self->length; i++ )
        {    
            self->objects[i-1] = self->objects[i];
            self->objects[i]   = 0;
        }
        self->length--;
        return head;
    }
    else
    {
        return null;
    }
}
```

```c/ix/Array.c
Array* Array_unshift( Array* self, void** object )
{
    if ( self->length == self->size )
    {
        Array_expand( self );
    }

    for ( int i=self->length; 0 < i; i-- )
    {    
        self->objects[i]   = self->objects[i-1];
        self->objects[i-1] = 0;
    }
    self->objects[0] = object;

    self->length++;

    return self;
}
```

```c/ix/Array.c
int Array_getLength( const Array* self )
{
    return self ? self->length : 0;
}
```

```c/ix/Array.c
const void* Array_getObject( const Array* self, int index )
{
    if ( index < self->length )
    {
        return self->objects[index];
    }
    else
    {
        return null;
    }
}
```

```c/ix/Array.c
int Array_Sizeof()
{
    return sizeof( Array );
}
```

### ArrayOfString

```!include/ix/ArrayOfString.h
#ifndef IX_ARRAYOFSTRING_H
#define IX_ARRAYOFSTRING_H

ArrayOfString* ArrayOfString_new();

ArrayOfString* ArrayOfString_free      (       ArrayOfString** self );
void           ArrayOfString_push      (       ArrayOfString*  self, ANY_STRING object );
String*        ArrayOfString_pop       (       ArrayOfString*  self );
String*        ArrayOfString_shift     (       ArrayOfString*  self );
void           ArrayOfString_unshift   (       ArrayOfString*  self, String** object );
void           ArrayOfString_append    (       ArrayOfString*  self, const ArrayOfString* other );
void           ArrayOfString_union     (       ArrayOfString*  self, const ArrayOfString* other );

bool           ArrayOfString_contains  ( const ArrayOfString*  self, const String* str );
int            ArrayOfString_getLength ( const ArrayOfString*  self            );
int            ArrayOfString_getLongest( const ArrayOfString*  self            );
const String*  ArrayOfString_getObject ( const ArrayOfString*  self, int index );

#endif
```

```!c/ix/ArrayOfString.c
#include "ix.h"

struct _ArrayOfString
{
    Array* array;
    int    longest;
};
```

```c/ix/ArrayOfString.c
ArrayOfString* ArrayOfString_new()
{
    ArrayOfString* self = Platform_Alloc( sizeof( ArrayOfString ) );
    if ( self )
    {
        self->array   = Array_new_destructor( (Destructor) String_free );
        self->longest = 0;
    }

    return self;
}
```

```c/ix/ArrayOfString.c
ArrayOfString* ArrayOfString_free( ArrayOfString** self )
{
    if ( *self )
    {
        Array_free   ( &(*self)->array );
        Platform_Free(    self         );
    }

    return *self;
}
```

```c/ix/ArrayOfString.c
void ArrayOfString_push( ArrayOfString* self, ANY_STRING _object )
{
    String** object = (String**) _object;

    int len = String_getLength( *object );
    if ( len > self->longest )
    {
        self->longest = len;
    }

    Array_push( self->array, (void**) object );
}
```

```c/ix/ArrayOfString.c
String* ArrayOfString_pop( ArrayOfString* self )
{
    return (String*) Array_pop( self->array );
}
```

```c/ix/ArrayOfString.c
String* ArrayOfString_shift( ArrayOfString* self )
{
    return (String*) Array_shift( self->array );
}
```

```c/ix/ArrayOfString.c
void ArrayOfString_unshift( ArrayOfString* self, String** object )
{
    Array_unshift( self->array, (void**) object );
}
```

```c/ix/ArrayOfString.c
bool ArrayOfString_contains( const ArrayOfString* self, const String* str )
{
    int n = Array_getLength( self->array );

    for ( int i=0; i < n; i++ )
    {
        const String* tmp = ArrayOfString_getObject( self, i );

        if ( String_equals( tmp, str ) ) return TRUE;
    }
    return FALSE;
}
```

```c/ix/ArrayOfString.c
int ArrayOfString_getLength( const ArrayOfString* self )
{
    return Array_getLength( self->array );
}
```

```c/ix/ArrayOfString.c
int ArrayOfString_getLongest( const ArrayOfString* self )
{
    return self->longest;
}
```

```c/ix/ArrayOfString.c
const String* ArrayOfString_getObject( const ArrayOfString* self, int index )
{
    return (const String*) Array_getObject( self->array, index );
}
```

```c/ix/ArrayOfString.c
void ArrayOfString_append( ArrayOfString* self, const ArrayOfString* other )
{
    int n = ArrayOfString_getLength( other );

    for ( int i=0; i < n; i++ )
    {
        String* tmp = String_copy( ArrayOfString_getObject( other, i ) );

        ArrayOfString_push( self, &tmp );
    }
}
```

```c/ix/ArrayOfString.c
void ArrayOfString_union( ArrayOfString* self, const ArrayOfString* other )
{
    int n = ArrayOfString_getLength( other );

    for ( int i=0; i < n; i++ )
    {
        const String* provisional = ArrayOfString_getObject( other, i );

        if ( !ArrayOfString_contains( self, provisional ) )
        {
            String* tmp = String_copy( provisional );
            ArrayOfString_push( self, &tmp );
        }
    }
}
```

### Console

```!include/ix/Console.h
#ifndef IX_CONSOLE_H
#define IX_CONSOLE_H

void Console_Write( const char* format, const char* optional );

#endif
```

```!c/ix/Console.c
#include <stdio.h>
#include "ix.h"
```

```c/ix/Console.c
void Console_Write( const char* format, const char* optional )
{
    fprintf( stdout, format, optional );
}
```

### Dictionary

```!include/ix/Dictionary.h
#ifndef IX_DICTIONARY_H
#define IX_DICTIONARY_H

#include "ix.h"

Dictionary* Dictionary_new( bool is_map, Destructor destructor );

Dictionary* Dictionary_free( Dictionary** self );

bool         Dictionary_put          (       Dictionary* self,       String** key,       void** value     );
bool         Dictionary_put_reference(       Dictionary* self,       String** key, const void*  reference );
bool         Dictionary_has          ( const Dictionary* self, const String* key );
const void*  Dictionary_get          ( const Dictionary* self, const String* key );
const Array* Dictionary_getEntries   ( const Dictionary* self );

#endif
```

```!c/ix/Dictionary.c
#include "ix.h"

struct _Dictionary
{
    Destructor destroy;
    bool       isMap;
    Array*     entries;
};

static const Entry* Dictionary_find( const Dictionary* self, const String* key );
```

```c/ix/Dictionary.c
Dictionary* Dictionary_new( bool is_map, Destructor destructor )
{
    Dictionary* self = Platform_Alloc( sizeof( Dictionary ) );
    if ( self )
    {
        self->destroy = destructor;
        self->isMap   = is_map;
        self->entries = Array_new_destructor( destructor );
    }
    return self;
}
```

```c/ix/Dictionary.c
Dictionary* Dictionary_free( Dictionary** self )
{
    if ( *self )
    {
        Entry* tmp;
        while( (tmp = (Entry*) Array_pop( (*self)->entries )) )
        {
            Entry_free( &tmp );
        }

        Array_free( &(*self)->entries );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ix/Dictionary.c
bool Dictionary_put( Dictionary* self, String** key, void** value )
{
    if ( self->isMap && Dictionary_has( self, *key ) )
    {
        String_free( key   );

        self->destroy( value );

        return FALSE;
    }
    else
    {
        Entry* entry = Entry_new_destructor( key, value, self->destroy );
        Array_push( self->entries, (void**) &entry );
        return TRUE;
    }
}
```

```c/ix/Dictionary.c
bool Dictionary_put_reference( Dictionary* self, String** key, const void* reference )
{
    if ( self->isMap && Dictionary_has( self, *key ) )
    {
        String_free( key );
        return FALSE;
    }
    else
    {
        Entry* entry = Entry_new( key, (void**) &reference );
        Array_push( self->entries, (void**) &entry );
        return TRUE;
    }
}
```

```c/ix/Dictionary.c
bool Dictionary_has( const Dictionary* self, const String* key )
{
    return (null != Dictionary_find( self, key ));
}
```

```c/ix/Dictionary.c
const void* Dictionary_get( const Dictionary* self, const String* key )
{
    const Entry* tmp = Dictionary_find( self, key );

    return (tmp) ? Entry_getValue( tmp ) : null;
}
```

```c/ix/Dictionary.c
const Array* Dictionary_getEntries( const Dictionary* self )
{
    return self->entries;
}
```

```c/ix/Dictionary.c
static const Entry* Dictionary_find( const Dictionary* self, const String* key )
{
    int n = Array_getLength( self->entries );
    for ( int i=0; i < n; i++ )
    {
        const Entry* tmp = (const Entry*) Array_getObject( self->entries, i );

        if ( String_equals( key, Entry_getKey( tmp ) ) )
        {
            return tmp;
        }
    }

    return null;
}
```

### Entry

```!include/ix/Entry.h
#ifndef IX_ENTRY_H
#define IX_ENTRY_H

#include "ix.h"

Entry* Entry_new           ( String** key, void** val );
Entry* Entry_new_destructor( String** key, void** val, Destructor destructor );

      Entry*  Entry_free    (       Entry** self );
const String* Entry_getKey  ( const Entry*  self );
const void*   Entry_getValue( const Entry*  self );

#endif
```

```!c/ix/Entry.c
#include "ix.h"

struct _Entry
{
    Destructor destroy;
    String*    key;
    void*      val;

};
```

```c/ix/Entry.c
Entry* Entry_new( String** key, void** val )
{
    Entry* self = Platform_Alloc( sizeof( Entry ) );
    if ( self )
    {
        self->key = Take( key );
        self->val = Take( val );
    }
    return self;
}
```

```c/ix/Entry.c
Entry* Entry_new_destructor( String** key, void** val, Destructor destructor )
{
    Entry* self = Platform_Alloc( sizeof( Entry ) );
    if ( self )
    {
        self->destroy = destructor;
        self->key     = Take( key );
        self->val     = Take( val );
    }
    return self;
}
```

```c/ix/Entry.c
Entry* Entry_free( Entry** self )
{
    if ( *self )
    {
        String_free( &(*self)->key );

        if ( (*self)->destroy )
        {
            (*self)->destroy( &(*self)->val );
        }
        Platform_Free( self );
    }
    return *self;
}
```

```c/ix/Entry.c
const String* Entry_getKey( const Entry* self )
{
    return self->key;
}
```

```c/ix/Entry.c
const void* Entry_getValue( const Entry* self )
{
    return self->val;
}
```

### File

```!include/ix/File.h
#ifndef IX_FILE_H
#define IX_FILE_H

#include "ix.h"

File*       File_new        ( const char* filepath );

File*       File_free       (       File** self );
bool        File_canRead    ( const File*  self );
const char* File_getFilePath( const File*  self );
bool        File_exists     ( const File*  self );

#endif
```

```!c/ix/File.c
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include "ix.h"

struct _File
{
    const char* filepath;
    bool        canRead;
    bool        exists;
};

static bool File_IsReadable   ( const char* filepath );
static bool File_IsRegularFile( const char* filepath );
```

```c/ix/File.c
File* File_new( const char* filepath )
{
    File* self = calloc( 1, sizeof( File ) );
    if ( self )
    {
        self->filepath = filepath;
        self->canRead  = File_IsReadable   ( filepath );
        self->exists   = File_IsRegularFile( filepath );
    }
    return self;
}
```

```c/ix/File.c
File* File_free( File** self )
{
    free( *self ); *self = 0;

    return *self;
}
```

```c/ix/File.c
bool File_canRead( const File* self )
{
    return self->canRead;
}
```

```c/ix/File.c
const char* File_getFilePath( const File* self )
{
    return self->filepath;
}
```

```c/ix/File.c
bool File_exists( const File* self )
{
    return self->exists;
}
```

```c/ix/File.c
bool File_IsReadable( const char* filepath )
{
    return (F_OK == access( filepath, R_OK ));
}
```

```c/ix/File.c
bool File_IsRegularFile( const char* filepath )
{
    struct stat sb;

    stat( filepath, &sb );

    switch( sb.st_mode & S_IFMT )
    {
    case S_IFREG:
        return TRUE;
    
    default:
        return FALSE;
    }
}
```

### Files Iterator

```!include/ix/FilesIterator.h
#ifndef IX_FILESITERATOR_H
#define IX_FILESITERATOR_H

FilesIterator* FilesIterator_new      ( const char** filepaths );
FilesIterator* FilesIterator_free     ( FilesIterator** self   );
bool           FilesIterator_hasNext  ( FilesIterator*  self   );
File*          FilesIterator_next     ( FilesIterator*  self   );

#endif
```

```!c/ix/FilesIterator.c
#include <stdlib.h>
#include "ix.h"
#include "todo.h"

struct _FilesIterator
{
    const char** filepaths;
    int          next;
};
```

```c/ix/FilesIterator.c
FilesIterator* FilesIterator_new( const char** filepaths )
{
    FilesIterator* self = calloc( 1, sizeof( FilesIterator ) );
    if ( self )
    {
        self->filepaths = filepaths;
        self->next      = 0;
    }
    return self;
}
```

```c/ix/FilesIterator.c
FilesIterator* FilesIterator_free( FilesIterator** self )
{
    free( *self ); *self = 0;

    return *self;
}
```

```c/ix/FilesIterator.c
bool FilesIterator_hasNext( FilesIterator* self )
{
    if ( null != self->filepaths[self->next] )
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}
```

```c/ix/FilesIterator.c
File* FilesIterator_next( FilesIterator* self )
{
    if ( FilesIterator_hasNext( self ) )
    {
        Console_Write( "FilesIterator_next: %s\n", self->filepaths[self->next] );

        return File_new( self->filepaths[self->next++] );
    } else {
        return null;
    }
}
```

### Node

```!include/ix/Node.h
#ifndef IX_NODE_H
#define IX_NODE_H

Node* Node_new ( Token** token );
Node* Node_free( Node**  self  );

void  Node_setParent   ( Node* self, const Node* parent );
void  Node_setTag      ( Node* self, const char* tag );
Node* Node_addChild    ( Node* self, Token** token );
Node* Node_getLastChild( Node* self );

const Token*  Node_getToken    ( const Node* self );
const String* Node_getTag      ( const Node* self );

bool          Node_hasChildren ( const Node* self );
NodeIterator* Node_iterator    ( const Node* self );
String*       Node_export      ( const Node* self );
String*       Node_tokenString ( const Node* self );

#endif
```

```!c/ix/Node.c
#include "ix.h"
#include "ixcompiler.Token.h"

struct _Node
{
    Token*      token;
    const Node* parent;
    Array*      children;
    String*     tag;
};
```

```c/ix/Node.c
Node* Node_new( Token** token )
{
    Node* self = Platform_Alloc( sizeof( Node ) );

    if ( self )
    {
        self->token    = *token; *token = null;
        self->children = Array_new_destructor( (Destructor) Node_free );
    }
    return self;
}
```

```c/ix/Node.c
Node* Node_free( Node** self )
{
    if ( *self )
    {
        Token_free( &(*self)->token );

        Node* node = null;
        while ( (node = Array_shift( (*self)->children )) )
        {
            Node_free( &node );
        }
        Array_free ( &(*self)->children );
        String_free( &(*self)->tag      );

        (*self)->parent = null;

        Platform_Free( self );
    }
}
```

```c/ix/Node.c
void Node_setParent( Node* self, const Node* parent )
{
    self->parent = parent;
}
```

```c/ix/Node.c
void Node_setTag( Node* self, const char* tag )
{
    self->tag = String_new( tag );
}
```

```c/ix/Node.c
Node* Node_addChild( Node* self, Token** token )
{
    Node* child = Node_new( token );
    Node* ref   = child;

    Array_push( self->children, (void**) &child );

    return ref;
}
```

```c/ix/Node.c
Node* Node_getLastChild( Node* self )
{
    int last = Array_getLength( self->children ) - 1;

    return (Node*) Array_getObject( self->children, last );
}
```

```c/ix/Node.c
const Token* Node_getToken( const Node* self )
{
    return self->token;
}
```

```c/ix/Node.c
const String* Node_getTag( const Node* self )
{
    return self->tag;
}
```

```c/ix/Node.c
bool Node_hasChildren( const Node* self )
{
    return (0 < Array_getLength( self->children ));
}
```

```c/ix/Node.c
NodeIterator* Node_iterator( const Node* self )
{
    return NodeIterator_new( self->children );
}
```

```c/ix/Node.c
String* Node_export( const Node* self )
{
    String* ret = null;
    {
        StringBuffer* sb = StringBuffer_new();
        NodeIterator* it = Node_iterator( self );
        while ( NodeIterator_hasNext( it ) )
        {
            const Node*   node  = NodeIterator_next( it );
            const Token*  token = Node_getToken( node );

            if ( NEWLINE == Token_getTokenType( token ) ) break;

            StringBuffer_append( sb, Token_getContent( token ) );
        }
        ret = String_new( StringBuffer_content( sb ) );
        StringBuffer_free( &sb );
    }
    return ret;
}
```

```c/ix/Node.c
String* Node_tokenString ( const Node* self )
{
    return String_new( Token_getContent( Node_getToken( self ) ) );
}
```

### NodeIterator

```!include/ix/NodeIterator.h
#ifndef IX_NODEITERATOR_H
#define IX_NODEITERATOR_H

#include "ix.h"

NodeIterator* NodeIterator_new                   ( const Array*  nodes );
NodeIterator* NodeIterator_free                  ( NodeIterator** self );
bool          NodeIterator_hasNext               ( NodeIterator*  self );
bool          NodeIterator_hasNonWhitespace      ( NodeIterator*  self );
bool          NodeIterator_hasNonWhitespaceOfType( NodeIterator*  self, EnumTokenType type );
const Node*   NodeIterator_next                  ( NodeIterator*  self );
const Node*   NodeIterator_peek                  ( NodeIterator*  self );
String*       NodeIterator_nextTokenString       ( NodeIterator*  self );


#endif
```

```!c/ix/NodeIterator.c
#include "ix.h"
#include "ixcompiler.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"

struct _NodeIterator
{
    const Array* nodes;
    int          next;
};
```

```c/ix/NodeIterator.c
NodeIterator* NodeIterator_new( const Array* nodes )
{
    NodeIterator* self = Platform_Alloc( sizeof( NodeIterator ) );
    if ( self )
    {
        self->nodes = nodes;
        self->next  = 0;
    }
    return self;
}
```

```c/ix/NodeIterator.c
NodeIterator* NodeIterator_free( NodeIterator** self )
{
    if ( *self )
    {
        (*self)->nodes = null;
        (*self)->next  = 0;

        Platform_Free( self );
    }
    return *self;
}
```

```c/ix/NodeIterator.c
bool NodeIterator_hasNext( NodeIterator* self )
{
    return (self->next < Array_getLength( self->nodes ));
}
```

```c/ix/NodeIterator.c
bool NodeIterator_hasNonWhitespace( NodeIterator* self )
{
    bool has_next_nws = FALSE;

    while ( NodeIterator_hasNext( self ) )
    {
        const Node*   node  = Array_getObject( self->nodes, self->next );
        const Token*  token = Node_getToken( node );
        EnumTokenType type  = Token_getTokenType( token );

        if ( LINECOMMENT == type )
        {
            while ( NodeIterator_hasNext( self ) )
            {
                const Token* token = Node_getToken( NodeIterator_next( self ) );

                if ( Token_getTokenType( token ) == NEWLINE )
                {
                    break;
                }
            }
        }
        else
        if ( WHITESPACE != TokenGroup_getGroupType( Token_getTokenGroup( token ) ) )
        {
            has_next_nws = TRUE;
            break;
        }
        else
        {
            NodeIterator_next( self );
        }
    }

    return has_next_nws;
}
```

```c/ix/NodeIterator.c
bool NodeIterator_hasNonWhitespaceOfType( NodeIterator* self, EnumTokenType type )
{
    bool has = FALSE;

    if ( NodeIterator_hasNonWhitespace( self ) )
    {
        const Node* peek = NodeIterator_peek( self );
        has = (type == Token_getTokenType( Node_getToken( peek ) ) );
    }
    return has;
}
```

```c/ix/NodeIterator.c
const Node* NodeIterator_next( NodeIterator* self )
{
    return (const void*) Array_getObject( self->nodes, self->next++ );
}
```

```c/ix/NodeIterator.c
const Node* NodeIterator_peek( NodeIterator* self )
{
    return (const void*) Array_getObject( self->nodes, self->next );
}
```

```c/ix/NodeIterator.c
String* NodeIterator_nextTokenString( NodeIterator* self )
{
    return Node_tokenString( NodeIterator_next( self ) );
}
```

### Object

```!include/ix/Object.h
#ifndef IX_OBJECT_H
#define IX_OBJECT_H

#include "ix.h"

struct _Object
{
    Object*(*free)(Object**);
};

Object* Object_new ();
Object* Object_init( Object*  self );
Object* Object_free( Object** self );

int     Object_Sizeof();

#endif
```

```!c/ix/Object.c
#include "ix.h"
```

```c/ix/Object.c
Object* Object_new()
{
    Object* self = Object_init( 0 );

    return self;
}
```

```c/ix/Object.c
Object* Object_init( Object* self )
{
    if ( !self ) self = Platform_Alloc( Object_Sizeof() );
    if ( self )
    {
        self->free = Object_free;
    }
    return self;
}
```

```c/ix/Object.c
Object* Object_free( Object** self )
{
    if ( self && *self )
    {
        if ( Object_free != (*self)->free )
        {
            (*self)->free( self );
        }
        else
        {
            Platform_Free( *self );
        }
    }
    return 0;
}
```

```c/ix/Object.c
int Object_Sizeof()
{
    return sizeof(Object);
}
```


### Path

```!include/ix/Path.h
#ifndef IX_PATH_H
#define IX_PATH_H

Path* Path_new( const char* target );

Path*       Path_free       (       Path** self );
bool        Path_exists     ( const Path*  self );
bool        Path_canWrite   ( const Path*  self );
const char* Path_getFullPath( const Path*  self );
Path*       Path_getParent  ( const Path*  self );

#endif
```

```!c/ix/Path.c
#include <stdlib.h>
#include "ix.h"

struct _Path
{
    bool  exists;
    bool  canWrite;
    char* path;
};
```

```c/ix/Path.c
Path* Path_new( const char* target )
{
    Path* self = calloc( 1, sizeof( Path ) );
    if ( self )
    {
        self->exists   = Platform_Location_IsDirectory( target );
        self->canWrite = Platform_Location_IsWritable ( target );
        self->path     = Platform_Location_FullPath   ( target );
    }

    return self;
}
```

```c/ix/Path.c
Path* Path_free( Path** self )
{
    free( (*self)->path );
    free( *self ); *self = 0;

    return *self;
}
```

```c/ix/Path.c
bool Path_exists( const Path* self )
{
    return self->exists;
}
```

```c/ix/Path.c
bool Path_canWrite( const Path* self )
{
    return self->canWrite;
}
```

```c/ix/Path.c
const char* Path_getFullPath( const Path* self )
{
    return self->path;
}
```

```c/ix/Path.c
Path* Path_getParent( const Path* self )
{
    Path* ret  = null;
    char* path = String_Copy( Path_getFullPath( self ) );
    int   n    = String_Length( path ) - 1;

    if ( '/' == path[n] )
    {
        path[n] = '\0';
        n--;
    }

    while ( 0 <= n )
    {
        if ( '/' == path[n] ) break;
        
        path[n--] = '\0';
    }

    ret = Path_new( path );

    Platform_Free( &path );

    return ret;
}
```

### PushbackReader

```!include/ix/PushbackReader.h
#ifndef IX_PUSHBACKREADER_H
#define IX_PUSHBACKREADER_H

PushbackReader* PushbackReader_new     ( const char*      filepath );
PushbackReader* PushbackReader_free    ( PushbackReader** self     );
int             PushbackReader_read    ( PushbackReader*  self     );
PushbackReader* PushbackReader_pushback( PushbackReader*  self     );

#endif
```

```!c/ix/PushbackReader.c
#include "ix.h"

struct _PushbackReader
{
    char* content;
    int   head;
    int   length;
};
```

```c/ix/PushbackReader.c
PushbackReader* PushbackReader_new( const char* filepath )
{
    PushbackReader* self = Platform_Alloc( sizeof( PushbackReader ) );
    File*           file = File_new( filepath );

    if ( self )
    {
        self->head = 0;

        if ( File_exists( file ) )
        {
            self->content = Platform_File_GetContents( filepath );
            self->length  = String_Length( self->content );
        }
        else
        {
            self->content = String_Copy( "" );
            self->length  = 0;
        }
    }

    File_free( &file );

    return self;
}
```

```c/ix/PushbackReader.c
PushbackReader* PushbackReader_free( PushbackReader** self )
{
    Platform_Free( &(*self)->content );
    Platform_Free( self );

    return *self;
}
```

```c/ix/PushbackReader.c
int PushbackReader_read( PushbackReader* self )
{
    return (self && (self->head < self->length)) ? self->content[self->head++] : 0;
}
```

```c/ix/PushbackReader.c
PushbackReader* PushbackReader_pushback( PushbackReader* self )
{
    self->head--;
    return self;
}
```.. Queue

```!include/ix/Queue.h
#ifndef IX_QUEUE_H
#define IX_QUEUE_H

Queue*      Queue_new       ( Destructor destroy );
Queue*      Queue_free      ( Queue** self );
Queue*      Queue_addHead   ( Queue* self, void** object );
Queue*      Queue_addTail   ( Queue* self, void** object );
void*       Queue_removeHead( Queue* self );
const void* Queue_getHead   ( Queue* self );
const void* Queue_getTail   ( Queue* self );
int         Queue_getLength ( Queue* self );

#endif
```

```!c/ix/Queue.c
#include "ix.h"

struct _Queue
{
    Array* inner;

};
```

```c/ix/Queue.c
Queue* Queue_new( Destructor destroy )
{
    Queue* self = Platform_Alloc( sizeof( Queue ) );

    if ( self )
    {
        self->inner = Array_new_destructor( destroy );
    }
    return self;
}
```

```c/ix/Queue.c
Queue* Queue_free( Queue** self )
{
    Array_free( &(*self)->inner );
    Platform_Free( self );

    return *self;
}
```

```c/ix/Queue.c
Queue* Queue_addHead( Queue* self, void** object )
{
    Array_unshift( self->inner, object );

    return self;
}
```

```c/ix/Queue.c
Queue* Queue_addTail( Queue* self, void** object )
{
    Array_push( self->inner, object );

    return self;
}
```

```c/ix/Queue.c
void* Queue_removeHead( Queue* self )
{
    return Array_shift( self->inner );
}
```

```c/ix/Queue.c
const void* Queue_getHead( Queue* self )
{
    return Array_getObject( self->inner, 0 );
}
```

```c/ix/Queue.c
const void* Queue_getTail( Queue* self )
{
    int last = Array_getLength( self->inner );
    if ( last > 0 )
    {
        return Array_getObject( self->inner, --last );
    }
    else
    {
        return null;
    }
}
```

```c/ix/Queue.c
int Queue_getLength( Queue* self )
{
    return Array_getLength( self->inner );
}
```

### String

```!include/ix/String.h
#ifndef IX_STRING_H
#define IX_STRING_H

String*        String_new           ( const char* content );
String*        String_free          (       String** self );
const char*    String_content       ( const String*  self );
int            String_getLength     ( const String*  self );
String*        String_copy          ( const String*  self );
String*        String_cat           ( const String*  self, const String* other );
String*        String_cat_chars     ( const String*  self, const char*   chars );
bool           String_equals        ( const String*  self, const String* other );
bool           String_equals_chars  ( const String*  self, const char*   chars );
bool           String_contains      ( const String*  self, const String* other );
bool           String_contains_chars( const String*  self, const char*   chars );
ArrayOfString* String_split         ( const String*  self, char separator      );
String*        String_toUpperCase   ( const String*  self );
String*        String_replace       ( const String*  self, char ch, char with );

String*        String_Cat    ( const char* string1, const char* string2 );
bool           String_Equals ( const char* string1, const char* string2 );
int            String_Length ( const char* s );
char*          String_Copy   ( const char* s );
char*          String_Convert( String** string );

#endif
```

```!c/ix/String.c
#include <string.h>
#include "ix.h"

struct _String
{
    char* content;
    int   length;
};

String* String_new_keep( char** keep );
```

```c/ix/String.c
String* String_new( const char* content )
{
    String* self = Platform_Alloc( sizeof(String) );
    if ( self )
    {
        self->content = String_Copy( content );
        self->length  = String_Length( content );
    }
    return self;
}
```

```c/ix/String.c
String* String_new_keep( char** keep )
{
    String* self = Platform_Alloc( sizeof(String) );
    if ( self )
    {
        self->length  = String_Length( *keep );
        self->content = Take( keep );
    }
    return self;
}
```

```c/ix/String.c
String* String_free( String** self )
{
    if ( *self )
    {
        Platform_Free( &(*self)->content );
        Platform_Free(    self           );
    }
    return *self;
}
```

```c/ix/String.c
const char* String_content( const String* self )
{
    return self->content;
}
```

```c/ix/String.c
int String_getLength( const String* self )
{
    return self->length;
}
```

```c/ix/String.c
String* String_copy( const String* self )
{
    return String_new( self->content );
}
```

```c/ix/String.c
String* String_cat( const String* self, const String* other )
{
    return String_cat_chars( self, other->content );
}
```

```c/ix/String.c
String* String_cat_chars( const String* self, const char* chars )
{
    return String_Cat( self->content, chars );
}
```

```c/ix/String.c
bool String_equals( const String* self, const String* other )
{
    return String_Equals( self->content, other->content );
}
```

```c/ix/String.c
bool String_equals_chars( const String* self, const char* chars )
{
    if ( self && chars )
    {
        const char* content = String_content( self );
        return (0 == strcmp( content, chars ));
    }
    else
    {
        return FALSE;
    }
}
```

```c/ix/String.c
bool String_contains( const String* self, const String* other )
{
    return String_contains_chars( self, String_content( other ) );
}
```

```c/ix/String.c
bool String_contains_chars( const String* self, const char* chars )
{
    return (NULL != strstr( String_content( self ), chars ));
}
```

```c/ix/String.c
ArrayOfString* String_split( const String* self, char separator )
{
    ArrayOfString* strings = ArrayOfString_new();
    {
        StringBuffer* sb      = StringBuffer_new();
        const char*   content = String_content( self );
        int           n       = String_getLength( self );

        for ( int i=0; i < n; i++ )
        {
            if ( content[i] == separator )
            {
                if ( !StringBuffer_isEmpty( sb ) )
                {
                    String* sbc = String_new( StringBuffer_content( sb ) );
                    ArrayOfString_push( strings, &sbc );
                    StringBuffer_free( &sb );
                    sb = StringBuffer_new();
                }
            }
            else
            {
                StringBuffer_append_char( sb, content[i] );
            }
        }

        if ( !StringBuffer_isEmpty( sb ) )
        {
            String* sbc = String_new( StringBuffer_content( sb ) );
            ArrayOfString_push( strings, &sbc );
        }
        StringBuffer_free( &sb );
    }
    return strings;
}
```

```c/ix/String.c
String* String_toUpperCase( const String* self )
{
    String* ret = null;
    {
        char* buffer = String_Copy( self->content );
        int   n      = self->length;

        for ( int i=0; i < n; i++ )
        {
            int ch = buffer[i];

            //    'a'                 'z'
            if ( (97 <= ch) && (ch <= 122) )
            {
                buffer[i] = ch - 32;
            }
        }
        ret = String_new( buffer );
        Platform_Free( &buffer );
    }
    return ret;
}
```

```c/ix/String.c
String* String_replace( const String* self, char ch, char with )
{
    String* ret = null;
    {
        char* buffer = String_Copy( self->content );
        int   n      = self->length;

        for ( int i=0; i < n; i++ )
        {
            if ( ch == buffer[i] ) buffer[i] = with;
        }
        ret = String_new( buffer );
        Platform_Free( &buffer );
    }
    return ret;
}
```

```c/ix/String.c
String* String_Cat( const char* s1, const char* s2 )
{
    int len1 = String_Length( s1 );
    int len2 = String_Length( s2 );
    int len  = len1 + len2 + 1;

    char* concatenated = Platform_Array( len, sizeof( char ) );

    int t=0;

    for ( int i=0; i < len1; i++ )
    {
        concatenated[t++] = s1[i];
    }

    for ( int i=0; i < len2; i++ )
    {
        concatenated[t++] = s2[i];
    }

    concatenated[t] = '\0';

    return String_new_keep( &concatenated );
}
```

```c/ix/String.c
char* String_Copy( const char* s )
{
    int   len  = String_Length( s ) + 2;
    char* copy = Platform_Array( len, sizeof( char ) );

    return strcpy( copy, s );
}
```

```c/ix/String.c
bool String_Equals( const char* string1, const char* string2 )
{
    if ( (NULL == string1) || (NULL == string2) )
    {
        return FALSE;
    }
    else
    {
        return (0 == strcmp( string1, string2 ));
    }
}
```

```c/ix/String.c
int String_Length( const char* s )
{
    return strlen( s );
}
```

```c/ix/String.c
char* String_Convert( String** string )
{
    char* tmp = (*string)->content; (*string)->content = null;

    String_free( string );

    return tmp;
}
```
### StringBuffer

```!include/ix/StringBuffer.h
#ifndef IX_STRINGBUFFER_H
#define IX_STRINGBUFFER_H

StringBuffer* StringBuffer_new                       ();
StringBuffer* StringBuffer_free                      ( StringBuffer** self                                                );
StringBuffer* StringBuffer_append_char               ( StringBuffer*  self,       char  ch                                );
StringBuffer* StringBuffer_append                    ( StringBuffer*  self, const char* suffix                            );
StringBuffer* StringBuffer_appendLine_prefix_optional( StringBuffer*  self, const char* prefix, String** optional         );

const char*   StringBuffer_content    ( const StringBuffer*  self );
bool          StringBuffer_isEmpty    ( const StringBuffer*  self );
String*       StringBuffer_toString   ( const StringBuffer*  self );

String*       StringBuffer_ConvertToString( StringBuffer** sb );

#endif
```

```!c/ix/StringBuffer.c
#include "ix.h"

struct _StringBuffer
{
    char* content;
    int   length;

};

String* StringBuffer_nullString = null;
```

```c/ix/StringBuffer.c
StringBuffer* StringBuffer_new()
{
    StringBuffer* self = Platform_Alloc( sizeof( StringBuffer ) );

    if ( self )
    {
        self->content = String_Copy( "" );
        self->length  = 0;
    }
    return self;
}
```

```c/ix/StringBuffer.c
StringBuffer* StringBuffer_free( StringBuffer** self )
{
    if ( *self )
    {
        Platform_Free( &(*self)->content );
        Platform_Free(    self           );
    }

    return *self;
}
```

```c/ix/StringBuffer.c
StringBuffer* StringBuffer_append_char( StringBuffer* self, char ch )
{
    char suffix[2] = { ch , '\0' };

    return StringBuffer_append( self, suffix );
}
```

```c/ix/StringBuffer.c
StringBuffer* StringBuffer_append( StringBuffer* self, const const char* suffix )
{
    self->length += String_Length( suffix );
    char*   tmp   = self->content;
    self->content = String_Convert( (String**) Give( String_Cat( tmp, suffix ) ) );

    Platform_Free( &tmp );

    return self;
}
```

```c/ix/StringBuffer.c
StringBuffer* StringBuffer_appendLine_prefix_optional( StringBuffer* self, const char* prefix, String** optional )
{
    if ( prefix && String_Length( prefix ) )
    {
        StringBuffer_append( self, prefix );
        StringBuffer_append( self, " "    );
    }

    if ( optional && *optional )
    {
        StringBuffer_append( self, String_content( *optional ) );
        String_free( optional );
    }
    StringBuffer_append( self, "\n" );
}
```

```c/ix/StringBuffer.c
const char* StringBuffer_content( const StringBuffer* self )
{
    return self->content;
}
```

```c/ix/StringBuffer.c
bool StringBuffer_isEmpty( const StringBuffer* self )
{
    return (0 == String_Length( self->content ));
}
```

```c/ix/StringBuffer.c
String* StringBuffer_toString( const StringBuffer* self )
{
    return String_new( StringBuffer_content( self ) );
}
```

```c/ix/StringBuffer.c
String* StringBuffer_ConvertToString( StringBuffer** sb )
{
    String* ret = String_new( (*sb)->content );
    StringBuffer_free( sb );
    return ret;
}
```

### Take

```!c/ixcompiler.Take.c
#include "ix.h"

static void* stash[100];
```

```c/ixcompiler.Take.c
void** Give( void* pointer )
{
    void** tmp = stash;

    while ( *tmp ) tmp++;

    *tmp = pointer;

    return tmp;
}
```

```c/ixcompiler.Take.c
void* Take( ANY given )
{
    void** _given = (void**) given;

    void* keeper = *_given; *_given = null;

    return keeper;
}
```

```c/ixcompiler.Take.c
void Swap( ANY _one, ANY _two )
{
    void** one = _one;
    void** two = _two;
    void*  tmp;

    tmp  = *one;
    *one = *two;
    *two =  tmp;
}
```

```!include/ix/Term.h
#ifndef IX_TERM_H
#define IX_TERM_H

#define COLOR_NORMAL   "\033[00m"
#define COLOR_BOLD     "\033[01m"
#define COLOR_LIGHT    "\033[02m"
#define COLOR_STRING   "\033[33m"
#define COLOR_TYPE     "\033[36m"
#define COLOR_MODIFIER "\033[94m"
#define COLOR_VALUE    "\033[33m"
#define COLOR_CHAR     "\033[33m"
#define COLOR_COMMENT  "\033[32m"
#define COLOR_UNKNOWN  "\033[41m"

void Term_Colour( void* stream, const char* color );

#endif
```

```!c/ix/Term.c
#include <stdio.h>
#include "ix.h"

void Term_Colour( void* stream, const char* color )
{
    fprintf( stream, "%s", color );
}
```
### Tree

```!include/ix/Tree.h
#ifndef IX_TREE_H
#define IX_TREE_H

Tree* Tree_new();
Tree* Tree_free   ( Tree** self );
void  Tree_setRoot( Tree*  self, Node** node );

const Node* Tree_getRoot( const Tree* self );

#endif
```

```!c/ix/Tree.c
#include "ix.h"

struct _Tree
{
    Node* root;
};
```

```c/ix/Tree.c
Tree* Tree_new()
{
    Tree* self = Platform_Alloc( sizeof( Tree ) );
    return self;
}
```

```c/ix/Tree.c
Tree* Tree_free( Tree** self )
{
    if ( *self )
    {
        Node_free( &(*self)->root );
        Platform_Free( self );
    }
    return *self;
}
```

```c/ix/Tree.c
void Tree_setRoot( Tree* self, Node** node )
{
    self->root = *node; *node = null;
}
```

```c/ix/Tree.c
const Node* Tree_getRoot( const Tree* self )
{
    return self->root;
}
```

```!include/ix/Platform.h
#ifndef IX_PLATFORM_H
#define IX_PLATFORM_H

void* Platform_Alloc                 ( int size_of );
void* Platform_Array                 ( int num, int size_of );
void* Platform_Free                  ( void* mem );

void  Platform_Exit                  ( int status );

bool  Platform_File_WriteContents    ( const char* location, const char* content, bool force );
char* Platform_File_GetContents      ( const char* location );

bool  Platform_Location_Exists       ( const char* location );
char* Platform_Location_FullPath     ( const char* location );
bool  Platform_Location_IsDirectory  ( const char* location );
bool  Platform_Location_IsReadable   ( const char* location );
bool  Platform_Location_IsRegularFile( const char* location );
bool  Platform_Location_IsWritable   ( const char* location );

bool  Platform_Path_Create           ( const Path* path     );

#endif
```

```!c/ix/posix/Platform.c
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/limits.h>

#include "ix.h"
```

```c/ix/posix/Platform.c
void* Platform_Alloc( int size_of )
{
    return calloc( 1, size_of );
}
```

```c/ix/posix/Platform.c
void* Platform_Array( int num, int size_of )
{
    return calloc( num, size_of );
}
```

```c/ix/posix/Platform.c
void* Platform_Free( void* mem )
{
    void** obj = (void**) mem;

    free( *obj ); *obj = 0;

    return *obj;
}
```

```c/ix/posix/Platform.c
void Platform_Exit( int status )
{
    exit( status );
}
```

```c/ix/posix/Platform.c
bool Platform_File_WriteContents( const char* location, const char* content, bool force )
{
    bool success = FALSE;

    FILE* fp = force ? fopen( location, "w+" ) : fopen( location, "w" );

    if ( fp )
    {
        int   n       = String_Length( content );
        int   written = fwrite( content, sizeof(char), n, fp );

        success = (n == written);
    }
    return success;
}
```

```c/ix/posix/Platform.c
char* Platform_File_GetContents( const char* location )
{
    char* content = null;
    FILE* fp      = fopen( location, "r" );

    if ( fp )
    {
        struct stat buf;

        if( 0 == lstat( location, &buf ) )
        {
            int size = buf.st_size;

            content = Platform_Array( size + 1, sizeof( char ) );

            int red = fread( content, size, 1, fp );
        }
    }
    return content;
}
```

```c/ix/posix/Platform.c
bool Platform_Location_Exists( const char* location )
{
    struct stat sb;

    return (F_OK == stat( location, &sb ));
}
```

```c/ix/posix/Platform.c
char* Platform_Location_FullPath( const char* location )
{
    char* ret = calloc( PATH_MAX, sizeof( char ) );

    if ( '/' == location[0] )
    {
        return strcpy( ret, location );
    }
    else
    {
        getcwd( ret, PATH_MAX );
        int last = strlen( ret );
        if ( '/' != ret[last-1] )
        {
            strcpy( &ret[last++], "/" );
        }
        strcpy( &ret[last], location );
    }

    return ret;
}
```

```c/ix/posix/Platform.c
bool Platform_Location_IsDirectory( const char* location )
{
    struct stat sb;

    stat( location, &sb );

    switch( sb.st_mode & S_IFMT )
    {
    case S_IFDIR:
        return TRUE;
    
    default:
        return FALSE;
    }
}
```

```c/ix/posix/Platform.c
bool Platform_Location_IsReadable( const char* location )
{
    return (F_OK == access( location, R_OK ));
}
```

```c/ix/posix/Platform.c
bool Platform_Location_IsRegularFile( const char* location )
{
    struct stat sb;

    stat( location, &sb );

    switch( sb.st_mode & S_IFMT )
    {
    case S_IFREG:
        return TRUE;
    
    default:
        return FALSE;
    }
}
```

```c/ix/posix/Platform.c
bool Platform_Location_IsWritable( const char* location )
{
    return (F_OK == access( location, W_OK ));
}
```

```c/ix/posix/Platform.c
bool Platform_Path_Create( const Path* path )
{
    bool success = FALSE;

    if ( Platform_Location_Exists( Path_getFullPath( path ) ) )
    {
        success = TRUE;
    }
    else
    {
        Path* parent = Path_getParent( path );
        if ( Platform_Path_Create( parent ) )
        {
            if ( 0 == mkdir( Path_getFullPath( path ), 0750 ) )
            {
                success = TRUE;
            }
        }
        Path_free( &parent );
    }
    return success;
}
```
### To Do

```!include/todo.h
#ifndef TODO_H
#define TODO_H

void Todo( const char* fn );

#endif
```

```!c/todo.c
#include <stdio.h>
#include "ixcompiler.h"
#include "todo.h"

void Todo( const char* fn )
{
    fprintf( stderr, "Todo: %s\n", fn );
    fflush( stderr );
}
```

## Commentary

This section provides a chronological commentary for significant issues and design decisions.

### 2021-11-14 (Sunday)

Have moved the testing of complete arguments from the Arguments class to the main method.
The philosophy behind this is that only the main method should be allowed to call 'exit'
so that crashes from witin methods can be better identified.

### 2021-12-06 (Monday)

Today I had a commit session of parsing related code that I wrote recently.
The IxParser class will take a tokenizer, which can now be parsed into a simple parse tree.
The start of each statement is the node of the tree, with tokens contained with a statement being the children of that node.
I have also implemented a simple printed tree output that shows this structure.
I feel that now is a good time to renumber/reorder the source files so that the quasi-source output is in a more readable order.

I realise that I will need to restructure the code in the main method to allow for the generation of a common C header files,
however, I plan to leave that for a bit later.
I plan to restructure the main method so that the argument checking code is in a sub-procedure in order to allow main to better focus on parsing and code generation.

### 2021-12-17 (Saturday)

I have made the following decisions regarding the parsing/code generation process.
The AST will be extracted from the IxParser and will operate independantly on each source file.
The IxParser will then process each AST to create a collection of IxSourceUnit objects that similarly contain lower level concrete objects.
A generator may then process this collection of IxSourceUnits in order to produce its language dependent output.

### 2022-01-02 (Sunday)

I've realised that I don't actually need all of the ArrayOf<Class> types explicitly.
The main reason I had them was so that I could easily deallocate the array and its contents by calling its "free" function.
However, I realised last night while reading through the code, that all I needed to do was pass a destructor function for the held type to the array when creating it.
The arrray can then use that destructor to deallocate each of the held objects.

### 2022-01-09 (Sunday)

Been implementing function generation.
Have decided to alter tokenisation and parsing in following ways:
The '@' and '%' are now the INSTANCEMEMBER and CLASSMEMBER tokens respectively.
This means that '%' will no longer be treated as an infixop (for mod).
When parsing statements, a statement that does not begin with a key word will have
a empty token representing a STATEMENT added and following tokens will be added as children to that node,
and when an infixop is encountered any following tokens will be added as children to that node.

### 2022-01-14 (Friday)

I've made some fairly major changes to how the tokenizer, AST parser, and Ix parsing work.
I added a mechinism that allows the AST parser to tidy unexpected tokens into separate branches of the parse tree.
I suspected this was a bit overkill and I wanted a less rigid way of forming the parse tree.
However, I was having a problem with not expecting STOP tokens at the end of statements.
So, I've now modified the tokenizer to do auto insertion of STOP tokens where they are required.
For example, a word should not be followed by anonther word etc. See Token_ShouldInsertStop for details.
This has allowed some simplification of the AST parser, which was a getting a bit complicated,
as I can now rely on coming across STOP tokens.

I'm quite happy with the form of the parse tree now, i.e.

1.  a class node only has one child node for each member.
2.  a parameters node only has one child node for each parameter.
3.  a statement block only has one child for each statement.
4.  fully qualified types are now separated onto a separate branch.
5.  infix operators separate subexpressions onto their own branch.

The above should make the transformation from the parse tree into the Ix Source object data structure much simpler.

