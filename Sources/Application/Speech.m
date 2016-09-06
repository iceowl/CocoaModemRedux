//
//  Speech.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 2/9/12.
//  Copyright 2012 Kok Chen, W7AY. All rights reserved.
//

#import "Speech.h"
#import "TextEncoding.h"

//	v0.96d

@implementation Speech

@synthesize synth           = _synth;
@synthesize lettersWord     = _lettersWord;
@synthesize enunciate       = _enunciate;
@synthesize buffer          = _buffer;
@synthesize enunciateKeys   = _enunciateKeys;
@synthesize timer           = _timer;

//@property (retain) NSSpeechSynthesizer *synth;
//@property (retain) NSMutableString *lettersWord;
//@property (retain) NSMutableDictionary *enunciate;
//@property (retain) NSMutableArray *buffer;
//@property (retain) NSArray *enunciateKeys;
//@property (retain) NSTimer *timer;


- (void)tick:(NSTimer*)timer
{
	int i ;
	NSMutableString *aggregate ;
	
	if ( needsSound ) {
		if ( producer != consumer ) {
			if ( [ _synth isSpeaking ] == NO ) {
				//  gather up to 8 buffers
				for ( i = 0; i < 8; i++ ) {
					//if ( [ buffer[consumer] characterAtIndex:0 ] == 011 ) {
					//	consumer = ( consumer+1 ) % kVoiceBuffers ;
					//	break ;
					//}
					if ( i == 0 ) aggregate = [ NSMutableString stringWithString:_buffer[consumer] ] ; else [ aggregate appendString:_buffer[consumer] ] ;
					consumer = ( consumer+1 ) % kVoiceBuffers ;
					if ( consumer == producer ) break ;
				}
				[ _synth startSpeakingString:aggregate ] ;
			}
		}
		if ( producer == consumer ) needsSound = NO ;
	}	
}

- (id)initWithVoice:(NSString*)voiceID
{
	int i ;
	NSString *name, *key, *value, *line ;
	NSRange range ;
	const char *path ;
	char string[257], *s ;
	FILE *ext ;
	
	self = [ super init ] ;
 
	if ( self ) {
        _synth = (NSSpeechSynthesizer*)[[ NSSpeechSynthesizer alloc ] initWithVoice:@"Agnes"] ;

        [ _synth setDelegate:self ] ;

		_lettersWord = [[ NSMutableString alloc ] init ] ;					//  v1.0
		previousLetter = 0 ;
		//  v1.0 enunciation
		_enunciate = [[ NSMutableDictionary alloc ] init ] ;
		_enunciateKeys = [ NSArray array ] ;
		if ( _enunciate ) {
			name =  @"~/Library/Application Support/cocoaModem/Enunciate.txt" ;
			path = [ [ name stringByExpandingTildeInPath ] cStringUsingEncoding:NSASCIIStringEncoding ] ;
			ext = fopen( path , "r" ) ;
			if ( ext ) {
				while ( 1 ) {
					string[0] = 0 ;
					if ( fgets( string, 256, ext ) == nil ) break ;
					//  replace eol by null and convert to NSString
					s = string ;
					while ( *s && *s != '\n' && *s != '\r' ) s++ ;
					*s = 0 ;
					line = [ NSString stringWithCString:string encoding:NSASCIIStringEncoding ] ;
					if ( line ) {
						range = [ line rangeOfString:@" " ] ;
						if ( range.location != NSNotFound ) {
							key = [ [ line substringToIndex:range.location ] uppercaseString ] ;
							key = [ [ @" " stringByAppendingString:key ] stringByAppendingString:@" " ] ;
							value = [ line substringFromIndex:range.location+1 ] ;
							if ( key != nil && value != nil ) {
								[ _enunciate setValue:value forKey:key ] ;
							}
						}
					}
				}
				_enunciateKeys = [ _enunciate allKeys ] ;
				fclose( ext ) ;
			}
		}
		//[ enunciateKeys retain ] ;
	        _buffer = [[NSMutableArray alloc] initWithCapacity: kVoiceBuffers];
		for ( i = 0; i < kVoiceBuffers; i++ ) {
			[_buffer insertObject:[[ NSMutableString alloc ] init ] atIndex:i];
			[[_buffer objectAtIndex:i] setString:@" " ] ;
		}
		producer = consumer = 0 ;
		needsSound = enabled = verbatim = deferredDot = muted = useSpell = NO ;
		_timer = nil ;
	}
	return self ;
}

- (void)dealloc
{
	//int i ;
	
	if ( _timer ) [ _timer invalidate ] ;
	//for ( i = 0; i < 64; i++ ) [ buffer[i] release ] ;
	//[ lettersWord release ] ;
	//[ enunciateKeys release ] ;
	//[ enunciate release ] ;
	//[ super dealloc ] ;
}

- (void)speak:(NSString*)string
{
	[ _synth startSpeakingString:string ] ;
}

- (void)queuedSpeak:(NSString*)string
{
	[ [_buffer objectAtIndex:producer] setString:string ] ;
	producer = ( producer+1 ) % kVoiceBuffers ;
	needsSound = YES ;
}

- (void)setVoice:(NSString*)name
{
	if ( name == nil || [ name isEqualToString:@"Default" ] ) {
		[ _synth setVoice:nil ] ;
		return ;
	}
	[ _synth setVoice:name ] ;
}

- (void)setVoiceEnable:(Boolean)state
{
	if ( state == NO ) {
		enabled = NO ;
		if ( _timer ) [ _timer invalidate ] ;
		_timer = nil ;
		[ _synth stopSpeaking ] ;
		return ;
	}
	enabled = YES ;
	if ( _timer == nil ) _timer = [ NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(tick:) userInfo:self repeats:YES ] ;
}

- (void)setVerbatim:(Boolean)state
{
	verbatim = state ;
}

- (void)setMute:(Boolean)state
{
	muted = state ;
	[ self clearVoice ] ;
}

- (void)setSpell:(Boolean)state
{
	useSpell = state ;
	[ self clearVoice ] ;
}

static Boolean isStringBreak( int character )
{
	switch ( character ) {
	case ' ':
	case '.':
	case '!':
	case '?':
	case '/':
	case ',':
	case ':':
	case ';':
	case '\t':
	case '\n':
	case '\r':
		return YES ;
	}
	return NO ;
}

- (void)spell:(int)ascii
{
	if ( ascii >= 'a' && ascii <= 'z' ) ascii += 'A' - 'a' ;	
	if ( ascii == previousLetter ) {
		if ( ascii == '\r' || ascii == '\n' || ascii == ' ' ) return ;
		[ _lettersWord appendString:@"-" ] ;
	}
	previousLetter = ascii ;
	
	switch ( ascii ) {
	case ' ':
		[ _lettersWord appendString:@", ," ] ;
		break ;
	case 'A':
		[ _lettersWord appendString:@" A " ] ;
		break ;
	case 'V':
		[ _lettersWord appendString:@" vee " ] ;
		break ;
	case 'S':
		[ _lettersWord appendString:@" s " ] ;
		break ;
	case 'Z':
		[ _lettersWord appendString:@" zed " ] ;
		break ;

	case 'O':
		[ _lettersWord appendString:@" oh " ] ;
		break ;
	case 'U':
		[ _lettersWord appendString:@" you " ] ;
		break ;
	case 'I':
		[ _lettersWord appendString:@" eye " ] ;
		break ;

	case '-':
		[ _lettersWord appendString:@" minus" ] ;
		break ;
	case '/':
		[ _lettersWord appendString:@". slash" ] ;
		break ;
	case '?':
		[ _lettersWord appendString:@". question" ] ;
		break ;
	case '(':
		[ _lettersWord appendString:@". open parenthesis" ] ;
		break ;
	case ')':
		[ _lettersWord appendString:@". close parenthesis" ] ;
		break ;
	case '\'':
		[ _lettersWord appendString:@". apostrophe" ] ;
		break ;
	case '=':
		[ _lettersWord appendString:@". equal" ] ;
		break ;
	case '%':
		[ _lettersWord appendString:@". percent" ] ;
		break ;
	case '"':
		[ _lettersWord appendString:@". quote" ] ;
		break ;
	case '*':
		[ _lettersWord appendString:@" star" ] ;
		previousLetter = 0 ;
		break ;
	case '.':
		[ _lettersWord appendString:@"/period" ] ;
		break ;
	case ',':
		[ _lettersWord appendString:@"/comma" ] ;
		break ;
	case ':':
		[ _lettersWord appendString:@". colon" ] ;
		break ;
	case ';':
		[ _lettersWord appendString:@". semi colon." ] ;
		break ;
	case '\r':
	case '\n':
		[ _lettersWord appendString:@". . new line." ] ;
		break ;
	default:
		[ _lettersWord appendString:@" " ] ;
		[ _lettersWord appendString:[ NSString stringWithFormat:@"%c", ascii ] ] ;
	}
	
	if ( ascii == ' ' ) {
		producer = ( producer+1 ) % kVoiceBuffers ;
		[ [_buffer objectAtIndex:producer] setString:_lettersWord ] ;
		[ [_buffer objectAtIndex:producer] appendString:@"." ] ;
		[ _lettersWord setString:@" " ] ;
		needsSound = YES ;
	}
	return ;
}

static Boolean substitute( NSMutableString *string, NSString *original, NSString *differentString )
{
	return ( [ string replaceOccurrencesOfString:original withString:differentString options:NSCaseInsensitiveSearch range:NSMakeRange( 0, [ string length ] ) ] > 0 ) ;
}

//	return YES if already spoken
- (Boolean)expand:(NSMutableString*)string
{
	int check, i, length ;
	Boolean hasLetter, hasDigit, substituted, wasDigit, isDigit ;
	NSString *original, *enunciateString ;
	
	if ( verbatim || [ string length ] < 1 ) return NO ;
	
	[ string setString:[ string  lowercaseString ] ] ;
		
	check = [ string characterAtIndex:1 ] ;
	if ( ( check == ' ' || check == '.' || check == '.' ) && [ string length ] >= 2 ) check = [ string characterAtIndex:1 ] ;
	
	original = [ NSString stringWithString:string ] ;
	
	enunciateString = [ _enunciate objectForKey:[ original uppercaseString ] ] ;
	
	if ( enunciateString ) {
		substitute( string, original, enunciateString ) ;
		return YES;
	}
	
	//  v1.02a check for words with mixed letters and digits.  If so, spell it.
	//  first, substitute with known mixed letter/digits
	substituted = YES ;
	switch ( check ) {
	case '1':
		if ( substitute( string, @" 17m ",	@" seventeen meters " ) ) break ;
		if ( substitute( string, @" 15m ",	@" fifteen meters " ) ) break ;
		if ( substitute( string, @" 12m ",	@" twelve meters " ) ) break ;
		if ( substitute( string, @" 10m ",	@" ten meters " ) ) break ;
		if ( substitute( string, @" 17m.",	@" seventeen meters " ) ) break ;
		if ( substitute( string, @" 15m.",	@" fifteen meters " ) ) break ;
		if ( substitute( string, @" 12m.",	@" twelve meters " ) ) break ;
		if ( substitute( string, @" 10m.",	@" ten meters " ) ) break ;
		substituted = NO ;
		break ;
	case '2':
		if ( substitute( string, @" 20m ",	@" twenty meters " ) ) break ;
		if ( substitute( string, @" 20m.",	@" twenty meters " ) ) break ;
		substituted = NO ;
		break ;
	case '3':
		if ( substitute( string, @" 30m ",	@" thirty meters " ) ) break ;
		if ( substitute( string, @" 30m.",	@" thirty meters " ) ) break ;
		substituted = NO ;
		break ;
	case '4':
		if ( substitute( string, @" 40m ",	@" forty meters " ) ) break ;
		if ( substitute( string, @" 40m.",	@" forty meters " ) ) break ;
		substituted = NO ;
		break ;
	case '5':
		if ( substitute( string, @" 599 ",	@" five nine nine, " ) ) break ;
		substituted = NO ;
		break ;
	case '6':
		if ( substitute( string, @" 6m ",	@" six meters " ) ) break ;
		substituted = NO ;
	case '7':
		if ( substitute( string, @" 73 ",	@" seven three, " ) ) break ;
		substituted = NO ;
		break ;
	case '8':
		if ( substitute( string, @" 80m ",	@" eighty meters " ) ) break ;
		if ( substitute( string, @" 80m.",	@" eighty meters " ) ) break ;
		substituted = NO ;
		break ;
	default:
		substituted = NO ;
		break ;
	}
	if ( substituted == NO ) {
		length = (int)[ string length ] ;
		hasLetter = hasDigit = NO ;
		for ( i = 1; i < length; i++ ) {
			check = [ string characterAtIndex:i ] ;
			if ( check >= '0' && check <= '9' ) hasDigit = YES ; 
			if ( check >= 'a' && check <= 'z' ) hasLetter = YES ;
		}
		if ( hasLetter == YES && hasDigit == YES ) {
			enunciateString = [ NSString stringWithString:string ] ;
			[ [_buffer objectAtIndex:producer] setString:@" " ] ;
			wasDigit = NO ;
			length = (int)[ enunciateString length ] ;
			for ( i = 0; i < length; i++ ) {
				check = [ enunciateString characterAtIndex:i ] ;
				isDigit = ( check >= '0' && check <= '9' ) ;
				if ( isDigit == NO && wasDigit == YES ) [ self spell:' ' ] ;
				[ self spell:check ] ;
				wasDigit = isDigit ;
			}
			return YES ;
		}
	}

	check = [ string characterAtIndex:1 ] ;
	switch ( check ) {
	case 'a':
	case 'A':
		if ( substitute( string, @" a ",	@" a-" ) ) break ;
		if ( substitute( string, @" ag ",	@" a-g " ) ) break ;
		if ( substitute( string, @" ar ",	@" a-r " ) ) break ;
		if ( substitute( string, @" arrl ",	@" a-double r ell " ) ) break ;
		if ( substitute( string, @" arrl.",	@" a-double r ell dot " ) ) break ;
		if ( substitute( string, @" abt ",	@" about " ) ) break ;
		if ( substitute( string, @" agn ",	@" again " ) ) break ;
		if ( substitute( string, @" agn?",	@" again? " ) ) break ;
		if ( substitute( string, @" alc ",	@" A L C " ) ) break ;
		if ( substitute( string, @" agc ",	@" A G C " ) ) break ;
		break ;
	case 'b':
	case 'B':
		if ( substitute( string, @" btu ",	@" back to u, " ) ) break ;
		if ( substitute( string, @" btw ",	@" by the way " ) ) break ;
		if ( substitute( string, @" brk ",	@" break. " ) ) break ;
		break ;
	case 'c':
	case 'C':
		if ( substitute( string, @" cul ",	@" see you later, " ) ) break ;
		if ( substitute( string, @" cpy",	@" copy " ) ) break ;
		if ( substitute( string, @" cpy?",	@" copy " ) ) break ;
		if ( substitute( string, @" copy?",	@" copy " ) ) break ;
		if ( substitute( string, @" cuagn ",	@" see you again " ) ) break ;
		if ( substitute( string, @" cocoamodem ",	@" cocoa modem " ) ) break ;
		break ;
	case 'd':
	case 'D':
		if ( substitute( string, @" de ",		@" from " ) ) break ;
		if ( substitute( string, @" dwn ",		@" down " ) ) break ;
		if ( substitute( string, @" op ",		@" operator " ) ) break ;
		if ( substitute( string, @" deg ",		@" degrees. " ) ) break ;
		if ( substitute( string, @" degs ",		@" degrees. " ) ) break ;
		if ( substitute( string, @" db ",		@" decibel. " ) ) break ;
		if ( substitute( string, @" didnt ",	@" didn't " ) ) break ;
		if ( substitute( string, @" doesnt ",	@" doesn't " ) ) break ;
		if ( substitute( string, @" digital ",	@" digital " ) ) break ;
		if ( substitute( string, @" digi",		@" digi-" ) ) break ;
		break ;
	case 'e':
	case 'E':
		if ( substitute( string, @" eqsl(ag) ",		@" e q s l, " ) ) break ;
		if ( substitute( string, @" eqsl ",			@" e q s l, " ) ) break ;
		if ( substitute( string, @" elecraft ",		@" ell-le-craft, " ) ) break ;
		break ;
	case 'f':
	case 'F':
		if ( substitute( string, @" freq ",	@" frequency " ) ) break ;
		if ( substitute( string, @" fldigi ", @" F L digi " ) ) break ;
		if ( substitute( string, @" fldigi.", @" F L digi " ) ) break ;
		break ;
	case 'g':
	case 'G':
		if ( substitute( string, @" gl ",	@" good luck " ) ) break ;
		break ;
	case 'h':
	case 'H':
		if ( substitute( string, @" how ",	@" how " ) ) break ;
		if ( substitute( string, @" hw.",	@" how. " ) ) break ;
		if ( substitute( string, @" hw ",	@" how " ) ) break ;
		if ( substitute( string, @" hr ",	@" here " ) ) break ;
		if ( substitute( string, @" hw?",	@" how copy " ) ) break ;
		break ;
	case 'i':
	case 'I':
		if ( substitute( string, @" icom ",	@" eye com " ) ) break ;
		if ( substitute( string, @" imd ",	@" eye emm dee " ) ) break ;
		break ;
	case 'k':
	case 'K':
		if ( substitute( string, @" k ",		@" go ahead. " ) ) break ;
		if ( substitute( string, @" kk ",		@" go ahead. " ) ) break ;
		if ( substitute( string, @" kkk ",		@" go ahead. " ) ) break ;
		if ( substitute( string, @" kkkk ",		@" go ahead. " ) ) break ;
		if ( substitute( string, @" kn ",	@" go ahead. " ) ) break ;
		if ( substitute( string, @" kt ",	@" knots " ) ) break ;
		if ( substitute( string, @" kt.",	@" knots " ) ) break ;
		break ;
	case 'l':
	case 'L':
		if ( substitute( string, @" loc ",	@" locator " ) ) break ;
		if ( substitute( string, @" lotw ",	@" logbook of the world. " ) ) break ;
		break ;
	case 'm':
	case 'M':
		if ( substitute( string, @" mtr ",	@" meters " ) ) break ;
		break ;
	case 'n':
	case 'N':
		if ( substitute( string, @" nnnn ",	@" end of message. " ) ) break ;
		if ( substitute( string, @" nr?",	@" number? " ) ) break ;
		break ;
	case 'o':
	case 'O':
		if ( substitute( string, @" OM ",	@" O M, " ) ) break ;
		if ( substitute( string, @" OSX ",	@" OS Ten " ) ) break ;
		break ;
	case 'p':
	case 'P':
		if ( substitute( string, @" pse ",	@" please " ) ) break ;
		if ( substitute( string, @" pls ",	@" please " ) ) break ;
		if ( substitute( string, @" pwr ",	@" power " ) ) break ;
		break ;
	case 'q':
	case 'Q':
		if ( substitute( string, @" qrz.com ",	@" Q R Zed dot com. " ) ) break ;
		if ( substitute( string, @" qrz",	@" Q R Zed " ) ) break ;
		if ( substitute( string, @" qso ",	@" Q S Oh " ) ) break ;
		break ;
	case 'r':
	case 'R':
		substitute( string, @" rpt ",		@" report " ) ;
		substitute( string, @" rsq ",		@" R S Q " ) ;
		substitute( string, @" rtty ",		@" re-tee " ) ;
		substitute( string, @" rigblaster ",@" rig blaster " ) ;
		break ;
	case 's':
	case 'S':
		if ( substitute( string, @" sk ",	@" signing off " ) ) break ;
		if ( substitute( string, @" sase ",	@" S A S E " ) ) break ;
		if ( substitute( string, @" sri ",	@" sorry " ) ) break ;
		if ( substitute( string, @" sry ",	@" sorry " ) ) break ;
		if ( substitute( string, @" stdby ",@" standby " ) ) break ;
		break ;
	case 't':
	case 'T':
		if ( substitute( string, @" tnx ",	@" thanks " ) ) break ;
		if ( substitute( string, @" tu ",	@" thank you " ) ) break ;
		break ;
	case 'u':
	case 'U':
		substitute( string, @" ur ",	@" your, " ) ;
		break ;
	case 'v':
	case 'V':
		substitute( string, @" vfo ",	@" V-F-oh " ) ;
		break ;
	case 'w':
	case 'W':
		if ( substitute( string, @" wx. ",		@" weather. " ) ) break ;
		if ( substitute( string, @" wx ",		@" weather " ) ) break ;
		if ( substitute( string, @" windom ",	@" wind dom " ) ) break ;
		if ( substitute( string, @" windoze ",	@" windows " ) ) break ;
		break ;
	case 'x':
	case 'X':
		substitute( string, @" xmit ",	@" transmit " ) ;
		break ;
	case 'y':
	case 'Y':
		if ( substitute( string, @" yaesu ",	@" yea sue " ) ) break ;
		if ( substitute( string, @" yrs ",		@" years " ) ) break ;
		if ( substitute( string, @" yeasu ",	@" yea sue " ) ) break ;
		break ;
	case 'z':
	case 'Z':
		substitute( string, @" zczc ",	@" begin of message. " ) ;
		break ;
	case '.':
		substitute( string, @". /",		@" ,slash " ) ;
		break ;
	case '@':
		substitute( string, @"@",		@" ,at " ) ;
		break ;
	case ':':
		substitute( string, @"@",		@" ,colon " ) ;
		break ;
	case '+':
		substitute( string, @"+",		@" plus " ) ;
		break ;
	case '/':
		substitute( string, @"/",		@". slash " ) ;
		break ;
	case '-':
		substitute( string, @" - ",		@"  " ) ;
		break ;
	case '?':
		substitute( string, @"?",		@" " ) ;
		break ;
	}
	// NSLog(@"(%@) check (%c) -> (%@)", original, check, string ) ;
	
	return NO ;
}

- (void)addToVoice:(int)ascii
{
	int length ;
	
	if ( enabled == NO || muted ) return ;
	
	if ( ascii == 0xd8 || ascii == 0xf8 ) ascii = '0' ;
	else if ( ascii == 8 ) {
		//  backspace
		length = (int)[ [_buffer objectAtIndex:producer] length ] ;
		if ( length > 0 ) {
			[ [_buffer objectAtIndex:producer] deleteCharactersInRange:NSMakeRange( length-1, 1 ) ] ;
			return ;
		}
	}
	
	if ( useSpell ) {
		[ self spell:ascii ] ;
		return ;
	}
	if ( ascii == '=' || ascii == '_' ) return ;
	
	if ( ascii == '\t' || ascii == ':' || ascii == '(' || ascii == ')' ) ascii = ' ' ;
	if ( ascii == '\n' || ascii == '\r' ) ascii = ',' ;
	
	if ( deferredDot && !( ascii == 'c' || ascii == 'C' ) ) {
		deferredDot = NO ;
		[ self expand:[_buffer objectAtIndex:producer] ] ;
		producer = ( producer+1 ) % kVoiceBuffers ;
		[[_buffer objectAtIndex:producer] setString:@" " ] ;
		[[_buffer objectAtIndex:producer] appendString:[ NSString stringWithFormat:@"%c", ascii ] ] ;
		needsSound = YES ;
		return ;
	}
	deferredDot = NO ;
	
	if ( [[_buffer objectAtIndex:producer] length ] > 15 ) {
		[ [_buffer objectAtIndex:producer] setString:@" " ] ;
		return ;
	}
	
	if ( isStringBreak( ascii ) ) {		
		if ( [[_buffer objectAtIndex:producer] length ] > 1 ) {
			switch ( ascii ) {
			default:
				[ [_buffer objectAtIndex:producer] appendString:[ NSString stringWithFormat:@" %c", ascii ] ] ;
				[ self expand:[_buffer objectAtIndex:producer] ] ;
				producer = ( producer+1 ) % kVoiceBuffers ;
				[ [_buffer objectAtIndex:producer] setString:@" " ] ;
				break ;
			case '\n':
			case '\r':
			case ' ':
				[ [_buffer objectAtIndex:producer] appendString:@" " ] ;
				[ self expand:[_buffer objectAtIndex:producer] ] ;
				producer = ( producer+1 ) % kVoiceBuffers ;
				[ [_buffer objectAtIndex:producer] setString:@" " ] ;
				break ;
			case '?':
				[ [_buffer objectAtIndex:producer] appendString:@"?" ] ;
				[ self expand:[_buffer objectAtIndex:producer] ] ;
				producer = ( producer+1 ) % kVoiceBuffers ;
				[ [_buffer objectAtIndex:producer] setString:@" " ] ;
				break ;
			case '.':
				[[_buffer objectAtIndex:producer] appendString:@"." ] ;
				deferredDot = YES ;
				break ;
			case '/':
				[ [_buffer objectAtIndex:producer] appendString:@" " ] ;
				[ self expand:[_buffer objectAtIndex:producer] ] ;
				producer = ( producer+1 ) % kVoiceBuffers ;
				[ [_buffer objectAtIndex:producer] setString:@" . / " ] ;
				[ self expand:[_buffer objectAtIndex:producer] ] ;
				producer = ( producer+1 ) % kVoiceBuffers ;
				[ [_buffer objectAtIndex:producer] setString:@" " ] ;
				break ;
			}
			needsSound = YES ;
		}
	}
	else {
		[ [_buffer objectAtIndex:producer] appendString:[ NSString stringWithFormat:@"%c", ascii ] ] ;
	}
}

- (void)speechSynthesizer:(NSSpeechSynthesizer*)sender didFinishSpeaking:(BOOL)success
{
	if ( producer != consumer && success == YES ) {
		needsSound = YES ;
	}
}

- (void)clearVoice
{
	int i ;
	
	[ _synth stopSpeaking ] ;
	for ( i = 0; i < kVoiceBuffers; i++ ) [ [_buffer objectAtIndex:i] setString:@" " ] ;
	deferredDot = NO ;
	producer = consumer = 0 ;
}

- (void)setRate:(float)rate
{
	//  NSSpeechSynthesizer setRate does not work with 10.4uSDK
}

@end
