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

class ManyToMany<A:Object, B:Object>
{
	var a:Class<A>;
	var b:Class<B>;
	var aObject:A;
	var bList:List<B>;
	var bListIDs:List<Int>;

	public var length(get,null):Int;

	#if server
		var tableName:String;
		static var managers:StringMap<Manager<Relationship>> = new StringMap();
		var bManager:Manager<B>;
		var manager:Manager<Relationship>;
	#end

	public function new(aObject:A, bClass:Class<B>, ?initialise=true)
	{
		this.aObject = aObject;
		#if server
			this.a = Type.getClass(aObject);
			this.b = bClass;
			bManager = untyped b.manager;
			this.tableName = generateTableName(a,b);
			this.manager = getManager(tableName);
			if (initialise) refreshList();
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
		static function getManager(tableName:String):Manager<Relationship>
		{
			var m;
			if (managers.exists(tableName))
			{
				m = managers.get(tableName);
			}
			else
			{
				#if php
					// haxe.rtti.Meta.getType(Relationship);
					// throw "Up to this point";
				#end
				m = new Manager(Relationship);
				m.table_name = tableName;
				managers.set(tableName, m);
			}
			return m;
		}

		static function isABeforeB(a,b)
		{
			// Get the names (class name, last section after package list)
			var aName = Type.getClassName(a).split('.').pop();
			var bName = Type.getClassName(b).split('.').pop();
			var arr = [aName,bName];
			arr.sort(function(x,y) return Reflect.compare(x,y));
			return (arr[0] == aName);
		}

		static public function generateTableName(a:Class<Dynamic>, b:Class<Dynamic>)
		{
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
			A function to create a join table for two classes.
		**/
		public static function createJoinTable( aModel:Class<Object>, bModel:Class<Object> ) {
			var tableName = generateTableName( aModel, bModel );
			var manager = getManager( tableName );
			if ( TableCreate.exists(Relationship.manager)==false )
				TableCreate.create( Relationship.manager );
		}

		@:access(sys.db.Manager)
		public function refreshList()
		{
			if (aObject != null)
			{
				var id = aObject.id;
				var bTableName = bManager.table_name;
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				var bColumn = (isABeforeB(a,b)) ? "r2" : "r1";

				bList = bManager.unsafeObjects('SELECT `$bTableName`.* FROM `$tableName` JOIN `${bManager.table_name}` ON $tableName.$bColumn=$bTableName.id WHERE $tableName.$aColumn=${Manager.quoteAny(id)} ORDER BY $tableName.modified ASC', false);
				bListIDs = bList.map(function (b:B) return b.id);
			}
		}
	#end


	/** Add a related object by creating a new Relationship on the appropriate join table.
	If the object you are adding does not have an ID, insert() will be called so that a valid
	ID can be obtained. */
	@:access( sys.db.Manager )
	public function add(bObject:B)
	{
		if (bObject != null && bList.has(bObject) == false)
		{
			bList.add(bObject);

			#if server
				if (bObject.id == null) bObject.insert();

				var r = if (isABeforeB(a,b)) new Relationship(aObject.id, bObject.id);
						else                 new Relationship(bObject.id, aObject.id);

				getManager(tableName).doInsert(r);
			#end
		}
	}

	public function remove(bObject:B)
	{
		if (bObject != null)
		{
			bList.remove(bObject);

			#if server
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				var bColumn = (isABeforeB(a,b)) ? "r2" : "r1";

				// manager.delete($a == aObject.id && $b == bObject.id);
				manager.unsafeDelete("DELETE FROM `" + tableName + "` WHERE " + aColumn + " = " + Manager.quoteAny(aObject.id) + " AND " + bColumn + " = " + Manager.quoteAny(bObject.id));
			#end
		}
	}

	public function clear()
	{
		bList.clear();
		#if server
			if (aObject != null)
			{
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				// manager.delete($a == aObject.id);
				manager.unsafeDelete("DELETE FROM `" + tableName + "` WHERE " + aColumn + " = " + Manager.quoteAny(aObject.id));
			}
		#end
	}

	public function setList(newBList:Iterable<B>)
	{
		// Get rid of old ones
		for (oldB in bList)
		{
			if (newBList.has(oldB) == false) remove(oldB);
		}
		// And add new ones
		for (b in newBList)
		{
			add (b);
		}
	}

	public function pop():B
	{
		var bObject = bList.pop();
		if (bObject != null && aObject != null)
		{

			#if server
				var aColumn = (isABeforeB(a,b)) ? "r1" : "r2";
				var bColumn = (isABeforeB(a,b)) ? "r2" : "r1";

				// manager.delete($a == aObject.id && $b == bObject.id);
				manager.unsafeDelete("DELETE FROM `" + tableName + "` WHERE " + aColumn + " = " + Manager.quoteAny(aObject.id) + " AND " + bColumn + " = " + Manager.quoteAny(bObject.id));
			#end
		}

		return bObject;
	}

	public function push(bObject:B)
	{
		add(bObject);
	}

	//
	// Static helpers
	//

	#if server
		/**
			A function to at once retrieve the related IDs of several objects.
			@param aModel The model for the object IDs you have
			@param bModel The model the the related object IDs you want to fetch
			@param aObjectIDs The specific models you want to get.  If not supplied, we'll get a map of ALL manyToMany relationships between these two models.
			@return An IntMap, where the key is aObjectID, and the value is a list of related bObjectIDs
		**/
		public static function relatedIDsforObjects(aModel:Class<Object>, bModel:Class<Object>, ?aObjectIDs:Iterable<SUId>):IntMap<List<Int>>
		{
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
			for (r in relationships)
			{
				var aID = (aBeforeB) ? r.r1 : r.r2;
				var bID = (aBeforeB) ? r.r2 : r.r1;

				var list = intMap.get(aID);
				if (list == null) intMap.set(aID, list = new List());

				list.add(bID);
			}

			return intMap;
		}
	#end

	//
	// Private
	//

	inline function get_length()
	{
		return bList.length;
	}
}


