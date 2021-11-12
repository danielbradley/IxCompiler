
## Introduction
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

#include "ixcompiler.h"
#include "ixcompiler.Arguments.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.File.h"
#include "ixcompiler.FilesIterator.h"
#include "ixcompiler.Path.h"
#include "todo.h"

int main( int argc, char** argv )
{
    int            status      = 1;
    Arguments*     args        = Arguments_new( argc, argv );
    bool           dry_run     = Arguments_hasFlag      ( args, ARGUMENT_DRY_RUN );
    const char*    target_lang = Arguments_getOption    ( args, ARGUMENT_TARGET_LANGUAGE );
    const char*    output_dir  = Arguments_getOption    ( args, ARGUMENT_OUTPUT_DIR );
    FilesIterator* files       = Arguments_filesIterator( args );
    Path*          output_path = Path_new( output_dir );

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
    {
        Generator* generator = Generator_new( target_lang );

        if ( !generator )
        {
            Console_Write( ABORT_TARGET_LANGUAGE_NOT_SUPPORTED, target_lang );
        }
        else
        {
            while ( FilesIterator_hasNext( files ) )
            {
                File* file = FilesIterator_next( files );

                if ( File_exists( file ) && File_canRead( file ) )
                {
                    Tokenizer* tokenizer = Tokenizer_new ( file );
                    IxParser*  parser    = IxParser_new  ( tokenizer );
                    AST*       ast       = IxParser_parse( parser );

                    if ( !dry_run )
                    {
                        status &= Generator_writeAST( generator, ast, output_path, file );
                    }

                    Tokenizer_free( &tokenizer );
                    IxParser_free( &parser );
                    AST_free( &ast );
                }

                File_free( &file );
            }
        }

        Generator_free( &generator );
    }

    Arguments_free    ( &args );
    FilesIterator_free( &files );
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
#define ABORT_NO_OUTPUT_DIR                 "Aborting, no output directory specified (--output-dir)\n"
#define ABORT_TARGET_LANGUAGE_NOT_SUPPORTED "Aborting, could not find generator for target language - %s\n"

#define ARGUMENT_DRY_RUN         "--dry-run"
#define ARGUMENT_OUTPUT_DIR      "--output-dir"
#define ARGUMENT_TARGET_LANGUAGE "--target-language"

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

typedef struct _Arguments     Arguments;
typedef struct _AST           AST;
typedef struct _File          File;
typedef struct _FilesIterator FilesIterator;
typedef struct _Generator     Generator;
typedef struct _IxParser      IxParser;
typedef struct _Path          Path;
typedef struct _Tokenizer     Tokenizer;

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
#include <stdlib.h>

#include "ixcompiler.h"
#include "ixcompiler.Arguments.h"
#include "ixcompiler.Console.h"
#include "ixcompiler.FilesIterator.h"
#include "ixcompiler.String.h"
#include "todo.h"

struct _Arguments
{
    bool         dryRun;
    const char*  outputDir;
    const char*  targetLanguage;
    const char** files;
};
```

```c/ixcompiler.Arguments.c
Arguments* Arguments_new( int argc, char** argv )
{
    int index = 0;

    Arguments* self = calloc( 1, sizeof( Arguments ) );
    if ( self )
    {
        self->files = calloc( argc, sizeof( char* ) );

        for ( int i=0; i < argc; i++ )
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

        if ( null == self->outputDir )
        {
            Console_Write( ABORT_NO_OUTPUT_DIR, "" );
            exit( -1 );
        }
    }
    return self;
}
```

```c/ixcompiler.Arguments.c
Arguments* Arguments_free( Arguments** self )
{
    free( (*self)->files );

    free( *self ); *self = 0;

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
        Console_Write( "Implementation error in Arguments_hasFlag - 'argument' must be an ARGUMENT defined constant.", "" );
        exit( -1 );
    }
}
```

```c/ixcompiler.Arguments.c
const char* Arguments_getOption( Arguments* self, const char* argument )
{
    if ( String_Equals( argument, ARGUMENT_DRY_RUN ) )
    {
        Console_Write( "Implementation error in Arguments_getOption - ARGUMENT_DRY_RUN is not valid for this function.", "" );
        exit( -1 );
    }
    else
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
        Console_Write( "Implementation error in Arguments_hasFlag - 'argument' must be an ARGUMENT defined constant.", "" );
        exit( -1 );
    }
}
```

```c/ixcompiler.Arguments.c
FilesIterator* Arguments_filesIterator( Arguments* self )
{
    return FilesIterator_new( self->files );
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

### File

```!include/ixcompiler.File.h
#ifndef IXCOMPILER_FILE_H
#define IXCOMPILER_FILE_H

File* File_new    ( const char* filepath );
File* File_free   ( File** self )         ;
bool  File_canRead( File*  self )         ;
bool  File_exists ( File*  self )         ;

#endif
```

```!c/ixcompiler.File.c
#include <stdlib.h>
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
    return FALSE;
}
```

```c/ixcompiler.File.c
bool File_exists( File* self )
{
    return FALSE;
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
FilesIterator* FilesIterator_free     ( FilesIterator** self )
{
    free( *self ); *self = 0;

    return *self;
}
```

```c/ixcompiler.FilesIterator.c
bool FilesIterator_hasNext( FilesIterator* self )
{
    return (null != self->filepaths[self->next]);
}
```

```c/ixcompiler.FilesIterator.c
File* FilesIterator_next( FilesIterator* self )
{
    if ( FilesIterator_hasNext( self ) )
    {
        return File_new( self->filepaths[self->next++] );
    } else {
        return null;
    }
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
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/limits.h>
#include "ixcompiler.h"
#include "ixcompiler.Path.h"

struct _Path
{
    bool  exists;
    bool  canWrite;
    char* path;
};

static bool  IsFolderAndExists  ( const char* target );
static bool  IsFolderAndCanWrite( const char* target );
static char* FullyQualifiedPath ( const char* target );
```


```c/ixcompiler.Path.c
Path* Path_new( const char* target )
{
    Path* self = calloc( 1, sizeof( Path ) );
    if ( self )
    {
        self->exists   = IsFolderAndExists  ( target );
        self->canWrite = IsFolderAndCanWrite( target );
        self->path     = FullyQualifiedPath ( target );
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

```c/ixcompiler.Path.c
bool IsFolderAndExists( const char* target )
{
    struct stat sb;

    stat( target, &sb );

    switch( sb.st_mode & S_IFMT )
    {
    case S_IFDIR:
        return TRUE;
    
    default:
        return FALSE;
    }
};
```

```c/ixcompiler.Path.c
bool IsFolderAndCanWrite( const char* target )
{
    return (F_OK == access( target, W_OK ));
}
```

```c/ixcompiler.Path.c
char* FullyQualifiedPath ( const char* target )
{
    char* ret = calloc( PATH_MAX, sizeof( char ) );

    if ( '/' == target[0] )
    {
        return strcpy( ret, target );
    }
    else
    {
        getcwd( ret, PATH_MAX );
        int last = strlen( ret );
        if ( '/' != ret[last-1] )
        {
            strcpy( &ret[last++], "/" );
        }
        strcpy( &ret[last], target );
    }

    return ret;
}
```
### String

```!include/ixcompiler.String.h
#ifndef IXCOMPILER_STRING_H
#define IXCOMPILER_STRING_H

bool String_Equals( const char* string1, const char* string2 );

#endif
```

```!c/ixcompiler.String.c
#include <string.h>
#include "ixcompiler.h"
#include "ixcompiler.String.h"
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
### To Do

```!include/todo.h
#ifndef TODO_H
#define TODO_H

AST*           AST_free               ( AST** self)                           ;
Generator*     Generator_new          ( const char* lang )                    ;
Generator*     Generator_free         ( Generator** self )                    ;
int            Generator_writeAST     ( Generator* self, AST*, Path*, File* ) ;
IxParser*      IxParser_new           ( Tokenizer* tokenizer )                ;
AST*           IxParser_parse         ( IxParser* self )                      ;
IxParser*      IxParser_free          ( IxParser** self )                     ;
Tokenizer*     Tokenizer_new          ( File* file )                          ;
Tokenizer*     Tokenizer_free         ( Tokenizer** self )                    ;

#endif
```

```!c/todo.c
#include <stdio.h>
#include "ixcompiler.h"
#include "todo.h"

static void Todo( const char* fn )
{
    fprintf( stderr, "Todo: %s\n", fn );
    fflush( stderr );
}

AST*           AST_free               ( AST** self)                           {  Todo( "AST_free"              ); return null; }
Generator*     Generator_new          ( const char* lang )                    {  Todo( "Generator_new"         ); return null; }
Generator*     Generator_free         ( Generator** self )                    {  Todo( "Generator_free"        ); return null; }
int            Generator_writeAST     ( Generator* self, AST*, Path*, File* ) {  Todo( "Generator_writeAST"    ); return null; }
IxParser*      IxParser_new           ( Tokenizer* tokenizer )                {  Todo( "IxParser_new"          ); return null; }
AST*           IxParser_parse         ( IxParser* self )                      {  Todo( "IxParser_parse"        ); return null; }
IxParser*      IxParser_free          ( IxParser** self )                     {  Todo( "IxParser_free"         ); return null; }
Tokenizer*     Tokenizer_new          ( File* file )                          {  Todo( "Tokenizer_new"         ); return null; }
Tokenizer*     Tokenizer_free         ( Tokenizer** self )                    {  Todo( "Tokenizer_free"        ); return null; }
```
