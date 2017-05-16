package ufront.db.migrations;

import sys.db.RecordInfos.RecordType;

/** A description of a column that exists on a database table. **/
typedef DBColumn = { name:String, type:RecordType, isNullable:Bool };

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
typedef DBForeignKey = { fields:Array<String>, relatedTableName:String, relatedTableFields:Array<String>, onUpdate:Null<DBReferentialAction>, onDelete:Null<DBReferentialAction> };

/** A description of a database table. **/
typedef DBTable = {
	var tableName:String;
	var fields:Array<DBColumn>;
	var indicies:Array<DBIndex>;
	var foreignKeys:Array<DBForeignKey>;
};

/** A schema describing the current state of the database. **/
typedef DBSchema = Array<DBTable>;
