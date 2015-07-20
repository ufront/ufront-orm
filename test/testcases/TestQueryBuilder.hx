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
		profile1.save();

		var person2 = new Person();
		person2.firstName = "Anna";
		person2.surname = "O'Neil";
		person2.email = "anna@ufront.net";
		person2.age = 24;
		person2.save();

		var profile2 = new Profile();
		profile2.person = person2;
		profile2.facebook = 'annaomusic';
		profile2.twitter = '__anna__o';
		profile2.save();

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
		var thirdOrderColumn = "surname";
		function fourth() return "modified";
		var query = Person.generateSelect(
			Fields(first = firstName,surname,age,modified,profile.facebook,profile.github),
			Where( ($age>min && $age==24) || $age<28+min),
			Where($bio==null || $firstName=="Jason"),
			OrderBy($age,$id,thirdOrderColumn,-fourth()),
			Limit(min,2)
		);
		var result = Person.select(
			Fields(first = firstName,surname,age,modified,profile.facebook,profile.github),
			Where( ($age>min && $age==24) || $age<28+min),
			Where($bio==null || $firstName=="Jason"),
			OrderBy($age,$id,thirdOrderColumn,-fourth()),
			Limit(min,2)
		);
		trace("RESULTS:");
		for ( row in result ) {
			trace ( row );
		}

		var result2 = Profile.select(
			Fields( first=person.firstName, last=person.surname, facebook, github, twitter )
		);
		trace("RESULTS2:");
		for ( row in result2 ) {
			trace ( row );
		}

		Assert.equals( "", query );
	}
}
