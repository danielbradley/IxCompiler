
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
#include "ixcompiler.Console.h"
#include "ixcompiler.File.h"
#include "ixcompiler.FilesIterator.h"
#include "ixcompiler.Generator.h"
#include "ixcompiler.IxParser.h"
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
    Generator*     generator   = Generator_new          ( target_lang );

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
        while ( FilesIterator_hasNext( files ) )
        {
            File* file = FilesIterator_next( files );

            if ( !File_exists( file ) )
            {
                Console_Write( ABORT_FILE_DOES_NOT_EXIST, File_getFilepath( file ) );
                exit( -1 );
            }
            else
            if ( !File_canRead( file ) )
            {
                Console_Write( ABORT_FILE_CANNOT_BE_READ, File_getFilepath( file ) );
                exit( -1 );
            }
            else
            if ( TRUE )
            {
                Tokenizer* tokenizer = Tokenizer_new( file );

                if ( TRUE )
                {
                    IxParser*  parser    = IxParser_new  ( tokenizer );
                    AST*       ast       = IxParser_parse( parser );

                    if ( !dry_run )
                    {
                        status &= Generator_writeAST( generator, ast, output_path, file );
                    }

                    AST_free( &ast );
                    IxParser_free( &parser );
                }
                Tokenizer_free( &tokenizer );
            }

            File_free( &file );
        }
    }

    Arguments_free    ( &args );
    FilesIterator_free( &files );
    Path_free         ( &output_path );
    Generator_free    ( &generator );

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

typedef struct _Arguments      Arguments;
typedef struct _Array          Array;
typedef struct _AST            AST;
typedef enum   _EnumTokenGroup EnumTokenGroup;
typedef enum   _EnumTokenType  EnumTokenType;
typedef struct _File           File;
typedef struct _FilesIterator  FilesIterator;
typedef struct _Generator      Generator;
typedef struct _IxParser       IxParser;
typedef struct _Node           Node;
typedef struct _NodeIterator   NodeIterator;
typedef struct _Path           Path;
typedef struct _PushbackReader PushbackReader;
typedef struct _Queue          Queue;
typedef struct _String         String;
typedef struct _StringBuffer   StringBuffer;
typedef struct _Token          Token;
typedef struct _TokenGroup     TokenGroup;
typedef struct _Tokenizer      Tokenizer;
typedef struct _Tree           Tree;

#endif
```

### AST

```!include/ixcompiler.AST.h
#ifndef IXCOMPILER_AST_H
#define IXCOMPILER_AST_H

#include "ixcompiler.h"

AST*        AST_new();
AST*        AST_free   ( AST** self );
void        AST_setTree( AST*  self, Tree** tree );
const Tree* AST_getTree( AST*  self );

#endif
```

```!c/ixcompiler.AST.c
#include "ixcompiler.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Tree.h"

struct _AST
{
    Tree* tree;
};
```

```c/ixcompiler.AST.c
AST* AST_new()
{
    AST* self = Platform_Alloc( sizeof( AST ) );
    if ( self )
    {
        self->tree = Tree_new();
    }

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
void AST_setTree( AST* self, Tree** tree )
{
    Tree_free( &self->tree );

    self->tree = *tree; *tree = null; 
}
```

```c/ixcompiler.AST.c
const Tree* AST_getTree( AST* self )
{
    return self->tree;
}
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

### Array

```!include/ixcompiler.Array.h
#ifndef IXCOMPILER_ARRAY_H
#define IXCOMPILER_ARRAY_H

Array* Array_new    ();
Array* Array_free   ( Array** self );
Array* Array_push   ( Array*  self, void** object );
void*  Array_shift  ( Array*  self );
Array* Array_unshift( Array*  self, void** object );

int         Array_length   ( const Array* self );
const void* Array_getObject( const Array* self, int index );

#endif
```

```!c/ixcompiler.Array.c
#include "ixcompiler.h"
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
int Array_length( const Array* self )
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

#endif
```

### File

```!include/ixcompiler.File.h
#ifndef IXCOMPILER_FILE_H
#define IXCOMPILER_FILE_H

File*       File_new        ( const char* filepath );
File*       File_free       ( File**      self     );
bool        File_canRead    ( File*       self     );
const char* File_getFilepath( File*       self     );
bool        File_exists     ( File*       self     );

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
bool File_canRead( File* self )
{
    return self->canRead;
}
```

```c/ixcompiler.File.c
const char* File_getFilepath( File* self )
{
    return self->filepath;
}
```

```c/ixcompiler.File.c
bool File_exists( File* self )
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

### Generator

```!include/ixcompiler.Generator.h
#ifndef IXCOMPILER_GENERATOR_H
#define IXCOMPILER_GENERATOR_H

Generator* Generator_new     ( const char* lang );
Generator* Generator_free    ( Generator** self );
int        Generator_writeAST( Generator* self, AST* ast, Path* output_path, File* source_file );

#endif
```

```!c/ixcompiler.Generator.c
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

struct _Generator
{
    char* targetLanguage;
};

static void PrintNode( const Node* node );
static void PrintTree( const Node* node, int indent );
```

```c/ixcompiler.Generator.c
Generator* Generator_new( const char* target_language )
{
    Generator* self = Platform_Alloc( sizeof( Generator ) );
    if ( self )
    {
        self->targetLanguage = String_Copy( target_language );
    }    

    if ( String_Equals( target_language, LANG_C ) )
    {
        return self;
    }
    else
    {
        return Generator_free( &self );
    }
}
```

```c/ixcompiler.Generator.c
Generator* Generator_free( Generator** self )
{
    if ( *self )
    {
        Platform_Free( &(*self)->targetLanguage );
        Platform_Free( self );
    }

    return *self;
}
```

```c/ixcompiler.Generator.c
int Generator_writeAST( Generator* self, AST* ast, Path* output_path, File* source_file )
{
    const Tree* tree = AST_getTree( ast );
    const Node* root = Tree_getRoot( tree );

    //PrintNode( root );
    PrintTree( root, -1 );

    return SUCCESS;
}
```

```c/ixcompiler.Generator.c
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

```c/ixcompiler.Generator.c
static void PrintTree( const Node* node, int indent )
{
    const Token* token = Node_getToken( node );

    if ( token )
    {
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

static void ParseRoot      ( Node* parent, Tokenizer* tokenizer );
static void ParseComplex   ( Node* parent, Tokenizer* tokenizer );
static void ParseClass     ( Node* parent, Tokenizer* tokenizer );
static void ParseMethod    ( Node* parent, Tokenizer* tokenizer );
static void ParseStatement ( Node* parent, Tokenizer* tokenizer, bool one_liner );
static void ParseBlock     ( Node* parent, Tokenizer* tokenizer );
static void ParseExpression( Node* parent, Tokenizer* tokenizer );
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
    AST*  ast  = AST_new();
    Tree* tree = Tree_new();
    {
        Token* t    = null;
        Node*  root = Node_new( &t );
        ParseRoot( root, self->tokenizer );
        Tree_setRoot( tree, &root );
    }
    AST_setTree( ast, &tree );

    return ast;
}
```

```c/ixcompiler.IxParser.c
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
            switch ( token_type )
            {
            case COPYRIGHT:
            case LICENSE:
                ParseStatement( Node_getLastChild( parent ), tokenizer, TRUE );
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

```c/ixcompiler.IxParser.c
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
            ParseClass( Node_getLastChild( parent ), tokenizer );
            break;
        }
        else
        if ( (token_group == ALPHANUMERIC) && (token_type == WORD) )
        {
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

```c/ixcompiler.IxParser.c
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

```c/ixcompiler.IxParser.c
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

```c/ixcompiler.IxParser.c
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

```c/ixcompiler.IxParser.c
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
        if ( (token_group == SYMBOLIC) && (token_type == SYMBOL) )
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

```c/ixcompiler.IxParser.c
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

### NodeIterator

```!include/ixcompiler.NodeIterator.h
#ifndef IXCOMPILER_NODEITERATOR_H
#define IXCOMPILER_NODEITERATOR_H

NodeIterator* NodeIterator_new    ( const Array*  nodes );
NodeIterator* NodeIterator_free   ( NodeIterator** self );
bool          NodeIterator_hasNext( NodeIterator*  self );
const Node*   NodeIterator_next   ( NodeIterator*  self );

#endif
```

```!c/ixcompiler.NodeIterator.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Platform.h"

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
    return (self->next < Array_length( self->nodes ));
}
```

```c/ixcompiler.NodeIterator.c
const Node* NodeIterator_next( NodeIterator* self )
{
    return (const void*) Array_getObject( self->nodes, self->next++ );
}
```

### Path

```!include/ixcompiler.Path.h
#ifndef IXCOMPILER_PATH_H
#define IXCOMPILER_PATH_H

Path* Path_new     ( const char* target );
Path* Path_free    ( Path** self )       ;
bool  Path_exists  ( Path* self )        ;
bool  Path_canWrite( Path* self )        ;

#endif
```

```!c/ixcompiler.Path.c
#include <stdlib.h>
#include "ixcompiler.h"
#include "ixcompiler.Path.h"
#include "ixcompiler.Platform.h"

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
bool Path_exists( Path* self )
{
    return self->exists;
}
```

```c/ixcompiler.Path.c
bool Path_canWrite( Path* self )
{
    return self->canWrite;
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
            self->content = Platform_GetFileContents( filepath );
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
    return Array_length( self->inner );
}
```

### String

```!include/ixcompiler.String.h
#ifndef IXCOMPILER_STRING_H
#define IXCOMPILER_STRING_H

String*     String_new    ( const char* content );
String*     String_free   ( String** self );

const char* String_content( const String* self );
int         String_length ( const String* self );
String*     String_copy   ( const String* self );
String*     String_cat    ( const String* self, const String* other );
bool        String_equals ( const String* self, const String* other );

char* String_Cat   ( const char* string1, const char* string2 );
bool  String_Equals( const char* string1, const char* string2 );
int   String_Length( const char* s );
char* String_Copy  ( const char* s );

#endif
```

```!c/ixcompiler.String.c
#include <string.h>
#include "ixcompiler.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.String.h"

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
int String_length( const String* self )
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
```

```c/ixcompiler.String.c
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

StringBuffer* StringBuffer_new        ();
StringBuffer* StringBuffer_free       ( StringBuffer** self                     );
StringBuffer* StringBuffer_append     ( StringBuffer*  self, const char* suffix );
StringBuffer* StringBuffer_append_char( StringBuffer*  self, char        ch     );
const char*   StringBuffer_content    ( StringBuffer*  self                     );
bool          StringBuffer_isEmpty    ( StringBuffer*  self                     );

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
const char* StringBuffer_content( StringBuffer* self )
{
    return self->content;
}
```

```c/ixcompiler.StringBuffer.c
bool StringBuffer_isEmpty( StringBuffer* self )
{
    return (0 == String_Length( self->content ));
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
### Token

```!include/ixcompiler.Token.h
#ifndef IXCOMPILER_TOKEN_H
#define IXCOMPILER_TOKEN_H

#include "ixcompiler.h"

Token*        Token_new                      ( Tokenizer* t, const char* content, TokenGroup* aGroup );
Token*        Token_free                     ( Token**      self );
const char*   Token_getContent               ( const Token* self );
TokenGroup*   Token_getTokenGroup            ( const Token* self );
EnumTokenType Token_getTokenType             ( const Token* self );
void          Token_print                    ( const Token* self, void* stream );

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
        self->t       = t;
        self->content = String_Copy  ( content );
        self->length  = String_Length( content );
        self->group   = TokenGroup_copy( aGroup );
        self->type    = Token_DetermineTokenType( aGroup, content );
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
TokenGroup* Token_getTokenGroup( const Token* self )
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
    fprintf( stream, "%s", self->content );
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

    case ':':   return OPERATOR;
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
    else if ( String_Equals( content, "const"      ) ) return PRIMITIVE;
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
    else                                              return WORD;
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
EnumTokenGroup TokenGroup_getGroupType ( TokenGroup*  self );
EnumTokenGroup TokenGroup_DetermineType( char ch );
bool           TokenGroup_matches      ( TokenGroup* self, char ch );
TokenGroup*    TokenGroup_copy         ( const TokenGroup* self );

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
EnumTokenGroup TokenGroup_getGroupType ( TokenGroup*  self )
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
bool TokenGroup_matches( TokenGroup* self, char ch )
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

Tokenizer* Tokenizer_new          ( File*       file );
Tokenizer* Tokenizer_free         ( Tokenizer** self );
Token*     Tokenizer_nextToken    ( Tokenizer*  self );
bool       Tokenizer_hasMoreTokens( Tokenizer*  self ); 

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
Tokenizer* Tokenizer_new( File* file )
{
    Tokenizer* self = Platform_Alloc( sizeof( Tokenizer ) );

    if ( self )
    {
        self->file   = file;
        self->reader = PushbackReader_new( File_getFilepath( self->file ) );
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

        PushbackReader_free( &(*self)->reader );

        Queue_free( &(*self)->queue );

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
bool Tokenizer_hasMoreTokens( Tokenizer* self )
{
    return (Queue_getLength( self->queue ) > 0);
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

### Node

```!include/ixcompiler.Node.h
#ifndef IXCOMPILER_NODE_H
#define IXCOMPILER_NODE_H

#include "ixcompiler.h"

Node* Node_new ( Token** token );
Node* Node_free( Node**  self  );

void  Node_setParent   ( Node* self, const Node* parent );
void  Node_addChild    ( Node* self, Token** token );
Node* Node_getLastChild( Node* self );

const Token*  Node_getToken   ( const Node* self );
bool          Node_hasChildren( const Node* self );
NodeIterator* Node_iterator   ( const Node* self );

#endif
```


```!c/ixcompiler.Node.c
#include "ixcompiler.h"
#include "ixcompiler.Array.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.NodeIterator.h"
#include "ixcompiler.Token.h"
#include "ixcompiler.Platform.h"

struct _Node
{
    Token*      token;
    const Node* parent;
    Array*      children;
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
        Array_free( &(*self)->children );
        
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
void Node_addChild( Node* self, Token** token )
{
    Node* child = Node_new( token );

    Array_push( self->children, (void**) &child );
}
```

```c/ixcompiler.Node.c
const Token* Node_getToken( const Node* self )
{
    return self->token;
}
```

```c/ixcompiler.Node.c
bool Node_hasChildren( const Node* self )
{
    return (0 < Array_length( self->children ));
}
```

```c/ixcompiler.Node.c
NodeIterator* Node_iterator( const Node* self )
{
    return NodeIterator_new( self->children );
}
```

```c/ixcompiler.Node.c
Node* Node_getLastChild( Node* self )
{
    int last = Array_length( self->children ) - 1;

    return (Node*) Array_getObject( self->children, last );
}
```

```!include/ixcompiler.Platform.h
#ifndef IXCOMPILER_PLATFORM_H
#define IXCOMPILER_PLATFORM_H

void* Platform_Alloc                 ( int size_of );
void* Platform_Array                 ( int num, int size_of );
void* Platform_Free                  ( void* mem );

void  Platform_Exit                  ( int status );

bool  Platform_Location_Exists       ( const char* location );
char* Platform_Location_FullPath     ( const char* location );
bool  Platform_Location_IsDirectory  ( const char* location );
bool  Platform_Location_IsReadable   ( const char* location );
bool  Platform_Location_IsRegularFile( const char* location );
bool  Platform_Location_IsWritable   ( const char* location );
char* Platform_GetFileContents       ( const char* location );

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
char* Platform_GetFileContents( const char* location )
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