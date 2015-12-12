package ufront;

/**
Ufront-ORM is the standard way to set up users, groups and permissions in Ufront.

Ufront is a client / server web framework built with Haxe.
ORM stands for Object Relational Mapping, and is about reading from a relational database (like MySQL or Sqlite) and turning database rows into objects in your programming language.
Therefore Ufront-ORM is the standard way for a Ufront app to interact with a relational database.

### Features

Ufront-ORM is built on top of the `sys.db` package in the standard library.

Essentially any class that extends `sys.db.Object` or `ufront.db.Object` will correlate with a table in the database.
And each object of that class will correlate to a row from that table in the database, and each field of that object, a column.

The documentation for the Haxe `sys.db` features are found here: <http://old.haxe.org/manual/spod>

On top of this, Ufront-ORM adds:

- A new base class (`ufront.db.Object`) that provides a few extra features.
	- Objects can exist on both the server and the client
	- Objects can be serialized and deserialized, and transferred between client and server with remoting.
	- Objects have built in validation support support using `@:validate()` metadata, `validate()` functions or `validate_$fieldName()` functions.
	- Default fields for all objects: `id:SId`, `created:SDateTime` and `modified:SDateTime`.
- Automatically create a static `manager` field added to each model (server side only).
- Easy join tables with `ManyToMany`.
- Easy foreign keys and relationships with `BelongsTo`, `HasOne`, `HasMany` and `ManyToMany` properties.
- The `DBSerializationTools` macros to easily set which fields in an object should be included for serialization / remoting.
- A `DatabaseID<Model>` type, that you can use in your API definitions. It is a type safe way of transferring only the ID of the object.

### Platform Support

Currently Ufront-ORM can only connect to databases on `SYS` platforms: Neko, PHP, CPP etc.
In a future version we hope to support NodeJS and asynchronous database connections.

Ufront-ORM makes it possible to share objects from these platforms to your client.
That is, you can read objects on the server, send them to the client, read them, analyze them, modify them, validate them, and send them back to the server to be saved.

Currently we unit-test Ufront-ORM with MySQL and Sqlite on PHP and Neko.
Other platforms may also work.
Bug reports and pull requests on the Github project are encouraged.

### Import shortcuts

The `ufront.ORM` module contains typedefs for commonly imported types in the `ufront-orm` package.

This allows you to use `import ufront.ORM;` rather than having lots of imports in your code.
**/
class ORM {}

// `ufront.db` package.
@:noDoc @:noUsing typedef DatabaseID<T:Object> = ufront.db.DatabaseID<T>;
@:noDoc @:noUsing typedef DBSerializationTools = ufront.db.DBSerializationTools;
@:noDoc @:noUsing typedef ManyToMany<A:Object,B:Object> = ufront.db.ManyToMany<A,B>;
@:noDoc @:noUsing typedef Object = ufront.db.Object;
@:noDoc @:noUsing typedef BelongsTo<T:Object> = ufront.db.Object.BelongsTo<T>;
@:noDoc @:noUsing typedef HasMany<T:Object> = ufront.db.Object.HasMany<T>;
@:noDoc @:noUsing typedef HasOne<T:Object> = ufront.db.Object.HasOne<T>;
@:noDoc @:noUsing typedef Relationship = ufront.db.Relationship;
@:noDoc @:noUsing typedef ValidationErrors = ufront.db.ValidationErrors;
