package testcases;

import utest.Assert;
import testcases.models.*;
import ufront.ORM;
import db.migrations.*;
import sys.db.Manager;
import minject.Injector;

class TestMigrations extends DBTestClass {

	var api:MigrationApi;
	var m1:Migration;
	var m2:Migration;

	override function setup() {
		super.setup();
		api = new MigrationApi();
		api.injector = new Injector();
		recreateTable( Migration.manager );
		dropJoinTable( BlogPost, Tag );
		dropTable( Tag.manager );
		dropTable( BlogPost.manager );
		dropTable( Profile.manager );
		dropTable( Person.manager );

		// Set up 2 fake migrations.
		m1 = new M20160508154702_Create_Person_Table();
		m1.save();
		@:privateAccess {
			m2 = new Migration([
				CreateTable({
					tableName: "fake_table",
					fields: [
						{ name:"id", type:DId, isNullable:false },
					],
					indicies: [],
					foreignKeys: [],
				})
			]);
			m2.migrationID = "M20160508160102_Create_Fake_Table";
			m2.save();
		}
	}

	function testFindingMigrations() {
		var dbMigrations = api.getMigrationsFromDB();
		Assert.equals( 2, dbMigrations.length );

		var codeMigrations = api.getMigrationsInCode();
		Assert.equals( 3, codeMigrations.length );

		var createFakeTable = api.getMigrationFromDB( "M20160508160102_Create_Fake_Table" );
		Assert.notNull( createFakeTable );

		var createTable = api.getMigrationInCode( "M20160508154702_Create_Person_Table" );
		Assert.notNull( createTable );

		var todo = api.findRequiredMigrations();
		Assert.isTrue( todo.autoDown );
		Assert.equals( 2, todo.up.length );
		Assert.equals( "M20160508195741_Create_BlogPost_Profile_Tag_Tables", todo.up[0].migrationID );
		Assert.equals( "M20160508203332_Add_Blog_Joins", todo.up[1].migrationID );
		Assert.equals( 1, todo.down.length );
		Assert.equals( "M20160508160102_Create_Fake_Table", todo.down[0].migrationID );
	}

	function testMutateSchema() {
		var dbSchema = api.getSchemaFromDB();
		Assert.equals( 2, dbSchema.length );
		Assert.equals( "Person", dbSchema[0].tableName );
		Assert.equals( "fake_table", dbSchema[1].tableName );

		var codeSchema = api.getSchemaFromCode();
		Assert.equals( 5, codeSchema.length );
		Assert.equals( "Person", codeSchema[0].tableName );
		Assert.equals( "BlogPost", codeSchema[1].tableName );
		Assert.equals( "Profile", codeSchema[2].tableName );
		Assert.equals( "Tag", codeSchema[3].tableName );
		Assert.equals( "_join_BlogPost_Tag", codeSchema[4].tableName );
	}

	function testMigrationManagerAndConnection() {
		api.applyMigrations( [m2], Up );
		api.syncMigrationsUp();
		Assert.isTrue( true );
	}
}
