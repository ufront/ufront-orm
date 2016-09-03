package testcases;

import utest.Assert;
import testcases.models.*;
using ufront.db.QueryBuilder;

class TestQueryBuilder extends DBTestClass {

	override function setup() {
		super.setup();
		recreateTable( Person.manager );
		recreateTable( Profile.manager );

		// Save should work as either `insert()` or `update()`
		var person1 = new Person();
		person1.id = 2;
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		person1.bio = "As a child, Jason used to enjoy breaking things. Not much has changed.";
		person1.insert();

		var profile1 = new Profile();
		profile1.person = person1;
		profile1.twitter = 'jasonaoneil';
		profile1.github = 'jasononeil';
		profile1.insert();

		var person2 = new Person();
		person2.id = 1;
		person2.firstName = "Anna";
		person2.surname = "O'Neil";
		person2.email = "anna@ufront.net";
		person2.age = 24;
		person2.insert();

		var profile2 = new Profile();
		profile2.person = person2;
		profile2.facebook = 'annaomusic';
		profile2.github = null;
		profile2.twitter = 'annaomusic';
		profile2.insert();

		var person3 = new Person();
		person3.id = 3;
		person3.firstName = "Theo";
		person3.surname = "Kitty";
		person3.email = "theo@ufront.net";
		person3.age = 2;
		person3.bio = "Theo is our cat.";
		person3.insert();
	}

	function checkFieldsExist( obj:Dynamic, fields:Array<String>, ?pos:haxe.PosInfos) {
		for (field in fields) {
			Assert.isTrue(Reflect.hasField(obj, field), 'Object `$obj` should have field "$field"', pos);
		}
	}

	function checkFieldsDoNotExist( obj:Dynamic, fields:Array<String>, ?pos:haxe.PosInfos) {
		for (field in fields) {
			Assert.isFalse(Reflect.hasField(obj, field), 'Object `$obj` should not have field "$field"', pos);
		}
	}

	function testSelect() {
		// Check the objects are returned and they have the model fields by default.
		var people = cnx.select( Person );
		Assert.equals( 3, people.length );
		for (person in people) {
			// TODO: make sure null fields exist.
			// checkFieldsExist(person, ["firstName", "surname", "email", "age", "bio"]);
			checkFieldsExist(person, ["firstName", "surname", "email", "age"]);
			checkFieldsDoNotExist(person, ["facebook","profile","save"]);
		}

		var profiles = cnx.select( Profile );
		Assert.equals( 2, profiles.length );
		for (profile in profiles) {
			// TODO: make sure null fields exist.
			// checkFieldsExist(profile, ["twitter", "facebook", "github"]);
			checkFieldsExist(profile, ["twitter"]);
			checkFieldsDoNotExist(profile, ["person","age","save"]);
		}
	}

	function testInheritedFields() {
		var profiles = cnx.select( Profile );
		for (profile in profiles) {
			checkFieldsExist(profile, ["id","created","modified"]);
		}
	}

	function testSelectFields() {
		// normal
		var profiles = cnx.select( Profile, Fields(id,twitter) );
		for (profile in profiles) {
			checkFieldsExist(profile, ["id","twitter"]);
			checkFieldsDoNotExist(profile, ["created","modified","facebook","github"]);
		}

		// alias
		var profiles = cnx.select( Profile, Fields(identifier = id,twitter) );
		for (profile in profiles) {
			checkFieldsExist(profile, ["identifier","twitter"]);
			checkFieldsDoNotExist(profile, ["id","created","modified","facebook","github"]);
		}

		// join column fields
		// join column field aliases
	}

	function testSelectJoins() {
		// belongsTo
		// hasOne
		// hasMany
		// manyToMany
	}

	function getName(p) return p.firstName;

	function testSelectWhere() {
		// constant expressions
		var people = cnx.select(Person, Where($firstName=="Jason"));
		var names = people.map(getName);
		Assert.equals(1, people.length);
		Assert.contains("Jason", names);

		var people = cnx.select(Person, Where($age>20));
		var names = people.map(getName);
		Assert.equals(2, people.length);
		Assert.contains("Jason", names);
		Assert.contains("Anna", names);

		// null checks
		var people = cnx.select(Person, Where($bio!=null));
		var names = people.map(getName);
		Assert.equals(2, people.length);
		Assert.contains("Jason", names);
		Assert.contains("Theo", names);

		var people = cnx.select(Person, Where($bio==null));
		Assert.equals(1, people.length);
		Assert.equals("Anna", people[0].firstName);

		// interpolation
		function findByName(name:String) {
			return cnx.select(Person, Where($firstName==name))[0];
		}
		Assert.equals(27, findByName("Jason").age);
		Assert.equals(24, findByName("Anna").age);

		// complex booleans
		var min = 20;
		var people = cnx.select(Person, Where($age>min && $age<25));
		Assert.equals(1, people.length);
		Assert.equals("Anna", people[0].firstName);

		var people = cnx.select(Person, Where($age>min && $firstName=="Jason"));
		Assert.equals(1, people.length);
		Assert.equals(27, people[0].age);

		var people = cnx.select(Person, Where($age>=27 || $firstName=="Theo"));
		var names = people.map(getName);
		Assert.equals(2, people.length);
		Assert.contains("Jason", names);
		Assert.contains("Theo", names);

		// multiple where conditions
		var people = cnx.select(Person, Where($age>min), Where($age<25));
		Assert.equals(1, people.length);
		Assert.equals("Anna", people[0].firstName);

		var people = cnx.select(Person, Where($age>min), Where($firstName=="Jason"));
		Assert.equals(1, people.length);
		Assert.equals(27, people[0].age);

		// select on aliased name
		var person = cnx.select(Person, Fields(first=firstName), Where($firstName=="Jason"))[0];
		Assert.equals("Jason", person.first);

		// Currently not supported.
		// var person = cnx.select(Person, Fields(first=firstName), Where($first=="Jason"))[0];
		// Assert.equals("Jason", person.first);

		// comparing one column to another
		var profiles = cnx.select(Profile, Where($twitter==$facebook));
		Assert.equals(1, profiles.length);
		Assert.equals("annaomusic", profiles[0].facebook);
		Assert.equals("annaomusic", profiles[0].twitter);

		var people = cnx.select(Person, Where($id>$age));
		Assert.equals(1, people.length);
		Assert.equals("Theo", people[0].firstName);

		// where condition on join column
	}

	function testSelectOrderBy() {
		function checkOrder(expectedNames, values, ?p:haxe.PosInfos) {
			var actualNames = values.map(getName).join(",");
			Assert.equals(expectedNames, actualNames, 'Expected order to be [$expectedNames] but was [$actualNames]', p);
		}

		// ascending and descending
		checkOrder("Theo,Anna,Jason", cnx.select(Person, OrderBy($age)));
		checkOrder("Jason,Anna,Theo", cnx.select(Person, OrderBy(-$age)));
		checkOrder("Anna,Jason,Theo", cnx.select(Person, OrderBy($firstName)));
		checkOrder("Theo,Jason,Anna", cnx.select(Person, OrderBy(-$firstName)));
		checkOrder("Anna,Jason,Theo", cnx.select(Person, OrderBy($id)));
		checkOrder("Theo,Jason,Anna", cnx.select(Person, OrderBy(-$id)));

		// constant values
		checkOrder("Anna,Jason,Theo", cnx.select(Person, OrderBy("id")));
		checkOrder("Jason,Anna,Theo", cnx.select(Person, OrderBy(-"age")));

		// interpolation
		var sortColumn = "id";
		checkOrder("Anna,Jason,Theo", cnx.select(Person, OrderBy(sortColumn)));
		var sortColumn = "age";
		checkOrder("Jason,Anna,Theo", cnx.select(Person, OrderBy(-sortColumn)));

		// multiple values
		var secondColumn = "age";
		checkOrder("Theo,Anna,Jason", cnx.select(Person, OrderBy($surname,secondColumn)));

		// order by on join column
	}

	function testSelectLimit() {
		// constant
		Assert.equals(3, cnx.select(Person).length);
		Assert.equals(2, cnx.select(Person, Limit(2)).length);
		Assert.equals(1, cnx.select(Person, Limit(1)).length);

		// interpolation
		var num = 10;
		Assert.equals(3, cnx.select(Person, Limit(num)).length);
		var num = 1;
		Assert.equals(1, cnx.select(Person, Limit(num)).length);

		// min and max
		var people = cnx.select(Person, OrderBy($id), Limit(0, 1));
		Assert.equals(1, people.length);
		Assert.equals("Anna", people[0].firstName);

		var people = cnx.select(Person, OrderBy($id), Limit(2, 10));
		Assert.equals(1, people.length);
		Assert.equals("Theo", people[0].firstName);

		var people = cnx.select(Person, OrderBy($id), Limit(1, 2));
		Assert.equals(2, people.length);
		Assert.equals("Jason", people[0].firstName);
		Assert.equals("Theo", people[1].firstName);

		var min = 1;
		var max = 2;
		var people = cnx.select(Person, OrderBy($id), Limit(min, max));
		Assert.equals(2, people.length);
		Assert.equals("Jason", people[0].firstName);
		Assert.equals("Theo", people[1].firstName);
	}
}
