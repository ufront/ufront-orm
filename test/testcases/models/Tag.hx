package testcases.models;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;

class Tag extends Object {
	@:validate( _.length>3, "Your tag url must be at least 3 letters long" )
	@:validate( ~/^[a-z0-9_]+$/.match(_), "Your tag url must only use a-z, 0-9 and underscores" )
	public var url:SString<10>;
	
	public var posts:ManyToMany<Tag,BlogPost>;
}