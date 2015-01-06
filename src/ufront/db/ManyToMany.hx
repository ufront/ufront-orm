package ufront.db;

#if server
	import sys.db.Manager;
	import sys.db.TableCreate;
#end
import sys.db.Types;
import ufront.db.Object;
import ufront.db.Relationship;
import haxe.ds.*;
using Lambda;
using tink.CoreApi;

// Note:
// Throughout this class, I've had to replace SPOD macro calls with the "unsafe" runtime calls.
// The reason for this is that the macro versions hardcode the table name into the query - and so
// they always use the "Relationship" table, rather than our custom table names for each join.
// In the code, I've left the macro line above the "unsafe" line, but commented out, so that
// you can see essentially what it is that we're trying to do.

// Note 2:
// On the server side, this class does all the expected database interactions.  On the client side
// it really does little more than keep a list of <B> objects.  When we send the ManyToMany object
// back to the server, the list will be sent back in-tact, so we can manipulate it, save it to the DB etc.

/**
An object used to join two tables/models with a Many-to-Many relationship.

A ManyToMany relationship is one where two models are joined but there's no obvious `BelongsTo` relationship - each object can be related to many others on each side.

Examples include:

- Blog Posts and Tags (each blog post can have many tags, each tag can have many blog posts)
- Users and Groups (each user can have many groups, each group can have many users)
- Projects and Staff (each project can have many staff assigned to it, each staff member could be assigned to one or more projects)
- Students and Classes, etc.

The join table follows the `Relationship` schema, but uses a different name for each join type.
The naming convention for join tables is `_join_$firstClass_$secondClass` where the class names are sorted alphabetically.

A current limitation is that you can only have one ManyToMany join table between each combination of models.
For example, you cannot have two properties `teachers:ManyToMany<Teacher,Class>` and `assistantTeachers:ManyToMany<Teacher,Class>` - they will both use the same join table.

The `ManyToMany` class has some static helpers for:

- `ManyToMany.generateTableName` Generating a join table name from two classes
- `ManyToMany.createJoinTable` Creating the join table in the database, if it does not exist
- `ManyToMany.relatedIDsforObjects` Getting the related IDs for a particular set of object

The `ManyToMany` object is used to find the related IDs for a particular object:

```haxe
var joins = new ManyToMany( myUser, Group );
for ( group in joins ) {
	trace( group );
}
joins.add( someNewGroup );
```

If in your models you specify a `ManyToMany` property, the build macro will automatically take care of constructing the `ManyToMany` object for you:

```haxe
// Please note the ordering of the two type parameters: you always do the current model first, the related model second.
class User {
	var groups:ManyToMany<User,Group>;
}
class Group {
	var users:ManyToMany<Group,User>;
}

function () {
	for ( group in myUser.groups ) {
		trace( '$myUser is in the group $group' );
		trace( 'The other people in that group are: '+group.users.join(", ") );
	}
}
```

Please note that on the server, SQL queries are executed immediately - if you `this.add()` a related object, it will insert the join row immediately.
This means that all of your related objects must be saved and have a valid ID before you start creating joins.

When you first create a ManyToMany object, it will fetch the list of related objects if `initialise` is true.
If you're accessing the joins through a model's `ManyToMany` property, the first time you call the getter it will fetch the list.

On the client, none of the SQL queries are executed, but the ManyToMany object can be serialized and shared between client and server.
This means you can serialize an object on the server with it's joins, and unserialize it on the client with the relationships in tact.
Making changes to the ManyToMany object on the client, such as adding another related object, will have no effect on the database.
**/
class ManyToMany<A:Object, B:Object> {
	var a:Class<A>;
	var b:Class<B>;
	var aObject:A;
	var bList:List<B>;
	var bListIDs:List<Int>;
	var unsavedBObjects:Null<List<B>>;

	/** The number of related objects. **/
	public var length(get,null):Int;

	#if server
		static var managers:StringMap<Manager<Relationship>> = new StringMap();
		var tableName:String;
		var bManager:Manager<B>;
		var manager:Manager<Relationship>;
	#end

	/**
		Create a new `ManyToMany` object for managing related objects between `aObject` and `bClass`.

		@param aObject - The current object. If `aObject` is null an exception will be thrown.
		@param bClass - The model of related objects you are joining with.
		@param initialise - Whether to fetch the current list of related objects immediately (server only, default is true).
	**/
	public function new(aObject:A, bClass:Class<B>, ?initialise=true) {
		if ( aObject==null )
			throw 'Error creating ManyToMany: aObject must not be null';
		
		this.aObject = aObject;
		this.b = bClass;
		#if server
			this.a = Type.getClass(aObject);
			bManager = untyped bClass.manager;
			this.tableName = generateTableName(a,b);
			this.manager = getManager(tableName);
			this.unsavedBObjects = new List();
			if (initialise) {
				refreshList();
			}
			else {
				this.bList = new List();
				this.bListIDs = new List();
			} 
		#else
			this.bList = new List();
			this.bListIDs = new List();
			this.unsavedBObjects = new List();
		#end
	}

	public inline function first() return bList.first();
	public inline function isEmpty() return bList.isEmpty();
	public inline function join(sep) return bList.join(sep);
	public inline function last() return bList.last();
	public inline function iterator() return bList.iterator();
	public inline function filter(predicate) return bList.filter(predicate);
	public inline function map(fn) return bList.map(fn);
	public inline function toString() return bList.toString();

	#if server
		@:access(sys.db.Manager)
		static function getManager(tableName:String):Manager<Relationship> {
			var m;
			if (managers.exists(tableName)) {
				m = managers.get(tableName);
			}
			else {
				// PHP requires us to explicitly call Relationship.manager for the metadata to be included in compilation.
				// We don't have to (or want to) do anything with it, just make sure the metadata is attached to the Relationship object.
				#if php
					Relationship.manager;
				#end
				m = new Manager(Relationship);
				m.table_infos.name = tableName;
				m.table_name = m.quoteField(tableName);
				managers.set(tableName, m);
			}
			return m;
		}

		static function isABeforeB(a,b) {
			// Get the names (class name, last section after package list)
			var aName = Type.getClassName(a).split('.').pop();
			var bName = Type.getClassName(b).split('.').pop();
			var arr = [aName,bName];
			arr.sort(function(x,y) return Reflect.compare(x,y));
			return (arr[0] == aName);
		}

		/**
			Generate the table name used to join these two classes.
		**/
		static public function generateTableName(a:Class<Dynamic>, b:Class<Dynamic>) {
			// Get the names (class name, last section after package list)
			var aName = Type.getClassName(a).split('.').pop();
			var bName = Type.getClassName(b).split('.').pop();

			// Sort the names alphabetically, so we don't end up with 2 join tables...
			var arr = [aName,bName];
			arr.sort(function(x,y) return Reflect.compare(x,y));

			// Join the names - eg join_SchoolClass_Student
			arr.unshift("_join");
			return arr.join('_');
		}
		
		/**
			Create a join table for the two classes if it does not exist already.
		**/
		public static function createJoinTable( aModel:Class<Object>, bModel:Class<Object> ) {
			var tableName = generateTableName( aModel, bModel );
			var manager = getManager( tableName );
			if ( TableCreate.exists(manager)==false )
				TableCreate.create( manager );
		}

		/**
			A function to at once retrieve the related IDs of several objects.
			
			@param aModel The model for the object IDs you have
			@param bModel The model the the related object IDs you want to fetch
			@param aObjectIDs The specific models you want to get.  If not supplied, we'll get a map of ALL manyToMany relationships between these two models.
			@return An IntMap, where the key is aObjectID, and the value is a list of related bObjectIDs
		**/
		public static function relatedIDsforObjects(aModel:Class<Object>, bModel:Class<Object>, ?aObjectIDs:Iterable<SUId>):IntMap<List<Int>> {
			// Set up
			var aBeforeB = isABeforeB(aModel,bModel);
			var tableName = generateTableName(aModel,bModel);
			var manager = getManager(tableName);
			var aColumn = (aBeforeB) ? "r1" : "r2";

			// Fetch the relationships
			var relationships;
			if (aObjectIDs == null)
				relationships = manager.all();
			else
				relationships = manager.unsafeObjects("SELECT * FROM `" + tableName + "` WHERE " + Manager.quoteList(aColumn, aObjectIDs) + " ORDER BY modified ASC", false);

			// Put them into an Intmap
			var intMap = new IntMap<List<Int>>();
			for (r in relationships) {
				var aID = (aBeforeB) ? r.r1 : r.r2;
				var bID = (aBeforeB) ? r.r2 : r.r1;
				var list = intMap.get(aID);
				if (list == null) intMap.set(aID, list = new List());
				list.add(bID);
			}
			return intMap;
		}

		/**
			Fetch the related objects from the database.
			If `aObject` does not have an ID, then it will just have an empty list for now.
			Any outstanding operations (`add` or `remove` operations that have not yet been committed to the database) will be lost.
		**/
		@:access(sys.db.Manager)
		public function refreshList() {
			unsavedBObjects.clear();
			if ( aObject.id!=null ) {
				var id = aObject.id;
				var bTableName = bManager.table_name; // Already has quotes.
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				var bColumn = (isABeforeB(a,b)) ? "r2" : "r1";
				bList = bManager.unsafeObjects('SELECT $bTableName.* FROM `$tableName` JOIN $bTableName ON `$tableName`.$bColumn=$bTableName.id WHERE `$tableName`.$aColumn=${Manager.quoteAny(id)} ORDER BY $tableName.modified ASC', false);
				bListIDs = bList.map(function (b:B) return b.id);
			}
			else {
				bList = new List();
				bListIDs = new List();
			}
		}

		/**
			This private function is used when a ManyToMany getter is accessed, and it has a null bList, but it has bListIDs and/or unsavedBObjects.
			This happens for instance if the object was serialized and unserialized (via remoting for example).
			This will perform a query to load the bList given the current IDs.
		**/
		function compileBList() {
			var bTableName = @:privateAccess bManager.table_name; // Already has quotes.
			if ( bListIDs!=null )
				// bList = bManager.search( $id in bListIDs );
				bList = bManager.unsafeObjects( 'SELECT * FROM $bTableName WHERE '+Manager.quoteList('id',bListIDs), false );
			else
				bList = new List();
			
			for ( newObj in unsavedBObjects ) {
				this.bList.add( newObj );
			}
		}
		
		/**
			Resolves any differences between the joins represented here and the joins in the database.
			Most actions (`add`, `remove`, `setList` etc) apply to the database immediately if a) we're on the server and b) both objects have an ID.
			If one of the joint objects is unsaved, or if we're on the client, then we might have a situation where our list here is out of sync with our list on the server.
			Calling this will add or remove joins from the database to match our current state.
			Please note if some of your objects are *still* unsaved, they will still remain unsaved.
		**/
		public function commitJoins() {
			setList( bList.list() );
			unsavedBObjects.clear();
		}
	#end

	/**
		Add a related object by creating a new Relationship on the appropriate join table.
		If either aObject or bObject have no ID, we will add them to our local list, and they will be updated when saving.
		If the object already has a relationship in the join table, it will be ignored.
	**/
	@:access( sys.db )
	public function add(bObject:B) {
		if (bObject!=null && bList.has(bObject)==false) {
			bList.add(bObject);
			var server = #if server true #else false #end;
			if (server && aObject.id!=null && bObject.id!=null) {
				#if server
					var r = if (isABeforeB(a,b)) new Relationship(aObject.id, bObject.id);
							else                 new Relationship(bObject.id, aObject.id);
					getManager(tableName).doInsert(r);
					unsavedBObjects.remove(bObject);
				#end
			}
			else {
				function reAdd() {
					if ( unsavedBObjects.has(bObject) ) {
						bList.remove( bObject );
						add( bObject );
					}
				}
				aObject.saved.handle( reAdd );
				bObject.saved.handle( reAdd );
				if ( unsavedBObjects.has(bObject)==false )
					unsavedBObjects.add( bObject );
			}
		}
	}

	/**
		Remove the relationship/join between our `aObject` and a particular `bObject`.
		
		If `bObject` is null this will have no effect.
		If `aObject` or `bObject` have no ID, then the `bObject` will be removed from the local list, but no database query will be executed.
	**/
	public function remove(bObject:B) {
		if (bObject!=null) {
			bList.remove(bObject);
			#if server
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				var bColumn = (isABeforeB(a,b)) ? "r2" : "r1";
				if ( aObject.id!=null && bObject.id!=null ) {
					// manager.delete($a == aObject.id && $b == bObject.id);
					manager.unsafeDelete("DELETE FROM `" + tableName + "` WHERE " + aColumn + " = " + Manager.quoteAny(aObject.id) + " AND " + bColumn + " = " + Manager.quoteAny(bObject.id));
				}
				else {
					// Because one of the IDs was null, the joins were never saved, so we don't have to clear them.
				}
			#end
		}
	}

	/**
		Remove all relationships between our `aObject` and any `bObjects`.
		If our `aObject` has no id, then no database call will be made.
	**/
	public function clear() {
		bList.clear();
		unsavedBObjects.clear();
		#if server
			if ( aObject.id!=null ) {
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				// manager.delete($a == aObject.id);
				manager.unsafeDelete("DELETE FROM `" + tableName + "` WHERE " + aColumn + " = " + Manager.quoteAny(aObject.id));
			}
			else {
				// Because aObject was never saved, the joins were never saved, so we don't have to clear them.
			}
		#end
	}

	/**
		Set the list of related B objects.
		Any objects that were not previously related will have a relationship added with `this.add()`
		Any objects that were previously related and are in `newBList` will not be affected.
		Any objects that were previously related and are not in `newBList` will have `this.remove()` called so they are no longer related.
	**/
	public function setList(newBList:Iterable<B>) {
		// Get rid of old ones
		for (oldB in bList) {
			if (newBList.has(oldB)==false)
				remove(oldB);
		}
		// And add new ones
		for (b in newBList) {
			add(b);
		}
	}

	//
	// Private
	//

	inline function get_length() {
		return bList.length;
	}
}


