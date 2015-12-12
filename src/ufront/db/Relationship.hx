package ufront.db;

import ufront.db.Object;
import sys.db.Types;

/**
A Relationship is the class used for a join table between in a `ManyToMany` relationship.

This is used internally by the `ManyToMany` class, and will operate on the correct tables depending on the object types.
**/
@noTable
class Relationship extends Object {
	public var r1:SUInt;
	public var r2:SUInt;

	public function new(r1:Int, r2:Int) {
		super();
		this.r1 = r1;
		this.r2 = r2;
		this.modified = this.created = Date.now();
	}
}
