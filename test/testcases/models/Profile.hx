package testcases.models;

import ufront.db.Object;
import sys.db.Types;

class Profile extends Object {
	public var person:BelongsTo<Person>;
	
	public var facebook:Null<SString<255>>;
	public var twitter:Null<SString<255>>;
	public var github:Null<SString<255>>;
}