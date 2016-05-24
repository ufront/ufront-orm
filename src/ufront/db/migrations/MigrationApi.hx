package ufront.db.migrations;

import ufront.db.migrations.Migration;
import ufront.MVC;
import minject.Injector;
#if sys
	import sys.db.Manager;
	import sys.db.Connection;
#end
using tink.CoreApi;
using Lambda;
/**
This API provides a way of keeping the migrations in your database in sync with the migrations described in your code.

A separate `MigrationCreationApi` is used to create Migration classes based on the differences between your models and your existing schema.
**/
class MigrationApi extends UFApi {

	@inject public var injector:Injector;

	/** Read the `uf_migration` table to and get an array of all migrations that have been run up. **/
	public function getMigrationsFromDB():Array<Migration> {
		return sortMigrations( Migration.manager.all().array() );
	}

	/** Get an array of all Migrations required for the current code state, by finding every `Migration` class in the `db.migrations` package. **/
	public function getMigrationsInCode():Array<Migration> {
		CompileTime.importPackage( "db.migrations" );
		var migrationClasses = CompileTime.getAllClasses( "db.migrations", Migration );
		var migrations = [for (m in migrationClasses) Type.createInstance(m,[]) ];
		return sortMigrations( migrations );
	}


	/** Retrieve a single migration that has been run up in the database, by its ID. **/
	public function getMigrationFromDB( id:String ):Migration {
		return Migration.manager.select( $migrationID==id );
	}

	/** Retrieve a single migration from the current code base, by its ID. **/
	public function getMigrationInCode( id:String ):Migration {
		return getMigrationsInCode().find( function(m) return m.migrationID==id );
	}

	/** Generate a `DBSchema` based on the current migrations found in `getMigrationsFromDB()`. **/
	public function getSchemaFromDB():DBSchema {
		var migrationsRunOnDB = getMigrationsFromDB();
		return mutateSchemma( [], migrationsRunOnDB, Up );
	}

	/** Read all `Migration` classes in the code base to build the expected schema. **/
	public function getSchemaFromCode():DBSchema {
		var migrationsInCode = getMigrationsInCode();
		return mutateSchemma( [], migrationsInCode, Up );
	}

	/**
	Find the migrations that must be run (both up and down) for the database schema to match the schema used in the code.

	The return object will inform you of:

	- Migrations that must be run `down`.
	- Migrations that must be run `up`.
	- Whether the down migrations can be run automatically or require manual intervention
		- If any `Down` migrations have a `CustomMigration` action, then they can only be run down in a version of the code where that migration exist.
		- You will need to check out a branch of the code where that migration existed, and run the list of migrations down, and then come back to the current branch, and run the `Up` migrations.
	**/
	public function findRequiredMigrations():{ autoDown:Bool, down:Array<Migration>, up:Array<Migration> } {
		var migrationsRunOnDB = getMigrationsFromDB();
		var migrationsInCode = getMigrationsInCode();
		var requiredMigrations = {
			down: [],
			up: [],
			autoDown: true,
		}
		for ( migInDB in migrationsRunOnDB ) {
			var migrationExistsInCode = migrationsInCode.exists( function(migInCode) return migInCode.migrationID==migInDB.migrationID );
			if ( migrationExistsInCode==false ) {
				if ( requiredMigrations.autoDown && migInDB.actions.exists(function(action) return action.match(CustomMigration(_,_))) ) {
					requiredMigrations.autoDown = false;
				}
				requiredMigrations.down.push( migInDB );
			}
		}
		for ( migInCode in migrationsInCode ) {
			var migrationExistsInDB = migrationsRunOnDB.exists( function(migInDB) return migInDB.migrationID==migInCode.migrationID );
			if ( migrationExistsInDB==false ) {
				requiredMigrations.up.push( migInCode );
			}
		}
		return requiredMigrations;
	}

	/**
	Attempt to sync the migrations in the DB to match the code.
	The migrations that need to be run will be fetched using `fetchRequiredMigrations`.
	If they are able to be run automatically, the `down` migrations will be applied, followed by the `up` migrations.
	If they can not run automatically, this will return a list of migrations that must be run down from a different code branch.
	**/
	public function syncMigrationsUp():Outcome<Noise,Array<Migration>> {
		var requiredMigrations = findRequiredMigrations();
		if ( requiredMigrations.autoDown ) {
			applyMigrations( requiredMigrations.down, Down );
			applyMigrations( requiredMigrations.up, Up );
			return Success( Noise );
		}
		else return Failure( requiredMigrations.down );
	}

	/**
	Run a set of migrations against the database.
	**/
	public function applyMigrations( migrations:Array<Migration>, direction:MigrationDirection ):Void {
		if ( !injector.hasMapping(MigrationManager) )
			injector.map( MigrationManager ).asSingleton();
		if ( !injector.hasMapping(Connection) )
			injector.map( Connection ).toValue( Manager.cnx );
		var migrationManager:MigrationManager = throw "NOT IMPLEMENTED"; // Should we @inject it?
		for ( migration in migrations ) {
			var migration = migrationManager.runMigration( migration, direction ).sure();
			switch direction {
				case Up:
					migration.save();
				case Down:
					migration.delete();
			}
		}
	}

	/**
	Transform a schema by applying migrations.

	@param existingSchema The schema we begin with. If you want to start from scratch, provide an empty array.
	@param migrations The migrations that are to be applied.
	@param migrationDirection The direction the migrations should be applied: Up or Down.
	@return A new `DBSchema` array that represents the DB schema after the migrations have been applied. The original schema object will not be changed.
	**/
	public function mutateSchemma( existingSchema:DBSchema, migrations:Array<Migration>, direction:MigrationDirection ):DBSchema {
		var schema = copyExistingSchema( existingSchema );
		for ( migration in migrations ) {
			for ( action in migration.actions ) {
				runActionOnSchema( schema, action, direction );
			}
		}
		return schema;
	}

	public static function copyExistingSchema( existingSchema:DBSchema ):DBSchema {
		var schema = [];
		if ( existingSchema!=null ) {
			for ( table in existingSchema ) {
				// Clone the `table` object to make sure we don't mutate the original schema.
				schema.push({
					tableName: table.tableName,
					fields: [for (f in table.fields) { name:f.name, type:f.type, isNullable:f.isNullable }],
					indicies: [for (i in table.indicies) { fields:i.fields.copy(), unique:i.unique }],
					foreignKeys: [for (f in table.foreignKeys) { fields:f.fields.copy(), relatedTableName:f.relatedTableName, relatedTableFields:f.relatedTableFields, onUpdate:f.onUpdate, onDelete:f.onDelete }],
				});
			}
		}
		return schema;
	}
	public static function sortMigrations( migrations:Array<Migration> ):Array<Migration> {
		migrations.sort( function(m1,m2) return Reflect.compare(m1.migrationID,m2.migrationID) );
		return migrations;
	}
	public static function getTableInSchema( schema:DBSchema, tableName:String ):Null<DBTable> {
		return schema.find( function(dbTable) return dbTable.tableName==tableName );
	}
	public static function getFieldInTable( table:DBTable, fieldName:String ):Null<DBColumn> {
		return table.fields.find( function(column) return column.name==fieldName );
	}
	public static function addTableToSchema( schema:DBSchema, table:DBTable ):Void {
		var existing = getTableInSchema( schema, table.tableName );
		if ( existing!=null )
			throw 'Failed to add table to schema: table ${table.tableName} already existed';
		schema.push({
			tableName: table.tableName,
			fields: table.fields,
			indicies: table.indicies,
			foreignKeys: table.foreignKeys
		});
	}
	public static function removeTableFromSchema( schema:DBSchema, name:String ):Void {
		var existing = getTableInSchema( schema, name );
		if ( existing==null )
			throw 'Failed to drop table from schema: table $name did not exist';
		schema.remove( existing );
	}
	public static function addFieldToSchema( schema:DBSchema, tableName:String, column:DBColumn ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to add field to schema: table $tableName did not exist';
		var existingField = getFieldInTable( existingTable, column.name );
		if ( existingField!=null )
			throw 'Failed to add field to schema: Column ${column.name} on table $tableName already existed';
		existingTable.fields.push({
			name: column.name,
			type: column.type,
			isNullable: column.isNullable,
		});
	}
	public static function modifyFieldInSchema( schema:DBSchema, tableName:String, before:DBColumn, after:DBColumn ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to modify field in schema: table $tableName did not exist';
		var existingField = getFieldInTable( existingTable, before.name );
		if ( existingField==null )
			throw 'Failed to modify field in schema: Column ${before.name} on table $tableName did not exist';
		existingField.name = after.name;
		existingField.type = after.type;
	}
	public static function removeFieldFromSchema( schema:DBSchema, tableName:String, field:DBColumn ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to remove field from schema: table $tableName did not exist';
		var existingField = getFieldInTable( existingTable, field.name );
		if ( existingField==null )
			throw 'Failed to remove field from schema: Column ${field.name} on table $tableName did not exist';
		existingTable.fields.remove( existingField );
	}
	public static function getIndexInTable( table:DBTable, index:DBIndex ):Null<DBIndex> {
		return table.indicies.find( function(i) {
			return '${i.fields}${i.unique}' == '${index.fields}${index.unique}';
		});
	}
	public static function addIndexToSchema( schema:DBSchema, tableName:String, index:DBIndex ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to add index to schema: table $tableName did not exist';
		var existingIndex = getIndexInTable( existingTable, index );
		if ( existingIndex!=null )
			throw 'Failed to add index to schema: An identical index already existed';
		existingTable.indicies.push({
			fields: index.fields,
			unique: index.unique
		});
	}
	public static function removeIndexFromSchema( schema:DBSchema, tableName:String, index:DBIndex ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to remove index from schema: table $tableName did not exist';
		var existingIndex = getIndexInTable( existingTable, index );
		if ( existingIndex==null )
			throw 'Failed to remove index from schema: No such index existed';
		existingTable.indicies.remove( existingIndex );
	}
	public static function getForeignKeyInTable( table:DBTable, foreignKey:DBForeignKey ):Null<DBForeignKey> {
		return table.foreignKeys.find( function(fk) {
			return '${fk.fields}${fk.relatedTableName}' == '${foreignKey.fields}${foreignKey.relatedTableName}';
		});
	}
	public static function addForeignKeyToSchema( schema:DBSchema, tableName:String, key:DBForeignKey ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to add foreign key to schema: table $tableName did not exist';
		var existingForeignKey = getForeignKeyInTable( existingTable, key );
		if ( existingForeignKey!=null )
			throw 'Failed to add foreign key to schema: An identical key already existed';
		existingTable.foreignKeys.push({
			fields: key.fields,
			relatedTableName: key.relatedTableName,
			relatedTableFields: key.relatedTableFields,
			onUpdate: key.onUpdate,
			onDelete: key.onDelete,
		});
	}
	public static function removeForeignKeyFromSchema( schema:DBSchema, tableName:String, key:DBForeignKey ):Void {
		var existingTable = getTableInSchema( schema, tableName );
		if ( existingTable==null )
			throw 'Failed to remove foreign key from schema: table $tableName did not exist';
		var existingKey = getForeignKeyInTable( existingTable, key );
		if ( existingKey==null )
			throw 'Failed to remove foreign key from schema: No such key existed';
		existingTable.foreignKeys.remove( existingKey );
	}
	public static function getTableName( model:Class<Dynamic> ):String {
		var manager = new Manager( model );
		return manager.dbInfos().name;
	}
	public static function sortModelsByJoinOrder( c1:Class<Dynamic>, c2:Class<Dynamic> ):Int {
		var name1 = Type.getClassName( c1 ).split( '.' ).pop();
		var name2 = Type.getClassName( c2 ).split( '.' ).pop();
		return Reflect.compare( name1, name2 );
	}
	public static function getJoinTableDescription( modelAName:String, modelBName:String ):DBTable {
		var modelA = Type.resolveClass( modelAName );
		var modelB = Type.resolveClass( modelBName );
		var tables = [modelA,modelB];
		tables.sort( sortModelsByJoinOrder );
		var tableNames = tables.map( getTableName );
		return {
			tableName: ManyToMany.generateTableName( modelA, modelB ),
			fields: [
				{ name:"id", type:DId, isNullable:false },
				{ name:"created", type:DDateTime, isNullable:false },
				{ name:"modified", type:DDateTime, isNullable:false },
				{ name:"r1", type:DUInt, isNullable:false },
				{ name:"r2", type:DUInt, isNullable:false },
			],
			indicies: [
				{ fields:["r1","r2"], unique:true },
				{ fields:["r1"], unique:false },
				{ fields:["r2"], unique:false },
			],
			foreignKeys: [
				{ fields:["r1"], relatedTableName:tableNames[0], relatedTableFields:["id"], onUpdate:Cascade, onDelete:Cascade },
				{ fields:["r2"], relatedTableName:tableNames[1], relatedTableFields:["id"], onUpdate:Cascade, onDelete:Cascade },
			]
		}
	}
	public static function runActionOnSchema( schema:DBSchema, action:MigrationAction, direction:MigrationDirection ):Void {
		switch direction {
			case Up:
				switch action {
					case CreateTable( table ): addTableToSchema( schema, table );
					case DropTable( table ): removeTableFromSchema( schema, table.tableName );
					case AddField( tableName, column ): addFieldToSchema( schema, tableName, column );
					case ModifyField( tableName, before, after ): modifyFieldInSchema( schema, tableName, before, after );
					case RemoveField( tableName, field ): removeFieldFromSchema( schema, tableName, field );
					case AddIndex( tableName, index ): addIndexToSchema( schema, tableName, index );
					case RemoveIndex( tableName, index ): removeIndexFromSchema( schema, tableName, index );
					case AddForeignKey( tableName, key ): addForeignKeyToSchema( schema, tableName, key );
					case RemoveForeignKey( tableName, key ): removeForeignKeyFromSchema( schema, tableName, key );
					case CreateJoinTable( modelAName, modelBName ): runActionOnSchema( schema, CreateTable(getJoinTableDescription(modelAName,modelBName)), Up );
					case RemoveJoinTable( modelAName, modelBName ): runActionOnSchema( schema, DropTable(getJoinTableDescription(modelAName,modelBName)), Up );
					// The following actions should have no effect on the schema:
					case InsertData( tableName, id, properties ):
					case DeleteData( tableName, id, properties ):
					case CustomMigration( up, down ):
				}
			case Down:
				switch action {
					case CreateTable( table ): removeTableFromSchema( schema, table.tableName );
					case DropTable( table ): addTableToSchema( schema, table );
					case AddField( tableName, column ): removeFieldFromSchema( schema, tableName, column );
					case ModifyField( tableName, before, after ): modifyFieldInSchema( schema, tableName, after, before );
					case RemoveField( tableName, column ): addFieldToSchema( schema, tableName, column );
					case AddIndex( tableName, index ): removeIndexFromSchema( schema, tableName, index );
					case RemoveIndex( tableName, index ): addIndexToSchema( schema, tableName, index );
					case AddForeignKey( tableName, key ): removeForeignKeyFromSchema( schema, tableName, key );
					case RemoveForeignKey( tableName, key ): addForeignKeyToSchema( schema, tableName, key );
					case CreateJoinTable( modelAName, modelBName ): runActionOnSchema( schema, CreateTable(getJoinTableDescription(modelAName,modelBName)), Down );
					case RemoveJoinTable( modelAName, modelBName ): runActionOnSchema( schema, DropTable(getJoinTableDescription(modelAName,modelBName)), Down );
					// The following actions should have no effect on the schema:
					case InsertData( tableName, id, properties ):
					case DeleteData( tableName, id, properties ):
					case CustomMigration( up, down ):
				}
		}
	}
}
