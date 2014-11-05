package testcases;

import utest.Assert;
import testcases.models.*;
import ufront.db.ManyToMany;

class TestManyToMany extends DBTestClass {
	
	var post1:BlogPost;
	var post2:BlogPost;
	var person1:Person;
	var tag1:Tag;
	var tag2:Tag;
	
	override function setup() {
		super.setup();
		recreateTable( Person.manager );
		recreateTable( BlogPost.manager );
		recreateTable( Tag.manager );
		recreateJoinTable( BlogPost, Tag );
		
		person1 = new Person();
		person1.id = 1;
		person1.firstName = "Jason";
		person1.surname = "O'Neil";
		person1.email = "jason@ufront.net";
		person1.age = 27;
		person1.bio = "As a child, Jason used to enjoy breaking things. Not much has changed.";
		
		post1 = new BlogPost();
		post1.author = person1;
		post1.title = "First Post";
		post1.text = "And we all know it's likely to be the last post because blogging is too hard";
		post1.url = "first_post";
		
		post2 = new BlogPost();
		post2.author = person1;
		post2.title = "Second Post";
		post2.text = "I'm probably apologizing for not posting very often...";
		post2.url = "second_post";
		
		tag1 = new Tag();
		tag1.url = "meta";
		
		tag2 = new Tag();
		tag2.url = "about_blogging";
	}
	
	function testTableName() {
		Assert.equals( "_join_BlogPost_Person", ManyToMany.generateTableName(BlogPost,Person) );
		Assert.equals( "_join_BlogPost_Person", ManyToMany.generateTableName(Person,BlogPost) );
		Assert.equals( "_join_BlogPost_Tag", ManyToMany.generateTableName(Tag,BlogPost) );
		Assert.equals( "_join_BlogPost_Tag", ManyToMany.generateTableName(BlogPost,Tag) );
		Assert.equals( "_join_Person_Profile", ManyToMany.generateTableName(Profile,Person) );
		Assert.equals( "_join_Person_Profile", ManyToMany.generateTableName(Person,Profile) );
	}
	
	function reloadJoins() {
		post1.tags.refreshList();
		post2.tags.refreshList();
		tag1.posts.refreshList();
		tag2.posts.refreshList();
	}
	
	function testBasics() {
		person1.save();
		post1.save();
		post2.save();
		tag1.save();
		tag2.save();
		
		Assert.equals( 0, post1.tags.length );
		Assert.equals( 0, post2.tags.length );
		Assert.equals( 0, tag1.posts.length );
		Assert.equals( 0, tag2.posts.length );
		
		post1.tags.add( tag1 );
		Assert.equals( 1, post1.tags.length );
		reloadJoins();
		Assert.equals( 1, post1.tags.length );
		Assert.equals( 0, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 0, tag2.posts.length );
		
		post1.tags.add( tag2 );
		Assert.equals( 2, post1.tags.length );
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
		Assert.equals( 0, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 1, tag2.posts.length );
		
		post2.tags.add( tag2 );
		Assert.equals( 1, post2.tags.length );
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
		Assert.equals( 1, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 2, tag2.posts.length );
		
		post2.tags.clear();
		Assert.equals( 0, post2.tags.length );
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
		Assert.equals( 0, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 1, tag2.posts.length );
		
		post2.tags.setList([tag1,tag2]);
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
		Assert.equals( 2, post2.tags.length );
		Assert.equals( 2, tag1.posts.length );
		Assert.equals( 2, tag2.posts.length );
		
		post2.tags.setList([tag2]);
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
		Assert.equals( 1, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 2, tag2.posts.length );
		
		post2.tags.setList([]);
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
		Assert.equals( 0, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 1, tag2.posts.length );
		
		post1.tags.remove( tag1 );
		reloadJoins();
		Assert.equals( 1, post1.tags.length );
		Assert.equals( 0, post2.tags.length );
		Assert.equals( 0, tag1.posts.length );
		Assert.equals( 1, tag2.posts.length );
	}
	
	function testAddingMultipleTimes() {
		person1.save();
		post1.save();
		post2.save();
		tag1.save();
		tag2.save();
		
		post1.tags.add( tag1 );
		post1.tags.add( tag1 );
		post1.tags.add( tag2 );
		post1.tags.add( tag2 );
		
		Assert.equals( 2, post1.tags.length );
		reloadJoins();
		Assert.equals( 2, post1.tags.length );
	}
	
	function testUnsavedRelations() {
		person1.save();
		
		Assert.isNull( post1.id );
		Assert.isNull( post2.id );
		Assert.isNull( tag1.id );
		Assert.isNull( tag2.id );
		
		post1.tags.add(tag1);
		tag2.posts.add(post2);
		
		Assert.notNull( post1.id );
		Assert.notNull( post2.id );
		Assert.notNull( tag1.id );
		Assert.notNull( tag2.id );
		
		Assert.equals( 1, post1.tags.length );
		Assert.equals( 1, post2.tags.length );
		Assert.equals( 1, tag1.posts.length );
		Assert.equals( 1, tag2.posts.length );
	}
}