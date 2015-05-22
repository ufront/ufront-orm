import utest.Assert;
import utest.Runner;
import utest.ui.Report;
import testcases.*;
import testcases.issues.*;
import sys.db.*;

class TestAll
{
	static function main(){
		var cnx = switch Sys.args()[0] {
			case "sqlite": Sqlite.open("test.db3");
			case "mysql": Mysql.connect({
				host: Sys.environment().exists("MYSQL_HOST")? Sys.getEnv("MYSQL_HOST") : "localhost",
				port: Sys.environment().exists("MYSQL_PORT")? Std.parseInt(Sys.getEnv("MYSQL_PORT")) : 3306,
				user: Sys.environment().exists("MYSQL_USER")? Sys.getEnv("MYSQL_USER") : "root",
				pass: Sys.environment().exists("MYSQL_PASSWORD")? Sys.getEnv("MYSQL_PASSWORD") : "root",
				database: Sys.environment().exists("MYSQL_DATABASE")? Sys.getEnv("MYSQL_DATABASE") : "ufrontormtest",
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
		
		runner.addCase( new Issue001(cnx) );
	}
}
