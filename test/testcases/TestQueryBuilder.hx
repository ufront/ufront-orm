package testcases;

import utest.Assert;
import testcases.models.*;
using ufront.db.QueryBuilder;

class TestQueryBuilder extends DBTestClass {
	override function setup() {
		super.setup();
		// recreateTable( Person.manager );
	}

	function testQueryBuilder() {
		var min = 12;
		var thirdOrderColumn = 1;
		var query = QueryBuilder.generateSelect(
			From(Person),
			Fields(first = firstName,surname),
			Where($age>min && age<17),
			Where($bio!=null),
			OrderBy(-$age,$surname,thirdOrderColumn),
			Limit(min,20)
		);
		var expected = "BUILD";
		Assert.equals(expected, query);
	}
}
