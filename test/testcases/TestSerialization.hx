package testcases;

import utest.Assert;
import testcases.models.*;
import haxe.Serializer;
import haxe.Unserializer;

class TestSerialization extends DBTestClass {
	
	var tag1:Tag;
	var tag2:Tag;
	var tag3:Tag;
	
	override function setup() {
		super.setup();
		recreateTable( Person.manager );
		recreateTable( Profile.manager );
		recreateTable( BlogPost.manager );
		recreateTable( Tag.manager );
		
		tag1 = new Tag();
		tag1.url = "coffee";
		
		tag2 = new Tag();
		tag2.url = "code";
		
		tag3 = new Tag();
		tag3.url = "cat_pictures";
	}
	
	function testSerializeUnsavedObject() {
		var tag1Serialized = Serializer.run( tag1 );
		Assert.equals( "Cy20:testcases.models.Tagy6:coffeey25:testcases.models.BlogPostnnnnng", tag1Serialized );
		var tag1Copy = Unserializer.run( tag1Serialized );
		Assert.equals( "coffee", tag1Copy.url );
	}
}