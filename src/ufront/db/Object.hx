package ufront.db;

import sys.db.Types;
import haxe.ds.StringMap;
#if ufront_clientds
	import clientds.Promise;
#end

using StringTools;
using Lambda;
using tink.core.Outcome;

/** Extended Database Object

Builds on sys.db.Object, but adds: a default unique ID (unsigned Int), as well as created and modified timestamps.

Also has methods to keep the timestamps up to date, and a generic "save" method when you're not sure if you need to insert or update.

This class also uses conditional compilation so that the objects can exist on non-server targets that have no 
access to sys.db.*, on these platforms the objects can be created and shared with remoting, and will be able to
save and fetch records through ClientDS.

We tell if it's a server platform by seeing checking for the #server define, so on your neko/php/cpp targets use `-D server`.

Two build macros will be applied to all objects that extends this class:

 * The first, is used to detects HasMany<T>, BelongsTo<T> and ManyToMany<A,B> types and 
sets them up as properties so they are handled correctly.
 * The second adds a "manager:sys.db.Manager" property on the server, or a "clientDS:clientds.ClientDs" property on the
 client, and initialises them.

Validation

override validate()

Security

override checkAuthRead()
override checkAuthWrite()

*/
#if server
	@noTable
#else
	@:keepSub
#end 

@:autoBuild(ufront.db.DBMacros.setupDBObject())
class Object #if server extends sys.db.Object #end
{
	public var id:SUId;
	public var created:SDateTime;
	public var modified:SDateTime;

	#if server
		public function new()
		{
			super();
			validationErrors = new StringMap();
		}

		/** Updates the "created" and "modified" timestamps, and then saves to the database if checkAuthWrite() and validate() both pass. */
		override public function insert()
		{
			if (this.validate())
			{
				if (this.checkAuthWrite())
				{
					this.created = Date.now();
					this.modified = Date.now();
					super.insert();
				}
				else throw 'You do not have permission to save object $this';
			}
			else {
				var errors = Lambda.array(validationErrors).join("\n");
				throw 'Data validation failed for $this: \n' + errors;
			}
		}

		/** Updates the "modified" timestamp, and then saves to the database if checkAuthWrite() and validate() both pass. */
		override public function update()
		{
			if (this.validate())
			{
				if (this.checkAuthWrite())
				{
					this.modified = Date.now();
					super.update();
				}
				else throw 'You do not have permission to save object $this';
			}
			else {
				var errors = Lambda.array(validationErrors).join(", ");
				throw 'Data validation failed for $this: ' + errors;
			}
		}
		
		/** Either updates or inserts the given record into the database, updating timestamps as necessary. 

		If `id` is null, then it needs to be inserted.  If `id` already exists, try to update first.  If that
		throws an error, it means that it is not inserted yet, so then insert it. */
		public function save()
		{
			if (id == null)
			{
				insert();
			}
			else
			{
				try 
				{
					untyped this._lock = true;
					update();
				}
				catch (e:Dynamic)
				{
					// If it failed because of a validation error, rethrow
					if (Std.string(e).indexOf('Data validation failed') != -1) throw e;

					// Error is probably because it had an ID, but it wasn't in the DB... so insert it
					insert();
				}
			}
		}
	
	#else

		#if ufront_clientds
			var _clientDS(default,never) : clientds.ClientDs<Dynamic>;
		#end

		public function new() 
		{
			validationErrors = new StringMap();
			setupClientDs();
		}

		function setupClientDs()
		{
			#if ufront_clientds
				if( _clientDS == null ) untyped _clientDS = Type.getClass(this).clientDS;
			#end
		}

		public function delete() { 
			#if ufront_clientds
				setupClientDs();
				return _clientDS.delete(this.id);
			#end
		}

		public function save() { 
			#if ufront_clientds
				setupClientDs();
				if (validate())
				{
					return _clientDS.save(this);
				}
				else 
				{
					var p = new Promise();
					var errors = Lambda.array(validationErrors).join("\n  ");
					var msg = 'Data validation failed for $this: \n  $errors';
					p.resolve( Failure(msg) );
					return p;
				}
			#end
		}

		public function refresh() { 
			#if ufront_clientds
				setupClientDs();
				return _clientDS.refresh(this.id);
			#end
		}

		public inline function insert() { save(); }
		public inline function update() { save(); }

		#if ufront_clientds
			@:skip var allRelationPromises:Array<Promise<Dynamic>>;
			public function loadRelations():Promise<Object> {
				allRelationPromises = [];
				var relArr:Array<String> = untyped Type.getClass(this).hxRelationships;
				for (relDetails in relArr) {
					var field = relDetails.split(",")[0];
					Reflect.callMethod( this, Reflect.field(this,'get_$field'), [] );
				}
				var p = new Promise();
				Promise.when( allRelationPromises ).then( function(_) { p.resolve(this); return null; } );
				return p;
			}
		#end
	
		public function toString()
		{
			var modelName = Type.getClassName(Type.getClass(this));
			return '$modelName#$id';
		}
	#end

	/** If a call to validate() fails, it will populate this map with a list of errors.  The key should
	be the name of the field that failed validation, and the value should be a description of the error. */
	@:skip public var validationErrors:StringMap<String>;

	/** A function to validate the current model.
	
	By default, this checks that no values are null unless they are Null<T> / SNull<T>, or if it the unique ID
	that will be automatically generated.  If any are null when they shouldn't be, the model fails to validate.

	It also looks for "validate_{fieldName}" functions, and if they match, it executes the function.  If the function
	throws an error or returns false, then validation will fail.

	If you override this method to add more custom validation, then we recommend starting with `super.validate()` and
	ending with `return (!validationErrors.keys.hasNext());`
	*/
	public function validate():Bool 
	{
		validationErrors = new StringMap();
		return (!validationErrors.keys().hasNext());
	}

	/** A function to check if the current user is allowed to read this object.  This always returns true, you should override it to be more useful */
	public function checkAuthRead():Bool { return true; }
	
	/** A function to check if the current user is allowed to save this object.  This always returns true, you should override it to be more useful */
	public function checkAuthWrite():Bool { return true; }


	/** An example hxSerializeFields array used for custom serializaton.  Each model should have it's own static field for this, generated by the build macro. */
	static var hxSerializeFields = ["id","created","modified"];
	
	/** Custom serialization.  It will serialize all fields listed in the model's static `hxSerializeFields` array, which should be generated by the build macro for each model. */
	@:access(ufront.db.ManyToMany)
	function hxSerialize( s : haxe.Serializer ) 
	{
		s.useEnumIndex = true;
		s.useCache = false;

		var fields:Array<String> = untyped Type.getClass(this).hxSerializeFields;
		for (f in fields)
		{
			if (f == "modified" || f == "created")
			{
				var date=Reflect.field(this, f);
				s.serialize((date!=null) ? date.getTime() : null);
			}
			else if (f.startsWith("ManyToMany"))
			{
				var m2m:ManyToMany<Dynamic,Dynamic> = Reflect.getProperty(this, "_" + f.substr(10));
				if (m2m!=null)
				{
					s.serialize(Type.getClassName(m2m.b));
					s.serialize(m2m.bListIDs);
				}
				else 
				{
					// Figure out the type by looking at hxRelationships
					var relArr:Array<String> = untyped Type.getClass(this).hxRelationships;
					
					// Field name, eg "classes"
					var fieldName = f.substr(10); 

					// Relationship info, eg "classes,ManyToMany,app.coredata.model.SchoolClass"
					var relEntry = relArr.filter(function (r) return r.startsWith(fieldName+","))[0]; 
					
					// Model name, eg "app.coredata.model.SchoolClass"
					var typeName = relEntry.split(",").pop();

					s.serialize(typeName);
					s.serialize(null);
				}
			}
			else
			{
				s.serialize(Reflect.getProperty(this, f));
			}
		}
	}

	/** Custom serialization.  It will unserialize all fields listed in the model's static `hxSerializeFields` array, which should be generated by the build macro for each model. */
	@:access(ufront.db.ManyToMany)
	function hxUnserialize( s : haxe.Unserializer ) 
	{
		var fields:Array<String> = untyped Type.getClass(this).hxSerializeFields;
		for (f in fields)
		{
			if (f == "modified" || f == "created")
			{
				var time:Null<Float> = s.unserialize();
				Reflect.setProperty(this, f, (time!=null) ? Date.fromTime(time) : Date.now());
			}
			else if (f.startsWith("ManyToMany"))
			{
				var bName = s.unserialize();
				var bListIDs = s.unserialize();

				if (bName != null)
				{
					var b = Type.resolveClass(bName);
					if (bListIDs == null) bListIDs = new List();

					var m2m = new ManyToMany(this, b);
					m2m.bListIDs = bListIDs;
					m2m.bList = null;
					Reflect.setField(this, "_"+f.substr(10), m2m);
				}
			}
			else 
			{
				Reflect.setProperty(this, f, s.unserialize());
			}
		}
	}
}

/** BelongsTo relation 

You can use this as if the field is just typed as whatever T is, but the build macro here will set it up as a property and will link to the related object correctly.  

T must be a type that extends ufront.db.Object  */
typedef BelongsTo<T> = T;

/** HasMany relation 

This type is transformed into an Iterable that lets you iterate over related objects.  Related objects are determined by a corresponding "BelongsTo<T>" in the related class.  

While the real data type here is a `List<T>`, we expose it as a `ReadOnlyList<T>` so that you are not tempted to push new objects to the list or remove objects from the list.  To update it you must update the related property on each related object.

T must be a type that extends `ufront.db.Object` */
typedef HasMany<T> = ReadOnlyList<T>

/** HasOne relation 

This type is transformed into a property that lets you fetch a single related object.  Related objects are determined by a corresponding "BelongsTo<T>" in the related class.  The property is read only - to update it you must update the BelongsTo<> property on the related object.

T must be a type that extends `ufront.db.Object` */
typedef HasOne<T> = Null<T>;

/** A simple wrapper of `List<T>` that exposes only the read operations, it does not allow modifying the list. */
abstract ReadOnlyList<T>(List<T>) from List<T> {

    public var length(get, never):Int;
    public var isEmpty(get, never):Bool;
    public var isNotEmpty(get, never):Bool;

    inline function get_length() return this.length;
    inline function get_isEmpty() return this.length==0;
    inline function get_isNotEmpty() return this.length>0;


    public inline function iterator() return this.iterator();
    public inline function filter(predicate) return this.filter(predicate);

    @:to inline function toArray():Array<T> return Lambda.array(this);
}