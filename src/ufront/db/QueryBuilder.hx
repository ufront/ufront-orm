package ufront.db;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;
using StringTools;
using tink.CoreApi;
#if macro
using tink.MacroApi;
#end

class QueryBuilder {
	public static macro function generateSelect( rest:Array<Expr> ) {
		var qb = new QueryBuilder();
		qb.extractExpressionsFromSelectCall( rest );
		qb.getModelClassType();
		qb.processFields();
		qb.processLimit();
		return qb.generateSelectQuery();
	}

	#if (macro || display)

	var originalExprs:{
		from:Expr,
		fields:Array<Expr>,
		where:Array<Expr>,
		limit:Pair<Expr,Expr>,
		orderBy:Array<Expr>
	};
	var table:SelectTable;
	var fields:Array<SelectField>;
	var limitOffset:Expr;
	var limitCount:Expr;

	public function new() {
		originalExprs = {
			from:null,
			fields:[],
			where:[],
			limit:null,
			orderBy:[]
		};
		table = {
			name:null,
			model:null,
			joins:[],
			fields:new Map()
		};
		fields = [];
	}

	/**
	Extract the relevant expressions from a select() call.
	**/
	function extractExpressionsFromSelectCall( args:Array<Expr> ) {
		for ( queryPartExpr in args ) switch queryPartExpr {
			case macro From($modelClassExpr):
				if ( this.originalExprs.from!=null )
					Context.error( 'Only one From() is allowed per select query', queryPartExpr.pos );
				this.originalExprs.from = modelClassExpr;
			case macro Fields($a{fields}):
				for ( fieldNameExpr in fields )
					this.originalExprs.fields.push( fieldNameExpr );
			case macro Where($a{whereConds}):
				for ( whereCondExpr in whereConds )
					this.originalExprs.where.push( whereCondExpr );
			case macro Limit($a{limitExprs}):
				if ( limitExprs.length>2 )
					Context.error( 'Limit should be in format: Limit(offset,number) or Limit(number)', limitExprs[2].pos );
				if ( this.originalExprs.limit!=null )
					Context.error( 'Only one Limit() is allowed per select query', queryPartExpr.pos );
				this.originalExprs.limit = new Pair( limitExprs[0], limitExprs[1] );
			case macro OrderBy($a{orderConds}):
				for ( orderByExpr in orderConds )
					this.originalExprs.orderBy.push( orderByExpr );
			case _:
				Context.error( 'Unknown query expression: ' + queryPartExpr.toString(), queryPartExpr.pos );
		}
	}

	/**
	From an expression of a class, eg `EConst(CIdent(app.model.Person))`, find the matching `ClassType`.
	**/
	function getModelClassType() {
		switch Context.typeof( this.originalExprs.from ) {
			case TType(_.get() => tdef, []) if (tdef.name.startsWith("Class<") && tdef.name.endsWith(">")):
				var typeName = tdef.name.substring("Class<".length, tdef.name.length-1);
				switch Context.getType( typeName ) {
					case TInst(_.get() => classType, []):
						this.table.name = getTableNameFromClassType( classType );
						this.table.model = classType;
						addFieldsFromClassTypeToContext( classType );
					case _:
						Context.error( 'Expected From() to contain a class, but was '+typeName, this.originalExprs.from.pos );
				}
			case other:
				Context.error( 'Expected From() to contain a class, but was '+other, this.originalExprs.from.pos );
		}
	}

	/**
	Get all of the fields in the model which are accessible for select queries.
	**/
	function addFieldsFromClassTypeToContext( classType:ClassType ) {
		// Add super-fields first.
		if ( classType.superClass!=null ) {
			var superClassType = classType.superClass.t.get();
			addFieldsFromClassTypeToContext( superClassType );
		}
		// Add any fields which are probably in the database. (Not skipped, and a var rather than a method).
		for ( classField in classType.fields.get() ) {
			if ( classField.meta.has(":skip")==false && classField.kind.match(FVar(_,_)) ) {
				this.table.fields.set( classField.name, classField );
			}
		}
	}

	function getTableNameFromClassType( ct:ClassType ):String {
		if ( ct.meta.has(":table") ) {
			var tableMeta = ct.meta.extract(":table")[0];
			if (tableMeta!=null && tableMeta.params!=null && tableMeta.params[0]!=null) {
				return tableMeta.params[0].getString().sure();
			}
		}
		return ct.name;
	}

	/**
	Process and validates the fields we are supposed to be selecting.
	**/
	function processFields() {
		for ( field in this.originalExprs.fields ) {
			switch field {
				case macro $i{aliasName} = $i{fieldName}:
					this.fields.push( getFieldDetails(aliasName,fieldName,this.table,field.pos) );
				case macro $i{fieldName}:
					this.fields.push( getFieldDetails(fieldName,fieldName,this.table,field.pos) );
				case _:
			}
			trace( field.toString() );
		}
	}

	function getFieldDetails( aliasName:String, fieldName:String, table:SelectTable, pos:Position ):SelectField {
		var classField = table.fields.get( fieldName );
		if ( classField==null )
			Context.error( 'Table ${table.name} has no column ${fieldName}', pos );
		// TODO: Add support for our related objects. We'll also need to make sure they're not skipped during `addFieldsFromClassTypeToContext`.
		return {
			name: aliasName,
			resultSetField: table.name + "." + fieldName,
			type: Left( classField.type )
		};
	}

	/**
	Process and validates the Limit() if there is one.
	**/
	function processLimit() {
		if ( this.originalExprs.limit!=null ) {
			var limit = this.originalExprs.limit;
			if ( limit.a!=null && limit.b!=null ) {
				// Use ECheckType and position metadata to give good error messages when there's something other than int.
				limitOffset = macro @:pos(limit.a.pos) (${limit.a}:Int);
				limitCount = macro @:pos(limit.b.pos) (${limit.b}:Int);
			}
			else {
				// Use ECheckType and position metadata to give good error messages when there's something other than int.
				limitOffset = macro 0;
				limitCount = macro @:pos(limit.a.pos) (${limit.a}:Int);
				limitCount.pos = limit.a.pos;
			}
		}
	}

	function generateSelectQuery():Expr {
		var table = macro $v{this.table.name};
		var fields = generateSelectQueryFields();
		var joins = macro "";
		var where = macro "";
		var orderBy = macro "";
		var limit = generateSelectQueryLimit();

		return macro 'SELECT '+$fields
			+" FROM "+$table
			+" "+$joins
			+" "+$where
			+" "+$orderBy
			+" "+$limit;
	}

	function generateSelectQueryFields():Expr {
		if ( fields.length>0 ) {
			var fieldNames = [];
			for ( f in fields ) {
				fieldNames.push( '${f.resultSetField} AS ${f.name}' );
			}
			return macro $v{fieldNames.join(", ")};
		}
		else return macro "*";
	}

	function generateSelectQueryLimitOrderBy():Expr {
		// TODO: make sure we are quoting these, checking for SQL injections.
		return macro "ORDER BY ___________";
	}

	function generateSelectQueryLimit():Expr {
		// TODO: make sure we are quoting these, checking for SQL injections.
		// TODO: think about supporting SQL Server 2012 syntax: http://stackoverflow.com/a/9241984/180995
		return macro "LIMIT "+$limitOffset+", "+$limitCount;
	}
	#end
}

typedef SelectTable = {
	name:String,
	model:ClassType,
	joins:Array<{ table:SelectTable, type:JoinType, leftField:String, rightField:String }>,
	fields:Map<String,ClassField>
}
@:enum abstract JoinType(String) from String to String {
	var Inner = "INNER JOIN";
	var Left = "LEFT JOIN";
	var Right = "LEFT JOIN";
}
typedef SelectField = {
	/** The name (or alias) of the field. **/
	name:String,
	/** The name of the field, as it is on the result set. eg `Student.id`. Will be null if this is a parent field. **/
	resultSetField:Null<String>,
	/** Either the type of this field, or if it is a parent, the group of child fields. **/
	type:Either<Type,Array<SelectField>>,
}
