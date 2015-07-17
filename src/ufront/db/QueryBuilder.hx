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
	/** Generate a select query on a given model. **/
	public static macro function generateSelect( model:ExprOf<Class<sys.db.Object>>, rest:Array<Expr> ):ExprOf<String> {
		return prepareSelectQuery( model, rest ).generateSelectQuery();
	}

	/** Execute a select query, returning an iterable of each matching row. **/
	public static macro function select( model:ExprOf<Class<sys.db.Object>>, rest:Array<Expr> ):Expr {
		var qb = prepareSelectQuery( model, rest );
		var query = qb.generateSelectQuery();
		var complexType = qb.generateComplexTypeForFields( qb.fields );
		return macro (sys.db.Manager.cnx.request($query):Iterator<$complexType>);
	}

	#if (macro)

	static function prepareSelectQuery( model:ExprOf<Class<sys.db.Object>>, rest:Array<Expr> ):QueryBuilder {
		var qb = new QueryBuilder();
		qb.extractExpressionsFromSelectCall( model, rest );
		qb.getModelClassType();
		qb.processFields();
		qb.processWhere();
		qb.processOrderBy();
		qb.processLimit();
		return qb;
	}

	var originalExprs:{
		from:Expr,
		fields:Array<Expr>,
		where:Array<Expr>,
		limit:Pair<Expr,Expr>,
		orderBy:Array<Expr>
	};
	var table:SelectTable;
	var fields:Array<SelectField>;
	var whereCondition:Expr;
	var limitOffset:Expr;
	var limitCount:Expr;
	var orderBy:Array<OrderBy>;

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
		orderBy = [];
	}

	/**
	Extract the relevant expressions from a select() call.
	**/
	function extractExpressionsFromSelectCall( model:ExprOf<Class<sys.db.Object>>, args:Array<Expr> ) {
		this.originalExprs.from = model;
		for ( queryPartExpr in args ) switch queryPartExpr {
			case macro Fields($a{fields}):
				for ( fieldNameExpr in fields )
					this.originalExprs.fields.push( fieldNameExpr );
			case macro Where($a{whereConds}):
				for ( whereCondExpr in whereConds )
					this.originalExprs.where.push( whereCondExpr );
			case macro Limit($a{limitExprs}):
				if ( limitExprs.length>2 )
					limitExprs[2].reject( 'Limit should be in format: Limit(offset,number) or Limit(number)' );
				if ( this.originalExprs.limit!=null )
					queryPartExpr.reject( 'Only one Limit() is allowed per select query' );
				this.originalExprs.limit = new Pair( limitExprs[0], limitExprs[1] );
			case macro OrderBy($a{orderConds}):
				for ( orderByExpr in orderConds )
					this.originalExprs.orderBy.push( orderByExpr );
			case _:
				queryPartExpr.reject( 'Unknown query expression: '+queryPartExpr.toString() );
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
						this.originalExprs.from.reject( 'Should be called on a Class<sys.db.Object>, but was $typeName' );
				}
			case other:
				this.originalExprs.from.reject( 'Should be called on a Class<sys.db.Object>, but was $other' );
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
				// Add all fields that are columns in the database.
				this.table.fields.set( classField.name, classField );
			}
			else {
				// Add any fields which are related tables (joins)
				switch classField.type {
					case TType(_.get() => { module:"ufront.db.Object", name:"HasOne" }, [relatedModel]):
						this.table.fields.set( classField.name, classField );
					case TType(_.get() => { module:"ufront.db.Object", name:"HasMany" }, [relatedModel]):
						this.table.fields.set( classField.name, classField );
					case TType(_.get() => { module:"ufront.db.Object", name:"BelongsTo" }, [relatedModel]):
						this.table.fields.set( classField.name, classField );
					case TType(_.get() => { module:"ufront.db.ManyToMany", name:"ManyToMany" }, [_,relatedModel]):
						this.table.fields.set( classField.name, classField );
					case _:
				}
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
					field.reject( 'Unexpected expression in field list: ${field.toString()}' );
			}
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
			type: Left( classField.type ),
			pos: pos
		};
	}

	/**
	Process and validate the Where() statements.
	**/
	function processWhere() {
		whereCondition = null;
		switch ( this.originalExprs.where.length ) {
			case 0:
			case 1:
				whereCondition = this.originalExprs.where[0];
			case x:
				whereCondition = macro (${this.originalExprs.where[0]});
				for ( i in 1...x )
					whereCondition = macro $whereCondition && (${this.originalExprs.where[i]});
		}
	}

	/**
	Process and validate the OrderBy() statements.
	**/
	function processOrderBy() {
		for ( field in this.originalExprs.orderBy ) {
			// Extract the direction and the expression that gives us the field.
			var direction:SortDirection,
			    fieldExpr:Expr;
			switch field {
				case macro -$expr: fieldExpr=expr; direction=Descending;
				case macro $expr: fieldExpr=expr; direction=Ascending;
			}
			//
			var orderByEntry = switch fieldExpr {
				case macro $i{columnIdent} if (columnIdent.startsWith("$")):
					// It is a column name.
					var columnName = checkColumnExists( columnIdent.substr(1), field.pos );
					{ column:Left(columnName), direction:direction };
				case macro $i{columnIdent}.$fieldAccess if (columnIdent.startsWith("$")):
					trace( 'We have a field access' );

					var columnName = checkColumnExists( columnIdent.substr(1), field.pos );
					{ column:Left(columnName), direction:direction };
				case macro $expr:
					// It is probably a runtime expression, we'll ask the compiler to check it is a String.
					{ column:Right(macro @:pos(expr.pos) ($expr:String)), direction:direction };
			}
			orderBy.push( orderByEntry );
		}
	}

	function checkColumnExists( columnName:String, pos:Position ) {
		// TODO: Adjust this to support checking columns in related/joined tables.
		// TODO: Consider if it is feasible to support field aliases
		if ( table.fields.exists(columnName)==false ) {
			Context.error( 'Column $columnName does not exist on table ${table.name}', pos );
		}
		return columnName;
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
		var where = generateWhere();
		var orderBy = generateOrderBy();
		var limit = generateLimit();

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

	function generateWhere():Expr {
		function exprIsColumn( expr:Expr ):Bool {
			return switch expr {
				case macro $i{name} if (name.startsWith("$")): true;
				default: false;
			}
		}
		function hasColumnInExpr( expr:Expr ):Bool {
			return expr.has( exprIsColumn );
		}
		function printWhereExpr( expr:Expr ):Expr {
			switch expr {
				case macro ($innerExpr):
					return macro "("+${printWhereExpr(innerExpr)}+")";
				case macro $expr1 && $expr2:
					return macro ${printWhereExpr(expr1)}+" AND "+${printWhereExpr(expr2)};
				case macro $expr1 || $expr2:
					return macro ${printWhereExpr(expr1)}+" OR "+${printWhereExpr(expr2)};
				case macro $colIdent==null, macro null==$colIdent if (exprIsColumn(colIdent)):
					return macro ${printWhereExpr(colIdent)}+" IS NULL";
				case macro $colIdent!=null, macro null!=$colIdent if (exprIsColumn(colIdent)):
					return macro ${printWhereExpr(colIdent)}+" IS NOT NULL";
				case { expr:EBinop(opType,expr1,expr2), pos:p }:
					var expr1IsColumn = exprIsColumn(expr1);
					var expr2IsColumn = exprIsColumn(expr2);
					if ( expr1IsColumn || expr2IsColumn ) {
						var opStr = switch opType {
							case OpEq: "=";
							case OpNotEq: "<>";
							case OpGt: ">";
							case OpGte: ">=";
							case OpLt: "<";
							case OpLte: "<=";
							default:
								expr.reject( 'Unsupported operator in Where() clause, only =,!=,<,>,<=,>= are supported:'+expr.toString() );
								"";
						}
						// Either print the column name or a quoted expression.
						expr1 = expr1IsColumn ? printWhereExpr( expr1 ) : quoteExpr( expr1 );
						expr2 = expr2IsColumn ? printWhereExpr( expr2 ) : quoteExpr( expr2 );
						return macro $expr1+" "+$v{opStr}+" "+$expr2;
					}
					else if ( hasColumnInExpr(expr1) || hasColumnInExpr(expr2) ) {
						expr.reject( 'Comparisons can have only a column or an expression on either side of the operator, not both: '+expr.toString() );
					}
					else {
						expr.reject( 'No column found in expression: '+expr.toString() );
					}
				case macro $i{_.substr(1) => colName} if (exprIsColumn(expr)):
					checkColumnExists( colName, expr.pos );
					return macro $v{colName};
				case _:

			}
			// If no match was found, reject it.
			expr.reject( 'Unsupported expression in Where() clause: '+expr.toString() );
			return macro "";
		}
		return
			if ( whereCondition==null ) macro "";
			else macro "WHERE "+${printWhereExpr(whereCondition)};
	}

	function quoteExpr( e:Expr ) {
		return switch e {
			case macro true: macro "TRUE";
			case macro false: macro "FALSE";
			default: macro sys.db.Manager.quoteAny( $e );
		}
	}

	function generateOrderBy():Expr {
		// TODO: make sure we are quoting these, checking for SQL injections.
		if ( orderBy.length>0 ) {
			var orderExpr = macro "ORDER BY";
			var first = true;
			for ( orderByEntry in orderBy ) {
				var commaExpr = (first) ? macro " " : macro ", ";
				var columnExpr = switch orderByEntry.column {
					case Left(name): macro $v{name};
					case Right(expr): expr;
				}
				var directionExpr = macro $v{(orderByEntry.direction:String)}
				orderExpr = macro $orderExpr + $commaExpr + $columnExpr + " " + $directionExpr;
				first = false;
			}
			return orderExpr;
		}
		else return macro "";
	}

	function generateLimit():Expr {
		// TODO: make sure we are quoting these, checking for SQL injections.
		// TODO: consider how to support SQL Server 2012 syntax: http://stackoverflow.com/a/9241984/180995
		return macro "LIMIT "+$limitOffset+", "+$limitCount;
	}

	function generateComplexTypeForFields( fields:Array<SelectField> ):ComplexType {
		var fieldsForCT:Array<Field> = [];
		for (f in fields) {
			var fieldCT = switch f.type {
				case Left(type): type.toComplex({ direct:true });
				case Right(subfields): generateComplexTypeForFields( subfields );
			}
			var field:Field = {
				pos: f.pos,
				name: f.name,
				kind: FVar(fieldCT, null),
			};
			fieldsForCT.push( field );
		}
		return TAnonymous( fieldsForCT );
	}
	#end
}

typedef SelectTable = {
	name:String,
	model:ClassType,
	joins:Array<JoinDescription>,
	fields:Map<String,ClassField>
}
typedef JoinDescription = {
	table:SelectTable,
	type:JoinType,
	leftField:String,
	rightField:String
};
@:enum abstract JoinType(String) from String to String {
	var InnerJoin = "INNER JOIN";
	var LeftJoin = "LEFT JOIN";
	var RightJoin = "LEFT JOIN";
}
typedef SelectField = {
	/** The name (or alias) of the field. **/
	name:String,
	/** The name of the field, as it is on the result set. eg `Student.id`. Will be null if this is a parent field. **/
	resultSetField:Null<String>,
	/** Either the type of this field, or if it is a parent, the group of child fields. **/
	type:Either<Type,Array<SelectField>>,
	/** The pos this field was declared. **/
	pos:Position,
}
typedef OrderBy = { column:Either<String,ExprOf<String>>, direction:SortDirection }
@:enum abstract SortDirection(String) to String {
	var Ascending = "ASC";
	var Descending = "DESC";
}
