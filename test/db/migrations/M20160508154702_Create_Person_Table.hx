package db.migrations;

import ufront.ORM;

class M20160508154702_Create_Person_Table extends Migration {
	public function new() {
		super([
			CreateTable({
				tableName: "Person",
				fields: [
					{ name:"firstName", type:DString(20) },
					{ name:"surname", type:DString(20) },
					{ name:"email", type:DString(50) },
					{ name:"age", type:DTinyUInt },
					{ name:"bio", type:DText },
				],
				indicies: [],
				foreignKeys: [],
			})
		]);
	}
}
