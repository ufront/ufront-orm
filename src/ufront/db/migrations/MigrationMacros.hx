package ufront.db.migrations;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.Serializer;
import sys.io.File;
import ufront.db.migrations.DBSchema;

/**
The plan.
- Add an onGenerate call that gets the DBSchema based on all types that are sys.db.Object
- Add an onGenerate call that gets the DBSchema based on all types that are ufront.db.migrations.Migration
- Diff them to find out what needs to change, and generate (and save!) a MyNewMigrations.hx file as a result.
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

	public static function exportSchema() {

		Context.onGenerate(function(types) {
			var migrationSchema:DBSchema = [];
			var modelSchema:DBSchema = [];

			var modelClassType = getClassTypeFromType(Context.getType( "sys.db.Object" ));
			var migrationClassType = getClassTypeFromType(Context.getType( "ufront.db.migration.Migration" ));
			for ( t in types ) {
				var ct = getClassTypeFromType(t);
				if ( isSubclassOf(ct,modelClassType) ) {
					var dbTable = getDBTableFromMigrationType( t );
					modelSchema.push( dbTable );
				}
				else if ( isSubclassOf(ct,migrationClassType) ) {
					var dbTable = getDBTableFromModelType( t );
					migrationSchema.push( dbTable );
				}
			}
		});

	}

	static function getClassTypeFromType(t:Type):Ref<ClassType> {
		return switch t {
			case TInst(ctRef, _): ctRef;
			case _: throw 'Type was not a class: $t';
		};
	}

	static function isSubclassOf( ctRef:Ref<ClassType>, parentClass:Ref<ClassType> ) {
		var ct = ctRef.get();
		if (ct.superClass!=null) {
			if (ct.superClass.t.toString()==parentClass.toString()) {
				return true;
			}
			return isSubclassOf(ct.superClass.t, parentClass);
		}
		return false;
	}

	static function getDBTableFromModelType( t:Type ):DBTable {
		return throw "TODO: implement";
	}

	static function getDBTableFromMigrationType( t:Type ):DBTable {
		return throw "TODO: implement";
	}
}
