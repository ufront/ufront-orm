# 1.0.0

This is a 1.0.0 release of ufront-orm

Small changes and bug fixes present.

-PHP Mysql : Fixes error in testValidateFieldFunction (Thanks Jon Borgonia)
-Fix compilation error when `sys.db.Types` is  not imported and `BelongsTo<>` is used. (Thanks Kevin Leung)
-Remove sys.db.Manager patch that was only required for Haxe 3.1.3
-Improved unit test coverage.

Please note that this library is failing with the Haxe development version at the time of release.
See [bug 4470](https://github.com/HaxeFoundation/haxe/issues/4470).
Please use Haxe 3.2.0 for now.

---

# Older changes

For changes prior to 1.0.0, please see http://lib.haxe.org/p/ufront-orm/versions/
