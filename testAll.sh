echo "Compile"
haxe test.hxml || exit

echo "Test neko mysql"
neko build/neko_test.n mysql || exit
echo "Test neko sqlite"
neko build/neko_test.n sqlite || exit

echo "Test PHP mysql"
php build/php_test.php mysql || exit
echo "Test PHP sqlite"
php build/php_test.php sqlite || exit
