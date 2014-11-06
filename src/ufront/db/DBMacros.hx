package ufront.db;
import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Type;
import sys.db.RecordMacros;
import ufront.util.BuildTools;
using tink.MacroApi;
using StringTools;
using Lambda;

class DBMacros
{
	public static function setupDBObject():Array<Field>
	{
		var fields = BuildTools.getFields();

		fields = setupRelations(fields);
		fields = addManager(fields);
		fields = addValidation(fields);
		fields = addHxSerializeFieldsArray(fields);
		
		// DCE can sometimes cause Bytes.toString() to not be compiled, which causes issues when working with SData.  
		// This is a workaround.
		Compiler.addMetadata( "@:keep", "haxe.io.Bytes", "toString", false );
		return fields;
	}

	#if macro
		static function error(msg:String, p:Position):Dynamic
		{
			#if (haxe_ver >= 3.100)
				return Context.fatalError( msg, p );
			#else
				return Context.error( msg, p );
			#end
		}

		static public function setupRelations(fields:Array<Field>):Array<Field>
		{
			var retFields:Array<Field> = null;

			// Loop over every field.
			// Because we alter the list, loop over a copy so we don't include any new fields.
			for (f in fields.copy())
			{
				// Check we're not dealing with any statics...
				if ((f.access.has(AStatic) || f.access.has(AMacro)) == false)
				{
					switch (f.kind)
					{
						case FVar(TPath(relType), _):
							// See if this var is one of our relationship types, and if so, process it.
							switch (relType)
							{
								case { name: "BelongsTo", pack: _, params: [TPType(TPath(modelType))] }:
									retFields = processBelongsToRelations(fields, f, modelType, false);
								case { name: "HasMany", pack: _, params: [TPType(TPath(modelType))] }:
									retFields = processHasManyRelations(fields, f, modelType);
								case { name: "HasOne", pack: _, params: [TPType(TPath(modelType))] }:
									retFields = processHasOneRelations(fields, f, modelType);
								case { name: "ManyToMany", pack: _, params: [TPType(TPath(modelA)), TPType(TPath(modelB))] }:
									retFields = processManyToManyRelations(fields, f, modelA, modelB);
								// If it was Null<T>, check if it was Null<BelongsTo<T>> and unpack it
								case { name: "Null", pack: _, params: [TPType(TPath(nullType))] }:
									switch (nullType)
									{
										case { name: "BelongsTo", pack: _, params: [TPType(TPath(modelType))] }:
											retFields = processBelongsToRelations(fields, f, modelType, true);
										case _:
									}
								case _:
							}
						// If they're trying to use a relation as a property, give an error
						case FProp(_, _, complexType, _):
							switch (complexType)
							{
								case TPath(t):
									switch (t.name)
									{
										case "HasMany" | "BelongsTo" | "HasOne" | "ManyToMany":
											// The compiler cache can be difficult here.  If a field has already had the macro run,
											// it's affects may be cached - so don't re-apply it.
											// Checking for @:skip metadata is one way to guess that this is the result of the macro,
											// and without it, we can still warn the user that they can only use it as a normal var.
											if (!f.meta.exists(function (metaEntry) return metaEntry.name == ":skip"))
											{
												error('On field `${f.name}`: ${t.name} can only be used with a normal var, not a property.', f.pos);
											}
										default:
									}
								case _:
							}
						case _:
					}
				}
			}
			return (retFields != null) ? retFields : fields;
		}

		static public function addManager(fields:Array<Field>):Array<Field>
		{
			#if (server || (client && ufront_clientds))
				var fieldName = if (Context.defined("server")) "manager" else "clientDS";
				if (fields.filter(function (f) return f.name == fieldName).length == 0)
				{
					// No manager exists, create one
					var classAsComplexType = Context.getLocalClass().toString().asComplexType();
					fields.push(createManagerAndClientDs(classAsComplexType));
				}
			#end
			return fields;
		}

		static public function addValidation(fields:Array<Field>):Array<Field>
		{
			// Create a validation function if it doesn't exist
			var validateFunction = fields.filter(function (f) return f.name == "validate")[0];
			if (validateFunction == null)
			{
				validateFunction = createEmptyValidateFunction();
				fields.push(validateFunction);
			}

			// Loop all fields,
			var ignoreList = ["new", "validate", "id", "created", "modified"];
			var validateFnNames = [];
			var numNullChecks = 1;
			for (f in fields.copy())
			{
				// Skip these ones
				if (ignoreList.has(f.name)) continue;
				if (f.access.has(AStatic) == true) continue;
				if (getMetaFromField(f, ":skip") != null) continue;

				switch (f.kind)
				{
					case FVar(TPath(tp),_):
						// add null checks to validate function
						if (tp.name != "Null" && tp.name != "SNull")
						{
							// If this isn't wrapped in Null<T> or SNull<T>, then add a null-check to validate();
							#if (hxjava || cpp)
							#else
							var nullCheck = macro { if ($i{f.name} == null) validationErrors.set($v{f.name}, $v{f.name} + ' is a required field.'); }
							BuildTools.addLinesToFunction(validateFunction, nullCheck, numNullChecks++);
							#end
						}
					case FFun(fn):
						// See if it's a validation function
						if (f.name.startsWith("validate_"))
						{
							var varName = f.name.substr(9);
							if (fields.filter(function (f) return f.name == varName).length > 0)
							{
								if (fn.args.length == 0)
									validateFnNames.push(f.name);
								else Context.warning('Validation function ${f.name} must have no arguments', f.pos);
							}
							else Context.warning('Validation function ${f.name} had no matching variable $varName', f.pos);
						}
					default: // Only operate on normal variables

				}

				// add validation functions by metadata
				var validateFieldName = "validate_" + f.name;
				var validateFieldFn = fields.filter(function (f) return f.name == validateFieldName)[0];
				if (f.meta!=null) for (meta in f.meta)
				{
					if (meta.name == ":validate")
					{
						var check:Expr;
						try
						{
							var e = f.name.resolve();
							var validationExpr = meta.params[0].substitute({ "_" : e });
							var reason =
								if (meta.params.length>1) meta.params[1];
								else macro $v{f.name} + ' failed validation.';
							// Only bother validating if the value is not null.  If it is null, and it shouldn't be,
							// the null checks above should catch it.
							check = macro if ( $e!=null ) {
								if ( !$validationExpr) validationErrors.set($v{f.name}, $reason);
							}
						}
						catch (e:Dynamic)
						{
							Context.warning('@:validate() metadata must contain a valid Haxe expression that can be used in an if(...) statement.', meta.pos);
							Context.warning(Std.string(e), meta.pos);
						}

						if (validateFieldFn == null)
						{
							validateFieldFn = createEmptyFieldValidateFunction(validateFieldName);
							fields.push(validateFieldFn);
							validateFnNames.push(validateFieldName);
						}
						BuildTools.addLinesToFunction(validateFieldFn, check, 0);
					}
				}
			}

			// Find any validate_varName() functions
			// Place them after null checks
			for (name in validateFnNames)
			{
				var fn = name.resolve();
				var fnCall = macro $fn();
				BuildTools.addLinesToFunction(validateFunction, fnCall, numNullChecks);
			}

			return fields;
		}

		static function addHxSerializeFieldsArray(fields:Array<Field>):Array<Field>
		{
			var serializeFields = [];
			var relationFields = [];

			// Loop all fields, look for fields to include in serialization
			for (f in fields.copy())
			{
				// Skip these ones
				if (f.access.has(AStatic) == true) continue;

				switch (f.kind)
				{
					case FVar(ct,_): // Any database fields are vars.

						// Check they're not skipped, or they have @:includeInSerialization
						var hasSkipMetadata = f.meta.exists(function (mEntry) return mEntry.name == ":skip") == true;
						var hasIncludeMetadata = f.meta.exists(function (mEntry) return mEntry.name == ":includeInSerialization") == true;
						if ( !hasSkipMetadata || hasIncludeMetadata ) {
							serializeFields.push(f.name);
						}


					case FProp(_,_,TPath(tp),_): // All relationships are properties

						// Extract the type
						var className = getRelatedModelTypeFromField(f);
						var foreignKey = getRelationKeyForField(f);
						switch (tp)
						{
							case { name: "BelongsTo", params:_, pack:_, sub:_ }
							   | { name: "Null", params:[TPType(TPath({ name: "BelongsTo", params:_, pack:_, sub:_ }))], pack:_, sub:_ }:
								relationFields.push('${f.name},BelongsTo,$className');
							case { name: "HasOne", params:_, pack:_, sub:_ }:
								relationFields.push('${f.name},HasOne,$className,$foreignKey');
							case { name: "HasMany", params:_, pack:_, sub:_ }:
								relationFields.push('${f.name},HasMany,$className,$foreignKey');
							case { name: "ManyToMany", params:_, pack:_, sub:_ }:
								relationFields.push('${f.name},ManyToMany,$className');
								serializeFields.push("ManyToMany" + f.name);
							default:
						}

					case _:
				}
			}

			// Check for fields in any super classes too...
			var currentClass = Context.getLocalClass().get();
			while (currentClass.superClass != null)
			{
				var s = currentClass.superClass.t.get();
				for (f in s.fields.get())
				{
					var className = getRelatedModelTypeFromField(f);
					var foreignKey = getRelationKeyForField(f);

					switch (f)
					{
						case { kind: FVar(AccNormal, AccNormal) } if (!f.meta.has(":skip")):
							// Any database fields are vars
							serializeFields.push(f.name);
						case { kind: FVar(AccCall,_), type: TType(t,_) }:
							// All relationships are properties
							if (t.get().name == "BelongsTo") relationFields.push('${f.name},BelongsTo,$className');
							else if (t.get().name == "HasOne") relationFields.push('${f.name},HasOne,$className,$foreignKey');
							else if (t.get().name == "HasMany") relationFields.push('${f.name},HasMany,$className,$foreignKey');
						case { kind: FVar(AccCall,_), type: TInst(t,_) }:
							if (t.get().name == "ManyToMany")
							{
								relationFields.push('${f.name},ManyToMany,$className');
								serializeFields.push("ManyToMany" + f.name);
							}
						default:
					}
				}
				currentClass = s;
			}

			// Create a hxSerializeFields static var if it doesn't exist
			var fieldsArray = fields.filter(function (f) return f.name == "hxSerializeFields")[0];
			if (fieldsArray == null)
			{
				fieldsArray = createFieldsArray();
				fields.push(fieldsArray);
			}
			switch (fieldsArray.kind)
			{
				case FVar(t, _):
					serializeFields.sort(Reflect.compare);
					var serializeFieldsExpr = serializeFields.map(function (str) return Context.makeExpr(str, fieldsArray.pos));
					var arrExpr:Expr = { expr: EArrayDecl(serializeFieldsExpr), pos: fieldsArray.pos };
					fieldsArray.kind = FVar(t, arrExpr);
				default:
			}

			// Create a hxSerializeFields static var if it doesn't exist
			var relationshipsArray = fields.filter(function (f) return f.name == "hxRelationships")[0];
			if (relationshipsArray == null)
			{
				relationshipsArray = createRelationshipsArray();
				fields.push(relationshipsArray);
			}
			switch (relationshipsArray.kind)
			{
				case FVar(t, _):
					relationFields.sort(Reflect.compare);
					var relationFieldsExpr = relationFields.map(function (str) return Context.makeExpr(str, relationshipsArray.pos));
					var arrExpr:Expr = { expr: EArrayDecl(relationFieldsExpr), pos: relationshipsArray.pos };
					relationshipsArray.kind = FVar(t, arrExpr);
				default:
			}

			return fields;
		}

		static function processBelongsToRelations(fields:Array<Field>, f:Field, modelType:TypePath, allowNull:Bool)
		{
			// Add skip metadata to the field
			f.meta.push({ name: ":skip", params: [], pos: f.pos });

			// Add the model path to some metadata, in a later build macro this metadata will be used to populate a "relations" array
			addMetadataForRelatedModel(f, modelType);

			// Add the ID field(s)
			// FOR NOW: fieldNameID:SId
			// LATER:
				// base the name of the ident in our metadata
				// figure out the type by analysing the type given in our field, opening the class, and looking for @:id() metadata or id:SId or id:SUId
			var idType:ComplexType;
			if (allowNull)
			{
				idType = TPath({
					sub: null,
					params: [TPType("SUInt".asComplexType())],
					pack: [],
					name: "Null"
				});
			}
			else
			{
				idType = "SUInt".asComplexType();
			}
			fields.push({
				pos: f.pos,
				name: f.name + "ID",
				meta: [],
				kind: FVar(idType),
				doc: 'The unique ID for field `${f.name}`.  This is what is actually stored in the database',
				access: [APublic]
			});

			// Change to a property, retrieve field type.
			switch (f.kind) {
				case FVar(t,e):
					f.kind = FProp("get","set",t,e);
				case _: error('On field `${f.name}`: BelongsTo can only be used with a normal var, not a property or a function.', f.pos);
			};

			// Get the type signiature we're using
			// generally _fieldName:T or _fieldName:Null<T>

			var modelTypeSig:ComplexType = null;
			if (allowNull)
			{
				modelTypeSig = TPath({
					sub: null,
					params: [TPType(TPath(modelType))],
					pack: [],
					name: "Null"
				});
			}
			else
			{
				modelTypeSig = TPath(modelType);
			}

			// Add the private container field

			fields.push({
				pos: f.pos,
				name: "_" + f.name,
				meta: [{ name: ":skip", params: [], pos: f.pos }], // Add @:skip metadata to this
				kind: FVar(modelTypeSig),
				doc: null,
				access: [APrivate]
			});

			// Add the getter

			var getterBody:Expr;
			var privateIdent = ("_" + f.name).resolve();
			var idIdent = (f.name + "ID").resolve();
			var modelPath = nameFromTypePath(modelType);
			var model = modelPath.resolve();
			if (Context.defined("server"))
			{
				getterBody = macro {
						if ($privateIdent == null && $idIdent != null)
							$privateIdent = $model.manager.get($idIdent);
					return $privateIdent;
				};
			}
			else
			{
				getterBody = macro {
					#if ufront_clientds
						if ($privateIdent == null && $idIdent != null) {
							// Should resolve synchronously if it's already in the cache
							var p = $model.clientDS.get($idIdent);
							p.then(function (v) $privateIdent = v);
							if (allRelationPromises!=null) allRelationPromises.push( p );
						}
					#end
					return $privateIdent;
				}
			}
			fields.push({
				pos: f.pos,
				name: "get_" + f.name,
				meta: [],
				kind: FieldType.FFun({
					ret: modelTypeSig,
					params: [],
					expr: getterBody,
					args: []
				}),
				doc: null,
				access: [APrivate]
			});

			// Add the setter

			var setterBody:Expr;
			if (allowNull)
			{
				setterBody = macro {
					$privateIdent = v;
					$idIdent = (v == null) ? null : v.id;
					return $privateIdent;
				}
			}
			else
			{
				setterBody = macro {
					$privateIdent = v;
					if (v == null) throw '${modelType.name} cannot be null';
					if (v.id == null) throw '${modelType.name} must be saved before you can set ${f.name}';
					$idIdent = v.id;
					return $privateIdent;
				}
			}
			fields.push({
				pos: f.pos,
				name: "set_" + f.name,
				meta: [],
				kind: FieldType.FFun({
					ret: modelTypeSig,
					params: [],
					expr: setterBody,
					args: [{
						value: null,
						type: modelTypeSig,
						opt: false,
						name: "v"
					}]
				}),
				doc: null,
				access: [APrivate]
			});

			return fields;
		}

		static function processHasManyRelations(fields:Array<Field>, f:Field, modelType:TypePath)
		{
			// Add skip metadata to the field
			f.meta.push({ name: ":skip", params: [], pos: f.pos });

			// Add the model path to some metadata, in a later build macro this metadata will be used to populate a "relations" array
			addMetadataForRelatedModel(f, modelType);

			// change var to property (get,null)
			// Switch kind
			//  - if var, change to property (get,null), get the fieldType
			//  - if property or function, throw error.  (if they want to do something custom, don't use the macro)
			// Return the property
			var fieldType:Null<ComplexType> = null;
			switch (f.kind) {
				case FVar(t,e):
					fieldType = t;
					f.kind = FProp("get","set",t,e);
				case _: error('On field `${f.name}`: HasMany can only be used with a normal var, not a property or a function.', f.pos);
			};
			
			// Values needed for reification of fields.
			var modelTypeSig:ComplexType = TPath(modelType);
			var iterableTypeSig:ComplexType = macro :List<$modelTypeSig>;
			var privateName = '_${f.name}';
			var privateIdent = privateName.resolve();
			var getterName = 'get_${f.name}';
			var setterName = 'set_${f.name}';
			var relationKey = getRelationKeyForField(f);
			var modelPath = nameFromTypePath(modelType);
			var model = modelPath.resolve();
			
			// Use reification to create the private field, the getter and the setter.
			var fieldsToAdd = macro class {
				@:skip private var $privateName:List<$modelTypeSig>;
				private function $getterName():List<$modelTypeSig> {
					#if server
						// if ($privateIdent == null) $privateIdent = $model.manager.search($i{relationKey} == s.id);
						if ($privateIdent == null) {
							var quotedID = sys.db.Manager.quoteAny(this.id);
							var table = untyped $model.manager.table_name;
							$privateIdent = $model.manager.unsafeObjects('SELECT * FROM ' + table + ' WHERE '+$v{relationKey}+' = '+quotedID, null);
						}
					#elseif ufront_clientds
						if ($privateIdent == null) {
							// Should resolve synchronously if it's already in the cache, otherwise it will return null and begin processing the request.
							var p = $model.clientDS.search({ $relationKey: this.id });
							p.then(function (res) $privateIdent = Lambda.list(res));
							if (allRelationPromises!=null) allRelationPromises.push( p );
						}
					#end
					return $privateIdent;
				}
				private function $setterName( list:List<$modelTypeSig> ):List<$modelTypeSig> {
					return $privateIdent = list;
				}
			}
			for( field in fieldsToAdd.fields ) {
				fields.push( field );
			}

			return fields;
		}

		static function processHasOneRelations(fields:Array<Field>, f:Field, modelType:TypePath)
		{
			// Add skip metadata to the field
			f.meta.push({ name: ":skip", params: [], pos: f.pos });

			// Add the model path to some metadata, in a later build macro this metadata will be used to populate a "relations" array
			addMetadataForRelatedModel(f, modelType);

			// Generate the type we want.  If it was HasMany<T>, the
			// generated type will be Null<T>

			var modelTypeSig = TPath({
				sub: null,
				params: [TPType(TPath(modelType))],
				pack: [],
				name: "Null"
			});

			// change var to property (get,null)
			// Switch kind
			//  - if var, change to property (get,null), get the fieldType
			//  - if property or function, throw error.  (if they want to do something custom, don't use the macro)

			switch (f.kind) {
				case FVar(t,e):
					f.kind = FProp("get","set",t,e);
				case _: error('On field `${f.name}`: HasOne can only be used with a normal var, not a property or a function.', f.pos);
			};
			
			// Values needed for reification of fields.
			var privateName = ("_" + f.name);
			var privateIdent = privateName.resolve();
			var getterName = ("get_" + f.name);
			var setterName = ("set_" + f.name);
			var relationKey = getRelationKeyForField(f);
			var modelPath = nameFromTypePath(modelType);
			var model = modelPath.resolve();
			
			// Use reification to create the private field, the getter and the setter.
			var fieldsToAdd = macro class {
				@:skip private var $privateName:$modelTypeSig;
				private function $getterName():$modelTypeSig {
					#if server
						// if ($privateIdent == null) $privateIdent = $model.manager.search($i{relationKey} == s.id);
						if ($privateIdent == null) {
							var quotedID = sys.db.Manager.quoteAny(this.id);
							var table = untyped $model.manager.table_name;
							$privateIdent = $model.manager.unsafeObjects('SELECT * FROM ' + table + ' WHERE '+$v{relationKey}+' = '+quotedID, null).first();
						}
					#elseif ufront_clientds
						if ($privateIdent == null) {
							// Should resolve synchronously if it's already in the cache, otherwise it will return null and begin processing the request.
							var p = $model.clientDS.search({ $relationKey: this.id });
							p.then(function (res) $privateIdent = res.iterator().next() );
							if (allRelationPromises!=null) allRelationPromises.push( p );
						}
					#end
					return $privateIdent;
				}
				private function $setterName( obj:$modelTypeSig ):$modelTypeSig {
					return $privateIdent = obj;
				}
			}
			for( field in fieldsToAdd.fields ) {
				fields.push( field );
			}

			return fields;
		}

		static var manyToManyModels:Array<String> = [];

		static function processManyToManyRelations(fields:Array<Field>, f:Field, modelA:TypePath, modelB:TypePath)
		{
			// Add skip metadata to the field
			f.meta.push({ name: ":skip", params: [], pos: f.pos });

			// Add the model path to some metadata, in a later build macro this metadata will be used to populate a "relations" array
			addMetadataForRelatedModel(f, modelB);

			// change var to property (get,null)
			// Switch kind
			//  - if var, change to property (get,null), get the fieldType
			//  - if property or function, throw error.  (if they want to do something custom, don't use the macro)
			// Return the property
			var fieldType:Null<ComplexType> = null;
			switch (f.kind) {
				case FVar(t,e):
					fieldType = t;
					f.kind = FProp("get","null",t,e);
					// Create getter or setter
				case _: error('On field `${f.name}`: ManyToMany can only be used with a normal var, not a property or a function.', f.pos);
			};

			// create var _propertyName (and skip)
			// Add the private container field
			// generally _fieldName:T
			fields.push({
				pos: f.pos,
				name: "_" + f.name,
				meta: [{ name: ":skip", params: [], pos: f.pos }], // Add @:skip metadata to this
				kind: FVar(fieldType),
				doc: null,
				access: [APrivate]
			});

			// Get the various exprs used in the getter

			var ident = ("_" + f.name).resolve();

			// create getter

			var getterBody:Expr;
			var bModelPath = nameFromTypePath(modelB);
			var bModelIdent = bModelPath.resolve();
			if (Context.defined("server"))
			{
				getterBody = macro {
					if ($ident == null) $ident = new ManyToMany(this, $bModelIdent);
					return $ident;
				};
			}
			else
			{
				getterBody = macro {
					if ($ident.bList == null)
					{
						$ident.bList = new List();
						#if ufront_clientds
							var p = $bModelIdent.clientDS.getMany(Lambda.array($ident.bListIDs));
							p.then(function (items) {
								for (id in $ident.bListIDs) {
									var item = items.get( id );
									if ( item!=null ) {
										$ident.bList.add( item );
									}
								}
							});
							if (allRelationPromises!=null) allRelationPromises.push( p );
						#end
					}
					return $ident;
				};
			}
			var accessMetadata = {
				pos: f.pos,
				params: [ "ufront.db.ManyToMany".resolve() ],
				name: ":access"
			};
			fields.push({
				pos: f.pos,
				name: "get_" + f.name,
				meta: [ accessMetadata ],
				kind: FieldType.FFun({
					ret: fieldType,
					params: [],
					expr: getterBody,
					args: []
				}),
				doc: null,
				access: [APrivate]
			});

			// Define a type for this relationship, so that a table is created by spodadmin correctly
			var relationshipModelTP:TypePath = {
				sub: null,
				params: [],
				pack: ["ufront","db"],
				name: "Relationship"
			};

			// Same logic as ManyToMany.generateTableName(a,b)
			var arr = [modelA.name,modelB.name];
			arr.sort(function(x,y) return Reflect.compare(x,y));
			var joinedName = arr.join('_');
			var tableName = "_join_" + joinedName;
			var modelName = "Join_" + joinedName;
			var tableNameExpr = tableName.toExpr();
			var pack = ["ufront","db","joins"];

			// Create the model if it doesn't already exist
			var className = pack.join(".") + "." + modelName;
			if ( !manyToManyModels.has(className) )
			{
				manyToManyModels.push(className);
				Context.defineType({
					pos: Context.currentPos(),
					params: [],
					pack: pack,
					name: modelName,
					meta: [{
						pos: Context.currentPos(),
						name: ":table",
						params: [ macro $tableNameExpr ]
					}],
					kind: TDClass( relationshipModelTP ),
					isExtern: false,
					fields: []
				});
			}

			return fields;
		}

		static function addMetadataForRelatedModel(f:Field, model:TypePath)
		{
			var modelPath = nameFromTypePath(model);
			// var type = try Context.getType(modelPath) catch (e:Dynamic) error('Type $modelPath on field ${f.name} was not found. ($e)', f.pos);
			var type = Context.getType(modelPath);
			var fullName = switch (type)
			{
				case TInst(t, _): t.toString();
				case _: modelPath;
			}
			f.meta.push({ name: ":modelPath", params: [macro $v{fullName}], pos: f.pos });
		}

		static function getRelationKeyForField(?f:Field, ?cf:ClassField):String
		{
			var relationKey:String = null;
			var relationKeyMeta = getMetaFromField(f, cf, ":relationKey");

			if (relationKeyMeta != null)
			{
				// If there is @:relationKey("nameOfBelongsToField") metadata, use that
				var rIdent = relationKeyMeta[0];
				switch (rIdent.expr)
				{
					case EConst(CIdent(r)):
						relationKey = r;
					case _:
						Context.fatalError( 'Unable to understand @:relationKey metadata on field ${f.name}.\nPlease use a simple field name without quotation marks.', f.pos );
				}
			}
			else
			{
				// If not, guess at the name. From "SomeClass" model get "someClassID" name
				var name = Context.getLocalClass().get().name;
				relationKey = name.charAt(0).toLowerCase() + name.substr(1) + "ID";
			}
			return relationKey;
		}

		static function getMetaFromField(?f:Field, ?cf:ClassField, name:String)
		{
			var metadata:Metadata;

			if (f != null) metadata = f.meta;
			if (cf != null) metadata = cf.meta.get();

			if ( metadata!=null )
				for (metaItem in metadata)
				{
					if (metaItem.name == name) return metaItem.params;
				}
			return null;
		}

		static function nameFromTypePath(t:TypePath)
		{
			return (t.pack.length == 0) ? t.name : (t.pack.join(".") + "." + t.name);
		}

		static function getRelatedModelTypeFromField(?f:Field, ?cf:ClassField)
		{
			var metadata:Metadata;

			if (f != null) metadata = f.meta;
			if (cf != null) metadata = cf.meta.get();

			for (metaItem in metadata)
			{
				if (metaItem.name == ":modelPath")
				{
					switch (metaItem.params[0].expr)
					{
						case EConst(CString(path)):
							return path;
						default:
					}
				}
			}
			return "";
		}

		static function createManagerAndClientDs(classType:ComplexType):Field
		{
			var classRef = classType.toString().resolve();
			var ct = macro : {
				#if server
					public static var manager:sys.db.Manager<$classType> = new sys.db.Manager($classRef);
				#elseif (client && ufront_clientds)
					public static var clientDS:clientds.ClientDs<$classType> = clientds.ClientDs.getClientDsFor($classRef);
				#end
			}

			return BuildTools.fieldsFromAnonymousType(ct)[0];
		}

		static function createEmptyValidateFunction():Field
		{
			var ct = macro : {
				override public function validate():Bool
				{
					// Do super class validation also.
					super.validate();

					// If there are no errors, then return true
					return validationErrors.isValid;
				}
			}

			return BuildTools.fieldsFromAnonymousType(ct)[0];
		}

		static function createEmptyFieldValidateFunction(validateFnName):Field
		{
			var ct = macro : {
				public function fnName() {}
			}
			var f = BuildTools.fieldsFromAnonymousType(ct)[0];
			f.name = validateFnName;
			return f;
		}

		static function createFieldsArray():Field
		{
			var ct = macro : {
				public static var hxSerializeFields:Array<String> = [];
			}

			return BuildTools.fieldsFromAnonymousType(ct)[0];
		}

		static function createRelationshipsArray():Field
		{
			var ct = macro : {
				public static var hxRelationships:Array<String> = [];
			}

			return BuildTools.fieldsFromAnonymousType(ct)[0];
		}
	#end
}
