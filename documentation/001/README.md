
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

    Path_free         ( &output_path );
    Arguments_free    ( &args );
    FilesIterator_free( &files );

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

#define ABORT_DIRECTORY_DOES_NOT_EXIST      "Aborting, output directory does not exist - %s"
#define ABORT_DIRECTORY_IS_NOT_WRITABLE     "Aborting, cannot write to output directory - %s"
#define ABORT_TARGET_LANGUAGE_NOT_SUPPORTED "Aborting, could not find generator for target language - %s"

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

typedef struct _Arguments Arguments;

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
#include "todo.h"

struct _Arguments
{
    bool        dryRun;
    const char* outputDir;
    const char* targetLanguage;
};
```

```c/ixcompiler.Arguments.c
Arguments* Arguments_new( int argc, char** argv )
{
    Arguments* self = calloc( 1, sizeof( Arguments ) );
    if ( self )
    {
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
        }
    }
    return self;
}
```

```c/ixcompiler.Arguments.c
Arguments* Arguments_free( Arguments** self )
{
    free( *self );
    self = 0;
    return null;
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
FilesIterator* Arguments_filesIterator( Arguments* self )                     { return null; }
```.. To Do

```!include/todo.h
#ifndef TODO_H
#define TODO_H

AST*           AST_free               ( AST** self)                           ;
void           Console_Write          ( const char*, const char* )            ;
bool           File_canRead           ( File* self )                          ;
bool           File_exists            ( File* self )                          ;
File*          File_free              ( File** self )                         ;
FilesIterator* FilesIterator_free     ( FilesIterator** self )                ;
bool           FilesIterator_hasNext  ( FilesIterator* self )                 ;
File*          FilesIterator_next     ( FilesIterator* self )                 ;
Generator*     Generator_new          ( const char* lang )                    ;
Generator*     Generator_free         ( Generator** self )                    ;
int            Generator_writeAST     ( Generator* self, AST*, Path*, File* ) ;
IxParser*      IxParser_new           ( Tokenizer* tokenizer )                ;
AST*           IxParser_parse         ( IxParser* self )                      ;
IxParser*      IxParser_free          ( IxParser** self )                     ;
Path*          Path_new               ( const char* target )                  ;
Path*          Path_free              ( Path** self )                         ;
bool           Path_exists            ( Path* self )                          ;
bool           Path_canWrite          ( Path* self )                          ;
bool           String_Equals          ( const char*, const char* )            ;
Tokenizer*     Tokenizer_new          ( File* file )                          ;
Tokenizer*     Tokenizer_free         ( Tokenizer** self )                    ;

#endif
```

```!c/todo.c
#include "ixcompiler.h"
#include "todo.h"

AST*           AST_free               ( AST** self)                           { return null; }
void           Console_Write          ( const char*, const char* )            {}
bool           File_canRead           ( File* self )                          { return null; }
bool           File_exists            ( File* self )                          { return null; }
File*          File_free              ( File** self )                         { return null; }
FilesIterator* FilesIterator_free     ( FilesIterator** self )                { return null; }
bool           FilesIterator_hasNext  ( FilesIterator* self )                 { return null; }
File*          FilesIterator_next     ( FilesIterator* self )                 { return null; }
Generator*     Generator_new          ( const char* lang )                    { return null; }
Generator*     Generator_free         ( Generator** self )                    { return null; }
int            Generator_writeAST     ( Generator* self, AST*, Path*, File* ) { return null; }
IxParser*      IxParser_new           ( Tokenizer* tokenizer )                { return null; }
AST*           IxParser_parse         ( IxParser* self )                      { return null; }
IxParser*      IxParser_free          ( IxParser** self )                     { return null; }
Path*          Path_new               ( const char* target )                  { return null; }
Path*          Path_free              ( Path** self )                         { return null; }
bool           Path_exists            ( Path* self )                          { return null; }
bool           Path_canWrite          ( Path* self )                          { return null; }
bool           String_Equals          ( const char*, const char* )            { return 0;    }
Tokenizer*     Tokenizer_new          ( File* file )                          { return null; }
Tokenizer*     Tokenizer_free         ( Tokenizer** self )                    { return null; }
```
