package db.migrations;

import ufront.ORM;

class M20160508195741_Create_BlogPost_Profile_Tag_Tables extends Migration {
	public function new() {
		super([
			CreateTable({
				tableName: "BlogPost",
				fields: [
					{ name:"authorID", type:DId },
					{ name:"title", type:DString(255) },
					{ name:"text", type:DText },
					{ name:"url", type:DString(20) },
				],
				indicies: [{ fields:["url"], unique:true }],
				foreignKeys: [],
			}),
			CreateTable({
				tableName: "Profile",
				fields: [
					{ name:"personID", type:DId },
					{ name:"facebook", type:DString(255) },
					{ name:"twitter", type:DString(255) },
					{ name:"github", type:DString(255) },
				],
				indicies: [],
				foreignKeys: [],
			}),
			CreateTable({
				tableName: "Tag",
				fields: [
					{ name:"url", type:DString(10) },
				],
				indicies: [],
				foreignKeys: [],
			}),
		]);
	}
}
