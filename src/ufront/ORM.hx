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
