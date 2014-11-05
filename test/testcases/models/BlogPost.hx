package testcases.models;

import ufront.db.Object;
import ufront.db.ManyToMany;
import sys.db.Types;

class BlogPost extends Object {
	static var reservedWords = ["about","home","contact","blog"];
	static var bannedWords = ["typescript","dart","hack"];
	
	public var author:BelongsTo<Person>;
	
	@:validate( title.length>0, "Your blog post must have a title" )
	public var title:SString<255>;
	
	@:validate( _.length>0, "You cannot have an empty blog post" )
	public var text:SText;
	function validate_text() {
		// We can have some more complex validation logic in a function.
		if ( text.split(" ").length>1000 )
			validationErrors["text"] = "More than 1000 words, this isn't an essay!";
		for ( bannedWord in bannedWords )
			if ( text.indexOf(bannedWord)>-1 ) validationErrors.set( "text", 'The word $bannedWord is not allowed!' );
	}
	
	@:validate( _.length>=3, "Your url must be at least 3 letters long" )
	@:validate( reservedWords.indexOf(_)==-1, "Your url must not be one of the reserved words "+reservedWords )
	@:validate( ~/^[a-z0-9_]+$/.match(_), "Your url must only use a-z, 0-9 and underscores" )
	public var url:SString<20>;
	
	public var tags:ManyToMany<BlogPost,Tag>;
	
	/**
		You can also perform a custom validation function.
	**/
	override public function validate() {
		super.validate();
		// Check that we don't already have another blog post with the same URL
		var existingPost = BlogPost.manager.select( $url==url );
		if ( existingPost!=null && existingPost.id!=this.id )
			validationErrors["url"] = 'The URL $url already exists on the post ${existingPost.title}.';
		return validationErrors.isValid;
	}
}