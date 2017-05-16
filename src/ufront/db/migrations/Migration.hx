package ufront.db.migrations;

import ufront.db.migrations.DBSchema;
import sys.db.Types;

/**
The actions that occur during a database migration.

These are designed to be able to run up and run down, so using an action will modify the database appropriately in both directions.

Each value except `CustomMigration` can be run "down" even if the migration no longer exists in the code.
So if you check out an old commit or branch, it will be able to undo the migrations.

The `CustomMigration` function does require the migration to exist in the code.
If you need to check out an old branch, you will need to run the migration "down" first before checking out the old code.
**/
enum MigrationAction {
	CreateTable( table:DBTable );
	DropTable( table:DBTable );
	AddField( tableName:String, field:DBColumn );
	ModifyField( tableName:String, before:DBColumn, after:DBColumn );
	RemoveField( tableName:String, field:DBColumn );
	AddIndex( tableName:String, index:DBIndex );
	RemoveIndex( tableName:String, index:DBIndex );
	AddForeignKey( tableName:String, foreignKey:DBForeignKey );
	RemoveForeignKey( tableName:String, foreignKey:DBForeignKey );
	CreateJoinTable( modelAName:String, modelBName:String );
	RemoveJoinTable( modelAName:String, modelBName:String );
	InsertData( tableName:String, columns:Array<String>, data:Array<{ id:Null<Int>, values:Array<Dynamic> }> );
	DeleteData( tableName:String, columns:Array<String>, data:Array<{ id:Null<Int>, values:Array<Dynamic> }> );
	/**
	Run a custom SQL statement on the database.

	One common use case here is performing a complex `UPDATE` query on the DB.

	Similar to `CustomMigration`, it is recommended that `CustomSql` not be used to change the schema.
	**/
	CustomSql( sqlUp:String, sqlDown:String );
	/**
	Run custom functions as part of the migration.

	These can only be run if they exist in the code.
	For example, if you switch to a new branch, and run a custom migration "up", it will be added.
	If you switch to the old branch, and try to run it "down", it will not be able to.
	You need to run it "down" from your new branch, where it exists, then switch to the old branch.

	It is recommended that a CustomMigration not affect the schema.
	For example, don't use it to create new columns or tables.
	If you do, the MigrationApi's ability to generate new migrations based on changes to your models will be broken.
	You must use the other MigrationActions to make sure MigrationApi can detect changes to the Schema accurately.
	**/
	CustomMigration( up:sys.db.Connection->Void, down:sys.db.Connection->Void );
	/**
	Similar to `CustomMigration`, but only performs an action in the "up" direction.

	An example where this is useful is populating a field that has been added.
	If the action `AddField` is followed by `CustomMigrationUp`, you can use the custom migration to populate the new field.
	When running down, the `CustomMigrationUp` is skipped and the field is deleted.

	The advantage is that this migration action does not block migrations from being run "down" if the migration no longer exists in the code.

	Similar to `CustomMigration`, it is recommended that `CustomMigrationUp` not be used to change the schema.
	**/
	CustomMigrationUp( up:sys.db.Connection->Void );
}

/**
A description of the direction that a `Migration` and it's related `MigrationActions` are running.
**/
enum MigrationDirection {
	Up;
	Down;
}

/**
A `Migration` that should be run (or has been run) on the database.

- When a Migration object exists in the code, but not in the database, it means this migration must be run "up" when syncing the database.
- When a Migration row exists in the database, but not the code, it means this migration must be run "down" when syncing the database.
- If the Migration exists both as an object in the code and a row in the database, it means the migration has been run "up" already, and this migration is in sync.

When creating a migration:

- Your migration is defined as a class that extends `ufront.db.Migration`.
- Your migration class should be in the `db.migrations` package or a sub-package.
- The class name should have the format `M${date}_${description}`
  The date should be in the format `yyyyMMddhhmmss`.
  The date will be used to apply the migrations in the correct order.
- By the end of the constructor, the `actions` array should be populated.
  The easiest way to do this is to pass an array to the super constructor: `super([ action1, action2 ])`.
- The constructor for your migration should not accept or require any function arguments.

```
package db.migrations.my.app;

class M20151028152503_AddEmailFieldToProfile extends Migration {
	public function new() {
		super([
			AddField( "UserProfile", { name:"email", type: DString(255) } )
		]);
	}
}
```

**/
@:autoBuild( ufront.db.migrations.MigrationMacros.migrationBuild() )
@:table("uf_migration")
@:index(migrationID,unique)
class Migration extends Object {
	/**
	The actions that are run as part of this migration.
	By storing these in the database, we can roll them backwards even if that migration no longer exists in the runtime version of the code.
	Please note that if you're trying to roll back a `CustomMigrationCode` action, you'll need to do it *while the code exists*, so before changing branches etc.
	**/
	public var actions(default,null):SData<Array<MigrationAction>>;

	/** The unique name of the migration. **/
	public var migrationID(default,null):String;

	function new( actions:Array<MigrationAction> ) {
		super();
		var className = Type.getClassName( Type.getClass(this) );
		this.migrationID = className.substr( className.lastIndexOf(".")+1 );
		this.actions = actions;
	}

	override public function toString():String {
		return migrationID;
	}
}
