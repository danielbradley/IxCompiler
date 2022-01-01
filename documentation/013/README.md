
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
#include "ixcompiler.Console.h"
#include "ixcompiler.File.h"
#include "ixcompiler.FilesIterator.h"
#include "ixcompiler.Generator.h"
#include "ixcompiler.IxParser.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.IxSourceUnitCollection.h"
#include "ixcompiler.Path.h"
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
            if ( TRUE )
            {
                Tokenizer* t   = Tokenizer_new( &file );
                AST*       ast = AST_new( &t );

                ASTPrinter_Print( ast );
                ASTCollection_add( ast_collection, &ast );
            }
        }

        int n = ASTCollection_getLength( ast_collection );

        for ( int i=0; i < n; i++ )
        {
            const AST* ast = ASTCollection_get( ast_collection, i );

            IxSourceUnit* source_unit = IxSourceUnit_new( ast );

            IxSourceUnitCollection_add( source_units, &source_unit );
        }

        if ( !dry_run )
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
### Includes

```!include/ixcompiler.h
//
// Copyright 2021 Daniel Robert Bradley
//

#ifndef IXCOMPILER_H
#define IXCOMPILER_H

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

#ifndef DISPOSABLE
#define DISPOSABLE
#endif

typedef struct _Arguments                       Arguments;
typedef struct _Array                           Array;
typedef struct _ArrayOfIxSourceFunction         ArrayOfIxSourceFunction;
typedef struct _ArrayOfIxSourceMember           ArrayOfIxSourceMember;
typedef struct _ArrayOfIxSourceMethod           ArrayOfIxSourceMethod;
typedef struct _ArrayOfIxSourceParameter        ArrayOfIxSourceParameter;
typedef struct _ArrayOfIxSourceStatement        ArrayOfIxSourceStatement;
typedef struct _ArrayOfString                   ArrayOfString;
typedef struct _AST                             AST;
typedef struct _ASTCollection                   ASTCollection;
typedef struct _Dictionary                      Dictionary;
typedef struct _Entry                           Entry;
typedef enum   _EnumTokenGroup                  EnumTokenGroup;
typedef enum   _EnumTokenType                   EnumTokenType;
typedef struct _File                            File;
typedef struct _FilesIterator                   FilesIterator;
typedef struct _Generator                       Generator;
typedef struct _IxParser                        IxParser;
typedef struct _IxSourceClass                   IxSourceClass;
typedef struct _IxSourceComment                 IxSourceComment;
typedef struct _IxSourceFunction                IxSourceFunction;
typedef struct _IxSourceHeader                  IxSourceHeader;
typedef struct _IxSourceInterface               IxSourceInterface;
typedef struct _IxSourceMember                  IxSourceMember;
typedef struct _IxSourceMethod                  IxSourceMethod;
typedef struct _IxSourceParameter               IxSourceParameter;
typedef struct _IxSourceSignature               IxSourceSignature;
typedef struct _IxSourceStatement               IxSourceStatement;
typedef struct _IxSourceUnit                    IxSourceUnit;
typedef struct _IxSourceUnitCollection          IxSourceUnitCollection;
typedef struct _Node                            Node;
typedef struct _NodeIterator                    NodeIterator;
typedef struct _Path                            Path;
typedef struct _PushbackReader                  PushbackReader;
typedef struct _Queue                           Queue;
typedef struct _String                          String;
typedef struct _StringBuffer                    StringBuffer;
typedef struct _Token                           Token;
typedef struct _TokenGroup                      TokenGroup;
typedef struct _Tokenizer                       Tokenizer;
typedef struct _Tree                            Tree;

typedef int(*GeneratorFn)( const IxSourceUnitCollection*, const Path* );

void** Give( void* pointer );
void*  Take( void* giver   );

#endif
```

### Arguments

```!include/ixcompiler.Arguments.h
#ifndef IXCOMPILER_ARGUMENTS_H
#define IXCOMPILER_ARGUMENTS_H

Arguments*     Arguments_new          ( int argc, char** argv );
Arguments*     Arguments_free         ( Arguments** self );
bool           Arguments_hasFlag      ( Arguments* self, const char* argument );
const char*    Arguments_getOption    ( Arguments* self, const char* argument );
FilesIterator* Arguments_filesIterator( Arguments* self );

#endif
```

```!c/ixcompiler.Arguments.c
#include "ixcompiler.h"
#include "ixcompiler.Arguments.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.FilesIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
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

enum _EnumTokenGroup
{
    UNKNOWN_GROUP,
    WHITESPACE,
    OPEN,
    CLOSE,
    SYMBOLIC,
    ESCAPE,
    ALPHANUMERIC,
    STRING,
    CHAR,
    VALUE,
    HEX_VALUE

};

#endif
```

### Enum Token Type

```!include/ixcompiler.EnumTokenType.h
#ifndef IXCOMPILER_ENUMTOKENTYPE_H
#define IXCOMPILER_ENUMTOKENTYPE_H

#include "ixcompiler.h"

enum _EnumTokenType
{
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
    OPERATOR,
    ASSIGNMENTOP,
    PREFIXOP,
    INFIXOP,
	POSTFIXOP,
    PREINFIXOP,
    PREPOSTFIXOP,
    STOP,
    LINECOMMENT,
    COMMENT,

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
};

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
    case OPERATOR:           return "OPERATOR";
    case ASSIGNMENTOP:       return "ASSIGNMENTOP";
    case PREFIXOP:           return "PREFIXOP";
    case INFIXOP:            return "INFIXOP";
    case POSTFIXOP:          return "POSTFIXOP";
    case PREINFIXOP:         return "PREINFIXOP";
    case PREPOSTFIXOP:       return "PREPOSTFIXOP";
    case STOP:               return "STOP";
    case LINECOMMENT:        return "LINECOMMENT";
    case COMMENT:            return "COMMENT";
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

### Token

```!include/ixcompiler.Token.h
#ifndef IXCOMPILER_TOKEN_H
#define IXCOMPILER_TOKEN_H

#include "ixcompiler.h"

Token*            Token_new                      ( Tokenizer* t, const char* content, TokenGroup* aGroup );
Token*            Token_free                     ( Token**      self );
const char*       Token_getContent               ( const Token* self );
const TokenGroup* Token_getTokenGroup            ( const Token* self );
EnumTokenType     Token_getTokenType             ( const Token* self );
void              Token_print                    ( const Token* self, void* stream );

#endif
```

```!c/ixcompiler.Token.c
#include <stdio.h>
#include "ixcompiler.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.Term.h"
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
void Token_print( const Token* self, void* stream )
{
    EnumTokenGroup group_type = TokenGroup_getGroupType( self->group );

    switch ( group_type )
    {
    case OPEN:
    case CLOSE:
    case SYMBOLIC:
        switch( self->type )
        {
        case COMMENT:
        case LINECOMMENT:
            Term_Colour( stream, COLOR_COMMENT );
            break;

        default:
            Term_Colour( stream, COLOR_BOLD );
        }
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
    //fprintf( stream, "%s", self->content );
    fprintf( stream, "%s (%s)", self->content, self->typeName );
    Term_Colour( stream, COLOR_NORMAL );
}
```


```c/ixcompiler.Token.c
EnumTokenType Token_DetermineTokenType( TokenGroup* group, const char* content )
{
    EnumTokenType type = UNKNOWN_TYPE;

    switch ( TokenGroup_getGroupType( group ) )
    {
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
    case ':':   return OFTYPE;
    case '':   return SYMBOL;
    case '!':
        switch ( content[1] )
        {
        case '=':  return INFIXOP;
        default:   return PREFIXOP;
        }
        break;

    case '@':   return SYMBOL;
    case '#':   return SYMBOL;
    case '$':   return SYMBOL;
    case '%':
        switch ( content[1] )
        {
        case '=':  return ASSIGNMENTOP;
        default:   return INFIXOP;
        }
        break;

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
        case '*':  return COMMENT;
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

### Token Group

```!include/ixcompiler.TokenGroup.h
#ifndef IXCOMPILER_TOKENGROUP_H
#define IXCOMPILER_TOKENGROUP_H

TokenGroup*    TokenGroup_new          ( char ch );
TokenGroup*    TokenGroup_free         ( TokenGroup** self );

EnumTokenGroup TokenGroup_getGroupType ( const TokenGroup* self );
bool           TokenGroup_matches      ( const TokenGroup* self, char ch );
TokenGroup*    TokenGroup_copy         ( const TokenGroup* self );
EnumTokenGroup TokenGroup_DetermineType( char ch );

#endif
```

```!c/ixcompiler.TokenGroup.c
#include "ixcompiler.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.Platform.h"
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

### Tokenizer

```!include/ixcompiler.Tokenizer.h
#ifndef IXCOMPILER_TOKENIZER_H
#define IXCOMPILER_TOKENIZER_H

Tokenizer* Tokenizer_new          ( File**      file );

Tokenizer*  Tokenizer_free         (       Tokenizer** self );
Token*      Tokenizer_nextToken    (       Tokenizer*  self );
bool        Tokenizer_hasMoreTokens( const Tokenizer*  self );
const File* Tokenizer_getFile      ( const Tokenizer*  self ); 

#endif
```


```!c/ixcompiler.Tokenizer.c
#include "ixcompiler.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.File.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.PushbackReader.h"
#include "ixcompiler.Queue.h"
#include "ixcompiler.StringBuffer.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"
#include "ixcompiler.Tokenizer.h"

struct _Tokenizer
{
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
        self->queue  = Queue_new();

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
static void primeQueue( Tokenizer* self )
{
    Token* token = null;

    if ( (token = next( self )) )
    {
        Queue_addTail( self->queue, (void**) &token );
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
        StringBuffer*  sb = StringBuffer_new();
        TokenGroup* group = TokenGroup_new( ch );

        sb = StringBuffer_append_char( sb, ch );

        while ( (ch2 = PushbackReader_read( self->reader )) )
        {
            EnumTokenGroup group_type = TokenGroup_getGroupType( group );

            if ( ESCAPE == group_type )
            {
                sb  = StringBuffer_append_char( sb, ch2 );
                ch2 = PushbackReader_read( self->reader );
                break;
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

### AST

```!include/ixcompiler.AST.h
#ifndef IXCOMPILER_AST_H
#define IXCOMPILER_AST_H

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
#include "ixcompiler.Node.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"
#include "ixcompiler.Tokenizer.h"
#include "ixcompiler.Tree.h"

struct _AST
{
    Tokenizer* tokenizer;
    Tree* tree;
};

static void Parse          ( AST* self );

static void ParseRoot      ( Node* parent, Tokenizer* tokenizer );
static void ParseComplex   ( Node* parent, Tokenizer* tokenizer );
static void ParseClass     ( Node* parent, Tokenizer* tokenizer );
static void ParseMethod    ( Node* parent, Tokenizer* tokenizer );
static void ParseStatement ( Node* parent, Tokenizer* tokenizer, bool one_liner );
static void ParseBlock     ( Node* parent, Tokenizer* tokenizer );
static void ParseExpression( Node* parent, Tokenizer* tokenizer );
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

    Parse( self );

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
static void Parse( AST* self )
{
    Token* t    = null;
    Node*  root = Node_new( &t );
    ParseRoot( root, self->tokenizer );
    Tree_setRoot( self->tree, &root );
}
```

```c/ixcompiler.AST.c
static void ParseRoot( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );

        Node_addChild( parent, &token );

        if ( token_group == ALPHANUMERIC )
        {
            Node* last = null;

            switch ( token_type )
            {
            case COPYRIGHT:
                last = Node_getLastChild( parent );
                Node_setTag( last, "copyright" );
                ParseStatement( last, tokenizer, TRUE );
                break;

            case LICENSE:
                last = Node_getLastChild( parent );
                Node_setTag( last, "license" );
                ParseStatement( last, tokenizer, TRUE );
                break;

            case MODIFIER:
                ParseComplex( Node_getLastChild( parent ), tokenizer );
                break;

            default:
                continue;
            }
        }
    }
}
```

```c/ixcompiler.AST.c
static void ParseComplex( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );
        const char*    content     = Token_getContent( token );
        int            ch          = content[0];

        Node_addChild( parent, &token );

        if ( (token_group == CLOSE)        && (token_type == ENDBLOCK) ) break;
        else
        if ( (token_group == ALPHANUMERIC) && (token_type == CLASS) )
        {
            Node_setTag( parent, "class" );
            ParseClass( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        if ( (token_group == ALPHANUMERIC) && (token_type == WORD) )
        {
            Node_setTag( parent, "method" );
            ParseMethod( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        if ( (token_group == OPEN)         && (token_type == STARTBLOCK) )
        {
            ParseBlock( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        {
            continue;
        }
    }
}
```

```c/ixcompiler.AST.c
static void ParseClass( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );
        const char*    content     = Token_getContent( token );
        int            ch          = content[0];

        Node_addChild( parent, &token );

        if ( (token_group == CLOSE)        && (token_type == ENDBLOCK) ) break;
        else
        if ( (token_group == OPEN) && (token_type == STARTBLOCK) )
        {
            ParseBlock( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        {
            continue;
        }
    }
}
```

```c/ixcompiler.AST.c
static void ParseMethod( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );
        const char*    content     = Token_getContent( token );
        int            ch          = content[0];

        Node_addChild( parent, &token );

        if ( (token_group == CLOSE)        && (token_type == ENDBLOCK) ) break;
        else
        if ( (token_group == OPEN) && (token_type == STARTEXPRESSION) )
        {
            ParseExpression( Node_getLastChild( parent ), tokenizer );
        }
        else
        if ( (token_group == OPEN) && (token_type == STARTBLOCK) )
        {
            ParseBlock( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        {
            continue;
        }
    }
}
```

```c/ixcompiler.AST.c
static void ParseStatement( Node* parent, Tokenizer* tokenizer, bool one_liner )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );

        Node_addChild( parent, &token );

        if ( token_type == STOP )
        {
            break;
        }
        else
        if ( one_liner && (token_type == NEWLINE) )
        {
            break;
        }
        else
        if ( (token_group == OPEN) && (token_type == STARTEXPRESSION) )
        {
            ParseExpression( Node_getLastChild( parent ), tokenizer );
        }
        else
        if ( (token_group == OPEN) && (token_type == STARTBLOCK) )
        {
            ParseBlock( Node_getLastChild( parent ), tokenizer );
            break;
        }
    }
}
```

```c/ixcompiler.AST.c
static void ParseBlock( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );
        const char*    content     = Token_getContent( token );
        int            ch          = content[0];

        Node_addChild( parent, &token );

        if ( (token_group == CLOSE)    && (token_type == ENDBLOCK) ) break;
        else
        if ( (token_group == SYMBOLIC) && ((token_type == SYMBOL) || (token_type == INFIXOP)) )
        {
            switch ( ch )
            {
            case '@':
            case '%':
                ParseStatement( Node_getLastChild( parent ), tokenizer, TRUE );
                break;
            }
        }
        else
        if ( (token_group == ALPHANUMERIC) && (token_type == KEYWORD) )
        {
            ParseStatement( Node_getLastChild( parent ), tokenizer, FALSE );
        }
        else
        if ( (token_group == ALPHANUMERIC) )
        {
            ParseStatement( Node_getLastChild( parent ), tokenizer, FALSE );
        }
    }
}
```

```c/ixcompiler.AST.c
static void ParseExpression( Node* parent, Tokenizer* tokenizer )
{
    while ( Tokenizer_hasMoreTokens( tokenizer ) )
    {
        Token*         token       = Tokenizer_nextToken( tokenizer );
        EnumTokenGroup token_group = TokenGroup_getGroupType( Token_getTokenGroup( token ) );
        EnumTokenType  token_type  = Token_getTokenType( token );
        const char*    content     = Token_getContent( token );
        int            ch          = content[0];

        Node_addChild( parent, &token );

        if ( (token_group == CLOSE)    && (token_type == ENDEXPRESSION) ) break;
        else
        if ( (token_group == OPEN) && (token_type == STARTEXPRESSION) )
        {
            ParseExpression( Node_getLastChild( parent ), tokenizer );
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
#include "ixcompiler.Array.h"
#include "ixcompiler.Platform.h"

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
        self->ast_collection = Array_new();
    }
    return self;
}
```

```c/ixcompiler.ASTCollection.c
ASTCollection* ASTCollection_free( ASTCollection** self )
{
    if ( *self )
    {
        if ( (*self)->ast_collection )
        {
            AST* ast;

            while ( (ast = Array_pop( (*self)->ast_collection )) )
            {
                AST_free( &ast );
            }
            Array_free( &(*self)->ast_collection );
            Platform_Free( self );
        }
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

void ASTPrinter_Print( const AST* ast );

#endif
```

```!c/ixcompiler.ASTPrinter.c
#include <stdio.h>
#include "ixcompiler.h"
#include "ixcompiler.AST.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.Generator.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.Tree.h"
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

#include "ixcompiler.h"

IxParser*      IxParser_new           ( Tokenizer* tokenizer )                ;
IxParser*      IxParser_free          ( IxParser** self )                     ;
AST*           IxParser_parse         ( IxParser* self )                      ;

#endif
```

```!c/ixcompiler.IxParser.c
#include "ixcompiler.h"
#include "ixcompiler.AST.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxParser.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"
#include "ixcompiler.Tokenizer.h"
#include "ixcompiler.Tree.h"

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

### Ix Source Class

```!include/ixcompiler.IxSourceClass.h
#ifndef IXCOMPILER_IXSOURCECLASS_H
#define IXCOMPILER_IXSOURCECLASS_H

#include "ixcompiler.h"

IxSourceClass* IxSourceClass_new( const Node* classNode );

IxSourceClass* IxSourceClass_free( IxSourceClass** self );

const ArrayOfIxSourceMember* IxSourceClass_getMembers( const IxSourceClass* self );

#endif
```

```!c/ixcompiler.IxSourceClass.c
#include <stdio.h>
#include "ixcompiler.ArrayOfString.h"
#include "ixcompiler.ArrayOfIxSourceMember.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceClass.h"
#include "ixcompiler.IxSourceMember.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.Token.h"

struct _IxSourceClass
{
    bool                   invalid;
    String*                accessModifier;
    String*                className;
    ArrayOfString*         interfaces;
    ArrayOfIxSourceMember* members;
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
        self->interfaces = ArrayOfString_new();
        self->members    = ArrayOfIxSourceMember_new();

        parseModifier( self, classModifierNode );
    }
    return self;
}
```

```c/ixcompiler.IxSourceClass.c
const ArrayOfIxSourceMember* IxSourceClass_getMembers( const IxSourceClass* self )
{
    return self->members;
}
```

```c/ixcompiler.IxSourceClass.c
static void parseModifier( IxSourceClass* self, const Node* classModifierNode )
{
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
        case SYMBOL:
            switch( value[0] )
            {
            case '@':
                parseMember( self, next );
            }
            break;

        case INFIXOP:
            switch( value[0] )
            {
            case '%':
                parseMember( self, next );
            }
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

    ArrayOfIxSourceMember_push( self->members, &member );
}
```

### Ix Source Comment

```!include/ixcompiler.IxSourceComment.h
#ifndef IXCOMPILER_IXSOURCECOMMENT_H
#define IXCOMPILER_IXSOURCECOMMENT_H

IxSourceComment* IxSourceComment_new();
IxSourceComment* IxSourceComment_free( IxSourceComment** self );

#endif
```

```!c/ixcompiler.IxSourceComment.c
#include "ixcompiler.h"
#include "ixcompiler.IxSourceComment.h"
#include "ixcompiler.Platform.h"

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
#include "ixcompiler.Platform.h"

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

IxSourceHeader* IxSourceHeader_new ( const char* keyword, const char* freeform_text );

IxSourceHeader* IxSourceHeader_free      (       IxSourceHeader** self );
const char*     IxSourceHeader_getKeyword( const IxSourceHeader*  self );
const char*     IxSourceHeader_getText   ( const IxSourceHeader*  self );

#endif
```

```!c/ixcompiler.IxSourceHeader.c
#include "ixcompiler.h"
#include "ixcompiler.IxSourceHeader.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

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

### Ix Source Member

```!include/ixcompiler.IxSourceMember.h
#ifndef IXCOMPILER_IXSOURCEMEMBER_H
#define IXCOMPILER_IXSOURCEMEMBER_H

#include "ixcompiler.h"

IxSourceMember* IxSourceMember_new( const Node* prefixNode );

IxSourceMember* IxSourceMember_free(                  IxSourceMember** self );
bool            IxSourceMember_isInvalid      ( const IxSourceMember*  self );
bool            IxSourceMember_isInstance     ( const IxSourceMember*  self );
const String*   IxSourceMember_getName        ( const IxSourceMember*  self );
const String*   IxSourceMember_getType        ( const IxSourceMember*  self );
const String*   IxSourceMember_getDefaultValue( const IxSourceMember*  self );

#endif
```

```!c/ixcompiler.IxSourceMember.c
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceMember.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.StringBuffer.h"
#include "ixcompiler.Token.h"

struct _IxSourceMember
{
    bool    invalid;
    bool    isInstance;
    String* prefix;
    String* name;
    String* oftype;
    String* type;
    String* equals;
    String* defaultValue;
};

static void IxSource_Unit_parseMember( IxSourceMember* self, const Node* prefixNode );
```

```c/ixcompiler.IxSourceMember.c
IxSourceMember* IxSourceMember_new( const Node* prefixNode )
{
    IxSourceMember* self = Platform_Alloc( sizeof( IxSourceMember ) );
    if ( self )
    {
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
        String_free  ( &(*self)->name         );
        String_free  ( &(*self)->type         );
        String_free  ( &(*self)->defaultValue );
        Platform_Free(    self                );
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
const String* IxSourceMember_getType( const IxSourceMember* self )
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
        case SYMBOL:
        case INFIXOP:
            self->prefix = String_new( value );
            switch ( value[0] )
            {
            case '@':
                self->isInstance = TRUE;
                break;
            case '%':
                self->isInstance = FALSE;
                break;
            default:
                self->invalid = TRUE;
            }
            break;
        
        default:
            self->invalid = TRUE;
        }
    }

    NodeIterator* it = Node_iterator( prefixNode );
    
    //  name
    if ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node ); 

        if ( Token_getTokenType( token ) == WORD )
        {
            self->name = String_new( Token_getContent( token ) );
        }
        else
        {
            self->invalid = TRUE;
        }
    }

    //  operator
    if ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node ); 

        if ( Token_getTokenType( token ) == OFTYPE )
        {
            self->oftype = String_new( Token_getContent( token ) );
        }
        else
        {
            self->invalid = TRUE;
        }
    }

    //  type
    if ( NodeIterator_hasNonWhitespace( it ) )
    {
        const Node*  node  = NodeIterator_next( it );
        const Token* token = Node_getToken( node ); 

        {
            StringBuffer* sb = StringBuffer_new();

            switch ( Token_getTokenType( token ) )
            {
            case PRIMITIVE:
            case WORD:
                StringBuffer_append( sb, Token_getContent( token ) );
                break;

            default:
                self->invalid = TRUE;
            }

            if ( NodeIterator_hasNonWhitespace( it ) )
            {
                const Node*  node  = NodeIterator_next( it );
                const Token* token = Node_getToken( node );

                switch ( Token_getTokenType( token ) )
                {
                case STARTSUBSCRIPT:
                    StringBuffer_append( sb, "[" );
                    if ( NodeIterator_hasNonWhitespace( it ) )
                    {
                        const Node*  node  = NodeIterator_next( it );
                        const Token* token = Node_getToken( node );

                        switch ( Token_getTokenType( token ) )
                        {
                        case ENDSUBSCRIPT:
                            StringBuffer_append( sb, "]" );
                            break;
                        default:
                            self->invalid = TRUE;
                        }
                    }
                    break;

                case ASSIGNMENTOP:
                    self->equals = String_new( Token_getContent( token ) );
                    break;
                
                default:
                    self->invalid = TRUE;
                }
            }
            self->type = StringBuffer_toString( sb );

            StringBuffer_free( &sb );
        }
    }
}
```

### Ix Source Method

```!include/ixcompiler.IxSourceMethod.h
#ifndef IXCOMPILER_IXSOURCEMETHOD_H
#define IXCOMPILER_IXSOURCEMETHOD_H

#include "ixcompiler.h"

IxSourceMethod* IxSourceMethod_new( const Node* modifierNode );

IxSourceMethod* IxSourceMethod_free             (       IxSourceMethod** self );
const char*     IxSourceMethod_getAccessModifier( const IxSourceMethod*  self );
const char*     IxSourceMethod_getConst         ( const IxSourceMethod*  self );
const char*     IxSourceMethod_getMethodName    ( const IxSourceMethod*  self );
const char*     IxSourceMethod_getReturnType    ( const IxSourceMethod*  self );

#endif
```

```!c/ixcompiler.IxSourceMethod.c
#include "ixcompiler.ArrayOfIxSourceParameter.h"
//#include "ixcompiler.ArrayOfIxSourceStatement.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.Token.h"

struct _IxSourceMethod
{
    bool                      invalid;
    bool                      isConst;
    String*                   modifier;     //  public
    String*                   konst;        //  const
    String*                   methodName;   //  getSomething
    ArrayOfIxSourceParameter* parameters;   //  ( name: Type*, size: int )
    String*                   oftype;       //  :
    String*                   returnType;   //  String*
    ArrayOfIxSourceStatement* statements;   //  ...
};

void IxSourceMethod_parseModifier    ( IxSourceMethod* self, const Node* modifierNode );
void IxSourceMethod_parseNameChildren( IxSourceMethod* self, const Node* nameNode     );
```

```c/ixcompiler.IxSourceMethod.c
IxSourceMethod* IxSourceMethod_new( const Node* modifierNode )
{
    IxSourceMethod* self = Platform_Alloc( sizeof( IxSourceMethod ) );
    if ( self )
    {
        self->modifier   = String_new( "" );
        self->konst      = String_new( "" );
        self->methodName = String_new( "" );
        self->oftype     = String_new( "" );
        self->returnType = String_new( "" );

        self->parameters = ArrayOfIxSourceParameter_new();
        //self->statements = ArrayOfIxSourceStatement_new();

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
        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getAccessModifier( const IxSourceMethod* self )
{
    return String_content( self->modifier );
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getConst( const IxSourceMethod* self )
{
    return (null != self->konst) ? String_content( self->konst ) : "";
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getMethodName( const IxSourceMethod* self )
{
    return String_content( self->methodName );
}
```

```c/ixcompiler.IxSourceMethod.c
const char* IxSourceMethod_getReturnType( const IxSourceMethod*  self )
{
    return String_content( self->returnType );
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

    self->modifier = String_new( Token_getContent( Node_getToken( modifierNode ) ) );

    NodeIterator* it = Node_iterator( modifierNode );

    //  const (optional)
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

        IxSourceMethod_parseNameChildren( self, node );
    }
    else
    {
        self->invalid = TRUE;
    }
}
```

```c/ixcompiler.IxSourceMethod.c
void IxSourceMethod_parseNameChildren( IxSourceMethod* self, const Node* nameNode )
{
    NodeIterator* it = Node_iterator( nameNode );

    //  '(' START
    if ( NodeIterator_hasNonWhitespaceOfType( it, STARTEXPRESSION ) )
    {
        NodeIterator_next( it );
        Console_Write( "Has Parameters\n", null );
        //
    }
    else
    {
        self->invalid = TRUE;
    }

    if ( NodeIterator_hasNonWhitespaceOfType( it, OFTYPE ) )
    {
        String_free( &(self->oftype) );
        self->oftype = String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) );

        if ( NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE ) || NodeIterator_hasNonWhitespaceOfType( it, PRIMITIVE ) )
        {
            String_free( &(self->returnType) );
            self->returnType = String_new( Token_getContent( Node_getToken( NodeIterator_next( it ) ) ) );
        }
        else
        {
            self->invalid = TRUE;
        }
    }
}
```
### Ix Source Parameter

```!include/ixcompiler.IxSourceParameter.h
#ifndef IXCOMPILER_IXSOURCEPARAMETER_H
#define IXCOMPILER_IXSOURCEPARAMETER_H

#include "ixcompiler.h"

IxSourceParameter* IxSourceParameter_new( String** name, String** type, String** defaultValue );
IxSourceParameter* IxSourceParameter_free( IxSourceParameter** self );

const String* IxSourceParameter_getName        ( const IxSourceParameter* self );
const String* IxSourceParameter_getType        ( const IxSourceParameter* self );
const String* IxSourceParameter_getDefaultValue( const IxSourceParameter* self );

#endif
```

```!c/ixcompiler.IxSourceParameter.c
#include "ixcompiler.IxSourceParameter.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _IxSourceParameter
{
    String* name;
    String* type;
    String* defaultValue;
};
```

```c/ixcompiler.IxSourceParameter.c
IxSourceParameter* IxSourceParameter_new( String** name, String** type, String** default_value )
{
    IxSourceParameter* self = Platform_Alloc( sizeof( IxSourceParameter ) );
    if ( self )
    {
        self->name         = Take( name          );
        self->type         = Take( type          );
        self->defaultValue = Take( default_value );
    }
    return self;
}
```

```c/ixcompiler.IxSourceParameter.c
IxSourceParameter* IxSourceParameter_free( IxSourceParameter** self )
{
    if ( *self )
    {
        String_free  ( &(*self)->name         );
        String_free  ( &(*self)->type         );
        String_free  ( &(*self)->defaultValue );
        Platform_Free(    self                );
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
const String* IxSourceParameter_getType( const IxSourceParameter* self )
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

### Ix Source Signature

```!include/ixcompiler.IxSourceSignature.h
#ifndef IXCOMPILER_IXSOURCESIGNATURE_H
#define IXCOMPILER_IXSOURCESIGNATURE_H

#include "ixcompiler.h"

IxSourceSignature* IxSourceSignature_new( String** access_modifier, bool const, String** method_name, ArrayOfIxSourceParameter** parameters, String** return_type );
IxSourceSignature* IxSourceSignature_free( IxSourceSignature** self );

const String*                   IxSourceSignature_getAccessModifier( const IxSourceSignature* self );
bool                            IxSourceSignature_isConst          ( const IxSourceSignature* self );
const String*                   IxSourceSignature_getMethodName    ( const IxSourceSignature* self );
const ArrayOfIxSourceParameter* IxSourceSignature_getParameters    ( const IxSourceSignature* self );
const String*                   IxSourceSignature_getReturnType    ( const IxSourceSignature* self );

#endif
```

```!c/ixcompiler.IxSourceSignature.c
#include "ixcompiler.ArrayOfIxSourceParameter.h"
#include "ixcompiler.IxSourceSignature.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _IxSourceSignature
{
    String*                   accessModifier;
    bool                      isConst;
    String*                   methodName;
    ArrayOfIxSourceParameter* parameters;
    String*                   returnType;
};
```

```c/ixcompiler.IxSourceSignature.c
IxSourceSignature* IxSourceSignature_new( String** access_modifier, bool is_const, String** method_name, ArrayOfIxSourceParameter** parameters, String** return_type )
{
    IxSourceSignature* self = Platform_Alloc( sizeof( IxSourceSignature ) );
    if ( self )
    {
        self->accessModifier = Take( access_modifier );
        self->isConst        = is_const;
        self->methodName     = Take( method_name );
        self->parameters     = Take( parameters  );
        self->returnType     = Take( return_type );
    }
    return self;
}
```

```c/ixcompiler.IxSourceSignature.c
IxSourceSignature* IxSourceSignature_free( IxSourceSignature** self )
{
    if ( *self )
    {
        String_free                   ( &(*self)->accessModifier );
        String_free                   ( &(*self)->methodName     );
        ArrayOfIxSourceParameter_free ( &(*self)->parameters     );
        String_free                   ( &(*self)->returnType     );
        Platform_Free                 (    self                  );
    }
    return *self;
}
```

### IxSourceUnit

```!include/ixcompiler.IxSourceUnit.h
#ifndef IXCOMPILER_IXSOURCEUNIT_H
#define IXCOMPILER_IXSOURCEUNIT_H

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
const ArrayOfIxSourceMethod* IxSourceUnit_getMethods       ( const IxSourceUnit*  self );

#endif
```

```!c/ixcompiler.IxSourceUnit.c
#include "ixcompiler.h"
#include "ixcompiler.ArrayOfIxSourceFunction.h"
#include "ixcompiler.ArrayOfIxSourceMethod.h"
#include "ixcompiler.ArrayOfString.h"
#include "ixcompiler.AST.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.File.h"
#include "ixcompiler.IxSourceClass.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.StringBuffer.h"
#include "ixcompiler.Tree.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"

struct _IxSourceUnit
{
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
    ArrayOfIxSourceMethod*     methods;
    ArrayOfIxSourceFunction*   functions;
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
const ArrayOfString* IxSourceUnit_getSignatures( const IxSourceUnit* self )
{
    return ArrayOfString_new();
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
const ArrayOfIxSourceMethod* IxSourceUnit_getMethods( const IxSourceUnit* self )
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
    self->methods        = ArrayOfIxSourceMethod_new();
    self->functions      = ArrayOfIxSourceFunction_new();

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
            self->class = IxSourceClass_new( node );
        }
        else
        if ( tag && String_equals( tag, method ) )
        {
            ArrayOfIxSourceMethod_push( self->methods, (IxSourceMethod**) Give( IxSourceMethod_new( node ) ) );
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

#endif
```

```!c/ixcompiler.IxSourceUnitCollection.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.ArrayOfString.h"
#include "ixcompiler.Dictionary.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.IxSourceUnitCollection.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _IxSourceUnitCollection
{
    Array*         collection;
    ArrayOfString* copyrightLines;
    ArrayOfString* licenseLines;
    Dictionary*    resolvedTypes;
};
```

```c/ixcompiler.IxSourceUnitCollection.c
IxSourceUnitCollection* IxSourceUnitCollection_new()
{
    IxSourceUnitCollection* self = Platform_Alloc( sizeof( IxSourceUnitCollection ) );
    if ( self )
    {
        self->collection     = Array_new();
        self->copyrightLines = ArrayOfString_new();
        self->licenseLines   = ArrayOfString_new();
        self->resolvedTypes  = Dictionary_new();
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
        (String**) Give( String_copy( IxSourceUnit_getFullName( *sourceUnit ) ) )
    );

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
    {
        int n = IxSourceUnitCollection_getLength( self );
        for ( int i=0; i < n; i++ )
        {
            ArrayOfString_append( functions, IxSourceUnit_getSignatures( IxSourceUnitCollection_get( self, i ) ) );
        }
    }
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

### Generator

```!include/ixcompiler.Generator.h
#ifndef IXCOMPILER_GENERATOR_H
#define IXCOMPILER_GENERATOR_H

#include "ixcompiler.h"

GeneratorFn Generator_FunctionFor( const char* target_language );

#endif
```

```!c/ixcompiler.Generator.c
#include <stdio.h>
#include "ixcompiler.Generator.h"
#include "ixcompiler.GeneratorForC.h"
#include "ixcompiler.String.h"
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

### Generator for C

```!include/ixcompiler.GeneratorForC.h
#ifndef IXCOMPILER_GENERATORFORC_H
#define IXCOMPILER_GENERATORFORC_H

#include "ixcompiler.h"

int Generator_FunctionForC( const IxSourceUnitCollection* source_units, const Path* output_path );

#endif
```

```!c/ixcompiler.GeneratorForC.c
#include <stdio.h>
#include "ixcompiler.ArrayOfIxSourceMember.h"
#include "ixcompiler.ArrayOfIxSourceMethod.h"
#include "ixcompiler.ArrayOfString.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.Dictionary.h"
#include "ixcompiler.File.h"
#include "ixcompiler.GeneratorForC.h"
#include "ixcompiler.IxSourceClass.h"
#include "ixcompiler.IxSourceMember.h"
#include "ixcompiler.IxSourceMethod.h"
#include "ixcompiler.IxSourceUnit.h"
#include "ixcompiler.IxSourceUnitCollection.h"
#include "ixcompiler.Path.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.StringBuffer.h"

#define TARGET_HEADER_NAME "/include/"
#define TARGET_SOURCE_NAME "/c/"

static void    GenerateAndWriteHeaderFile( const IxSourceUnitCollection* sourceUnits, const String* outputDir );
static String* GenerateHeaderFile        ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateIfDef             ( const IxSourceUnit*           sourceUnit  );
static String* GenerateTypeDef           ( const String*                 type,        int           longest  );

static void    GenerateAndWriteSourceFile        ( const IxSourceUnitCollection* sourceUnits, const String* outputDir );
static String* GenerateSourceFile                ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateIncludes                  ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateStructs                   ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateStructForSourceUnit       ( const IxSourceUnit*           sourceUnit, const Dictionary* resolvedTypes );
static String* GenerateStructMembersForSourceUnit( const IxSourceUnit*           sourceUnit, const Dictionary* resolvedTypes );
static String* GenerateMethods                   ( const IxSourceUnitCollection* sourceUnits );
static String* GenerateMethodsForSourceUnit      ( const IxSourceUnit*           sourceUnit  );
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

    GenerateAndWriteHeaderFile( sourceUnits, target_header_dir );
    GenerateAndWriteSourceFile( sourceUnits, target_source_dir );

    for ( int i=0; i < n; i++ )
    {
    }

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
static void GenerateAndWriteHeaderFile( const IxSourceUnitCollection* sourceUnits, const String* outputDir )
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
        StringBuffer_appendLine( sb, "#ifndef", GenerateIfDef( first ) );
        StringBuffer_appendLine( sb, "#define", GenerateIfDef( first ) );
        StringBuffer_appendLine( sb, "",        null                   );

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

        // Types
        {
            ArrayOfString* types   = IxSourceUnitCollection_retrieveTypes( sourceUnits );
            int            num     = ArrayOfString_getLength ( types );
            int            longest = ArrayOfString_getLongest( types );

            for ( int i=0; i < num; i++ )
            {
                const String* type = ArrayOfString_getObject( types, i );
                StringBuffer_appendLine( sb, "typedef struct", GenerateTypeDef( type, longest ) );
            }
        }

        ArrayOfString* functions = IxSourceUnitCollection_retrieveFunctions( sourceUnits );

        StringBuffer_appendLine( sb, "",        null                   );
        StringBuffer_appendLine( sb, "#endif",  null                   );
    }
    content = String_new( StringBuffer_content( sb ) );
    StringBuffer_free( &sb );

    return content;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateIfDef( const IxSourceUnit* sourceUnit )
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
static String* GenerateTypeDef( const String* type, int longest )
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
static void GenerateAndWriteSourceFile( const IxSourceUnitCollection* sourceUnits, const String* outputDir )
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

        StringBuffer_appendLine( sb, "#include", GenerateIncludes( sourceUnits ) );
        StringBuffer_appendLine( sb,         "", GenerateStructs ( sourceUnits ) );
        StringBuffer_appendLine( sb,         "", GenerateMethods ( sourceUnits ) );

        ret = String_new( StringBuffer_content( sb ) );
    }
    return ret;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateIncludes( const IxSourceUnitCollection* sourceUnits )
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
static String* GenerateStructs( const IxSourceUnitCollection* sourceUnits )
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

                StringBuffer_appendLine( sb, "", GenerateStructForSourceUnit( sourceUnit, resolvedTypes ) );
            }
            structs = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return structs;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateStructForSourceUnit( const IxSourceUnit* sourceUnit, const Dictionary* resolvedTypes )
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
                StringBuffer_appendLine( sb, "", GenerateStructMembersForSourceUnit( sourceUnit, resolvedTypes ) );
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
static String* GenerateStructMembersForSourceUnit( const IxSourceUnit* sourceUnit, const Dictionary* resolvedTypes )
{
    String* members = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            const IxSourceClass*         class = IxSourceUnit_getClass( sourceUnit );
            const ArrayOfIxSourceMember* array = IxSourceClass_getMembers( class );
            {
                int n = ArrayOfIxSourceMember_getLength( array );
                for ( int i=0; i < n; i++ )
                {
                    const IxSourceMember* member = ArrayOfIxSourceMember_getObject( array, i );

                    if ( IxSourceMember_isInstance( member ) )
                    {
                        StringBuffer_append( sb, "\n" );
                        StringBuffer_append( sb, "\t" );

                        if ( IxSourceMember_isInvalid( member ) )
                        {
                            StringBuffer_append( sb, "!!" );
                        }

                        const String* type = IxSourceMember_getType( member );
                        {
                            String* ctype     = String_copy( type );
                            String* subscript = String_new( "[]" );
                            {
                                if ( String_contains( ctype, subscript ) )
                                {
                                    String_free( &ctype );
                                    ctype = String_replace( type, '[', '\0' );
                                }
                                else
                                {
                                    String_free( &subscript );
                                    subscript = String_new( "" );
                                }

                                {
                                    const String* fullCType = Dictionary_get( resolvedTypes, ctype );
                                    if ( fullCType )
                                    {
                                        String_free( &ctype );
                                        ctype = String_replace( fullCType, '.', '_' );
                                    }
                                }

                                StringBuffer_append( sb, String_content( ctype ) );
                                StringBuffer_append( sb, " "  );
                                StringBuffer_append( sb, String_content( IxSourceMember_getName( member ) ) );
                                StringBuffer_append( sb, String_content( subscript ) );
                                StringBuffer_append( sb, ";"  );
                            }
                            String_free( &ctype     );
                            String_free( &subscript );
                        }
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
static String* GenerateMethods( const IxSourceUnitCollection* sourceUnits )
{
    String* methods = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            int n = IxSourceUnitCollection_getLength( sourceUnits );

            for ( int i=0; i < n; i++ )
            {
                const IxSourceUnit* sourceUnit = IxSourceUnitCollection_get( sourceUnits, i );
                StringBuffer_appendLine( sb, "", GenerateMethodsForSourceUnit( sourceUnit ) );
            }
            methods = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return methods;
}
```

```c/ixcompiler.GeneratorForC.c
static String* GenerateFunctionForMethod( const IxSourceMethod* method, const char* classPrefix );

static String* GenerateMethodsForSourceUnit( const IxSourceUnit* sourceUnit )
{
    const char* classPrefix = IxSourceUnit_getPrefix( sourceUnit );

    String* st_methods = null;
    {
        StringBuffer* sb = StringBuffer_new();
        {
            const ArrayOfIxSourceMethod* methods = IxSourceUnit_getMethods( sourceUnit );
            {
                int n = ArrayOfIxSourceMethod_getLength( methods );
                for ( int i=0; i < n; i++ )
                {
                    const IxSourceMethod* method = ArrayOfIxSourceMethod_getObject( methods, i );
                    StringBuffer_appendLine( sb, "", GenerateFunctionForMethod( method, classPrefix ) );
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
static String* GenerateFunctionForMethod( const IxSourceMethod* method, const char* classPrefix )
{
    String* st_method = null;
    {
        const char* returnType = IxSourceMethod_getReturnType( method );
        const char* pointer    = "";

        if ( String_Equals( returnType, "" ) )
        {
            returnType = "void";
        }

        const char* methodName = IxSourceMethod_getMethodName( method );
        if ( String_Equals( methodName, "new" ) )
        {
            returnType = classPrefix;
            pointer    = "*";
        }

        StringBuffer* sb = StringBuffer_new();
        {
            StringBuffer_append( sb, "// " );
            StringBuffer_append( sb, IxSourceMethod_getAccessModifier( method ) );
            StringBuffer_append( sb, " " );
            StringBuffer_append( sb, IxSourceMethod_getConst( method ) );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, returnType );
            StringBuffer_append( sb, pointer );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, classPrefix );
            StringBuffer_append( sb, "_" );
            StringBuffer_append( sb, methodName );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, "(" );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, ")" );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, "{" );
            StringBuffer_append( sb, "\n" );
            StringBuffer_append( sb, "}" );
            StringBuffer_append( sb, "\n" );

            st_method = StringBuffer_toString( sb );
        }
        StringBuffer_free( &sb );
    }
    return st_method;
}
```

### Array

```!include/ixcompiler.Array.h
#ifndef IXCOMPILER_ARRAY_H
#define IXCOMPILER_ARRAY_H

#include "ixcompiler.h"

Array* Array_new    ();
Array* Array_free   ( Array** self );
Array* Array_push   ( Array*  self, void** object );
void*  Array_pop    ( Array*  self );
void*  Array_shift  ( Array*  self );
Array* Array_unshift( Array*  self, void** object );

int         Array_getLength( const Array* self            );
const void* Array_getObject( const Array* self, int index );

#endif
```

```!c/ixcompiler.Array.c
#include "ixcompiler.Array.h"
#include "ixcompiler.Platform.h"

struct _Array
{
    void** objects;
    int    length;
    int    size;
};
```

```c/ixcompiler.Array.c
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

```c/ixcompiler.Array.c
Array* Array_new()
{
    Array* self = Platform_Alloc( sizeof( Array ) );

    if ( self )
    {
        self->objects = 0;
        self->length  = 0;
        self->size    = 0;
    }
    return self;
}
```

```c/ixcompiler.Array.c
Array* Array_free( Array** self )
{
    Platform_Free( &(*self)->objects );
    Platform_Free( *self );

    return *self;
}
```

```c/ixcompiler.Array.c
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

```c/ixcompiler.Array.c
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

```c/ixcompiler.Array.c
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

```c/ixcompiler.Array.c
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

```c/ixcompiler.Array.c
int Array_getLength( const Array* self )
{
    return self->length;
}
```

```c/ixcompiler.Array.c
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

### ArrayOfIxSourceFunction

```!include/ixcompiler.ArrayOfIxSourceFunction.h
#ifndef IXCOMPILER_ARRAYOFIXSOURCEFUNCTION_H
#define IXCOMPILER_ARRAYOFIXSOURCEFUNCTION_H

#include "ixcompiler.h"

ArrayOfIxSourceFunction* ArrayOfIxSourceFunction_new();

ArrayOfIxSourceFunction* ArrayOfIxSourceFunction_free      (       ArrayOfIxSourceFunction** self );
void                     ArrayOfIxSourceFunction_push      (       ArrayOfIxSourceFunction*  self, IxSourceFunction** object );
IxSourceFunction*        ArrayOfIxSourceFunction_pop       (       ArrayOfIxSourceFunction*  self );
IxSourceFunction*        ArrayOfIxSourceFunction_shift     (       ArrayOfIxSourceFunction*  self );
void                     ArrayOfIxSourceFunction_unshift   (       ArrayOfIxSourceFunction*  self, IxSourceFunction** object );

int                      ArrayOfIxSourceFunction_getLength ( const ArrayOfIxSourceFunction*  self            );
const IxSourceFunction*  ArrayOfIxSourceFunction_getObject ( const ArrayOfIxSourceFunction*  self, int index );

#endif
```

```!c/ixcompiler.ArrayOfIxSourceFunction.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.ArrayOfIxSourceFunction.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.IxSourceFunction.h"

struct _ArrayOfIxSourceFunction
{
    Array* array;
};
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
ArrayOfIxSourceFunction* ArrayOfIxSourceFunction_new()
{
    ArrayOfIxSourceFunction* self = Platform_Alloc( sizeof( ArrayOfIxSourceFunction ) );
    if ( self )
    {
        self->array   = Array_new();
    }

    return self;
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
ArrayOfIxSourceFunction* ArrayOfIxSourceFunction_free( ArrayOfIxSourceFunction** self )
{
    if ( *self )
    {
        IxSourceFunction* tmp;
        while ( (tmp = Array_pop( (*self)->array ) ) )
        {
            IxSourceFunction_free( &tmp );
        }
        Array_free   ( &(*self)->array );
        Platform_Free(    self         );
    }

    return *self;
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
void ArrayOfIxSourceFunction_push( ArrayOfIxSourceFunction* self, IxSourceFunction** object )
{
    Array_push( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
IxSourceFunction* ArrayOfIxSourceFunction_pop( ArrayOfIxSourceFunction* self )
{
    return (IxSourceFunction*) Array_pop( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
IxSourceFunction* ArrayOfIxSourceFunction_shift( ArrayOfIxSourceFunction* self )
{
    return (IxSourceFunction*) Array_shift( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
void ArrayOfIxSourceFunction_unshift( ArrayOfIxSourceFunction* self, IxSourceFunction** object )
{
    Array_unshift( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
int ArrayOfIxSourceFunction_getLength( const ArrayOfIxSourceFunction* self )
{
    return Array_getLength( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceFunction.c
const IxSourceFunction* ArrayOfIxSourceFunction_getObject( const ArrayOfIxSourceFunction* self, int index )
{
    return (const IxSourceFunction*) Array_getObject( self->array, index );
}
```

### ArrayOfIxSourceMember

```!include/ixcompiler.ArrayOfIxSourceMember.h
#ifndef IXCOMPILER_ARRAYOFIXSOURCEMEMBER_H
#define IXCOMPILER_ARRAYOFIXSOURCEMEMBER_H

#include "ixcompiler.h"

ArrayOfIxSourceMember* ArrayOfIxSourceMember_new();

ArrayOfIxSourceMember* ArrayOfIxSourceMember_free      (       ArrayOfIxSourceMember** self );
void                   ArrayOfIxSourceMember_push      (       ArrayOfIxSourceMember*  self, IxSourceMember** object );
IxSourceMember*        ArrayOfIxSourceMember_pop       (       ArrayOfIxSourceMember*  self );
IxSourceMember*        ArrayOfIxSourceMember_shift     (       ArrayOfIxSourceMember*  self );
void                   ArrayOfIxSourceMember_unshift   (       ArrayOfIxSourceMember*  self, IxSourceMember** object );

int                    ArrayOfIxSourceMember_getLength ( const ArrayOfIxSourceMember*  self            );
const IxSourceMember*  ArrayOfIxSourceMember_getObject ( const ArrayOfIxSourceMember*  self, int index );

#endif
```

```!c/ixcompiler.ArrayOfIxSourceMember.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.ArrayOfIxSourceMember.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.IxSourceMember.h"

struct _ArrayOfIxSourceMember
{
    Array* array;
};
```

```c/ixcompiler.ArrayOfIxSourceMember.c
ArrayOfIxSourceMember* ArrayOfIxSourceMember_new()
{
    ArrayOfIxSourceMember* self = Platform_Alloc( sizeof( ArrayOfIxSourceMember ) );
    if ( self )
    {
        self->array   = Array_new();
    }

    return self;
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
ArrayOfIxSourceMember* ArrayOfIxSourceMember_free( ArrayOfIxSourceMember** self )
{
    if ( *self )
    {
        IxSourceMember* tmp;
        while ( (tmp = Array_pop( (*self)->array ) ) )
        {
            IxSourceMember_free( &tmp );
        }
        Array_free   ( &(*self)->array );
        Platform_Free(    self         );
    }

    return *self;
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
void ArrayOfIxSourceMember_push( ArrayOfIxSourceMember* self, IxSourceMember** object )
{
    Array_push( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
IxSourceMember* ArrayOfIxSourceMember_pop( ArrayOfIxSourceMember* self )
{
    return (IxSourceMember*) Array_pop( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
IxSourceMember* ArrayOfIxSourceMember_shift( ArrayOfIxSourceMember* self )
{
    return (IxSourceMember*) Array_shift( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
void ArrayOfIxSourceMember_unshift( ArrayOfIxSourceMember* self, IxSourceMember** object )
{
    Array_unshift( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
int ArrayOfIxSourceMember_getLength( const ArrayOfIxSourceMember* self )
{
    return Array_getLength( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceMember.c
const IxSourceMember* ArrayOfIxSourceMember_getObject( const ArrayOfIxSourceMember* self, int index )
{
    return (const IxSourceMember*) Array_getObject( self->array, index );
}
```

### ArrayOfIxSourceMethod

```!include/ixcompiler.ArrayOfIxSourceMethod.h
#ifndef IXCOMPILER_ARRAYOFIXSOURCEMETHOD_H
#define IXCOMPILER_ARRAYOFIXSOURCEMETHOD_H

#include "ixcompiler.h"

ArrayOfIxSourceMethod* ArrayOfIxSourceMethod_new();

ArrayOfIxSourceMethod* ArrayOfIxSourceMethod_free      (       ArrayOfIxSourceMethod** self );
void                   ArrayOfIxSourceMethod_push      (       ArrayOfIxSourceMethod*  self, IxSourceMethod** object );
IxSourceMethod*        ArrayOfIxSourceMethod_pop       (       ArrayOfIxSourceMethod*  self );
IxSourceMethod*        ArrayOfIxSourceMethod_shift     (       ArrayOfIxSourceMethod*  self );
void                   ArrayOfIxSourceMethod_unshift   (       ArrayOfIxSourceMethod*  self, IxSourceMethod** object );

int                    ArrayOfIxSourceMethod_getLength ( const ArrayOfIxSourceMethod*  self            );
const IxSourceMethod*  ArrayOfIxSourceMethod_getObject ( const ArrayOfIxSourceMethod*  self, int index );

#endif
```

```!c/ixcompiler.ArrayOfIxSourceMethod.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.ArrayOfIxSourceMethod.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.IxSourceMethod.h"

struct _ArrayOfIxSourceMethod
{
    Array* array;
};
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
ArrayOfIxSourceMethod* ArrayOfIxSourceMethod_new()
{
    ArrayOfIxSourceMethod* self = Platform_Alloc( sizeof( ArrayOfIxSourceMethod ) );
    if ( self )
    {
        self->array   = Array_new();
    }

    return self;
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
ArrayOfIxSourceMethod* ArrayOfIxSourceMethod_free( ArrayOfIxSourceMethod** self )
{
    if ( *self )
    {
        IxSourceMethod* tmp;
        while ( (tmp = Array_pop( (*self)->array ) ) )
        {
            IxSourceMethod_free( &tmp );
        }
        Array_free   ( &(*self)->array );
        Platform_Free(    self         );
    }

    return *self;
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
void ArrayOfIxSourceMethod_push( ArrayOfIxSourceMethod* self, IxSourceMethod** object )
{
    Array_push( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
IxSourceMethod* ArrayOfIxSourceMethod_pop( ArrayOfIxSourceMethod* self )
{
    return (IxSourceMethod*) Array_pop( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
IxSourceMethod* ArrayOfIxSourceMethod_shift( ArrayOfIxSourceMethod* self )
{
    return (IxSourceMethod*) Array_shift( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
void ArrayOfIxSourceMethod_unshift( ArrayOfIxSourceMethod* self, IxSourceMethod** object )
{
    Array_unshift( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
int ArrayOfIxSourceMethod_getLength( const ArrayOfIxSourceMethod* self )
{
    return Array_getLength( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceMethod.c
const IxSourceMethod* ArrayOfIxSourceMethod_getObject( const ArrayOfIxSourceMethod* self, int index )
{
    return (const IxSourceMethod*) Array_getObject( self->array, index );
}
```

### ArrayOfIxSourceParameter

```!include/ixcompiler.ArrayOfIxSourceParameter.h
#ifndef IXCOMPILER_ARRAYOFIXSOURCEPARAMETER_H
#define IXCOMPILER_ARRAYOFIXSOURCEPARAMETER_H

#include "ixcompiler.h"

ArrayOfIxSourceParameter* ArrayOfIxSourceParameter_new();

ArrayOfIxSourceParameter* ArrayOfIxSourceParameter_free      (       ArrayOfIxSourceParameter** self );
void                      ArrayOfIxSourceParameter_push      (       ArrayOfIxSourceParameter*  self, IxSourceParameter** object );
IxSourceParameter*        ArrayOfIxSourceParameter_pop       (       ArrayOfIxSourceParameter*  self );
IxSourceParameter*        ArrayOfIxSourceParameter_shift     (       ArrayOfIxSourceParameter*  self );
void                      ArrayOfIxSourceParameter_unshift   (       ArrayOfIxSourceParameter*  self, IxSourceParameter** object );

int                       ArrayOfIxSourceParameter_getLength ( const ArrayOfIxSourceParameter*  self            );
const IxSourceParameter*  ArrayOfIxSourceParameter_getObject ( const ArrayOfIxSourceParameter*  self, int index );

#endif
```

```!c/ixcompiler.ArrayOfIxSourceParameter.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.ArrayOfIxSourceParameter.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.IxSourceParameter.h"

struct _ArrayOfIxSourceParameter
{
    Array* array;
};
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
ArrayOfIxSourceParameter* ArrayOfIxSourceParameter_new()
{
    ArrayOfIxSourceParameter* self = Platform_Alloc( sizeof( ArrayOfIxSourceParameter ) );
    if ( self )
    {
        self->array   = Array_new();
    }

    return self;
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
ArrayOfIxSourceParameter* ArrayOfIxSourceParameter_free( ArrayOfIxSourceParameter** self )
{
    if ( *self )
    {
        IxSourceParameter* tmp;
        while ( (tmp = Array_pop( (*self)->array ) ) )
        {
            IxSourceParameter_free( &tmp );
        }
        Array_free   ( &(*self)->array );
        Platform_Free(    self         );
    }

    return *self;
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
void ArrayOfIxSourceParameter_push( ArrayOfIxSourceParameter* self, IxSourceParameter** object )
{
    Array_push( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
IxSourceParameter* ArrayOfIxSourceParameter_pop( ArrayOfIxSourceParameter* self )
{
    return (IxSourceParameter*) Array_pop( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
IxSourceParameter* ArrayOfIxSourceParameter_shift( ArrayOfIxSourceParameter* self )
{
    return (IxSourceParameter*) Array_shift( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
void ArrayOfIxSourceParameter_unshift( ArrayOfIxSourceParameter* self, IxSourceParameter** object )
{
    Array_unshift( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
int ArrayOfIxSourceParameter_getLength( const ArrayOfIxSourceParameter* self )
{
    return Array_getLength( self->array );
}
```

```c/ixcompiler.ArrayOfIxSourceParameter.c
const IxSourceParameter* ArrayOfIxSourceParameter_getObject( const ArrayOfIxSourceParameter* self, int index )
{
    return (const IxSourceParameter*) Array_getObject( self->array, index );
}
```

### ArrayOfString

```!include/ixcompiler.ArrayOfString.h
#ifndef IXCOMPILER_ARRAYOFSTRING_H
#define IXCOMPILER_ARRAYOFSTRING_H

#include "ixcompiler.h"

ArrayOfString* ArrayOfString_new();

ArrayOfString* ArrayOfString_free      (       ArrayOfString** self );
void           ArrayOfString_push      (       ArrayOfString*  self, String** object );
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

```!c/ixcompiler.ArrayOfString.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.ArrayOfString.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _ArrayOfString
{
    Array* array;
    int    longest;
};
```

```c/ixcompiler.ArrayOfString.c
ArrayOfString* ArrayOfString_new()
{
    ArrayOfString* self = Platform_Alloc( sizeof( ArrayOfString ) );
    if ( self )
    {
        self->array   = Array_new();
        self->longest = 0;
    }

    return self;
}
```

```c/ixcompiler.ArrayOfString.c
ArrayOfString* ArrayOfString_free( ArrayOfString** self )
{
    if ( *self )
    {
        String* tmp;
        while ( (tmp = Array_pop( (*self)->array ) ) )
        {
            String_free( &tmp );
        }
        Array_free   ( &(*self)->array );
        Platform_Free(    self         );
    }

    return *self;
}
```

```c/ixcompiler.ArrayOfString.c
void ArrayOfString_push( ArrayOfString* self, String** object )
{
    int len = String_getLength( *object );
    if ( len > self->longest )
    {
        self->longest = len;
    }

    Array_push( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfString.c
String* ArrayOfString_pop( ArrayOfString* self )
{
    return (String*) Array_pop( self->array );
}
```

```c/ixcompiler.ArrayOfString.c
String* ArrayOfString_shift( ArrayOfString* self )
{
    return (String*) Array_shift( self->array );
}
```

```c/ixcompiler.ArrayOfString.c
void ArrayOfString_unshift( ArrayOfString* self, String** object )
{
    Array_unshift( self->array, (void**) object );
}
```

```c/ixcompiler.ArrayOfString.c
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

```c/ixcompiler.ArrayOfString.c
int ArrayOfString_getLength( const ArrayOfString* self )
{
    return Array_getLength( self->array );
}
```

```c/ixcompiler.ArrayOfString.c
int ArrayOfString_getLongest( const ArrayOfString* self )
{
    return self->longest;
}
```

```c/ixcompiler.ArrayOfString.c
const String* ArrayOfString_getObject( const ArrayOfString* self, int index )
{
    return (const String*) Array_getObject( self->array, index );
}
```

```c/ixcompiler.ArrayOfString.c
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

```c/ixcompiler.ArrayOfString.c
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

```!include/ixcompiler.Console.h
#ifndef IXCOMPILER_CONSOLE_H
#define IXCOMPILER_CONSOLE_H

void Console_Write( const char* format, const char* optional );

#endif
```

```!c/ixcompiler.Console.c
#include <stdio.h>
#include "ixcompiler.h"
#include "ixcompiler.Console.h"
```

```c/ixcompiler.Console.c
void Console_Write( const char* format, const char* optional )
{
    fprintf( stdout, format, optional );
}
```

### Dictionary

```!include/ixcompiler.Dictionary.h
#ifndef IXCOMPILER_DICTIONARY_H
#define IXCOMPILER_DICTIONARY_H

#include "ixcompiler.h"

Dictionary* Dictionary_new();

Dictionary* Dictionary_free( Dictionary** self );

bool          Dictionary_put(       Dictionary* self, String** key, String** value );
bool          Dictionary_has( const Dictionary* self, const String* key );
const String* Dictionary_get( const Dictionary* self, const String* key );

#endif
```

```!c/ixcompiler.Dictionary.c
#include "ixcompiler.Array.h"
#include "ixcompiler.Dictionary.h"
#include "ixcompiler.Entry.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _Dictionary
{
    bool   isMap;
    Array* entries;
};

static const Entry* Dictionary_find( const Dictionary* self, const String* key );
```

```c/ixcompiler.Dictionary.c
Dictionary* Dictionary_new( bool is_map )
{
    Dictionary* self = Platform_Alloc( sizeof( Dictionary ) );
    if ( self )
    {
        self->isMap = is_map;
        self->entries = Array_new();
    }
    return self;
}
```

```c/ixcompiler.Dictionary.c
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

```c/ixcompiler.Dictionary.c
bool Dictionary_put( Dictionary* self, String** key, String** value )
{
    if ( self->isMap && Dictionary_has( self, *key ) )
    {
        String_free( key   );
        String_free( value );

        return FALSE;
    }
    else
    {
        Entry* entry = Entry_new( key, value );
        Array_push( self->entries, (void**) &entry );
        return TRUE;
    }
}
```

```c/ixcompiler.Dictionary.c
bool Dictionary_has( const Dictionary* self, const String* key )
{
    return (null != Dictionary_find( self, key ));
}
```

```c/ixcompiler.Dictionary.c
const String* Dictionary_get( const Dictionary* self, const String* key )
{
    const Entry* tmp = Dictionary_find( self, key );

    return (tmp) ? Entry_getValue( tmp ) : null;
}
```

```c/ixcompiler.Dictionary.c
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

```!include/ixcompiler.Entry.h
#ifndef IXCOMPILER_ENTRY_H
#define IXCOMPILER_ENTRY_H

#include "ixcompiler.h"

Entry* Entry_new( String** key, String** val );

      Entry*  Entry_free    (       Entry** self );
const String* Entry_getKey  ( const Entry*  self );
const String* Entry_getValue( const Entry*  self );

#endif
```

```!c/ixcompiler.Entry.c
#include "ixcompiler.Entry.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _Entry
{
    String* key;
    String* val;

};
```

```c/ixcompiler.Entry.c
Entry* Entry_new( String** key, String** val )
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

```c/ixcompiler.Entry.c
Entry* Entry_free( Entry** self )
{
    if ( *self )
    {
        String_free( &(*self)->key );
        String_free( &(*self)->val );

        Platform_Free( self );
    }
    return *self;
}
```

```c/ixcompiler.Entry.c
const String* Entry_getKey( const Entry* self )
{
    return self->key;
}
```

```c/ixcompiler.Entry.c
const String* Entry_getValue( const Entry* self )
{
    return self->val;
}
```

### File

```!include/ixcompiler.File.h
#ifndef IXCOMPILER_FILE_H
#define IXCOMPILER_FILE_H

#include "ixcompiler.h"

File*       File_new        ( const char* filepath );

File*       File_free       (       File** self );
bool        File_canRead    ( const File*  self );
const char* File_getFilePath( const File*  self );
bool        File_exists     ( const File*  self );

#endif
```

```!c/ixcompiler.File.c
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include "ixcompiler.h"
#include "ixcompiler.File.h"

struct _File
{
    const char* filepath;
    bool        canRead;
    bool        exists;
};

static bool File_IsReadable   ( const char* filepath );
static bool File_IsRegularFile( const char* filepath );
```

```c/ixcompiler.File.c
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

```c/ixcompiler.File.c
File* File_free( File** self )
{
    free( *self ); *self = 0;

    return *self;
}
```

```c/ixcompiler.File.c
bool File_canRead( const File* self )
{
    return self->canRead;
}
```

```c/ixcompiler.File.c
const char* File_getFilePath( const File* self )
{
    return self->filepath;
}
```

```c/ixcompiler.File.c
bool File_exists( const File* self )
{
    return self->exists;
}
```

```c/ixcompiler.File.c
bool File_IsReadable( const char* filepath )
{
    return (F_OK == access( filepath, R_OK ));
}
```

```c/ixcompiler.File.c
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

```!include/ixcompiler.FilesIterator.h
#ifndef IXCOMPILER_FILESITERATOR_H
#define IXCOMPILER_FILESITERATOR_H

FilesIterator* FilesIterator_new      ( const char** filepaths );
FilesIterator* FilesIterator_free     ( FilesIterator** self   );
bool           FilesIterator_hasNext  ( FilesIterator*  self   );
File*          FilesIterator_next     ( FilesIterator*  self   );

#endif
```

```!c/ixcompiler.FilesIterator.c
#include <stdlib.h>
#include "ixcompiler.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.File.h"
#include "ixcompiler.FilesIterator.h"
#include "todo.h"

struct _FilesIterator
{
    const char** filepaths;
    int          next;
};
```

```c/ixcompiler.FilesIterator.c
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

```c/ixcompiler.FilesIterator.c
FilesIterator* FilesIterator_free( FilesIterator** self )
{
    free( *self ); *self = 0;

    return *self;
}
```

```c/ixcompiler.FilesIterator.c
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

```c/ixcompiler.FilesIterator.c
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

```!include/ixcompiler.Node.h
#ifndef IXCOMPILER_NODE_H
#define IXCOMPILER_NODE_H

#include "ixcompiler.h"

Node* Node_new ( Token** token );
Node* Node_free( Node**  self  );

void  Node_setParent   ( Node* self, const Node* parent );
void  Node_setTag      ( Node* self, const char* tag );
void  Node_addChild    ( Node* self, Token** token );
Node* Node_getLastChild( Node* self );

const Token*  Node_getToken    ( const Node* self );
const String* Node_getTag      ( const Node* self );

bool          Node_hasChildren ( const Node* self );
NodeIterator* Node_iterator    ( const Node* self );
String*       Node_export      ( const Node* self );

#endif
```

```!c/ixcompiler.Node.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.StringBuffer.h"

struct _Node
{
    Token*      token;
    const Node* parent;
    Array*      children;
    String*     tag;
};
```

```c/ixcompiler.Node.c
Node* Node_new( Token** token )
{
    Node* self = Platform_Alloc( sizeof( Node ) );

    if ( self )
    {
        self->token    = *token; *token = null;
        self->children = Array_new();
    }
    return self;
}
```

```c/ixcompiler.Node.c
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

```c/ixcompiler.Node.c
void Node_setParent( Node* self, const Node* parent )
{
    self->parent = parent;
}
```

```c/ixcompiler.Node.c
void Node_setTag( Node* self, const char* tag )
{
    self->tag = String_new( tag );
}
```

```c/ixcompiler.Node.c
void Node_addChild( Node* self, Token** token )
{
    Node* child = Node_new( token );

    Array_push( self->children, (void**) &child );
}
```

```c/ixcompiler.Node.c
Node* Node_getLastChild( Node* self )
{
    int last = Array_getLength( self->children ) - 1;

    return (Node*) Array_getObject( self->children, last );
}
```

```c/ixcompiler.Node.c
const Token* Node_getToken( const Node* self )
{
    return self->token;
}
```

```c/ixcompiler.Node.c
const String* Node_getTag( const Node* self )
{
    return self->tag;
}
```

```c/ixcompiler.Node.c
bool Node_hasChildren( const Node* self )
{
    return (0 < Array_getLength( self->children ));
}
```

```c/ixcompiler.Node.c
NodeIterator* Node_iterator( const Node* self )
{
    return NodeIterator_new( self->children );
}
```

```c/ixcompiler.Node.c
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

### NodeIterator

```!include/ixcompiler.NodeIterator.h
#ifndef IXCOMPILER_NODEITERATOR_H
#define IXCOMPILER_NODEITERATOR_H

NodeIterator* NodeIterator_new                   ( const Array*  nodes );
NodeIterator* NodeIterator_free                  ( NodeIterator** self );
bool          NodeIterator_hasNext               ( NodeIterator*  self );
bool          NodeIterator_hasNonWhitespace      ( NodeIterator*  self );
bool          NodeIterator_hasNonWhitespaceOfType( NodeIterator*  self, EnumTokenType type );
const Node*   NodeIterator_next                  ( NodeIterator*  self );
const Node*   NodeIterator_peek                  ( NodeIterator*  self );

#endif
```

```!c/ixcompiler.NodeIterator.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.EnumTokenType.h"
#include "ixcompiler.EnumTokenGroup.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.TokenGroup.h"

struct _NodeIterator
{
    const Array* nodes;
    int          next;
};
```

```c/ixcompiler.NodeIterator.c
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

```c/ixcompiler.NodeIterator.c
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

```c/ixcompiler.NodeIterator.c
bool NodeIterator_hasNext( NodeIterator* self )
{
    return (self->next < Array_getLength( self->nodes ));
}
```

```c/ixcompiler.NodeIterator.c
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

```c/ixcompiler.NodeIterator.c
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

```c/ixcompiler.NodeIterator.c
const Node* NodeIterator_next( NodeIterator* self )
{
    return (const void*) Array_getObject( self->nodes, self->next++ );
}
```

```c/ixcompiler.NodeIterator.c
const Node* NodeIterator_peek( NodeIterator* self )
{
    return (const void*) Array_getObject( self->nodes, self->next );
}
```

### Path

```!include/ixcompiler.Path.h
#ifndef IXCOMPILER_PATH_H
#define IXCOMPILER_PATH_H

Path* Path_new( const char* target );

Path*       Path_free       (       Path** self );
bool        Path_exists     ( const Path*  self );
bool        Path_canWrite   ( const Path*  self );
const char* Path_getFullPath( const Path*  self );
Path*       Path_getParent  ( const Path*  self );

#endif
```

```!c/ixcompiler.Path.c
#include <stdlib.h>
#include "ixcompiler.h"
#include "ixcompiler.Path.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

struct _Path
{
    bool  exists;
    bool  canWrite;
    char* path;
};
```

```c/ixcompiler.Path.c
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

```c/ixcompiler.Path.c
Path* Path_free( Path** self )
{
    free( (*self)->path );
    free( *self ); *self = 0;

    return *self;
}
```

```c/ixcompiler.Path.c
bool Path_exists( const Path* self )
{
    return self->exists;
}
```

```c/ixcompiler.Path.c
bool Path_canWrite( const Path* self )
{
    return self->canWrite;
}
```

```c/ixcompiler.Path.c
const char* Path_getFullPath( const Path* self )
{
    return self->path;
}
```

```c/ixcompiler.Path.c
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

```!include/ixcompiler.PushbackReader.h
#ifndef IXCOMPILER_PUSHBACKREADER_H
#define IXCOMPILER_PUSHBACKREADER_H

PushbackReader* PushbackReader_new     ( const char*      filepath );
PushbackReader* PushbackReader_free    ( PushbackReader** self     );
int             PushbackReader_read    ( PushbackReader*  self     );
PushbackReader* PushbackReader_pushback( PushbackReader*  self     );

#endif
```

```!c/ixcompiler.PushbackReader.c
#include "ixcompiler.h"
#include "ixcompiler.File.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.PushbackReader.h"
#include "ixcompiler.String.h"

struct _PushbackReader
{
    char* content;
    int   head;
    int   length;
};
```

```c/ixcompiler.PushbackReader.c
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

```c/ixcompiler.PushbackReader.c
PushbackReader* PushbackReader_free( PushbackReader** self )
{
    Platform_Free( &(*self)->content );
    Platform_Free( self );

    return *self;
}
```

```c/ixcompiler.PushbackReader.c
int PushbackReader_read( PushbackReader* self )
{
    return (self && (self->head < self->length)) ? self->content[self->head++] : 0;
}
```

```c/ixcompiler.PushbackReader.c
PushbackReader* PushbackReader_pushback( PushbackReader* self )
{
    self->head--;
    return self;
}
```.. Queue

```!include/ixcompiler.Queue.h
#ifndef IXCOMPILER_QUEUE_H
#define IXCOMPILER_QUEUE_H

Queue* Queue_new       ();
Queue* Queue_free      ( Queue** self );
Queue* Queue_addHead   ( Queue* self, void** object );
Queue* Queue_addTail   ( Queue* self, void** object );
void*  Queue_removeHead( Queue* self );
int    Queue_getLength ( Queue* self );

#endif
```

```!c/ixcompiler.Queue.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Queue.h"

struct _Queue
{
    Array* inner;

};
```

```c/ixcompiler.Queue.c
Queue* Queue_new()
{
    Queue* self = Platform_Alloc( sizeof( Queue ) );

    if ( self )
    {
        self->inner = Array_new();
    }
    return self;
}
```

```c/ixcompiler.Queue.c
Queue* Queue_free( Queue** self )
{
    Array_free( &(*self)->inner );
    Platform_Free( self );

    return *self;
}
```

```c/ixcompiler.Queue.c
Queue* Queue_addHead( Queue* self, void** object )
{
    Array_unshift( self->inner, object );

    return self;
}
```

```c/ixcompiler.Queue.c
Queue* Queue_addTail( Queue* self, void** object )
{
    Array_push( self->inner, object );

    return self;
}
```

```c/ixcompiler.Queue.c
void* Queue_removeHead( Queue* self )
{
    return Array_shift( self->inner );
}
```

```c/ixcompiler.Queue.c
int Queue_getLength( Queue* self )
{
    return Array_getLength( self->inner );
}
```

### String

```!include/ixcompiler.String.h
#ifndef IXCOMPILER_STRING_H
#define IXCOMPILER_STRING_H

String*        String_new    ( const char* content );

String*        String_free       (       String** self );
const char*    String_content    ( const String*  self );
int            String_getLength  ( const String*  self );
String*        String_copy       ( const String*  self );
String*        String_cat        ( const String*  self, const String* other );
bool           String_equals     ( const String*  self, const String* other );
bool           String_contains   ( const String*  self, const String* other );
ArrayOfString* String_split      ( const String*  self, char separator      );
String*        String_toUpperCase( const String*  self );
String*        String_replace    ( const String*  self, char ch, char with );

char*          String_Cat   ( const char* string1, const char* string2 );
bool           String_Equals( const char* string1, const char* string2 );
int            String_Length( const char* s );
char*          String_Copy  ( const char* s );

#endif
```

```!c/ixcompiler.String.c
#include <string.h>
#include "ixcompiler.h"
#include "ixcompiler.ArrayOfString.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.StringBuffer.h"

struct _String
{
    char* content;
    int   length;
};
```

```c/ixcompiler.String.c
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

```c/ixcompiler.String.c
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

```c/ixcompiler.String.c
const char* String_content( const String* self )
{
    return self->content;
}
```

```c/ixcompiler.String.c
int String_getLength( const String* self )
{
    return self->length;
}
```

```c/ixcompiler.String.c
String* String_copy( const String* self )
{
    return String_new( self->content );
}
```

```c/ixcompiler.String.c
String* String_cat( const String* self, const String* other )
{
    char* tmp = String_Cat( self->content, other->content );
    String* ret = String_new( tmp );
    Platform_Free( &tmp );

    return ret;
}
```

```c/ixcompiler.String.c
bool String_equals( const String* self, const String* other )
{
    return String_Equals( self->content, other->content );
}
```

```c/ixcompiler.String.c
bool String_contains( const String* self, const String* other )
{
    return (NULL != strstr( String_content( self ), String_content( other ) ) );
}
```

```c/ixcompiler.String.c
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

```c/ixcompiler.String.c
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

```c/ixcompiler.String.c
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

```c/ixcompiler.String.c
char* String_Cat( const char* s1, const char* s2 )
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

    return concatenated;
}
```

```c/ixcompiler.String.c
char* String_Copy( const char* s )
{
    int   len  = String_Length( s ) + 2;
    char* copy = Platform_Array( len, sizeof( char ) );

    return strcpy( copy, s );
}
```

```c/ixcompiler.String.c
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

```c/ixcompiler.String.c
int String_Length( const char* s )
{
    return strlen( s );
}
```
### StringBuffer

```!include/ixcompiler.StringBuffer.h
#ifndef IXCOMPILER_STRINGBUFFER_H
#define IXCOMPILER_STRINGBUFFER_H

StringBuffer* StringBuffer_new              ();
StringBuffer* StringBuffer_free             ( StringBuffer** self                     );
StringBuffer* StringBuffer_append           ( StringBuffer*  self, const char* suffix );
StringBuffer* StringBuffer_append_char      ( StringBuffer*  self, char        ch     );
StringBuffer* StringBuffer_appendLine       ( StringBuffer*  self, char* prefix, DISPOSABLE String* string );


const char*   StringBuffer_content    ( const StringBuffer*  self );
bool          StringBuffer_isEmpty    ( const StringBuffer*  self );
String*       StringBuffer_toString   ( const StringBuffer*  self );

#endif
```

```!c/ixcompiler.StringBuffer.c
#include "ixcompiler.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"
#include "ixcompiler.StringBuffer.h"

struct _StringBuffer
{
    char* content;
    int   length;

};

String* StringBuffer_nullString = null;
```

```c/ixcompiler.StringBuffer.c
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

```c/ixcompiler.StringBuffer.c
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

```c/ixcompiler.StringBuffer.c
StringBuffer* StringBuffer_append( StringBuffer* self, const char* suffix )
{
    self->length += String_Length( suffix );
    char* tmp = self->content;
    self->content = String_Cat( tmp, suffix );

    Platform_Free( &tmp );

    return self;
}
```

```c/ixcompiler.StringBuffer.c
StringBuffer* StringBuffer_append_char( StringBuffer* self, char ch )
{
    char suffix[2] = { ch , '\0' };

    return StringBuffer_append( self, suffix );
}
```

```c/ixcompiler.StringBuffer.c
StringBuffer* StringBuffer_appendLine ( StringBuffer*  self, char* prefix, DISPOSABLE String* optional_string )
{
    if ( String_Length( prefix ) )
    {
        StringBuffer_append( self, prefix );
        StringBuffer_append( self, " "    );
    }

    if ( optional_string )
    {
        StringBuffer_append( self, String_content( optional_string ) );
        String_free( &optional_string );
    }
    StringBuffer_append( self, "\n" );
}
```

```c/ixcompiler.StringBuffer.c
const char* StringBuffer_content( const StringBuffer* self )
{
    return self->content;
}
```

```c/ixcompiler.StringBuffer.c
bool StringBuffer_isEmpty( const StringBuffer* self )
{
    return (0 == String_Length( self->content ));
}
```

```c/ixcompiler.StringBuffer.c
String* StringBuffer_toString( const StringBuffer* self )
{
    return String_new( StringBuffer_content( self ) );
}
```

### Take

```!c/ixcompiler.Take.c
#include "ixcompiler.h"

static void* stash[100];

void** Give( void* pointer )
{
    void** tmp = stash;

    while ( *tmp ) tmp++;

    *tmp = pointer;

    return tmp;
}

void* Take( void* giver )
{
    void** _giver = (void**) giver;

    void* keeper = *_giver; *_giver = null;

    return keeper;
}
```

```!include/ixcompiler.Term.h
#ifndef IXCOMPILER_TERM_H
#define IXCOMPILER_TERM_H

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

```!c/ixcompiler.Term.c
#include <stdio.h>
#include "ixcompiler.Term.h"

void Term_Colour( void* stream, const char* color )
{
    fprintf( stream, "%s", color );
}
```
### Tree

```!include/ixcompiler.Tree.h
#ifndef IXCOMPILER_TREE_H
#define IXCOMPILER_TREE_H

#include "ixcompiler.h"

Tree* Tree_new();
Tree* Tree_free   ( Tree** self );
void  Tree_setRoot( Tree*  self, Node** node );

const Node* Tree_getRoot( const Tree* self );

#endif
```

```!c/ixcompiler.Tree.c
#include "ixcompiler.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Tree.h"

struct _Tree
{
    Node* root;
};
```

```c/ixcompiler.Tree.c
Tree* Tree_new()
{
    Tree* self = Platform_Alloc( sizeof( Tree ) );
    return self;
}
```

```c/ixcompiler.Tree.c
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

```c/ixcompiler.Tree.c
void Tree_setRoot( Tree* self, Node** node )
{
    self->root = *node; *node = null;
}
```

```c/ixcompiler.Tree.c
const Node* Tree_getRoot( const Tree* self )
{
    return self->root;
}
```

```!include/ixcompiler.Platform.h
#ifndef IXCOMPILER_PLATFORM_H
#define IXCOMPILER_PLATFORM_H

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

```!c/posix/ixcompiler.Platform.c
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/limits.h>

#include "ixcompiler.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Path.h"
#include "ixcompiler.String.h"
```

```c/posix/ixcompiler.Platform.c
void* Platform_Alloc( int size_of )
{
    return calloc( 1, size_of );
}
```

```c/posix/ixcompiler.Platform.c
void* Platform_Array( int num, int size_of )
{
    return calloc( num, size_of );
}
```

```c/posix/ixcompiler.Platform.c
void* Platform_Free( void* mem )
{
    void** obj = (void**) mem;

    free( *obj ); *obj = 0;

    return *obj;
}
```

```c/posix/ixcompiler.Platform.c
void Platform_Exit( int status )
{
    exit( status );
}
```

```c/posix/ixcompiler.Platform.c
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

```c/posix/ixcompiler.Platform.c
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

```c/posix/ixcompiler.Platform.c
bool Platform_Location_Exists( const char* location )
{
    struct stat sb;

    return (F_OK == stat( location, &sb ));
}
```

```c/posix/ixcompiler.Platform.c
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

```c/posix/ixcompiler.Platform.c
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

```c/posix/ixcompiler.Platform.c
bool Platform_Location_IsReadable( const char* location )
{
    return (F_OK == access( location, R_OK ));
}
```

```c/posix/ixcompiler.Platform.c
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

```c/posix/ixcompiler.Platform.c
bool Platform_Location_IsWritable( const char* location )
{
    return (F_OK == access( location, W_OK ));
}
```

```c/posix/ixcompiler.Platform.c
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
