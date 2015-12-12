package ufront.db.migrations;

#if macro
import ufront.db.migrations.Migration;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.Serializer;
import sys.io.File;

/**
// On each of your files that might contain models:
--macro ufront.db.migrations.MigrationCreator.exportSchemaToFile( "server.schema" );
--macro ufront.db.migrations.MigrationCreator.exportSchemaToFile( "client.schema" );
--macro ufront.db.migrations.MigrationCreator.exportSchemaToFile( "tasks.schema" );

// Then, on your task runner (or whatever you use to do your migrations):
--macro ufront.db.migrations.MigrationCreator.exportSchemaToFile( "tasks.schema" );
**/
class MigrationCreator {
	/**
	Find every model used in this build and export the resulting schema to a file.
	**/
	public static function exportSchemaToFile( filename:String ):Void {
		Context.onGenerate(function(types) {
			var schema:DBSchema = [];
			for ( t in types ) {
				var dbTable = getDBTableFromType( t );
				if ( dbTable!=null ) {
					schema.push( dbTable );
				}
			}
			// TODO: figure out if we need to include ManyToMany join tables in our schema. And if we do, how?
			var serializedSchema = Serializer.run( schema );
			File.saveContent( filename, serializedSchema );
		});
	}

	// public static function

	static function getDBTableFromType( t:Type ):DBTable {
		return throw "TODO: implement";
	}
}
#end
