package testcases.issues;

import utest.Assert;
import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;

class Issue001 extends DBTestClass {
	
	var obj1:Issue001_MyObject;
	var obj2:Issue001_MyObject;
	var obj3:Issue001_MyObject;
	var cat1:Issue001_Category;
	var cat2:Issue001_Category;
	var cat3:Issue001_Category;
	var lang1:Issue001_Language;
	var lang2:Issue001_Language;
	var lang3:Issue001_Language;
	
	override function setup() {
		super.setup();
		recreateTable( Issue001_MyObject.manager );
		recreateTable( Issue001_Category.manager );
		recreateTable( Issue001_Language.manager );
		recreateJoinTable( Issue001_MyObject, Issue001_Category );
		recreateJoinTable( Issue001_MyObject, Issue001_Language );
		
		obj1 = new Issue001_MyObject();
		obj1.objectName = "Object 1";
		obj1.save();
		
		obj2 = new Issue001_MyObject();
		obj2.objectName = "Object 2";
		obj2.save();
		
		obj3 = new Issue001_MyObject();
		obj3.objectName = "Object 3";
		obj3.save();
		
		cat1 = new Issue001_Category();
		cat1.categoryName = "Category 1";
		cat1.save();
		
		cat2 = new Issue001_Category();
		cat2.categoryName = "Category 2";
		cat2.save();
		
		cat3 = new Issue001_Category();
		cat3.categoryName = "Category 3";
		cat3.save();
		
		lang1 = new Issue001_Language();
		lang1.languageName = "Language 1";
		lang1.save();
		
		lang2 = new Issue001_Language();
		lang2.languageName = "Language 2";
		lang2.save();
		
		lang3 = new Issue001_Language();
		lang3.languageName = "Language 3";
		lang3.save();
	}
	
	function reloadJoins() {
		obj1.categories.refreshList();
		obj2.categories.refreshList();
		obj3.categories.refreshList();
		
		obj1.languages.refreshList();
		obj2.languages.refreshList();
		obj3.languages.refreshList();
		
		cat1.objects.refreshList();
		cat2.objects.refreshList();
		cat3.objects.refreshList();
		
		lang1.objects.refreshList();
		lang2.objects.refreshList();
		lang3.objects.refreshList();
	}

	function testMultipleManyToMany() {
		Assert.equals( 0, obj1.categories.length );
		Assert.equals( 0, obj1.languages.length );
		Assert.equals( 0, obj2.categories.length );
		Assert.equals( 0, obj2.languages.length );
		Assert.equals( 0, obj3.categories.length );
		Assert.equals( 0, obj3.languages.length );
		Assert.equals( 0, cat1.objects.length );
		Assert.equals( 0, cat2.objects.length );
		Assert.equals( 0, cat3.objects.length );
		Assert.equals( 0, lang1.objects.length );
		Assert.equals( 0, lang2.objects.length );
		Assert.equals( 0, lang3.objects.length );
		
		obj1.categories.setList([ cat1 ]);
		obj2.categories.setList([ cat1, cat2 ]);
		obj3.categories.setList([ cat1, cat2, cat3 ]);
		obj1.languages.setList([ lang1, lang2, lang3 ]);
		obj2.languages.setList([ lang1, lang2 ]);
		obj3.languages.setList([ lang1 ]);
		reloadJoins();
		Assert.equals( 1, obj1.categories.length );
		Assert.equals( 3, obj1.languages.length );
		Assert.equals( 2, obj2.categories.length );
		Assert.equals( 2, obj2.languages.length );
		Assert.equals( 3, obj3.categories.length );
		Assert.equals( 1, obj3.languages.length );
		Assert.equals( 3, cat1.objects.length );
		Assert.equals( 2, cat2.objects.length );
		Assert.equals( 1, cat3.objects.length );
		Assert.equals( 3, lang1.objects.length );
		Assert.equals( 2, lang2.objects.length );
		Assert.equals( 1, lang3.objects.length );
		
		obj1.categories.setList([]);
		obj1.languages.clear();
		reloadJoins();
		Assert.equals( 0, obj1.categories.length );
		Assert.equals( 0, obj1.languages.length );
		Assert.equals( 2, obj2.categories.length );
		Assert.equals( 2, obj2.languages.length );
		Assert.equals( 3, obj3.categories.length );
		Assert.equals( 1, obj3.languages.length );
		Assert.equals( 2, cat1.objects.length );
		Assert.equals( 2, cat2.objects.length );
		Assert.equals( 1, cat3.objects.length );
		Assert.equals( 2, lang1.objects.length );
		Assert.equals( 1, lang2.objects.length );
		Assert.equals( 0, lang3.objects.length );
	}
}

class Issue001_MyObject extends Object {
	public var objectName:String;
	public var categories:ManyToMany<Issue001_MyObject,Issue001_Category>;
	public var languages:ManyToMany<Issue001_MyObject,Issue001_Language>;
}

class Issue001_Category extends Object {
	public var categoryName:String;
	public var objects:ManyToMany<Issue001_Category,Issue001_MyObject>;
}

class Issue001_Language extends Object {
	public var languageName:String;
	public var objects:ManyToMany<Issue001_Language,Issue001_MyObject>;
}