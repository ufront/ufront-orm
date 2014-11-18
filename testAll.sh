echo "Start Haxe server"
haxe --wait 6123 &

sleep 1

echo "Compile #1"
haxe --connect 6123 test.hxml || exit

echo "Test neko mysql"
neko build/neko_test.n mysql || exit
echo "Test neko sqlite"
neko build/neko_test.n sqlite || exit

echo "Test PHP mysql"
php build/php_test.php mysql || exit
echo "Test PHP sqlite"
php build/php_test.php sqlite || exit

echo "Compile #2 (using cache)"
haxe --connect 6123 test.hxml || exit

echo "Re-test neko mysql after compile using cache"
neko build/neko_test.n mysql || exit

echo "Finished! All tests passed"
