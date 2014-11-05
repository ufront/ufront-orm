package testcases.models;

import ufront.db.Object;
import sys.db.Types;

class Person extends Object {
	public var firstName:SString<20>;
	public var surname:SString<20>;
	@:validate( _.length>3 && _.indexOf("@")>0 )
	public var email:SString<50>;
	public var age:STinyUInt;
	public var bio:Null<SText>;
	
	// Some relationships
	public var profile:HasOne<Profile>;
	@:relationKey(authorID) public var posts:HasMany<BlogPost>;
}