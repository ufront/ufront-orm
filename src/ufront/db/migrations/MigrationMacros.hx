package ufront.db.migrations;

import haxe.macro.Expr;
import haxe.macro.Context;
// import haxe.macro.Type;
// import ufront.db.migrations.Migration;
// import haxe.Serializer;
// import sys.io.File;

// TODO:
// Re-style this is a compile-time command:
// haxe server.hxml --no-output --macro ufront.db.migrations.MigrationMacros.createMigration( "add_user_table" );
// ufront --create-migration server.hxml add_user_table

/**
// On each of your files that might contain models:
--macro ufront.db.migrations.MigrationMacros.exportSchemaToFile( "server.schema" );
--macro ufront.db.migrations.MigrationMacros.exportSchemaToFile( "client.schema" );
--macro ufront.db.migrations.MigrationMacros.exportSchemaToFile( "tasks.schema" );

// Then, on your task runner (or whatever you use to do your migrations):
--macro ufront.db.migrations.MigrationCreator.exportSchemaToFile( "tasks.schema" );
**/
class MigrationMacros {

	/**
	Build macro for `ufront.db.migrations.Migration`.
	Currently only adds `@:table("uf_migration")` metadata to each subclass.
	**/
	public static function migrationBuild():Array<Field> {
		var lc = Context.getLocalClass().get();
		lc.meta.add( ":table", [macro "uf_migration"], lc.pos );
		return null;
	}

	// /**
	// Find every model used in this build and export the resulting schema to a file.
	// **/
	// public static function exportSchemaToFile( filename:String ):Void {
	// 	Context.onGenerate(function(types) {
	// 		var schema:DBSchema = [];
	// 		for ( t in types ) {
	// 			var dbTable = getDBTableFromType( t );
	// 			if ( dbTable!=null ) {
	// 				schema.push( dbTable );
	// 			}
	// 		}
	// 		// TODO: figure out if we need to include ManyToMany join tables in our schema. And if we do, how?
	// 		var serializedSchema = Serializer.run( schema );
	// 		File.saveContent( filename, serializedSchema );
	// 	});
	// }
	//
	// // public static function
	//
	// static function getDBTableFromType( t:Type ):DBTable {
	// 	return throw "TODO: implement";
	// }
}
