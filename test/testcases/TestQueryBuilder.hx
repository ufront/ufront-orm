package testcases;

import utest.Assert;
import testcases.models.*;
using ufront.db.QueryBuilder;

class TestQueryBuilder extends DBTestClass {
	override function setup() {
		super.setup();
		recreateTable( Person.manager );

		// Save should work as either `insert()` or `update()`
		var person1 = new Person();
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		person1.bio = "As a child, Jason used to enjoy breaking things. Not much has changed.";
		person1.insert();

		var person2 = new Person();
		person2.firstName = "Anna";
		person2.surname = "O'Neil";
		person2.email = "anna@ufront.net";
		person2.age = 24;
		person2.save();

		var person3 = new Person();
		person3.firstName = "Theo";
		person3.surname = "O'Neil";
		person3.email = "theo@ufront.net";
		person3.age = 2;
		person3.bio = "Theo is our cat.";
		person3.save();
	}

	function testQueryBuilder() {
		var min = 0;
		var thirdOrderColumn = "id";
		function fourth() return "modified";
		var result = Person.select(
			Where($age>min && age<17),
			Where($bio!=null),
			Fields(first = firstName,surname,age,modified),
			OrderBy($age,$surname,thirdOrderColumn,-fourth()),
			Limit(min,2)
		);
		for ( row in result ) {
			trace ( row.surname.substr(0) );
		}
	}
}
