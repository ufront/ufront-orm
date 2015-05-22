#!/bin/bash

HAXE_COMPILER_PORT=6123

echo "Start Haxe server"
if [ -f /tmp/haxe_compiler.$HAXE_COMPILER_PORT.pid ]
  then
    kill -9 $(cat /tmp/haxe_compiler.$HAXE_COMPILER_PORT.pid) &> /dev/null ;
    rm /tmp/haxe_compiler.$HAXE_COMPILER_PORT.pid
fi
haxe --wait $HAXE_COMPILER_PORT &
echo "$!" > /tmp/haxe_compiler.$HAXE_COMPILER_PORT.pid

sleep 1

mkdir -p doc build

echo "Compile #1"
haxe --connect $HAXE_COMPILER_PORT test.hxml || exit

echo "Test neko mysql"
neko build/neko_test.n mysql || exit
echo "Test neko sqlite"
neko build/neko_test.n sqlite || exit

echo "Test PHP mysql"
php build/php_test.php mysql || exit
echo "Test PHP sqlite"
php build/php_test.php sqlite || exit

echo "Compile #2 (using cache)"
haxe --connect $HAXE_COMPILER_PORT test.hxml || exit

echo "Re-test neko mysql after compile using cache"
neko build/neko_test.n mysql || exit

echo "Finished! All tests passed"
