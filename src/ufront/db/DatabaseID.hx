package ufront.db;

import ufront.db.Object;

/**
	DatabaseID is a helper abstract to help document which type of ID an API wishes to receive.

	There are a few advantages to having your API accept a database ID rather than an ordinary Int:

	- Your Haxe generated API documentation will explain which object ID it is expecting.
	- You can call `api( myObject )` rather than `api( myObject.id )`, which will verify you are using the correct type when you compile.
**/
abstract DatabaseID<T:Object>( Int ) from Int to Int {
	inline function new(id:Int) this = id;
	@:to public function toInt():Int return this;
	@:from public static function fromObject<T:Object>( o:T ):DatabaseID<T> return new DatabaseID( o.id );
}