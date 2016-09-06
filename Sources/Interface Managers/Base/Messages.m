//
//  Messages.m
//  cocoaModem
//
//  Created by Kok Chen on Tue Jun 08 2004.
	#include "Copyright.h"
//

#import "Messages.h"
#import "AYTextView.h"
#import "TextEncoding.h"
#import "Application.h"
#import "AppDelegate.h"

@implementation Messages

@synthesize sessionStartDate   = _sessionStartDate;
@synthesize controllingTabView = _controllingTabView;
@synthesize logTabItem         = _logTabItem;
@synthesize logView            = _logView;
@synthesize bufferedString     = _bufferedString;


static Messages *mainLog ;


+ (void)logMessage:(char*)format,...
{
	va_list ap ;
	char msg[256] ;
	
	va_start( ap, format ) ;						//  v0.38  reduce vargs to a single level
	vsprintf( msg, format, ap ) ;
	va_end( ap ) ;

	[ mainLog msg:msg ] ;
}

+ (int)alertWithMessageText:(NSString*)msg informativeText:(NSString*)info
{
	//  v1.02e
	if ( [ [ NSApp delegate ] appLevel ] == 0 ) {
		if ( [ [ NSApp delegate ] voiceAssist ] ) {
			[ [ NSApp delegate ] speakAssist:[ NSString stringWithFormat:@"Alert! %@ .", msg ] ] ;
			[ [ NSApp delegate ] setSpeakAssistInfo:info ] ;
			return NSAlertDefaultReturn ;
		}
	}
	else {
		if ( [ [ [ NSApp delegate ] application ] voiceAssist ] ) {
			[ [ [ NSApp delegate ] application ] speakAssist:[ NSString stringWithFormat:@"Alert! %@ .", msg ] ] ;
			[ [ [ NSApp delegate ] application ] setSpeakAssistInfo:info ] ;
			return NSAlertDefaultReturn ;
		}
	}
	return (int)[ [ NSAlert alertWithMessageText:msg defaultButton:NSLocalizedString( @"OK", nil ) alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@",info ] runModal ] ;
}

+ (void)alertWithHiraganaError
{
	[ [ NSAlert alertWithMessageText:NSLocalizedString( @"Unrecognized encoding", nil ) defaultButton:NSLocalizedString( @"OK", nil ) alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString( @"kotoeri", nil ) ] runModal ] ;
}

+ (void)appleScriptError:(NSDictionary*)dict script:(const char*)from
{
	int code ;
	NSString *msg ;
	NSString *nstr ;
	char *errString, str[256] ;

	if ( dict ) {
		code = [ [ dict objectForKey:NSAppleScriptErrorNumber] intValue ] ;
		msg = [ dict objectForKey:NSAppleScriptErrorMessage ] ;
		nstr = nil ;
		switch ( code ) {
		case -43:
			nstr = NSLocalizedString( @"File not found", nil ) ;
			break ;
		case -120:
			nstr = NSLocalizedString( @"Directory not found", nil ) ;
			break ;
		case -128:
			//  user cancelled
			return ;
		case -1703:
			nstr = NSLocalizedString( @"Wrong data type", nil ) ;
			break ;
		case -2753:
			nstr = NSLocalizedString( @"Undefined variable", nil ) ;
			break ;
		}
		if ( nstr == nil ) {
			errString = (char*)[ [ [ NSError errorWithDomain:NSOSStatusErrorDomain code:code userInfo:nil ] localizedDescription ] cStringUsingEncoding:NSASCIIStringEncoding  ] ;
			sprintf( str, "%s for %s script.\n\nError detail: %s", errString, from, [ msg cStringUsingEncoding:NSASCIIStringEncoding  ] ) ;
		}
		else {
			errString = (char*)[ nstr cStringUsingEncoding:NSUTF8StringEncoding ] ;
			sprintf( str, "%s for %s script.", errString, from ) ;
		}
		[ self alertWithMessageText:NSLocalizedString( @"AppleScript error", nil ) informativeText:[ NSString stringWithCString:str encoding:NSASCIIStringEncoding] ] ;
	}
}

//  initialize with given view
- (id)initIntoView:(NSTextView*)view
{
	self = [ super init ] ;
	if ( self ) {
		_sessionStartDate = [ NSDate date ] ;
		if ( [ [NSBundle mainBundle] loadNibNamed:@"ModemLog" owner:self topLevelObjects:nil ] ) {
			// loadNib should have set up contentView connection
			if ( contentView ) {
				mainLog = self ;
				_logView = view ;
				return self ;
			}
		}
	}
	return nil ;
}

//  initialize, and load the log view from the Nib into the tab view (not used in cocoaModem 2.0)
- (id)initIntoTabView:(NSTabView*)tabview
{
	self = [ super init ] ;
	if ( self ) {
		_sessionStartDate =  [ NSDate date ] ;
		if ( [ [NSBundle mainBundle] loadNibNamed:@"ModemLog" owner:self topLevelObjects:nil] ) {
			// loadNib should have set up contentView connection
			if ( contentView ) {
				//  create a new TabViewItem for config
				_logTabItem = [ [ NSTabViewItem alloc ] init ] ;
				[ _logTabItem setLabel:@"Diagnostics" ] ;
				[ _logTabItem setView:contentView ] ;
				//  and insert as tabView item
				_controllingTabView = tabview ;
				[ _controllingTabView addTabViewItem:_logTabItem ] ;
				mainLog = self ;
				return self ;
			}
		}
	}
	return nil ;
}

- (void)appendToBuffer:(NSString*)str
{
	if ( str == nil ) return ;
	
	[ _bufferedString appendString:str ] ;

	if ( [ [ _logView window ] isVisible ] ) {
		[ _logView setEditable:YES ] ;
		[ _logView insertText:_bufferedString ] ;
		[ _logView setEditable:NO ] ;
		[ _bufferedString setString:@"" ] ;
	}
}

- (void)show
{
	NSWindow *window ;
	
	window = [ _logView window ] ;
	[ window orderFront:self ] ;
	if ( [ _bufferedString length ] > 0 ) {
		[ self appendToBuffer:@"" ] ;
	}
}

- (void)awakeFromApplication
{
	mainLog = self ;
	_bufferedString = [ NSMutableString stringWithCapacity:4096 ];
	[ self appendToBuffer:NSLocalizedString( @"welcome", nil ) ] ;
}

- (void)msg:(char*)msg
{
	double elapsed ;
	int m, s, n ;
	char fullmsg[256] ;
	
	elapsed = [ [ NSDate date ] timeIntervalSinceDate:_sessionStartDate ] ;
	n = elapsed ;
	s = n%60 ;
	m = ( n/60 )%60;
	n = ( elapsed-n )*1000 ;
	if ( n >= 1000 ) n = 999 ;
	
	sprintf( fullmsg, "[ %02d: %02d: %02d.%03d ]  %s\n", n/3600, m, s, n, msg ) ;	
	[ (Messages*)mainLog appendToBuffer:[ NSString stringWithCString:fullmsg encoding:NSASCIIStringEncoding] ] ;
}


@end
