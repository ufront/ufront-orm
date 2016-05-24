package ufront.db.migrations;

import ufront.db.migrations.Migration;
import sys.db.Connection;
import sys.db.TableCreate;
import sys.db.Types;
import sys.db.RecordInfos;
import sys.db.Manager;

class MigrationConnection {

	var cnx:Connection;

	@inject
	public function new( cnx:Connection ) {
		this.cnx = cnx;
	}

	public function createTable( table:DBTable ) {
		var s = new StringBuf();
		s.add( 'CREATE TABLE ' );
		s.add( cnx.quote(table.tableName) );
		s.add( '\n(\n' );
		var decls = [];
		for( column in table.fields )
			decls.push( getColumnDefinition(cnx.dbName(),column) );
		if( cnx.dbName()!="SQLite" )
			decls.push( "PRIMARY KEY ('id')" );
		for ( key in table.foreignKeys )
			decls.push( getForeignKeyDefinition(table.tableName,key) );
		for ( index in table.indicies )
			decls.push( getIndexDefinition(table.tableName,index) );
		s.add( decls.join(",\n") );
		s.add( "\n)" );
		cnx.request( s.toString() );
	}

	public function dropTable( table:DBTable ) {
		cnx.request( 'DROP TABLE ${table.tableName}' );
	}

	public function addField( tableName:String, field:DBColumn ) {
		var tableName = quoteField( tableName );
		var fieldDefinition = getColumnDefinition( cnx.dbName(), field );
		cnx.request( 'ALTER TABLE $tableName ADD $fieldDefinition' );
	}

	public function modifyField( tableName:String, before:DBColumn, after:DBColumn ) {
		var tableName = quoteField( tableName );
		var oldFieldName = quoteField( before.name );
		var newFieldDefinition = getColumnDefinition( cnx.dbName(), after );
		cnx.request( 'ALTER TABLE $tableName CHANGE $oldFieldName $newFieldDefinition' );
	}

	public function removeField( tableName:String, field:DBColumn ) {
		var tableName = quoteField( tableName );
		var fieldName = quoteField( field.name );
		cnx.request( 'ALTER TABLE $tableName DROP $fieldName' );
	}

	public function addIndex( tableName:String, index:DBIndex ) {
		var tableName = quoteField( tableName );
		var indexDefinition = getIndexDefinition( tableName, index );
		cnx.request( 'ALTER TABLE $tableName ADD $indexDefinition' );
	}

	public function removeIndex( tableName:String, index:DBIndex ) {
		var tableName = quoteField( tableName );
		var indexName = getIndexName( tableName, index );
		cnx.request( 'ALTER TABLE $tableName DROP INDEX $indexName' );
	}

	public function addForeignKey( tableName:String, foreignKey:DBForeignKey ) {
		var tableName = quoteField( tableName );
		var foreignKeyDefinition = getForeignKeyDefinition( tableName, foreignKey );
		cnx.request( 'ALTER TABLE $tableName ADD $foreignKeyDefinition' );
	}

	public function removeForeignKey( tableName:String, foreignKey:DBForeignKey ) {
		var tableName = quoteField( tableName );
		var foreignKeyName = getForeignKeyName( tableName, foreignKey );
		cnx.request( 'ALTER TABLE $tableName DROP FOREIGN KEY $foreignKeyName' );
	}

	public function createJoinTable( modelAName:String, modelBName:String ) {
		var dbTable = MigrationApi.getJoinTableDescription( modelAName, modelBName );
		createTable( dbTable );
	}

	public function removeJoinTable( modelAName:String, modelBName:String ) {
		var dbTable = MigrationApi.getJoinTableDescription( modelAName, modelBName );
		dropTable( dbTable );
	}

	public function insertData( tableName:String, columns:Array<String>, data:Array<{ id:Null<Int>, values:Array<Dynamic> }> ) {
		var tableName = quoteField( tableName );
		var queryStart = 'INSERT INTO $tableName';
		queryStart += '(' + columns.map( quoteField ).join( ", " ) + ')';
		queryStart += ' VALUES\n';
		// Save one row at a time, keeping track of the IDs created.
		for ( row in data ) {
			var s = new StringBuf();
			s.add( queryStart );
			s.add( '(' );
			var firstValue = false;
			for ( val in row.values ) {
				cnx.addValue( s, val );
				if ( !firstValue ) firstValue = true;
				else s.add( ', ' );
			}
			s.add( ')' );
			cnx.request( s.toString() );
			row.id = cnx.lastInsertId();
		}
		return data;
	}

	public function deleteData( tableName:String, columns:Array<String>, data:Array<{ id:Null<Int>, values:Array<Dynamic> }> ) {
		var tableName = quoteField( tableName );
		var ids = [for (row in data) if (row.id!=null) row.id];
		var whereCondition = Manager.quoteList( 'id', ids );
		cnx.request( 'DELETE FROM $tableName WHERE $whereCondition' );
	}

	public function customMigration( fn:Void->Void ) {
		fn();
	}

	static function quoteField( name:String ):String {
		return @:privateAccess Manager.KEYWORDS.exists(name.toLowerCase()) ? '`$name`' : name;
	}

	static function getColumnDefinition( dbName:String, column:DBColumn ):String {
		if( dbName=="SQLite" && column.type.match(DUId | DBigId) ) {
			throw "S" + Std.string( column.type ).substr(1) + ' is not supported by $dbName : use SId instead';
		}
		var colName = quoteField( column.name );
		var colType = TableCreate.getTypeSQL( column.type, dbName );
		var colisNullable = column.isNullable ? "" : "NOT NULL";
		return '$colName $colType $colisNullable';
	}

	static function getForeignKeyDefinition( tableName:String, key:DBForeignKey ):String {
		var keyName = getForeignKeyName( tableName, key );
		var keys = quoteField( key.fields.join(", ") );
		var relatedTable = quoteField( key.relatedTableName );
		var relatedKeys = key.relatedTableFields.map( quoteField ).join( ", " );
		if ( key.onUpdate==null )
			key.onUpdate = Restrict;
		if ( key.onDelete==null )
			key.onDelete = Restrict;
		return
			'CONSTRAINT $keyName FOREIGN KEY ($keys)'
			+' REFERENCES $relatedTable($relatedKeys)'
			+' ON UPDATE ${key.onUpdate} ON DELETE ${key.onDelete}';
	}

	static function getForeignKeyName( tableName:String, key:DBForeignKey ):String {
		return quoteField( tableName+"_"+key.fields.join("_") );
	}

	static function getIndexDefinition( tableName:String, index:DBIndex ):String {
		var unique = if ( index.unique ) "UNIQUE" else "";
		var indexName = getIndexName( tableName, index );
		var keys = index.fields.map( quoteField ).join( "," );
		return '${unique} KEY ${indexName} ($keys)';
	}

	static function getIndexName( tableName:String, index:DBIndex ):String {
		return quoteField( tableName+"_"+index.fields.join("_") );
	}

}
