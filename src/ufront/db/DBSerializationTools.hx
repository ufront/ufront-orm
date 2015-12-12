package ufront.db;

#if macro
import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.Type;
import haxe.macro.Expr;
using tink.MacroApi;
using tink.CoreApi;
#else
import ufront.db.Object;
#end

/**
This class provides two alias methods for `DBSerializationTools.with()`.

Even though `DBSerializationTools.with()` works with iterables, when you are using it as a mixin (`using ufront.db.DBSerializationTools`), it only takes effect on single objects.

This class provides alias so that you can just as easily write either `User.manager.get(1).with(groups)` or  `User.manager.all().with(groups)`.
**/
class DBIterableSerializationTools {
	/**
	An alias for `DBSerializationTools.with()`.

	This method allows the `with()` mixin to work with `Iterable<ufront.db.Object>` rather than just `ufront.db.Object`.

	@param iter A collection of objects.
	@param properties The details of which properties to include in serialization. See `DBSerializationTools` for details on the syntax.
	@return The original iterable, after each object's `hxSerializationFields` array has been updated.
	**/
	public static macro function with( iter:ExprOf<Iterable<Object>>, properties:Array<Expr> ):Expr {
		return DBSerializationTools.processWithCall( iter, properties );
	}

	/**
	An alias of `DBIterableSerializationTools.with()`, for those who prefer a more descriptive method name.
	**/
	public static macro function setSerializationFields( iter:ExprOf<Iterable<Object>>, properties:Array<Expr> ):Expr {
		return DBSerializationTools.processWithCall( iter, properties );
	}
}

/**
DBSerializationTools provides a macro helper to quickly and safely change which fields will be included when the object is serialized.

This is particularly useful when using remoting APIs in Ufront-MVC, where database objects on the server will be serialized and sent to the client.
You can specify with clarity exactly which properties should be included when sent to the client.

These macros work by changing the values in `ufront.db.Object.hxSerializationFields`, but add a much more concise syntax and type safety guarantees.

### Usage

```haxe
using ufront.db.DBSerializationTools;

// Get a specific user, with their related groups and permissions.
var users = User.manager.get( id ).with( groups, userPermissions );

// Get a specific user, without their sensitive data
var user = User.manager.get( id ).with( -salt, -password );

// Get a specific user, with their related groups and permissions, but without their sensitive data
var user = User.manager.get( id ).with( groups, userPermissions, -salt, -password );

// Now with a list of all users.
var users = User.manager.all().with( groups, userPermissions, -salt, -password );

// What if we want the groups, and the group permissions?
var users = User.manager.all().with( groups=>[permissions], userPermissions );

// And what about the other users in the groups?
var users = User.manager.all().with( groups=>[permissions,users] );

// And if we want to hide sensitive data for those other users?
var users = User.manager.all().with( groups=>[permissions,users=>[-salt,-password]] );;

// What if we want to only include the user names?
// We use the `[]` to signify we are emptying the existing fields, so they won't be serialized.
var users = User.manager.all().with( [], username );

// The same applies to sub-properties
var users = User.manager.all().with( groups=>[ [], "name" ] );

// It can get quite complex (though still easier than editing hxSerializationFields manually!):
var authorPosts = BlogPost.manager.search( $author==authorID ).with(
	tags=>[ name, url, posts=[[]] ], // Get all the related tags. We also get the posts in those tags, but without any data - so we can just get the length.
	author=>[ fullName, bio, avatarUrl, user=>[[],username] ], // Get the author's profile, and their user object (but only the username)
	title, url, intro, headerImageUrl, id, created, modified, // And then some content we want
	-fullText, // And some we don't want

	// This one is interesting: because above we include tags, and it gets added to our hxSerializationFields.
	// But then we loop through all of the posts in those tags, and empty the related hxSerializationFields.
	// This means we end up getting rid of the "tags" field we just added. So we can add it again.
	// If anyone has a good solution to avoid this problem of recursive changes, let us know!
	// (Possibly ordering the macro expressions so that "deep" changes occur before "shallow" changes?)
	tags
);
```

The macro will always return the object it began with, after making the necessary changes to each `hxSerializationFields` array.
**/
class DBSerializationTools {
	/**
	Change the fields that will be included when the object is serialized.

	@param iter A ufront DB object.
	@param properties The details of which properties to include in serialization. See the class documentation above for details on the syntax.
	@return The original object, after its `hxSerializationFields` array has been updated.
	**/
	public static macro function with( obj:ExprOf<Object>, properties:Array<Expr> ):Expr {
		return processWithCall( obj, properties );
	}

	/**
	An alias of `DBSerializationTools.with()`, for those who prefer a more descriptive method name.
	**/
	public static macro function setSerializationFields( obj:ExprOf<Object>, properties:Array<Expr> ):Expr {
		return processWithCall( obj, properties );
	}

	#if macro
	/**
	The internal expression transformation macro used by both `DBSerializationTools` and `DBIterableSerializationTools`.
	**/
	public static function processWithCall( obj:Expr, properties:Array<Expr> ):Expr {
		var lines = DBSerializationTools.process( obj, obj, properties, [macro var __obj = $obj] );
		lines.push( macro __obj );
		return macro @:pos(obj.pos) $b{lines};
	}

	static function processObject( obj:Expr, typedExpr:Expr, properties:Array<Expr>, blockExpressions:Array<Expr> ):Array<Expr> {
		var fields = macro @:pos(obj.pos) $obj.hxSerializationFields;
		function addField( propertyName:String ) {
			var expr = macro if ($fields.indexOf($v{propertyName})==-1) $fields.push( $v{propertyName} );
			blockExpressions.push( expr );
		}
		function removeField( propertyName:String ) {
			var expr = macro while ($fields.indexOf($v{propertyName})>-1) $fields.remove( $v{propertyName} );
			blockExpressions.push( expr );
		}
		for ( p in properties ) {
			switch p {
				case macro []:
					blockExpressions.push( macro $fields = [] );
				case macro $i{propertyName}:
					// Ensure the property exists (this will throw a compiler error if not).
					Context.typeof( macro @:pos(obj.pos) $typedExpr.$propertyName );
					addField( propertyName );
				case macro -$i{propertyName}:
					Context.typeof( macro @:pos(obj.pos) $typedExpr.$propertyName );
					removeField( propertyName );
				case macro $i{propertyName}=>$a{subProperties}:
					var property = macro @:pos(obj.pos) $obj.$propertyName;
					var typedProperty = macro @:pos(obj.pos) $typedExpr.$propertyName;
					addField( propertyName );
					process( property, typedProperty, subProperties, blockExpressions );
				case _:
					p.reject( 'Could not understand property name ${p.toString()}' );
			}
		}
		return blockExpressions;
	}

	static function processObjects( iterable:Expr, typedIterable:Expr, properties:Array<Expr>, blockExpressions:Array<Expr> ):Array<Expr> {
		var ident = macro __obj;
		var typeExpr = macro $typedIterable.iterator().next();
		var lines = processObject( ident, typeExpr, properties, [] );
		var block = macro $b{lines};
		var loopExpr = macro for ($ident in $iterable) $block;
		blockExpressions.push( loopExpr );
		return blockExpressions;
	}

	static function process( expr:Expr, typedProp:Expr, properties:Array<Expr>, blockExpressions:Array<Expr> ):Array<Expr> {
		var exprType = Context.typeof( typedProp );
		var objectType = (macro :ufront.db.Object).toType().sure();
		var iterableType = (macro :Iterable<ufront.db.Object>).toType().sure();

		if ( Context.unify(exprType, objectType) ) {
			return processObject( expr, typedProp, properties, blockExpressions );
		}
		else if ( Context.unify(exprType,iterableType) ) {
			return processObjects( expr, typedProp, properties, blockExpressions );
		}
		else {
			return expr.reject( '${expr.toString()} was not a `ufront.db.Object` or `Iterable<ufront.db.Object>`' );
		}
	}
	#end
}
