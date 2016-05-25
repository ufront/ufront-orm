package db.migrations;

import ufront.ORM;

class M20160508195741_Create_BlogPost_Profile_Tag_Tables extends Migration {
	public function new() {
		super([
			CreateTable({
				tableName: "BlogPost",
				fields: [
					{ name:"id", type:DId, isNullable:false },
					{ name:"created", type:DDateTime, isNullable:false },
					{ name:"modified", type:DDateTime, isNullable:false },
					{ name:"authorID", type:DInt, isNullable:false },
					{ name:"title", type:DString(255), isNullable:false },
					{ name:"text", type:DText, isNullable:false },
					{ name:"url", type:DString(20), isNullable:false },
				],
				indicies: [{ fields:["url"], unique:true }],
				foreignKeys: [],
			}),
			CreateTable({
				tableName: "Profile",
				fields: [
					{ name:"id", type:DId, isNullable:false },
					{ name:"created", type:DDateTime, isNullable:false },
					{ name:"modified", type:DDateTime, isNullable:false },
					{ name:"personID", type:DInt, isNullable:false },
					{ name:"facebook", type:DString(255), isNullable:true },
					{ name:"twitter", type:DString(255), isNullable:true },
					{ name:"github", type:DString(255), isNullable:true },
				],
				indicies: [],
				foreignKeys: [],
			}),
			CreateTable({
				tableName: "Tag",
				fields: [
					{ name:"id", type:DId, isNullable:false },
					{ name:"created", type:DDateTime, isNullable:false },
					{ name:"modified", type:DDateTime, isNullable:false },
					{ name:"url", type:DString(10), isNullable:false },
				],
				indicies: [],
				foreignKeys: [],
			}),
		]);
	}
}
