import sys.db.*;
import ufront.db.*;
import testcases.models.*;
import testcases.issues.Issue001;
import ufront.db.migrations.Migration;

class DBTestClass {
	var cnx:Connection;

	public function new( cnx:Connection ) {
		this.cnx = cnx;
	}

	function setup() {
		Manager.cnx = cnx;
		#if php
			// See https://github.com/ufront/ufront-orm/issues/9
			Migration.manager;
			BlogPost.manager;
			Tag.manager;
			Profile.manager;
			Person.manager;
			Issue001_MyObject.manager;
			Issue001_Category.manager;
			Issue001_Language.manager;
		#end
		// TODO: is there an easy, cross platform "DROP ALL TABLES" option?
		dropTable( Migration );
		dropJoinTable( BlogPost, Tag );
		dropTable( Tag );
		dropTable( BlogPost );
		dropTable( Profile );
		dropTable( Person );
		dropJoinTable( Issue001_MyObject, Issue001_Category );
		dropJoinTable( Issue001_MyObject, Issue001_Language );
		dropTable( Issue001_MyObject );
		dropTable( Issue001_Category );
		dropTable( Issue001_Language );
	}

	function teardown() {
		Manager.cnx = null;
	}

	function dropTable( cls:Class<sys.db.Object> ) {
		var manager = new Manager( cls );
		var tableName = @:privateAccess manager.table_name;
		try {
			cnx.request( 'DROP TABLE IF EXISTS $tableName' );
		} catch(e:Dynamic) {
			Sys.println( 'Error running `DROP TABLE IF EXISTS $tableName`: $e' );
		}
	}

	function createTable( cls:Class<sys.db.Object> ) {
		var manager = new Manager( cls );
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

	function createJoinTable( classA:Class<ufront.db.Object>, classB:Class<ufront.db.Object> ) {
		var tableName = ManyToMany.generateTableName( classA, classB );
		ManyToMany.createJoinTable( classA, classB );
	}
}
