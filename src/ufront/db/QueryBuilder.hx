package ufront.db;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;
using StringTools;
using tink.CoreApi;
using Lambda;
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
		table = null;
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
				this.table = getTableInfoFromType( Context.getType(typeName), this.originalExprs.from.pos );
			case other:
				this.originalExprs.from.reject( 'Should be called on a Class<sys.db.Object>, but was $other' );
		}
	}

	function getTableInfoFromType( t:Type, pos:Position ):SelectTable {
		var modelTable = {
			name:null,
			model:null,
			fields:new Map()
		};
		switch t {
			case TInst(_.get() => classType, []):
				modelTable.name = getTableNameFromClassType( classType );
				modelTable.model = classType;
				addFieldsFromClassTypeToTable( classType, modelTable );
			case _:
				Context.error( 'Expected a class, but ${t.toString()} was $t', pos );
		}
		return modelTable;
	}

	/**
	Get all of the fields in the model which are accessible for select queries.
	**/
	@:access( ufront.db.DBMacros )
	function addFieldsFromClassTypeToTable( classType:ClassType, modelTable:SelectTable ) {
		// Add super-fields first.
		if ( classType.superClass!=null ) {
			var superClassType = classType.superClass.t.get();
			addFieldsFromClassTypeToTable( superClassType, modelTable );
		}
		// Add any fields which are probably in the database. (Not skipped, and a var rather than a method).
		for ( classField in classType.fields.get() ) {
			if ( classField.meta.has(":skip")==false && classField.kind.match(FVar(_,_)) ) {
				// Add all fields that are columns in the database.
				modelTable.fields.set( classField.name, Left(classField) );
			}
			else {
				// Add any fields which are related tables (joins)
				function addJoinField( relatedModel:Type, joinType:JoinType ) {
					var relatedTable = Lazy.ofFunc( getTableInfoFromType.bind(relatedModel,classField.pos) );
					var joinDescription = { relatedTable:relatedTable, usedInQuery:false, type:joinType };
					modelTable.fields.set( classField.name, Right(joinDescription) );
				}
				switch classField.type {
					case TType(_.get() => { module:"ufront.db.Object", name:"HasOne" }, [relatedModel]):
						var relationKey = DBMacros.getRelationKeyForField( modelTable.model.name, classField );
						addJoinField( relatedModel, JTHasOne(relationKey) );
					case TType(_.get() => { module:"ufront.db.Object", name:"HasMany" }, [relatedModel]):
						var relationKey = DBMacros.getRelationKeyForField( modelTable.model.name, classField );
						addJoinField( relatedModel, JTHasMany(relationKey) );
					case TType(_.get() => { module:"ufront.db.Object", name:"BelongsTo" }, [relatedModel]):
						addJoinField( relatedModel, JTBelongsTo );
					case TType(_.get() => { module:"ufront.db.ManyToMany", name:"ManyToMany" }, [_,relatedModel]):
						addJoinField( relatedModel, JTManyToMany );
					case TType(_, _):
						// TODO: follow typedefs recursively to see if there is a typedef to one of the above relation types.
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
		var errorMsg = 'Unexpected expression in field list';
		for ( field in this.originalExprs.fields ) {
			switch field {
				case macro $alias = $column:
					var aliasParts = extractFieldAccessParts( alias, errorMsg );
					var fieldParts = extractFieldAccessParts( column, errorMsg );
					addField( aliasParts, fieldParts, field.pos );
				case macro $column:
					var fieldParts = extractFieldAccessParts( column, errorMsg );
					addField( fieldParts.copy(), fieldParts, field.pos );
			}
		}
	}

	function extractFieldAccessParts( e:Expr, errorMsg:String ):Array<String> {
		switch e {
			case macro $i{ident}:
				return [ident];
			case macro $expr.$fieldAccess:
				var arr = extractFieldAccessParts( expr, errorMsg );
				arr.push( fieldAccess );
				return arr;
			case _:
				e.reject( '$errorMsg: ${e.toString()}' );
				return [];
		}
	}

	function addField( aliasParts:Array<String>, fieldParts:Array<String>, pos:Position ) {
		// If the alias is a property access, drill down through the parent fields to get the relevant SelectField.
		var currentFields = this.fields;
		var field:SelectField = null;
		while ( aliasParts.length>0 ) {
			var aliasName = aliasParts.shift();
			field = currentFields.find(function(f) return f.name==aliasName);
			if ( field==null ) {
				field = {
					name:aliasName,
					resultSetField:null,
					type:null,
					pos:pos
				};
				currentFields.push( field );
			}
			// If there are still more fields to come, set this one up as a parent.
			if ( aliasParts.length>0 && field.type==null ) {
				currentFields = [];
				field.type = Right(currentFields);
			}
			else if ( aliasParts.length>0 ) {
				switch field.type {
					case Right(subFields):
						currentFields = subFields;
					case Left(_):
						Context.error( 'The field alias ${aliasParts.join(".")} part $aliasName is being used as both a column and a join', pos );
				}
			}
		}
		// Now that we have the relevant SelectField, set the details.
		var colPair = getColumn( fieldParts, pos );
		var selectTable = colPair.a;
		var classField = colPair.b;
		field.type = Left( classField.type );
		field.resultSetField = '${selectTable.name}.${classField.name}';
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
					// TODO: refactor this to use extractFieldAccessParts and support join columns
					var columnName = columnIdent.substr(1);
					var pair = getColumn( [columnName], field.pos );
					var table = pair.a;
					var field = pair.b;
					{ column:Left({ table:table.name, column:field.name }), direction:direction };
				case macro $expr:
					// It is probably a runtime expression, we'll ask the compiler to check it is a String.
					{ column:Right(macro @:pos(expr.pos) ($expr:String)), direction:direction };
			}
			orderBy.push( orderByEntry );
		}
	}

	function getColumn( columnParts:Array<String>, pos:Position ):Pair<SelectTable,ClassField> {
		// TODO: Consider if it is feasible to support field aliases
		var currentTable:SelectTable = table;
		while ( columnParts.length>0 ) {
			var part = columnParts.shift();
			var field = currentTable.fields.get( part );
			if ( field!=null ) {
				switch field {
					case Left(classField):
						if ( columnParts.length==0 )
							return new Pair( currentTable, classField );
						else
							Context.error( 'Cannot access property "${columnParts.join(".")}" on column "$part" on table "${currentTable.name}"', pos );
					case Right(joinDescription):
						currentTable = joinDescription.relatedTable.get();
						// Mark this join as being used so we include it in the query.
						joinDescription.usedInQuery = true;
				}
			}
			else Context.error( 'Column $part does not exist on table ${currentTable.name}', pos );
		}
		return null;
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
		var table = generateTable();
		var fields = generateSelectQueryFields();
		var where = generateWhere();
		var orderBy = generateOrderBy();
		var limit = generateLimit();

		return macro 'SELECT '+$fields
			+" FROM "+$table
			+" "+$where
			+" "+$orderBy
			+" "+$limit;
	}

	function generateTable():Expr {
		var tableAndJoins = addJoins( table.name, table );
		var ret = macro $v{tableAndJoins};
		return ret;
	}

	function addJoins( tableAndJoins:String, currentTable:SelectTable ):String {
		for ( fieldName in currentTable.fields.keys() ) {
			switch currentTable.fields[fieldName] {
				case Right(join) if (join.usedInQuery):
					switch join.type {
						case JTHasOne(relKey):
							var relatedTable = join.relatedTable.get();
							var joinStatement = 'JOIN ${relatedTable.name} ON ${relatedTable.name}.${relKey} = ${currentTable.name}.id';
							tableAndJoins = '$tableAndJoins $joinStatement';
							tableAndJoins = addJoins( tableAndJoins, relatedTable );
						case JTHasMany(relKey):
							throw "HasMany Joins are not supported yet";
						case JTBelongsTo:
							var relatedTable = join.relatedTable.get();
							var joinStatement = 'JOIN ${relatedTable.name} ON ${relatedTable.name}.id = ${currentTable.name}.${fieldName}ID';
							tableAndJoins = '$tableAndJoins $joinStatement';
							tableAndJoins = addJoins( tableAndJoins, relatedTable );
						case JTManyToMany:
							throw "ManyToMany Joins are not supported yet";
					}
				case _:
			}
		}
		return tableAndJoins;
	}

	function generateSelectQueryFields():Expr {
		if ( fields.length>0 ) {
			var fieldNames = [];
			for ( f in fields ) {
				addFieldToFieldList( f, "", fieldNames );
			}
			return macro $v{fieldNames.join(", ")};
		}
		else return macro "*";
	}

	function addFieldToFieldList( f:SelectField, prefix:String, fieldNames:Array<String> ) {
		switch f.type {
			case Left(t):
				fieldNames.push( '${f.resultSetField} AS ${prefix}${f.name}' );
			case Right(subfields):
				for ( subfield in subfields ) {
					addFieldToFieldList( subfield, prefix+f.name+"_", fieldNames );
				}
		}
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
				// TODO: support field access / joins.
				// case $i{columnName}.$fieldAccess if (exprIsColumn(expr))
				// OR use extractFieldAccessParts.
				case macro $i{_.substr(1) => colName} if (exprIsColumn(expr)):
					getColumn( [colName], expr.pos );
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
					case Left(details):
						macro $v{details.table}+"."+$v{details.column};
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
		return
			if ( limitOffset!=null && limitCount!=null ) macro "LIMIT "+$limitOffset+", "+$limitCount;
			else macro "";
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
	fields:Map<String,Either<ClassField,JoinDescription>>
}
typedef JoinDescription = {
	relatedTable:Lazy<SelectTable>,
	usedInQuery:Bool,
	type:JoinType
}
enum JoinType {
	JTBelongsTo;
	JTHasOne( relationKey:String );
	JTHasMany( relationKey:String );
	JTManyToMany;
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
typedef OrderBy = {
	/** Either a static table/column name, or a runtime expression which will give the table/column name. **/
	column:Either<{ table:String, column:String },ExprOf<String>>,
	/** Ascending or Descending? **/
	direction:SortDirection
}
@:enum abstract SortDirection(String) to String {
	var Ascending = "ASC";
	var Descending = "DESC";
}
