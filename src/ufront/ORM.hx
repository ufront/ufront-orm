package ufront;

/**
The `ufront.ORM` module contains typedefs for commonly imported types in the `ufront-orm` package.

This allows you to use `import ufront.ORM;` or `using ufront.ORM` rather than having lots of imports in your code.
**/
class ORM {}

// `ufront.db` package.
@:noDoc @:noUsing typedef DatabaseID<T:Object> = ufront.db.DatabaseID<T>;
@:noDoc @:noUsing typedef ManyToMany<A:Object,B:Object> = ufront.db.ManyToMany<A,B>;
@:noDoc @:noUsing typedef Object = ufront.db.Object;
@:noDoc @:noUsing typedef BelongsTo<T:Object> = ufront.db.Object.BelongsTo<T>;
@:noDoc @:noUsing typedef HasMany<T:Object> = ufront.db.Object.HasMany<T>;
@:noDoc @:noUsing typedef HasOne<T:Object> = ufront.db.Object.HasOne<T>;
@:noDoc @:noUsing typedef Relationship = ufront.db.Relationship;
@:noDoc @:noUsing typedef ValidationErrors = ufront.db.ValidationErrors;

// `ufront.db.migrations` package.
@:noDoc @:noUsing typedef DBColumn = ufront.db.migrations.Migration.DBColumn;
@:noDoc @:noUsing typedef DBIndex = ufront.db.migrations.Migration.DBIndex;
@:noDoc @:noUsing typedef DBReferentialAction = ufront.db.migrations.Migration.DBReferentialAction;
@:noDoc @:noUsing typedef DBForeignKey = ufront.db.migrations.Migration.DBForeignKey;
@:noDoc @:noUsing typedef DBTable = ufront.db.migrations.Migration.DBTable;
@:noDoc @:noUsing typedef DBSchema = ufront.db.migrations.Migration.DBSchema;
@:noDoc @:noUsing typedef MigrationAction = ufront.db.migrations.Migration.MigrationAction;
@:noDoc @:noUsing typedef MigrationDirection = ufront.db.migrations.Migration.MigrationDirection;
@:noDoc @:noUsing typedef Migration = ufront.db.migrations.Migration;
@:noDoc @:noUsing typedef MigrationApi = ufront.db.migrations.MigrationApi;
@:noDoc @:noUsing typedef MigrationConnection = ufront.db.migrations.MigrationConnection;
@:noDoc @:noUsing typedef MigrationManager = ufront.db.migrations.MigrationManager;
// @:noDoc @:noUsing typedef MigrationMacros = ufront.db.migrations.MigrationMacros;
