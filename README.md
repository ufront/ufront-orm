ufront-orm
==========

The ORM (Object Relational Mapper) for Ufront.

This allows you to create a class like this:

```haxe
import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;
class BlogPost extends Object {
	var title:SString<255>;
	var text:SText;
	var author:BelongsTo<User>;
	var headerImage:HasOne<ImageAttachment>;
	var comments:HasMany<Comment>;
	var tags:ManyToMany<BlogPost,Tag>;
}
```

You can then save these objects to the database easily:

```haxe
var p = new BlogPost();
p.title = "Short Lambdas";
p.text = "Y U NO short lambdas, Haxe? Seriously, even Java has them.";
p.author = jason;
p.save();
// Look, it has saved, has it's own ID and everything!
trace( p.id, p.created, p.modified );
```

You can also fetch objects using the manager:

```haxe
var firstPost = BlogPost.manager.get( 1 );
var allPosts = BlogPost.manager.all();
var postsAboutCats = BlogPost.manager.search($title=="Funny Cat Photo");

trace( postsAboutCats.length ); // How embarrassing!

for ( post in postsAboutCats ) {
	post.delete(); // Show no mercy!
}
```

`ufront-orm` builds on Haxe's `sys.db.*` DB classes and macros.
For more information on how Haxe Database records work, [this wiki page](http://old.haxe.org/manual/spod) is still the best resource.
This includes information about how the types in `sys.db.Types` map to certain database column types.

The key differences in `ufront.db.*` compared to `sys.db.*` are:

- Each model comes with `id`, `created` and `modified` fields built in.
- Each model has a `save()` method, which calls either `insert()` or `update()` as required.
- Objects can be serialized and shared between client and server, especially through Haxe remoting.
- We have macro powered relationships for `BelongsTo`, `HasOne`, `HasMany` and `ManyToMany`.
- We have macro powered validation for each field, or for the model, that must pass before saving.

Project Details
---------------

Installation:

	haxelib install ufront-orm

Using the latest git version:

	haxelib git ufront-orm https://github.com/ufront/ufront-orm.git

Current Status:

- Release Candidate.
- We are based on the Haxe `sys.db.*` classes, which had many bug fixes between Haxe 3.1.3 and 3.2.
- Ufront ORM is fairly stable, and in use in my (Jason's) production on 2 different large scale apps.
- There are unit tests for most basic functionality. They pass on Neko (with Haxe 3.1.3+) and PHP (with Haxe 3.2+). I should probably set up one of those cool widgets that auto-updates.
- The code compiles and works on Client side JS, and I use it in production, but it's not unit tested.
- There have been minor breaking changes lately, hence staying in RC status. These include: changing the serialization format, changing the way ManyToMany handles unsaved objects, etc. Once it's been stable for a while we'll release 1.0.
- Other Haxe sys targets, like Java, Python, C++ etc should work in theory, but have not been tested at all, so in practice, it probably doesn't compile yet :)
- The Haxe classes we base off would need fundamental changes to support NodeJS Async database connections, so this is unlikely to be supported in the near future, though is not out of the question.

Contributions:

- Yes please!
- Ask a question on Stack Overflow (and tag it "haxe") if you need an answer.
- Create an Issue on Github if you find a bug or want to request a feature.
- If you need paid support contact <jason@ufront.net>

ufront.db.Object
----------------

##### Extra fields: id, created, modified

This extends sys.db.Object as the base class all your models are built upon.  It adds 3 fields, which are to be present on every model: id:SId, created:SDateTime, modified:SDateTime.  

Forcing an integer unique ID makes it easy for us to work with relationships and generic APIs.  I might consider changing this in future so different sorts of primary keys are allowed, or at least, facilitate a way to provide a bigger primary key if you need more than the default Integer size.

The `created` and `modified` fields are timestamps, and they are updated automatically as you call `insert()`, `update()` or `save()`.  This sort of info is used often enough that it's nice to have them as part of the base class, and this is a pattern also seen in other database layers such as ActiveRecord.

##### The save() method

We also provide a generic "save()" method.  This either inserts or updates an object, and means you don't have to think about whether or not it already exists.  The logic goes like this: if your object doesn't have "id" defined, it isn't inserted yet, so call insert().  If it does, it probably already is in the database, so try an "update()", but if that fails, then try "insert()".  It should cover most edge cases accurately.

##### Client friendly

The `ufront.db.Object` does a fair amount of conditional compilation to make sure that your models can be seamlessly compiled on the client or on the server.  On the client, Object doesn't extend 'sys.db.Object', it has it's own class, so it should compile safely.  Now, if you're using the experimental `ufront-clientds` haxelib, the client classes can even use save(), delete(), insert() and update(), and they'll start a remoting call and return a promise for when everything is done.  Even without `ufront-clientds` library though, `ufront-orm` will let you build, validate, serialize and unserialize your models on both the client and server, and transfer them using Haxe remoting.

See the [SPOD tutorial](http://haxe.org/manual/spod) on the Haxe website for details of how this works.

##### Other features of `ufront.db.Object`

* Serialization - these objects include custom `hxSerialize` and `hxUnserialize` methods, and some macro-injected-metadata, to make sure we serialize and unserialize our objects consistently between platforms - which is very helpful for transferring objects between the client and server!
* We create a `public static var manager:Manager<MyModel>;` field on the server.
* If using the experimental `ufront-clientds` haxelib, we create a `public static var clientDS:ClientDS<MyModel>;` field on the client.
* We have a `saved` signal that you can use to trigger certain actions after an object has been saved.

Validation
----------

There are 3 ways of adding validation to your ufront models:

-  Using `@:validate` metadata on a given field.

   The first expression in the metadata must be a boolean statement that returns `true` if the field is valid.
   As a shortcut you can use an `_` instead of typing out the field name each time (see `password` example below).
   You can also give a second argument with text explaining the validation error.

-  A `function validate_myField` function for a specific field.

   And field which has a corresponding `validate_$fieldName()` function will call that function when performing validation.
   The function should perform some validation, and add error messages to the `validationErrors` object if the field is invalid.
   See the `postcode` and `validate_postcode` example below.

-  The class wide `function validate():Bool` function.

   The `validate()` function can be called manually, and is also called when `save()`, `insert()` or `update()` are called.
   It checks the validation for every field, and then returns `true` or `false`.
   See the example below for a demonstration of how to include your own logic in the `validate()` method.
   If you try to save an object which is not valid, a String containing the validation error messages is thrown.


Examples:

```haxe
@:validate( name!="" )
public var name:SString<50>;

@:validate( _.length>6, "Password must be at least 6 characters long" )
public var password:SString<50>;

@:validate( ~/[a-z0-9_]@mycompany.com/.match(_), "Your email address is not a valid mycompany.com address" )
public var email:Null<SString<50>>;

public var phone:Null<SString<20>>;

public var postcode:SInt;

function validate_postcode() {
	var postcodesAvailable = [ 6000, 6001, 6005 ]
	if ( postcodesAvailable.indexOf(postcode)==-1 ) 
		validationErrors.set( "postcode", 'Sorry, our service is not available in $postcode yet' );
}

override public function validate():Bool {
	super.validate(); // Call all the other validation functions and checks.
	if ( phone==null && email==null ) {
		validationErrors.set( 'phone', 'Either phone or email must be provided' );
		validationErrors.set( 'email', 'Either phone or email must be provided' );
	}
	return validationErrors.isValid;
}
```

And then

```
	var u = new AppUser();
	u.name = ""; // Fails: "name failed validation."
	u.name = "jason"; // Okay
	u.password = "test"; // Fails: "Password must be at least 6 characters long"
	u.validate(); // True or false
	u.validationErrors; // [ name=>"name failed validation", password=>"Password must be at least 6 characters long" ]
	u.save(); // Will only save if validate() is true, otherwise will throw an error
```

Relationships
-------------

Haxe's sys.db.* classes do provide some very basic support for one-to-one relations, but it was relatively inflexible and it required a fair amount of boilerplate code to get other features working, such as many-to-many relationships.  I've tried to speed all of that up here with the help of some build macros and a generic "Relationship" class.

There are 4 basic relationships we support so far:

 * `BelongsTo<RelatedModel>`
 * `HasOne<RelatedModel>`
 * `HasMany<RelatedModel>`
 * `ManyToMany<ThisModel,RelatedModel>`

Currently I'm not entering foreign keys for these into the database, and DB joins are only used in `ManyToMany`, not the other relationship types.  So there is room for optimisation here in future.

### BelongsTo

`BelongsTo<T>` specifies a simple, one way relation.  Each object of this type, belongs to another one of that type.  A Purchase might belong to a Customer, a Photo might belong to a User etc.

The syntax for specifying this is simple:

```haxe
	public var user:BelongsTo<User>;
```

What this becomes after we do our macro magic:

```haxe
	@:skip @:isVar public var user(get,set):User;  // Don't store this column in the database, just store the ID
	public var userID:SUId;                        // A variable for the unique ID representing our related person

	// the private getter and setter

	function get_user() {
		#if server
			if (user == null) user = User.manager.get(userID);
		#end
		return user;
	}
	function set_user(u:User) {
		if ( u==null ) throw 'Field user must not be null';
		if ( u.id==null ) throw 'Field user must be set to an object which already has an ID';
		userID = u.id;
		return user = u;
	}
```

As you can see, it does a fair amount to try and reduce the amount of typing you have to do :)

##### Differences to Haxe's build in @:relation() metadata

Haxe has one existing feature for setting up relationships, the `@:relation(id)` metadta.  In effect, this is almost identical to what we are doing here.  Key differences:

 * Syntax.  We use the `BelongsTo<T>` typedef, and don't require metadata.
 * This integrates better with `HasOne` and `HasMany` fields on the related model.
 * Currently we don't create a foreign key when creating tables in the DBAdmin module.  This may be added in future.
 * Searching - the search() macro doesn't recognise our relations yet.  So Haxe SPOD relations can do `User.manager.serach($group==myGroup)`, but for now we have to do `User.manager.search($groupID==myGroup.id)`.  I'm hopeful that I can add this feature in future.
 * It was easier for me to write the other relations this way.  If I can get better integration with the native haxe macros in future, I will.

##### Nullable

If you want it to be optional, so it can be set to null, use `Null<BelongsTo<User>>`.

### HasOne

`HasOne<T>` and `BelongsTo<T>` are quite similar, and are related in many ways.  The key difference is that the foreign key is stored in the class with the BelongsTo field.  Let's look at an example.

In our app, we have a Student model, and a StudentProfile model.  Now each Student has exactly one student profile, and each student profile belongs to exactly one student.  So which one is BelongsTo, and which one uses HasOne?

In our case, it makes sense that the profile belongs to the student, the student does not belong to their profile.  So:

```haxe
	class StudentProfile {
		...
		public var student:BelongsTo< Student >;
	}
	class Student {
		...
		public var studentProfile:HasOne< StudentProfile >;
	}
```

Now, the foreign key will be automatically added to the Student Profile

```haxe
	class StudentProfile {
		public var student:BelongsTo< Student >;
		public var studentID:SId;
	}
```

The `Student` model has no field relating to `StudentProfile` in the database.  When it needs to get the profile, it's getter will essentially perform something similar to `StudentProfile.select($studentID == this.id)`.

##### How we guess the name of the foreign key.

For this to work, our build macro has to guess the name of the foreign key in the related table.  In the example above, the "profile" getter in the Student model needs to know that in StudentProfile, the foreign key we're looking for is called "studentID".  Here we use a convention: by default, we will assume the name is the same as the model name, but with a lower case first letter, and an uppercase "ID" at the end.

So `HasOne<Student>` would look for `studentID`, and `HasOne<StudentProfile>` would look for `studentProfileID`.

If that's not what your foreign key is called, say you used `child`/`childID` instead of `student`/`studentID`, you can specify this in metadata:

```haxe
	// This tells us, when looking in StudentProfile, our foreign key is "childID", not "studentID"
	@:relationKey(childID) public var studentProfile:HasOne<StudentProfile>;
```

##### Nullable

A `HasOne<T>` is assumed to be nullable, because you don't know if the `Student.manager.select($studentID==this.id)` query will find any results.

### HasMany

`HasMany<T>` is used when many related objects belong to this one.  So if your comments model has a field:

```haxe
	public var user:BelongsTo<User>;
```

then you could get your User model to have a `HasMany<Comment>` relationship:

```haxe
	public var comments:HasMany<Comment>;
```

Now, the `HasMany<T>` basically translates to `List<T>`.  But please note that updating the list does not update the database.  For example, this doesn't work:

```haxe
	myUser.comments.push(new Comment()); // This would update the list in Haxe, but would not touch the DB
```

Instead, try this:

```haxe
	var c = new Comment();
	c.user = myUser;
	c.save(); // As we save this, the next time we retrieve a list of comments for myUser, it will be included.
```

So that's the basic way this works.  Behind the scenes, the build macro basically transforms the code from:

```
	public var comments:HasMany<Comment>;
```

into:

```haxe
	@:skip public var comments(get,set):Iterable< Comment >;
	
	function get_comments() {
		#if server
			if (comments == null) Comment.manager.search($userID == this.id)
		#end
		return comments;
	}
	function set_comments(comments) {
		return this.comments = comments;
	}
```

If no related objects belong to this one, then an empty list will be returned.

### ManyToMany

`ManyToMany<A,B>` is used for situations where many things go together:

- At a school, each Student has many Classes, and each Class has many Students.
- On a blog, each Tag has many Posts, and each Post has many Tags.  Defining a ManyToMany is simple:

```haxe
	// In your Student model
	public var classes:ManyToMany<Student,SchoolClass>;

	// And the other side, in your SchoolClass model:
	public var students:ManyToMany<SchoolClass,Student>;
```

The first type parameter (A) should be the type of the current class/model, and the second (B) is for the related class/model.  These are both fed into a ManyToMany object.  The behaviour is a little bit complicated, but it's sort of like this:

 * ManyToMany behaves like a list.  You can add a related item, you can remove a related item, you can iterate over all the related items etc.
 * To keep track of the relations, a JOIN table is set up.  It is named `_join_${Model1Name}_${Model2Name}`.  This table reflects the "Relationship" model.
 * Each item in your ManyToMany is essentially a Relationship, between `<A>` and `<B>`.  The relationship merely saves the IDs for A and B to the join table described above.  
 * The first time you access the `ManyToMany` object, the getter constructs it, and uses an SQL JOIN query to fetch the related B objects using the join table to match them to the current A object.
 * Any changes you make to the list will be updated in the join table.
 * If one of the joint objects is not saved yet, the join isn't created until after we save and have a valid ID.

In practice, it looks like this:

```haxe
	// Let's enrol Jason (a student) in a bunch of classes (updating from the student end)

	var jason:Student;

	jason.classes.setList([scienceClass,englishClass,mathsClass]);  // enrol a student in many classes
	jason.classes.add(computingClass);                              // add a single enrolment for this student

	// Let's enrol a bunch of students in our science class (updating from the class end)

	scienceClass.setList([jason,aaron,anna,justin]);                // enrol many students in a class
	scienceClass.add(mathilda);                                     // add a single student to this class

	// you can also remove things

	jason.classes.remove(scienceClass);                             // remove a single class from this student's enrolments
	computingClass.students.clear();                                // unenrol all students from this class

	// Or iterate over them

	for (cl in jason.classes) {
		trace ('In ${cl.name}, Jason has ${cl.students.length} class mates');
	}
```

The full list of methods and properties you have access to on a ManyToManyRelation:

- `length:Int`
- `refreshList()`
- `first():B`
- `add(obj:B)`
- `remove(obj:B)`
- `clear()`
- `setList(iter:Iterable<B>)`
- `iterator():Iterator<B>`

See the API documentation for more details.

So in many ways it behaves like a regular list, but it's updating that join table in the background.  If there are no related objects, ManyToMany comes back with a length of 0.

Finally, on the client side, the ManyToMany structure survives, but none of the changes are written back to the database.  That is to say - if you receive a ManyToMany object through Haxe remoting, it will still be in tact on the other side, but you can't refresh it, add to it, remove from it etc.  It's pretty much read-only on the client.

