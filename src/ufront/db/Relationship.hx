package ufront.db;

import ufront.db.Object;
import sys.db.Types;

@noTable
class Relationship extends Object
{
	public var r1:SUInt;
	public var r2:SUInt;

	public function new(r1:Int, r2:Int)
	{
		super();
		this.r1 = r1;
		this.r2 = r2;
	}
}
