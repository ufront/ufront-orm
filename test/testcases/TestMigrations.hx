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
		createTable( Migration );

		// Set up 2 fake migrations.
		m1 = new M20160508154702_Create_Person_Table();
		m1.save();

		cnx.request( 'DROP TABLE IF EXISTS fake_table' );
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
		Migration.manager.delete( $id!=-1 );
		// Try apply 2 migrations up manually.
		api.applyMigrations( [m1,m2], Up );
		// Now m1 should stay, m2 should go Down, and the rest should go Up.
		api.syncMigrationsUp();

		// Assert that m2 has been migrated "Down".
		Assert.raises(function() {
			cnx.request( "SELECT * FROM fake_table" );
		}, "Expected fake_table to not exist, but it did");

		// Assert that all our other tables now exist.
		var person = new Person();
		person.firstName = "Jason";
		person.surname = "O'Neil";
		person.email = "jason@ufront.net";
		person.age = 28;
		person.bio = null;
		person.insert();

		var profile = new Profile();
		profile.person = person;
		profile.github = "jasononeil";
		profile.twitter = "jasonaoneil";
		profile.save();

		var post = new BlogPost();
		post.author = person;
		post.title = "F1rst P0st!!1";
		post.url = "first_post";
		post.text = "How clever and witty!";
		post.save();

		var tag = new Tag();
		tag.url = "meaningless_fluff";
		tag.save();
		tag.posts.add( post );

		Assert.equals( 1, Person.manager.all().length );
		Assert.equals( 1, Profile.manager.all().length );
		Assert.equals( 1, BlogPost.manager.all().length );
		Assert.equals( 1, Tag.manager.all().length );
		Assert.equals( post, Tag.manager.all().first().posts.first() );

		// Let's see if our CASCADE / RESTRICT relationships work!
		if ( cnx.dbName()!="SQLite" ) {
			Assert.raises(function() {
				person.delete();
				cnx.request( "SELECT * FROM fake_table" );
			}, "Expected person.delete() to be RESTRICTED because of the BlogPost_authorID foreignKey, but it was allowed.");
			post.delete();
			person.delete();
			Assert.equals( 0, Person.manager.all().length );
			Assert.equals( 0, Profile.manager.all().length );
			Assert.equals( 0, BlogPost.manager.all().length );
			Assert.equals( 1, Tag.manager.all().length );
			sys.db.Manager.cleanup();
			Assert.equals( 0, Tag.manager.all().first().posts.length );
		}
	}
}
