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

	function dropTable( manager:Manager<Dynamic> ) {
		var tableName = @:privateAccess manager.table_name;
		try {
			cnx.request( 'DROP TABLE IF EXISTS $tableName' );
		} catch(e:Dynamic) {
			Sys.println( 'Error running `DROP TABLE IF EXISTS $tableName`: $e' );
		}
	}

	function recreateTable( manager:Manager<Dynamic> ) {
		dropTable( manager );
		TableCreate.create( manager );
	}

	function dropJoinTable( classA:Class<ufront.db.Object>, classB:Class<ufront.db.Object> ) {
		var tableName = ManyToMany.generateTableName( classA, classB );
		try {
			cnx.request( 'DROP TABLE IF EXISTS $tableName' );
		} catch(e:Dynamic) {
			Sys.println( 'Error running `DROP TABLE IF EXISTS $tableName`: $e' );
		}
	}

	function recreateJoinTable( classA:Class<ufront.db.Object>, classB:Class<ufront.db.Object> ) {
		dropJoinTable( classA, classB );
		var tableName = ManyToMany.generateTableName( classA, classB );
		ManyToMany.createJoinTable( classA, classB );
	}
}
