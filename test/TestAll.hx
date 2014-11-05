import utest.Assert;
import utest.Runner;
import utest.ui.Report;
import testcases.*;
import sys.db.*;

class TestAll
{
	static function main(){
		var cnx = switch Sys.args()[0] {
			case "sqlite": Sqlite.open("test.db3");
			case "mysql": Mysql.connect({
				host: "localhost",
				user: "ufrontormtest",
				pass: "ufrontormtest",
				database: "ufrontormtest",
			});
			default: throw "Please specify which db connection (sqlite/mysql) you wish to test with";
		}
		var runner = new Runner();
		addTests( runner, cnx );
		Report.create(runner);
		runner.run();
	}
	
	public static function addTests( runner:Runner, cnx:Connection ) {
		runner.addCase( new TestObjects(cnx) );
		runner.addCase( new TestRelationships(cnx) );
		runner.addCase( new TestSerialization(cnx) );
		runner.addCase( new TestValidation(cnx) );
		runner.addCase( new TestManyToMany(cnx) );
	}
}
