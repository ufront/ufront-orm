package testcases;

import utest.Assert;
import testcases.models.*;

class TestObjects extends DBTestClass {
	override function setup() {
		super.setup();
		recreateTable( Person.manager );
	}

	function testManager() {
		// A static `manager` property should be created on each model.
		Assert.notNull( Person.manager );
	}
	
	function testSave() {
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
		
		person1.email = "jason@gmail.com";
		person2.email = "anna@gmail.com";
		
		person1.save();
		person2.update();
		
		var person3 = new Person();
		person1.firstName = "Theo";
		person1.surname = "O'Neil";
		person1.email = "theo@ufront.net";
		person1.age = 2;
		person1.bio = "Theo is our cat.";
		person1.id = 1; // Override one of our other rows!
		person1.save();
		
		// Check `created` and `modified` are being set.
		Assert.equals( 2, Person.manager.all().length );
		var p1 = Person.manager.get(1);
		Assert.equals( "Theo", p1.firstName );
		Assert.isTrue( p1.modified.getTime() >= p1.created.getTime() );
	}

	function testToString() {
		// Check that toString() behaves as expected
		var person1 = new Person();
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		Assert.equals( "testcases.models.Person#new", person1.toString() );
		person1.insert();
		Assert.equals( 'testcases.models.Person#${person1.id}', person1.toString() );
	}
}
