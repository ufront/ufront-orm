package ufront.db;

import haxe.ds.StringMap;
import tink.CoreApi;

abstract ValidationErrors( StringMap<Array<String>> ) {

	public function new() this = new StringMap();

	public var length(get,never):Int;
	public var isValid(get,never):Bool;
	public var isInvalid(get,never):Bool;

	public function reset() {
		for ( key in this.keys() ) {
			this.remove( key );
		}
	}

	/** Add an error to a particular field.  If the field already has an error, this will be added to it **/
	@:arrayAccess public function set( field:String, error:String ) {
		if ( !this.exists(field) ) this.set( field, [] );
		this.get( field ).push( error );
		return error;
	}

	/** Get a list of errors for a particular field.  Null if there are no errors.  If multiple errors, they are joined together with '\n' **/
	@:arrayAccess public function errorMessage( field:String ):String {
		if ( !this.exists(field) ) return null;
		return this.get( field ).join("\n");
	}

	/** Get a list of errors for a particular field as an array.  Array is empty if there are no errors. **/
	@:arrayAccess public function errors( field:String ):Array<String> {
		if ( !this.exists(field) ) return [];
		return this.get( field );
	}

	/** Get a list of errors for a particular field as an array.  Array is empty if there are no errors. **/
	@:arrayAccess public function isFieldValid( field:String ):Bool {
		if ( !this.exists(field) ) return true;
		return this.get( field ).length == 0;
	}

	@:to public inline function toMap():Map<String,Array<String>> {
		return this;
	}

	@:to public function toSimpleMap() {
		var m = new Map<String,String>();
		for ( k in this.keys() ) {
			m.set( k, this.get(k).join("\n") );
		}
		return this;
	}

	@:to public function toArray():Array<Pair<String,String>> {
		return [ for ( key in this.keys() ) for ( err in this.get(key) ) new Pair( key, err ) ];
	}

	@:to public function toSimpleArray():Array<String> {
		return [ for ( arr in this ) for ( err in arr ) err ];
	}

	@:to public function toString() {
		return toSimpleArray().join("\n");
	}

	public inline function iterator():Iterator<Pair<String,String>> {
		return toArray().iterator();
	}

	function get_length() {
		var l = 0;
		for ( arr in this ) l += arr.length;
		return l;
	}

	inline function get_isValid() return get_length()==0;
	inline function get_isInvalid() return get_length()>0;
}