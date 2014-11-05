package testcases;

import utest.Assert;
import testcases.models.*;
import sys.db.Manager;

class TestRelationships extends DBTestClass {
	
	var post1:BlogPost;
	var post2:BlogPost;
	var person1:Person;
	var profile1:Profile;
	var profile2:Profile;
	
	override function setup() {
		super.setup();
		recreateTable( Person.manager );
		recreateTable( Profile.manager );
		recreateTable( BlogPost.manager );
		
		person1 = new Person();
		person1.id = 1;
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		person1.bio = "As a child, Jason used to enjoy breaking things. Not much has changed.";
		
		post1 = new BlogPost();
		post1.title = "First Post";
		post1.text = "And we all know it's likely to be the last post because blogging is too hard";
		post1.url = "first_post";
		
		post2 = new BlogPost();
		post2.title = "Second Post";
		post2.text = "I'm probably apologizing for not posting very often...";
		post2.url = "second_post";
		
		profile1 = new Profile();
		profile1.twitter = "jasonaoneil";
		profile1.github = "jasononeil";
		
		profile2 = new Profile();
		profile2.facebook = "annaomusic";
	}
	
	function testBelongsToHasMany() {
		person1.save();
		Assert.equals( 0, person1.posts.length );
		
		// Save a post, and re-fetch the person's related posts to check it's associated.
		post1.author = person1;
		post1.save();
		person1.refresh();
		Assert.equals( 1, person1.posts.length );
		
		// Save a post, and re-fetch the person's related posts to check it's associated.
		post2.author = person1;
		post2.save();
		person1.refresh();
		Assert.equals( 2, person1.posts.length );
	}
	
	function testBelongsToHasOne() {
		person1.save();
		Assert.isNull( person1.profile );
		
		// Save the profile, check it's related.
		profile1.person = person1;
		profile1.save();
		person1.refresh();
		Assert.equals( "jasonaoneil", person1.profile.twitter );
		
		// Save a different profile, check it's related.
		// Please note if there is more than one match, we do not specify which match will be chosen.
		profile1.delete();
		profile2.person = person1;
		profile2.save();
		person1.refresh();
		Assert.equals( "annaomusic", person1.profile.facebook );
	}
	
	function testPreventUnsavedRelationships() {
		person1.id = null;
		Assert.raises( function() profile1.person = person1 );
	}
}
