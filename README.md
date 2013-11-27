ufront-orm
==========

The Object Relational Mapper, allows easy, type-safe access to your database.  Builds on Haxe's SPOD but adds macro powered relationships, validation and client side usage.

Ufcommon DB
===========

This package contains some helpers, base classes etc to help with using Relational Databases in your app.  Everything here is mostly generic, and seems to work with both the Sqlite and MySQL database connections.

I haven't documented these thoroughly yet, but here is quick overview:

ufront.db.Object
------------------

##### Extra fields: id, created, modified

This extends sys.db.Object as the base class all your models are built upon.  It adds 3 fields, which are to be present on every model: id:SUId, created:SDateTime, modified:SDateTime.  

Forcing an unsigned integer unique ID makes it easy for us to work with relationships and generic APIs.  I might consider changing this in future so different sorts of primary keys are allowed, or at least, facilitate a way to provide a bigger primary key if you need more than the default Integer size.

The "created" and "modified" fields are timestamps, and they are updated automatically as you call insert(), update() or save().  This sort of info is used often enough that it's nice to have them as part of the base class, and this is a pattern also seen in other database layers such as ActiveRecord.

##### The save() method

We also provide a generic "save()" method.  This either inserts or updates an object, and means you don't have to think about whether or not it already exists.  The logic goes like this: if your object doesn't have "id" defined, it isn't inserted yet, so call insert().  If it does, it probably already is in the database, so try an "update()", but if that fails, then try "insert()".  It should cover most edge cases accurately.

##### Client friendly

The ufront.db.Object does a fair amount of conditional compilation to make sure that your models can be seamlessly compiled on the client or on the server.  On the client, Object doesn't extend 'sys.db.Object', it has it's own (relatively empty) class, so it should compile safely.  Now, if you're using ClientDS the client classes can even use save(), delete(), insert() and update(), and they'll start a remoting call and return a promise for when everything is done.  But you'll be able to build your models and work with them, and transfer them via remoting to the server API where they can be saved again.

In your classes, you'll still have to use conditional compilation for some of the imports and when setting up the manager.  In my models, it is quite common to see 2 sets of conditional compilation, like so:

In your models, you will want to import `Types`, which contains the Haxe typedefs that let you specify information about the database structure:

	import sys.db.Types;

See the [SPOD tutorial](http://haxe.org/manual/spod) on the Haxe website for details of how this works.

Finally, you may be used to adding a static `manager` field on your model, like so:
	
	public static var manager:sys.db.Manager<Family> = new sys.db.Manager(Family);

Because the Manager won't work on the client, we need to make sure this goes only on the server.  But we do also have something that will work on the client, if you're using ClientDS:

	public static var clientDS:ClientDs<Family> = new ClientDs(Family);

Now, to save you the effort and the conditional compilation for switching between these, a build macro will automatically add these fields for you.

##### Autobuild macro magic

Any model you have which extends ufront.db.Object will be subject to our autobuild macro, which processes the relations and means you have to write less boilerplate code to get models talking to each other.  You can read more about these below.


Validation
-------------

```
	@:validate( name!="" )
    public var name:SString<50>;

    @:validate( _.length>6, "Password must be at least 6 characters long" )
    public var password:SString<50>;

    @:validate( ~/[a-z0-9_]@mycompany.com/.match(_), "Your email address is not a valid mycompany.com address" )
    public var email:SString<50>;

    public var postcode:SInt;

    function validate_postcode() {
    	var postcodesAvailable = [ 6000, 6001, 6005 ]
    	if ( postcodesAvailable.indexOf(postcode)==-1 ) 
    		validationErrors.set( "postcode", 'Sorry, our service is not available in $postcode yet' );
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

 * BelongsTo< SomeModel >
 * HasOne< SomeModel >
 * HasMany< SomeModel >
 * ManyToMany< ThisModel, RelatedModel >

Currently I'm not entering foreign keys for these into the database, nor am I using DB joins to speed things up.  So there is room for optimisation here in future.

### BelongsTo

BelongsTo< T > specifies a simple, one way relation.  This model, belongs to another one.  A Purchase might belong to a Customer, a Photo might belong to a User etc.  

The syntax for specifying this is simple:

	public var user:BelongsTo< User >;

What this becomes after we do our macro magic:

	@:skip public var user(get,set):User;	// Don't store this column in the database, just store the ID
	public var userID:SUId;					// A variable for the unique ID representing our related person
	
	// the private getter and setter

	var _user:User;							// A variable for caching the related user
	function get_user()
	{
		#if server 							// If we're on the client, they can only see a related object if it's been cached
			if (_user == null) 				// If we haven't cached the related object yet, go get it
				_user = User.manager.get(userID);
		#end
		return _user;
	}
	function set_user(u:User)
	{
		userID = (u == null) ? u.id : null;
		return _user = u;
	}

As you can see, it does a fair amount to try and reduce the amount of typing you have to do :)

##### Differences to Haxe's build in @:relation() metadata

Haxe has one existing feature for setting up relationships, the `@:relation(id)` metadta.  In effect, this is almost identical to what we are doing here.  Key differences:

 * Syntax.  We use the BelongsTo< T > typedef, and don't require metadata.
 * Searching - the search() macro doesn't recognise our relations yet.  So Haxe SPOD relations can do `User.manager.serach($group==myGroup)`, but for now we have to do `User.manager.search($groupID==myGroup.id)`.  I'm hopeful that I can add this feature in future.
 * It was easier for me to write the other relations this way.  If I can get better integration with the native haxe macros in future, I will.

##### Nullable

If you want it to be optional, so it can be null, use `Null<BelongsTo<User>>`.

### HasOne

HasOne< T > and BelongsTo< T > are quite similar, and are related in many ways.  The key difference is that the foreign key is stored in the class with the BelongsTo field.  Let's look at an example.

In our app, we have a Student model, and a StudentProfile model.  Now each Student has exactly one student profile, and each student profile belongs to exactly one student.  So which one is BelongsTo, and which one uses HasOne?

In our case, it makes sense that the profile belongs to the student, the student does not belong to their profile.  So:

	class StudentProfile {
		...
		public var student:BelongsTo< Student >;
	}
	class Student {
		...
		public var studentProfile:HasOne< StudentProfile >;
	}

Now, the foreign key will be automatically added to the Student Profile

	class StudentProfile {
		...
		public var student:BelongsTo< Student >;
		public var studentID:SUid;
	}

The Student model has no field relating to StudentProfile in the database.  When it needs to get the profile, it's getter will essentially perform something similar to `StudentProfile.select($studentID == this.id)`

##### How we guess the name of the foreign key.

For this to work, our build macro has to guess the name of the foreign key in the related table.  In the example above, the "profile" getter in the Student model needs to know that in StudentProfile, the foreign key we're looking for is called "studentID".  Here we use convention over configuration: by default, we will assume the name is the same as the model name, but with a lower case first letter, and an uppercase "ID" at the end.

So "HasOne< Student >" would look for "studentID", and "HasOne< StudentProfile >" would look for "studentProfileID".

If that's not what your foreign key is called, say you used "child"/"childID" instead of "student"/"studentID", you can specify this in metadata:
	
	// This tells us, when looking in StudentProfile, our foreign key is "childID", not "studentID"
	@:relationKey(childID) public var studentProfile:HasOne< StudentProfile >;

##### Nullable

If you want it to be optional, so it can be null, use `Null<HasOne<User>>`.

### HasMany

HasMany< T > is used when many related objects belong to this one.  So if your comments model has a field:

	public var user:BelongsTo< User >;

then you could get your User model to have a HasMany<Comment> relationship:

	public var comments:HasMany< Comment >;

Now, the HasMany< T > basically translates to Iterable< T >.  It actually returns a List<T>, but I have typed it as Iterable to remind the user that changing the value of the list does not update the database.  For example, this doesn't work:

	myUser.comments.push(new Comment()); // This would update the list in Haxe, but would not touch the DB

Instead, try this:

	var c = new Comment();
	c.user = myUser;
	c.save(); // As we save this, the next time we retrieve a list of comments for myUser, it will be included.

So that's the basic way this works.  Behind the scenes, the build macro basically transforms the code from:

	public var comments:HasMany< Comment >;

into:

	@:skip public var comments(get,null):Iterable< Comment >;
	
	@:skip var _comments:Iterable< Comment >
	function get_comments()
	{
		#if server
			if (_comments == null)
				Comment.manager.search($userID == this.id)
		#end
		return _comments;
	}

If no related objects belong to this one, then an empty list will be returned.

### ManyToMany

ManyToMany< A, B > is used for situations where many things go together.  Each Student has many Classes, and each Class has many Students.  Each Tag has many Posts, and each Post has many Tags.  Defining a ManyToMany is simple:
	
	// In your Student model
	public var classes:ManyToMany< Student, SchoolClass >;

	// And the other side, in your SchoolClass model:
	public var students:ManyToMany< SchoolClass, Student >;

The first type parameter (A) should be the type of the current class/model, and the second (B) is for the related class/model.  These are both fed into a ManyToMany object.  The behaviour is a little bit complicated, but it's sort of like this:

 * ManyToMany behaves like a list.  You can add a related item, you can remove a related item, you can iterate over all the related items etc.
 * To keep track of the relations, a JOIN table is set up.  It is named _join_{Model1Name}_{Model2Name}.  This table reflects the "Relationship" model.
 * Each item in your ManyToMany is essentially a Relationship, between < A > and < B >.  The relationship merely saves the IDs for A and B to the join table described above.  
 * The first time you request the related object, it does 2 SQL queries: the first searches the join table and finds the list of Relationships.  From there, it has the IDs of the related objects, so the second query fetches all the related objects and adds them to your list.  A future optimisation may be to use SQL table joins to reduce the number of queries here.
 * Any changes you make to the list will be updated in the join table.

In practice, it looks like this:
	
	// Update the relationships from the students end

	var jason:Student;

	jason.classes.setList([scienceClass,englishClass,mathsClass]);	// enrol a student in many classes
	jason.classes.add(computingClass);								// add a single enrolment for this student

	// or from the class end

	scienceClass.setList([jason,aaron,anna,justin]);				// enrol many students in a class
	scienceClass.add(mathilda);										// add a single student to this class

	// you can also remove things

	jason.classes.remove(scienceClass);								// remove a single class from this student's enrolments
	computingClass.students.clear();								// unenrol all students from this class

	// Or iterate over them

	for (cl in jason.classes)
	{
		trace ('In ${cl.name}, Jason has ${cl.students.length} class mates');
	}

The full list of methods and properties you have access to on a ManyToManyRelation:

 * length:Int
 * refreshList()
 * first():B
 * add(obj:B)
 * remove(obj:B)
 * clear()
 * setList(iter:Iterable< B >)
 * iterator():Iterable< B >
 * pop():B
 * push(obj:B)

So in many ways it behaves like a regular list, but it's updating that join table in the background.  If there are no related objects, ManyToMany comes back with a length of 0.

Finally, on the client side, the ManyToMany structure survives, but none of the changes are written back to the database.  That is to say - if you receive a ManyToMany object through Haxe remoting, it will still be in tact on the other side, but you can't refresh it, add to it, remove from it etc.  It's pretty much read-only on the client.

