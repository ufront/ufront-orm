package ufront.db.migrations;

#if sys
import sys.db.Types;
import sys.db.RecordInfos.RecordType;

/** A description of a column that exists on a database table. **/
typedef DBColumn = { name:String, type:RecordType };

/** A description of an index that exists on a database table. **/
typedef DBIndex = { fields:Array<String>, unique:Bool };

/** Possible values for `ON UPDATE` and `ON DELETE` referential actions with foreign keys. **/
@:enum abstract DBReferentialAction(String) from String to String {
	var Cascade = "CASCADE";
	var Restrict = "RESTRICT";
	var NoAction = "NO ACTION";
	var SetNull = "SET NULL";
	var SetDefault = "SET DEFAULT";
}

/** A description of a foreign key that exists on a database table. **/
typedef DBForeignKey = { fields:Array<String>, relatedTableName:String, onUpdate:Null<DBReferentialAction>, onDelete:Null<DBReferentialAction> };

/** A description of a database table. **/
typedef DBTable = {
	var tableName:String;
	var fields:Array<DBColumn>;
	var indicies:Array<DBIndex>;
	var foreignKeys:Array<DBForeignKey>;
};

/** A schema describing the current state of the database. **/
typedef DBSchema = Array<DBTable>;

/**
A description of the actions that can occur during a database migration.
These could be run up or down.
**/
enum MigrationAction {
	CreateTable( table:DBTable );
	DropTable( table:DBTable );
	AddField( tableName:String, field:DBColumn );
	ModifyField( tableName:String, before:DBColumn, after:DBColumn );
	RemoveField( tableName:String, field:DBColumn );
	AddIndex( tableName:String, index:DBIndex );
	RemoveIndex( tableName:String, index:DBIndex );
	AddForeignKey( tableName:String, index:DBForeignKey );
	RemoveForeignKey( tableName:String, index:DBForeignKey );
	CreateJoinTable( modelAName:String, modelBName:String );
	RemoveJoinTable( modelAName:String, modelBName:String );
	InsertData( tableName:String, id:Null<Int>, properties:{} );
	DeleteData( tableName:String, id:Null<Int>, properties:{} );
	/** Run custom functions as part of the migration. **/
	CustomMigration( up:Void->Void, down:Void->Void );
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

Migration objects should be created by subclassing, and the sub-classes should appear in the "migrations" package or a sub-package:

```
package migrations.my.app;

class 20151028152503_AddEmailFieldToProfile extends Migration {
	// Constructor must take no arguments and call super function.
	public function new() {
		super([
			AddField( "UserProfile", { name:"email", type: DString(255) } )
		]);
	}
}
```

**/
class Migration extends Object {
	/**
	The actions that are run as part of this migration.
	By storing these in the database, we can roll them backwards even if that code no longer exists in the database.
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
}
#end
