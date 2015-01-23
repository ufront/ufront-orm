package ufront.db;

import sys.db.Types;
import haxe.ds.StringMap;
import haxe.rtti.Meta;
#if server
	import sys.db.Manager;
#elseif ufront_clientds
	import clientds.Promise;
#end

using StringTools;
using Lambda;
using tink.CoreApi;

/** 

Ufront DB Objects

This is the base class for models in Ufront's "Model, View, Controller" pattern.

Each model extends `ufront.db.Object`, and uses simple fields to describe what kind of data each of these objects will contain, and how that is saved to the database.
The type of each variable matches the type used in the database.

On the server, this class extends `sys.db.Object` and adds:

- a default unique `this.id` field (`SUId`, unsigned auto-incrementing integer)
- a `this.created` timestamp (`SDateTime`)
- a `this.modified` timestamps (`SDateTime`)
- modified `this.insert()` and `this.update()` methods that check validation and updates `this.created` and `this.modified` timestamps
- a `this.save()` method that performs either `this.insert()` or `this.update()`
- a `this.validate()` method that checks if the object is valid. This method is filled out with validation rules by a build macro.
- a `this.validationErrors` property to check which errors were found in validation.
- macro powered `this.hxSerialize()` and `this.hxUnserialize()` methods to ensure these objects serialize and unserialize nicely.
- a default `this.toString()` method that provides "${modelName}#${id}" eg "Person#23"
- a `save` signal

On the client, this *does not* longer extends `sys.db.Object`, so you can interact with your models even on targets that don't have access to the `sys.db` APIs - for example, Javascript in the browser.

This means that:

- Client side code can create, edit, and validate the objects.
- You can send objects back and forward using Haxe remoting, for example saving an object to the server, or retrieving a list from the server.
- When you unpack the object on the client it is fully typed, and you get full code re-use between client and server.
- They just can't save them back to the database, because you can't connect to (for example) MySQL directly.
- There is the experimental `ClientDS` library which allows you to save back to the server asynchronously using a remoting API.

You should use `-D server` or `-D client` defines in your hxml build file to help ufront know whether we're compiling for the server or client.

Build macro effects:

- Process `BelongsTo<T>`, `HasMany<T>`, `HasOne<T>` and `ManyToMany<A,B>` relationships and create the appropriate getters and setters.
- Add the appropriate validation checks to our `this.validate()` method.
- Save appropriate metadata for being able to serialize and unserialize correctly.
- On the server, create a `public static var manager:Manager<T> = new Manager(T)` property for each class.
- On the client, if using ClientDS, create a `public static var clientDS:ClientDS<T>` property for each class.

**/

#if server
	@noTable
#else
	@:keepSub
#end

#if !macro @:autoBuild(ufront.db.DBMacros.setupDBObject()) #end
class Object #if server extends sys.db.Object #end {
	
	/** A default ID. Auto-incrementing 32-bit Int. **/
	public var id:SId;
	
	/** The time this record was first created. **/
	public var created:SDateTime;
	
	/** The time this record was last modified. **/
	public var modified:SDateTime;

	/** A signal that is triggered after a successful save. **/
	@:skip public var saved(get,null):Signal<Noise>;
	@:skip var savedTrigger:SignalTrigger<Noise>;

	#if server
		public function new() {
			validationErrors = new ValidationErrors();
			super();
		}

		/**
			Inserts a new record to the database.
			Will throw an error if `this.validate()` fails.
			Updates the "created" and "modified" timestamps before saving.
		**/
		override public function insert() {
			if (this.validate()) {
				this.created = Date.now();
				this.modified = Date.now();
				super.insert();
				if ( savedTrigger!=null )
					savedTrigger.trigger( Noise );
			}
			else {
				var errors = Lambda.array(validationErrors).join("\n");
				throw 'Data validation failed for $this: \n' + errors;
			}
		}

		/**
			Updates an existing record in the database.
			Will throw an error if `this.validate()` fails.
			Updates the "modified" timestamp before saving.
		**/
		override public function update() {
			if (this.validate()) {
				this.modified = Date.now();
				super.update();
			}
			else {
				var errors = Lambda.array(validationErrors).join(", ");
				throw 'Data validation failed for $this: ' + errors;
			}
		}

		/**
			Save a record (either inserting or updating) to the database.
			If `id` is null, then it needs to be inserted.
			If `id` already exists, try to update first.
			If that throws an error, it means that it is not inserted yet, so then insert it.
			Updates the "created" and "modified" timestamps as required.
		**/
		public function save() {
			if (id == null) {
				insert();
			}
			else {
				try {
					untyped this._lock = true;
					update();
				}
				catch (e:Dynamic) {
					// If it failed because of a validation error, rethrow
					if (Std.string(e).indexOf('Data validation failed') != -1) throw e;
					// TODO: if we have a duplicate index error, this gets caught, an insert is attempted, and the message is just confusing.

					// Error is probably because it had an ID, but it wasn't in the DB... so insert it
					insert();
				}
			}
		}
		
		/**
			Refresh the relations on this object.
			Currently this does not refresh the object itself, it merely empties the cached related objects so they will be fetched again.
			In future we might get this to refresh the object itself from the database.
		**/
		public function refresh() {
			var relArr:Array<String> = cast Meta.getType(Type.getClass(this)).ufRelationships;
			if ( relArr!=null ) for (relDetails in relArr) {
				var fieldName = relDetails.split(",")[0];
				Reflect.setField( this, fieldName, null );
			}
		}
		
		/**
			Even though it's non-sensical to have a manager on `ufront.db.Object`, the Haxe record macros (not the ufront ones) add a `__getManager` field if we don't have one (platforms other than neko.)
			This breaks things when you have an inheritance chain, where `ufront.db.Object` doesn't have a manager, but it's children do.
			As a workaround I'm putting this private static manager here.
		**/
		private static var manager:Manager<Object> = new Manager(Object);
	#else

		#if ufront_clientds
			var _clientDS(default,never) : clientds.ClientDs<Dynamic>;
		#end

		public function new() {
			validationErrors = new ValidationErrors();
			setupClientDs();
		}

		function setupClientDs() {
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
				if (validate()) {
					var promise = _clientDS.save(this);
					promise.then(function(_) {
						if ( savedTrigger!=null )
							savedTrigger.trigger( Noise );
					});
					return promise;
				}
				else {
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
				var relArr:Array<String> = cast Meta.getType(Type.getClass(this)).ufRelationships;
				if ( relArr!=null ) for (relDetails in relArr) {
					var field = relDetails.split(",")[0];
					Reflect.callMethod( this, Reflect.field(this,'get_$field'), [] );
				}
				var p = new Promise();
				Promise.when( allRelationPromises ).then( function(_) { p.resolve(this); return null; } );
				return p;
			}
		#end

	#end


	#if server override #end
	public function toString():String {
		var modelName = Type.getClassName(Type.getClass(this));
		var idStr = (id!=null) ? ''+id : 'new';
		return '$modelName#$idStr';
	}

	/** If a call to validate() fails, it will populate this map with a list of errors.  The key should
	be the name of the field that failed validation, and the values should be a description of any errors. */
	@:skip public var validationErrors:ValidationErrors;

	/** A function to validate the current model.

	By default, this checks that no values are null unless they are Null<T> / SNull<T>, or if it the unique ID
	that will be automatically generated.  If any are null when they shouldn't be, the model fails to validate.

	It also looks for "validate_{fieldName}" functions, and if they match, it executes the function.  If the function
	throws an error or returns false, then validation will fail.

	If you override this method to add more custom validation, then we recommend starting with `super.validate()` and
	ending with `return validationErrors.isValid;`
	*/
	public function validate():Bool {
		if ( validationErrors==null )  validationErrors = new ValidationErrors();
		else validationErrors.reset();
		
		_validationsFromMacros();
		
		return validationErrors.isValid;
	}
	
	/** The build macro will save override this method and populate it with validation statements. **/
	function _validationsFromMacros() {}
	
	function get_saved():Signal<Noise> {
		if ( saved==null ) {
			savedTrigger = Signal.trigger();
			saved = savedTrigger.asSignal();
		}
		return saved;
	}

	/** Custom serialization.  It will serialize all fields listed in the model's `@ufSerialize` metadata, which should be generated by the build macro for each model. */
	@:access(ufront.db.ManyToMany)
	function hxSerialize( s : haxe.Serializer ) {
		s.useEnumIndex = true;
		s.useCache = false;

		var fields:Array<String> = cast Meta.getType(Type.getClass(this)).ufSerialize;
		for (f in fields) {
			if (f == "modified" || f == "created") {
				var date=Reflect.field(this, f);
				s.serialize((date!=null) ? date.getTime() : null);
			}
			else if (f.startsWith("ManyToMany")) {
				var m2m:ManyToMany<Dynamic,Dynamic> = Reflect.field(this, f.substr(10));
				if (m2m!=null) {
					s.serialize(Type.getClassName(m2m.b));
					s.serialize(m2m.bListIDs);
					s.serialize(m2m.unsavedBObjects);
				}
				else {
					// Figure out the type by looking at ufRelationships
					var relArr:Array<String> = cast Meta.getType(Type.getClass(this)).ufRelationships;

					// Field name, eg "classes"
					var fieldName = f.substr(10);

					// Relationship info, eg "classes,ManyToMany,app.coredata.model.SchoolClass"
					var relEntry = relArr.filter(function (r) return r.startsWith(fieldName+","))[0];

					// Model name, eg "app.coredata.model.SchoolClass"
					var typeName = relEntry.split(",").pop();

					s.serialize(typeName);
					s.serialize(null);
					s.serialize(null);
				}
			}
			else {
				s.serialize(Reflect.getProperty(this, f));
			}
		}
	}

	/** Custom serialization.  It will unserialize all fields listed in the model's `@ufSerialize` metadata, which should be generated by the build macro for each model. */
	@:access(ufront.db.ManyToMany)
	function hxUnserialize( s : haxe.Unserializer ) {
		var fields:Array<String> = cast Meta.getType(Type.getClass(this)).ufSerialize;
		for (f in fields) {
			if (f == "modified" || f == "created") {
				var time:Null<Float> = s.unserialize();
				Reflect.setProperty(this, f, (time!=null) ? Date.fromTime(time) : Date.now());
			}
			else if (f.startsWith("ManyToMany")) {
				var bName = s.unserialize();
				var bListIDs = s.unserialize();
				var unsavedBObjects = s.unserialize();

				if (bName != null) {
					var b = Type.resolveClass(bName);
					if (bListIDs == null) bListIDs = new List();
					if (unsavedBObjects == null) unsavedBObjects = new List();

					var m2m = new ManyToMany(this, b);
					m2m.bListIDs = bListIDs;
					m2m.unsavedBObjects = unsavedBObjects;
					m2m.bList = null;
					Reflect.setField(this, f.substr(10), m2m);
				}
			}
			else {
				Reflect.setProperty(this, f, s.unserialize());
			}
		}
		this.validationErrors = new ValidationErrors();
	}
}

/**
BelongsTo relationship.

Use this whenever the current object belongs to just one instance of another object.
For example a BlogPost might belong to an Author, and an Invoice might belong to a Customer.

The build macro will transform this into a property to fetch the related object from the database.
You use it directly.

```haxe
class BlogPost extends Object {
	public var author:BelongsTo<Author>;
}

function() {
	var blogPost = BlogPost.get(1);
	blogPost.author.name; // Will fetch the related "Author" object, cache it, and get the name.
	blogPost.author.email; // Will use the cached related "Author" object, and get the email.
}
```

T must be a type that extends ufront.db.Object.
**/
typedef BelongsTo<T> = T;

/**
HasMany relationship.

This type is transformed into an List that lets you iterate over related objects.
Related objects are determined by a corresponding "BelongsTo<T>" in the related class.

Please note that at this time setting or modifying the list has no effect on the database.
To update the relations in the database you must update the related `BelongsTo` property on each related object.

```haxe
class Author extends Object {
	public var posts:HasMany<BlogPost>;
}
function() {
	var author = Author.manager.get(1);
	author.posts.length; // Will fetch the `List` of related BlogPost objects, cache it, and get the length of the list.
	author.posts.first(); // Will use the cached `List` of related BlogPost objects, and fetch the first post.

	var newBlogPost = new BlogPost();
	newBlogPost.author = author;
	newBlogPost.save();
}
```

T must be a type that extends `ufront.db.Object`
**/
typedef HasMany<T> = List<T>

/**
HasOne relationship.

This behaves the same as `HasMany`, but only fetches the first related object, not a list of all relationships.

Similar to `HasMany`, you must update relationships by changing the `BelongsTo` property on the related object.

T must be a type that extends `ufront.db.Object`
**/
typedef HasOne<T> = Null<T>;
