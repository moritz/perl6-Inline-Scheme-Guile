use NativeCall;

constant UNKNOWN_TYPE  = -2;
constant VOID          = -1;
constant ZERO          = 0;
constant TYPE_NIL      = 1;
constant TYPE_BOOL     = 2;
constant TYPE_INTEGER  = 3;
constant TYPE_STRING   = 4;
constant TYPE_DOUBLE   = 5;
constant TYPE_RATIONAL = 6;
constant TYPE_COMPLEX  = 7;
constant TYPE_SYMBOL   = 8;
constant TYPE_KEYWORD  = 9;

class Inline::Scheme::Guile::Symbol { has Str $.name }
class Inline::Scheme::Guile::Keyword { has Str $.name }

class Inline::Scheme::Guile::AltDouble is repr('CStruct')
	{
	has num64 $.real_part;
	has num64 $.imag_part;
	}

class Inline::Scheme::Guile::AltType is repr('CUnion')
	{
	has long $.int_content;
	has num64 $.double_content;
	has Str  $.string_content;
	HAS Inline::Scheme::Guile::AltDouble $.complex_content;
	}

class Inline::Scheme::Guile::ConsCell is repr('CStruct')
	{
	has int32 $.type;
	HAS Inline::Scheme::Guile::AltType $.content;
	}

class Inline::Scheme::Guile
	{
	sub native(Sub $sub)
		{
		my Str $path = %?RESOURCES<libraries/guile-helper>.Str;
		die "unable to find libguile-helper library"
			unless $path;
		trait_mod:<is>($sub, :native($path));
		}

	sub _dump( Str $expression ) { ... }
		native(&_dump);

	method _dump( Str $expression )
		{
		say "Asserting '$expression'";
		_dump( $expression );
		}

	sub run( Str $expression,
		 &marshal_guile (Pointer[Inline::Scheme::Guile::ConsCell]) )
		   { ... }
		native(&run);

	method run( Str $expression )
		{
		my @stuff;
		my $ref = sub ( Pointer[Inline::Scheme::Guile::ConsCell] $cell )
			{
			CATCH
				{
				warn "Don't die in callback, warn instead.\n";
				warn $_;
				}
			my $type = $cell.deref.type;
			given $type
				{
				when TYPE_KEYWORD
					{
					my $content = $cell.deref.content;
					@stuff.push( Inline::Scheme::Guile::Keyword.new( :name($content.string_content) ) );
					}

				when TYPE_SYMBOL
					{
					my $content = $cell.deref.content;
					@stuff.push( Inline::Scheme::Guile::Symbol.new( :name($content.string_content) ) );
					}

				when TYPE_STRING
					{
					my $content = $cell.deref.content;
					@stuff.push( $content.string_content );
					}

				when TYPE_COMPLEX
					{
					my $content = $cell.deref.content;
					@stuff.push( $content.complex_content.real_part + ( $content.complex_content.imag_part * i ) );
					}

				when TYPE_RATIONAL
					{
					my $content = $cell.deref.content;
					@stuff.push(
						$content.rational_content.numerator_part /
						$content.rational_content.denominator_part );
					}

				when TYPE_DOUBLE
					{
					my $content = $cell.deref.content;
					@stuff.push( $content.double_content );
					}

				when TYPE_INTEGER
					{
					my $content = $cell.deref.content;
					@stuff.push( $content.int_content );
					}

				when TYPE_BOOL
					{
					my $content = $cell.deref.content;
					if $content.int_content == 1
						{
						@stuff.push( True );
						}
					else
						{
						@stuff.push( False );
						}
					}

				when TYPE_NIL
					{
					@stuff.push( Nil );
					}

				when VOID
					{
					# Don't do anything in this case.
					}

				when UNKNOWN_TYPE
					{
					warn "Unknown type caught\n";
					}
				}
			}
		run( $expression, $ref );
		return @stuff;
		}
	}
