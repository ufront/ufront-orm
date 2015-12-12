# Migrations in Ufront-ORM

### Do I need migrations?

If you:

- Have multiple servers that you have to keep up to date (eg a cluster of VPS servers on AWS)
- Have multiple developers working on different sections of the code and need to keep the dev versions up to date
- Use git branches to work on different features, and need to change your database tables as quickly as you change your git branches

...then you probably need migrations.

If you have a simple use case (just one developer, just one server, not much git branching) then you might not need to use migrations.  A simpler solution would be to use `ufadmin` and the `dbadmin` module to sync your database structure to your code models.

### Aim

The aim of our migration system is:

- To be able to have changes to the database structure described in your code.
- To be able to run these changes automatically, so that your database structure keeps up with your code.
- To be able to roll back these changes as automatically as possible.









--------------

Creating your migrations:

- You could create a class that extends `Migration` manually.
- Or
	- We have a build macro that looks for every `Object` and adds a field.
	- It outputs the DBSchema from that build, serialized into a file.
	- We have a UFTool that can help produce the migrations
		- It reads all the schemas from disk
		- `static function mergeSchemas()` (and throw an error if there is a conflict)
		- So, now we have a combined "target" schema.
		- In ?????????, we output the schema created by `MigrationApi.getSchemaFromCode()`
		- `static function diffSchemas( targetSchema, currentCode ):Array<MigrationAction>`
		- Our tool then generates a hx file for the migration
	- Maybe we have an "inProgress" flag for migrations, where it can roll down/up easily as we tweak it?

/migrations/
/schema/target/server.schema
/schema/target/client.schema
/schema/current.schema

------------------------------------------

What if migrations are JSON instead?

{
	id: "20151028152503_AddEmailFieldToProfile";
	actions: [
		{ type:"AddField", name:"email", type:["DString",255] },
	]
}

You could possibly even get away with Haxe code and Context.parse():

```
AddField( "email", DString(255) ),
AddField( "salt", DString(32) ),
```

That would have a few advantages:
	- We could easily read them and write them from UFTool or from macros or from code or manually.
Disadvantages:
	- It would mean we can't run custom code.
