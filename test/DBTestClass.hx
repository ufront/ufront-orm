import sys.db.*;
import ufront.db.*;

class DBTestClass {
	var cnx:Connection;
	
	public function new( cnx:Connection ) {
		this.cnx = cnx;
	}
	
	function setup() {
		Manager.cnx = cnx;
	}
	
	function teardown() {
		Manager.cnx = null;
	}
	
	function recreateTable( manager:Manager<Dynamic> ) {
		var tableName = @:privateAccess manager.table_name;
		try cnx.request( 'DROP TABLE $tableName' ) catch(e:Dynamic) {}
		TableCreate.create( manager );
	}
	
	function recreateJoinTable( classA:Class<ufront.db.Object>, classB:Class<ufront.db.Object> ) {
		var tableName = ManyToMany.generateTableName( classA, classB );
		try cnx.request( 'DROP TABLE $tableName' ) catch(e:Dynamic) {}
		ManyToMany.createJoinTable( classA, classB );
	}
}
