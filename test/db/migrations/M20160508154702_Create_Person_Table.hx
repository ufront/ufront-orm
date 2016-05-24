package db.migrations;

import ufront.ORM;

class M20160508154702_Create_Person_Table extends Migration {
	public function new() {
		super([
			CreateTable({
				tableName: "Person",
				fields: [
					{ name:"firstName", type:DString(20), isNullable:false },
					{ name:"surname", type:DString(20), isNullable:false },
					{ name:"email", type:DString(50), isNullable:false },
					{ name:"age", type:DTinyUInt, isNullable:false },
					{ name:"bio", type:DText, isNullable:true },
				],
				indicies: [],
				foreignKeys: [],
			})
		]);
	}
}
