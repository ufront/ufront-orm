package db.migrations;

import ufront.ORM;

class M20160508203332_Add_Blog_Joins extends Migration {
	public function new() {
		super([
			CreateJoinTable( "testcases.models.Tag", "testcases.models.BlogPost" ),
			AddIndex( "Profile", { fields: ["personID"], unique:false } ),
			AddForeignKey( "Profile", { fields: ["personID"], relatedTableName:"Person", relatedTableFields:["id"], onUpdate:Cascade, onDelete:Cascade } ),
			AddForeignKey( "BlogPost", { fields: ["authorID"], relatedTableName:"Person", relatedTableFields:["id"], onUpdate:Cascade, onDelete:Restrict } ),
		]);
	}
}
