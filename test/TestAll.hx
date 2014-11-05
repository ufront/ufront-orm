import utest.Assert;
import utest.Runner;
import utest.ui.Report;
import testcases.*;
import sys.db.*;

class TestAll
{
	static function main(){
		var runner = new Runner();
		addSQLiteTests( runner );
		Report.create(runner);
		runner.run();
	}

	static function addSQLiteTests( runner:Runner ) {
		var cnx = Sqlite.open("test.db3");
		addTests( runner, cnx );
	}
	
	public static function addTests( runner:Runner, cnx:Connection ) {
		runner.addCase( new TestObjects(cnx) );
		runner.addCase( new TestRelationships(cnx) );
		runner.addCase( new TestSerialization(cnx) );
		runner.addCase( new TestValidation(cnx) );
		runner.addCase( new TestManyToMany(cnx) );
	}
}