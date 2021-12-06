
.. Node

~!include/ixcompiler.Node.h~
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
~


~!c/ixcompiler.Node.c~
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
~

~c/ixcompiler.Node.c~
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
~

~c/ixcompiler.Node.c~
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
~

~c/ixcompiler.Node.c~
void Node_setParent( Node* self, const Node* parent )
{
    self->parent = parent;
}
~

~c/ixcompiler.Node.c~
void Node_addChild( Node* self, Token** token )
{
    Node* child = Node_new( token );

    Array_push( self->children, (void**) &child );
}
~

~c/ixcompiler.Node.c~
const Token* Node_getToken( const Node* self )
{
    return self->token;
}
~

~c/ixcompiler.Node.c~
bool Node_hasChildren( const Node* self )
{
    return (0 < Array_length( self->children ));
}
~

~c/ixcompiler.Node.c~
NodeIterator* Node_iterator( const Node* self )
{
    return NodeIterator_new( self->children );
}
~

~c/ixcompiler.Node.c~
Node* Node_getLastChild( Node* self )
{
    int last = Array_length( self->children ) - 1;

    return (Node*) Array_getObject( self->children, last );
}
~
