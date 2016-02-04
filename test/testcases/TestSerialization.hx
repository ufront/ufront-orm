package testcases;

import utest.Assert;
import testcases.models.*;
import haxe.Serializer;
import haxe.Unserializer;
using ufront.db.DBSerializationTools;

class TestSerialization extends DBTestClass {

	var person1:Person;
	var profile1:Profile;
	var post1:BlogPost;
	var post2:BlogPost;
	var tag1:Tag;
	var tag2:Tag;
	var tag3:Tag;

	override function setup() {
		super.setup();
		recreateTable( Person.manager );
		recreateTable( Profile.manager );
		recreateTable( BlogPost.manager );
		recreateTable( Tag.manager );
		recreateJoinTable( BlogPost, Tag );

		tag1 = new Tag();
		tag1.url = "coffee";
		tag1.save();

		tag2 = new Tag();
		tag2.url = "code";
		tag2.save();

		tag3 = new Tag();
		tag3.url = "cat_pictures";
		tag3.save();

		person1 = new Person();
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		person1.bio = "As a child, Jason used to enjoy breaking things. Not much has changed.";
		person1.save();

		post1 = new BlogPost();
		post1.title = "First Post";
		post1.text = "And we all know it's likely to be the last post because blogging is too hard";
		post1.url = "first_post";
		post1.author = person1;
		post1.save();
		post1.tags.setList([ tag1, tag2 ]);

		post2 = new BlogPost();
		post2.title = "Second Post";
		post2.text = "I'm probably apologizing for not posting very often...";
		post2.url = "second_post";
		post2.author = person1;
		post2.save();
		post2.tags.setList([ tag2, tag3 ]);

		profile1 = new Profile();
		profile1.twitter = "jasonaoneil";
		profile1.github = "jasononeil";
		profile1.person = person1;
		profile1.save();
	}

	function testSerializeUnsavedObject() {
		tag1.id = null;
		tag1.modified = null;
		tag1.created = null;
		var tag1Serialized = Serializer.run( tag1 );
		Assert.equals( "Cy20:testcases.models.Tagy29:url%2Cid%2Ccreated%2Cmodifiedy6:coffeennng", tag1Serialized );
		var tag1Copy = Unserializer.run( tag1Serialized );
		Assert.equals( "coffee", tag1Copy.url );
	}

	function testDefaultHxSerializationFields() {
		Assert.equals( "url,id,created,modified", tag1.hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname,email,age,bio,id,created,modified", person1.hxSerializationFields.join(",") );
		Assert.equals( "facebook,twitter,github,personID,id,created,modified", profile1.hxSerializationFields.join(",") );
		Assert.equals( "title,text,url,authorID,id,created,modified", post1.hxSerializationFields.join(",") );
	}

	function testHxSerializationFields() {
		Assert.equals( "url,id,created,modified", tag1.hxSerializationFields.join(",") );

		tag1.hxSerializationFields.push( "posts" );
		Assert.equals( "url,id,created,modified,posts", tag1.hxSerializationFields.join(",") );

		tag1.hxSerializationFields = ["id,url"];
		Assert.equals( "id,url", tag1.hxSerializationFields.join(",") );
	}

	function testSerializeMacros() {
		tag1.with( posts );
		Assert.equals( "url,id,created,modified,posts", tag1.hxSerializationFields.join(",") );

		tag1.setSerializationFields( -created, -modified );
		Assert.equals( "url,id,posts", tag1.hxSerializationFields.join(",") );

		DBSerializationTools.with( tag1, [], url );
		Assert.equals( "url", tag1.hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithHasOne() {
		person1.with( profile, -created, -modified );
		Assert.equals( "firstName,surname,email,age,bio,id,profile", person1.hxSerializationFields.join(",") );

		person1.with( [], firstName, surname, profile=>[[],twitter,github] );
		Assert.equals( "firstName,surname,profile", person1.hxSerializationFields.join(",") );
		Assert.equals( "twitter,github", person1.profile.hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithHasMany() {
		person1.with( posts );
		Assert.equals( "firstName,surname,email,age,bio,id,created,modified,posts", person1.hxSerializationFields.join(",") );

		person1.with( [], firstName, surname, posts=>[[],title,url] );
		Assert.equals( "firstName,surname,posts", person1.hxSerializationFields.join(",") );
		Assert.equals( "title,url", person1.posts.first().hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithBelongsTo1() {
		profile1.with( twitter, github, person );
		Assert.equals( "facebook,twitter,github,personID,id,created,modified,person", profile1.hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithBelongsTo2() {
		profile1.with( [], twitter, github, person=>[posts] );
		Assert.equals( "twitter,github,person", profile1.hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname,email,age,bio,id,created,modified,posts", profile1.person.hxSerializationFields.join(",") );
		Assert.equals( "title,text,url,authorID,id,created,modified", profile1.person.posts.first().hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithBelongsTo3() {
		profile1.with( [], twitter, github, person=>[[],firstName,surname,posts=>[[],title,url]] );
		Assert.equals( "twitter,github,person", profile1.hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname,posts", profile1.person.hxSerializationFields.join(",") );
		Assert.equals( "title,url", profile1.person.posts.first().hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithManyToMany1() {
		// Return the attached posts, but with no data for them. Could be a round-a-bout way to fetch the length :)
		tag1.with( [], url, posts=>[[]] );
		Assert.equals( "url,posts", tag1.hxSerializationFields.join(",") );
		Assert.equals( "", tag1.posts.first().hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithManyToMany2() {
		tag3.with( [], url, id, posts=>[[],title,url,author] );
		Assert.equals( "url,id,posts", tag3.hxSerializationFields.join(",") );
		Assert.equals( "title,url,author", tag3.posts.first().hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname,email,age,bio,id,created,modified", tag3.posts.first().author.hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithManyToMany3() {
		tag3.with( [], url, id, posts=>[[],title,url,author=>[[],firstName,surname]] );
		Assert.equals( "url,id,posts", tag3.hxSerializationFields.join(",") );
		Assert.equals( "title,url,author", tag3.posts.first().hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname", tag3.posts.first().author.hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithManyToMany4() {
		tag3.with( [], url, id, posts=>[[],title,url,author=>[[],firstName,surname,profile=>[[],twitter]]] );
		Assert.equals( "url,id,posts", tag3.hxSerializationFields.join(",") );
		Assert.equals( "title,url,author", tag3.posts.first().hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname,profile", tag3.posts.first().author.hxSerializationFields.join(",") );
		Assert.equals( "twitter", tag3.posts.first().author.profile.hxSerializationFields.join(",") );
	}

	function testSerializeMacrosWithManyToMany5() {
		// Here we go tag->post->tags, and the loop on the inner tags is removing the fields from the outer tag.
		// The only workaround I could think of was to re-specify "id" and "posts" on the outer tag after the loop of inner tags has run.
		tag3.with( [], url, posts=>[[],title,url,author,tags=>[[],url]], id, posts );
		Assert.equals( "url,id,posts", tag3.hxSerializationFields.join(",") );
		Assert.equals( "title,url,author,tags", tag3.posts.first().hxSerializationFields.join(",") );
		Assert.equals( "url", tag2.hxSerializationFields.join(",") );
	}

	function testIterableSerialize() {
		[].with( [] );

		var tags = Tag.manager.all().with( [], url, posts=>[[],url,title,author,tags] );
		Assert.equals( "url,posts", tags.first().hxSerializationFields.join(",") );
		Assert.equals( "url,title,author,tags", tags.first().posts.first().hxSerializationFields.join(",") );
		Assert.equals( "firstName,surname,email,age,bio,id,created,modified", tags.first().posts.first().author.hxSerializationFields.join(",") );
		Assert.equals( "url,posts", tags.first().posts.first().tags.last().hxSerializationFields.join(",") );
	}
}
