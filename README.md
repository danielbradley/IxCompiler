
## Introduction
## Design
## Implementation

```
ixcompiler --target _gen/c --target-language C [--dry-run]
```

```!include/ixcompiler.h
//
// Copyright 2021 Daniel Robert Bradley
//

#ifndef _ixcompiler_h_
#define _ixcompiler_h_

#define ABORT_PATH_EXISTS "Aborting, target path does not exist - %s"
#define ABORT_PATH_WRITE  "Aborting, cannot write to target path - %s"
#define ABORT_TARGET_LANG "Aborting, could not find generator for targuet language - %s"

#define TARGET          "--target"
#define TARGET_LANGUAGE "--target_language"
#define DRY_RUN         "--dry_run"

#ifndef bool
#define bool int
#endif

#ifndef null
#define null 0
#endif

#endif
```

```!c/main.c
//
//  Copyright 2021 Daniel Robert Bradley
//

#include <stdlib.h>
#include "ixcompiler.h"
#include "todo.h"

int main( int argc, char** argv )
{
    int            status      = 1;
    Arguments*     args        = Arguments_new( argc, argv );
    FilesIterator* files       = Arguments_filesIterator( args );
    const char*    target_lang = Arguments_getOption( TARGET_LANGUAGE );
    const char*    target      = Arguments_getOption( TARGET );
    Path*          target_path = Path_new( target );
    bool           dry_run     = Arguments_hasFlag( DRY_RUN );

    if ( !Path_exists( target_path ) )
    {
        Console_Write( ABORT_PATH_EXISTS, target );
        exit( -1 );
    }
    else
    if ( !Path_canWrite( target_path ) )
    {
        Console_Write( ABORT_PATH_WRITE, target );
        exit( -1 );
    }
    else
    {
        Generator* generator = Generator_new( target_lang );

        if ( !generator )
        {
            Console_Write( ABORT_TARGET_LANG, target_lang );
        }
        else
        {
            while ( FilesIterator_hasNext( files ) )
            {
                File* file = FilesIterator_next( files );

                if ( File_exists( file ) && File_canRead( file ) )
                {
                    Tokenizer* tokenizer = Tokenizer_new( file );
                    IxParser*  parser    = IxParser_new( tokenizer );
                    AST*       ast       = IxParser_parse( parser );

                    if ( !dry_run )
                    {
                        status &= Generator_writeAST( generator, ast, target_path, file );
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

    Path_free( &target_path );
    Arguments_free( &args );
    FilesIterator_free( &files );

    return !status;
}
```

```!include/todo.h
#ifndef _todo_h_
#define _todo_h_

typedef void Arguments;
typedef void AST;
typedef void File;
typedef void FilesIterator;
typedef void Generator;
typedef void IxParser;
typedef void Path;
typedef void Tokenizer;

AST*           AST_free               ( AST* self)                            { return null; }
Arguments*     Arguments_new          ( int argc, char** argv )               { return null; }
Arguments*     Arguments_free         ( Arguments* self )                     { return null; }
bool           Arguments_hasFlag      ( Arguments* self )                     { return null; }
const char*    Arguments_getOption    ( Arguments* self )                     { return null; }
FilesIterator* Arguments_filesIterator( Arguments* self )                     { return null; }
void           Console_Write          ( const char*, const char* )            {}
bool           File_canRead           ( File* self )                          { return null; }
bool           File_exists            ( File* self )                          { return null; }
File*          File_free              ( File* self )                          { return null; }
FilesIterator* FilesIterator_free     ( FilesIterator* self )                 { return null; }
bool           FilesIterator_hasNext  ( FilesIterator* self )                 { return null; }
File*          FilesIterator_next     ( FilesIterator* self )                 { return null; }
Generator*     Generator_new          ( const char* lang )                    { return null; }
Generator*     Generator_free         ( Generator* self )                     { return null; }
int            Generator_writeAST     ( Generator* self, AST*, Path*, File* ) { return null; }
IxParser*      IxParser_new           ( Tokenizer* tokenizer )                { return null; }
AST*           IxParser_parse         ( IxParser* self )                      { return null; }
IxParser*      IxParser_free          ( IxParser* self )                      { return null; }
Path*          Path_new               ( const char* target )                  { return null; }
Path*          Path_free              ( Path* self )                          { return null; }
bool           Path_exists            ( Path* self )                          { return null; }
bool           Path_canWrite          ( Path* self )                          { return null; }
Tokenizer*     Tokenizer_new          ( File* file )                          { return null; }
Tokenizer*     Tokenizer_free         ( Tokenizer* self )                     { return null; }

#endif
```