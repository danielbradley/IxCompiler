
.. Tree

~!include/ixcompiler.Tree.h~
#ifndef IXCOMPILER_TREE_H
#define IXCOMPILER_TREE_H

#include "ixcompiler.h"

Tree* Tree_new();
Tree* Tree_free   ( Tree** self );
void  Tree_setRoot( Tree*  self, Node** node );

const Node* Tree_getRoot( const Tree* self );

#endif
~

~!c/ixcompiler.Tree.c~
#include "ixcompiler.h"
#include "ixcompiler.Node.h"
#include "ixcompiler.Platform.h"
#include "ixcompiler.Tree.h"

struct _Tree
{
    Node* root;
};
~

~c/ixcompiler.Tree.c~
Tree* Tree_new()
{
    Tree* self = Platform_Alloc( sizeof( Tree ) );
    return self;
}
~

~c/ixcompiler.Tree.c~
Tree* Tree_free( Tree** self )
{
    if ( *self )
    {
        Node_free( &(*self)->root );
        Platform_Free( self );
    }
    return *self;
}
~

~c/ixcompiler.Tree.c~
void Tree_setRoot( Tree* self, Node** node )
{
    self->root = *node; *node = null;
}
~

~c/ixcompiler.Tree.c~
const Node* Tree_getRoot( const Tree* self )
{
    return self->root;
}
~
