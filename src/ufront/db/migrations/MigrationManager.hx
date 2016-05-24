package ufront.db.migrations;

import ufront.db.migrations.Migration;
using tink.CoreApi;

class MigrationManager {

	var cnx:MigrationConnection;

	@inject
	public function new( cnx:MigrationConnection ) {
		this.cnx = cnx;
	}

	/**
	Run a migration `Up`, applying each action to the database.

	@param The migration to run.
	@param The direction to run the migration.
	@return The migration, but with the actions modified and ready to be saved to the DB.
	**/
	public function runMigration( migration:Migration, direction:MigrationDirection ):Outcome<Migration,Error> {
		for ( i in 0...migration.actions.length ) {
			var action = migration.actions[i];
			switch runAction( action, direction ) {
				case Success(actionToSave):
					migration.actions[i] = actionToSave;
				case Failure(err):
					return Failure(err);
			}
		}
		return Success( migration );
	}

	/**
	Run a migration action in the specified direction, applying it to the database.

	@param The action to run.
	@param The direction to run the action.
	@return A version of the action that can be serialized and saved in the migrations table.
	**/
	public function runAction( action:MigrationAction, direction:MigrationDirection ):Outcome<MigrationAction,Error> {
		return switch direction {
			case Up:
				runUp( action );
			case Down:
				runDown( action );
		}
	}

	/**
	Run a migration action `Up`, applying it to the database.

	@param The action to run up.
	@return A version of the action that can be serialized and saved in the migrations table.
	**/
	public function runUp( action:MigrationAction ):Outcome<MigrationAction,Error> {
		return switch action {
			case CreateTable( table ):
				cnx.createTable( table );
				Success( action );
			case DropTable( table ):
				cnx.dropTable( table );
				Success( action );
			case AddField( tableName, field ):
				cnx.addField( tableName, field );
				Success( action );
			case ModifyField( tableName, before, after ):
				cnx.modifyField( tableName, before, after );
				Success( action );
			case RemoveField( tableName, field ):
				cnx.removeField( tableName, field );
				Success( action );
			case AddIndex( tableName, index ):
				cnx.addIndex( tableName, index );
				Success( action );
			case RemoveIndex( tableName, index ):
				cnx.removeIndex( tableName, index );
				Success( action );
			case AddForeignKey( tableName, foreignKey ):
				cnx.addForeignKey( tableName, foreignKey );
				Success( action );
			case RemoveForeignKey( tableName, foreignKey ):
				cnx.removeForeignKey( tableName, foreignKey );
				Success( action );
			case CreateJoinTable( modelAName, modelBName ):
				cnx.createJoinTable( modelAName, modelBName );
				Success( action );
			case RemoveJoinTable( modelAName, modelBName ):
				cnx.removeJoinTable( modelAName, modelBName );
				Success( action );
			case InsertData( tableName, columns, data ):
				var newData = cnx.insertData( tableName, columns, data );
				Success( InsertData(tableName,columns,newData) );
			case DeleteData( tableName, columns, data ):
				cnx.deleteData( tableName, columns, data );
				Success( action );
			case CustomMigration( up, down ):
				cnx.customMigration( up );
				Success( CustomMigration(null,null) );
		}
	}

	/**
	Run a migration action `Down`, reversing it on the database.

	@param The action to run down.
	@return A version of the action that can be serialized and saved in the migrations table.
	**/
	public function runDown( action:MigrationAction ):Outcome<MigrationAction,Error> {
		return switch action {
			case CreateTable( table ):
				cnx.dropTable( table );
				Success( action );
			case DropTable( table ):
				cnx.createTable( table );
				Success( action );
			case AddField( tableName, field ):
				cnx.removeField( tableName, field );
				Success( action );
			case ModifyField( tableName, before, after ):
				cnx.modifyField( tableName, after, before );
				Success( action );
			case RemoveField( tableName, field ):
				cnx.addField( tableName, field );
				Success( action );
			case AddIndex( tableName, index ):
				cnx.removeIndex( tableName, index );
				Success( action );
			case RemoveIndex( tableName, index ):
				cnx.addIndex( tableName, index );
				Success( action );
			case AddForeignKey( tableName, foreignKey ):
				cnx.removeForeignKey( tableName, foreignKey );
				Success( action );
			case RemoveForeignKey( tableName, foreignKey ):
				cnx.addForeignKey( tableName, foreignKey );
				Success( action );
			case CreateJoinTable( modelAName, modelBName ):
				cnx.removeJoinTable( modelAName, modelBName );
				Success( action );
			case RemoveJoinTable( modelAName, modelBName ):
				cnx.createJoinTable( modelAName, modelBName );
				Success( action );
			case InsertData( tableName, columns, data ):
				cnx.deleteData( tableName, columns, data );
				Success( action );
			case DeleteData( tableName, columns, data ):
				var newData = cnx.insertData( tableName, columns, data );
				Success( InsertData(tableName,columns,newData) );
			case CustomMigration( up, down ):
				cnx.customMigration( down );
				Success( CustomMigration(null,null) );
		}
	}
}
