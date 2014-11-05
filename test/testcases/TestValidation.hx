package testcases;

import utest.Assert;
import testcases.models.*;

class TestValidation extends DBTestClass {
	
	var person1:Person;
	var post1:BlogPost;
	
	override function setup() {
		super.setup();
		recreateTable( Person.manager );
		recreateTable( BlogPost.manager );
		
		person1 = new Person();
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		person1.bio = "As a child, Jason used to enjoy breaking things. Not much has changed.";
		person1.save();
		
		post1 = new BlogPost();
		post1.author = person1;
		post1.title = "First Post";
		post1.text = "And we all know it's likely to be the last post because blogging is too hard";
		post1.url = "first_post";
	}
	
	function testPreventSaving() {
		person1.firstName = null; // Invalid!
		Assert.raises( function () person1.save(), String );
		
		person1.firstName = "Jason"; // Valid!
		person1.save();
	}
	
	function testNullValuesAreInvalid() {
		// With all valid values, it passes validation.
		Assert.isTrue( person1.validate() );
		
		// Bio is allowed to be null, check it still passes validation.
		person1.bio = null;
		Assert.isTrue( person1.validate() );
		
		// Let's set the non-nullable properties to null, and check that validation fails as expected.
		person1.firstName = null;
		person1.surname = null;
		person1.email = null;
		person1.age = null;
		Assert.isFalse( person1.validate() );
		Assert.equals( 4, person1.validationErrors.length );
		Assert.equals( 1, person1.validationErrors.errors("firstName").length );
		Assert.equals( 1, person1.validationErrors.errors("surname").length );
		Assert.equals( 1, person1.validationErrors.errors("email").length );
		Assert.equals( 1, person1.validationErrors.errors("age").length );
		Assert.equals( 0, person1.validationErrors.errors("bio").length );
	}
	
	function testSingleMetadataValidation() {
		Assert.isTrue( person1.validate() );
		person1.email = "not an email address";
		Assert.isFalse( person1.validate() );
		Assert.equals( 1, person1.validationErrors.length );
		Assert.equals( "email failed validation.", person1.validationErrors["email"][0] );
		
	}
	
	function testMetadataValidationWithMessage() {
		Assert.isTrue( post1.validate() );
		post1.title = "";
		Assert.isFalse( post1.validate() );
		Assert.equals( 1, post1.validationErrors.length );
		Assert.equals( "Your blog post must have a title", post1.validationErrors.toString() );
	}
	
	function testMultipleMetadataValidation1() {
		Assert.isTrue( post1.validate() );
		post1.url = "12";
		Assert.isFalse( post1.validate() );
		Assert.equals( 1, post1.validationErrors.length );
		Assert.equals( "Your url must be at least 3 letters long", post1.validationErrors.toString() );
	}
	
	function testMultipleMetadataValidation2() {
		Assert.isTrue( post1.validate() );
		post1.url = "home";
		Assert.isFalse( post1.validate() );
		Assert.equals( 1, post1.validationErrors.length );
		Assert.equals( "Your url must not be one of the reserved words [about,home,contact,blog]", post1.validationErrors.toString() );
	}
	
	function testMultipleMetadataValidation3() {
		Assert.isTrue( post1.validate() );
		post1.url = "invalid characters";
		Assert.isFalse( post1.validate() );
		Assert.equals( 1, post1.validationErrors.length );
		Assert.equals( "Your url must only use a-z, 0-9 and underscores", post1.validationErrors.toString() );
	}
	
	function testMetadataValidationWithNullValue() {
		Assert.isTrue( post1.validate() );
		post1.title = null;
		Assert.isFalse( post1.validate() );
		Assert.equals( 1, post1.validationErrors.length );
		Assert.equals( "title is a required field.", post1.validationErrors.toString() );
	}
	
	function testValidateFieldFunction() {
		Assert.isTrue( post1.validate() );
		
		post1.text = "";
		Assert.isFalse( post1.validate() );
		Assert.equals( "You cannot have an empty blog post", post1.validationErrors.toString() );
		
		post1.text = "i really like the typescript and dart languages";
		Assert.isFalse( post1.validate() );
		Assert.equals( "The word typescript is not allowed!\nThe word dart is not allowed!", post1.validationErrors.toString() );
		
		post1.text = [for (i in 0...1500) 'word$i'].join(" ");
		Assert.isFalse( post1.validate() );
		Assert.equals( "More than 1000 words, this isn't an essay!", post1.validationErrors.toString() );
	}
	
	function testValidateModelFunction() {
		post1.save();
		
		var post2 = new BlogPost();
		post2.author = person1;
		post2.title = "First Post in a long time";
		post2.text = "Sorry I never post";
		post2.url = "first_post";
		Assert.isFalse( post2.validate() );
		Assert.equals( "The URL first_post already exists on the post First Post.", post2.validationErrors.toString() );
	}
}