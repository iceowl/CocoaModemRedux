//
//  ContestMacroSheet.m
//  cocoaModem
//
//  Created by Kok Chen on 10/15/04.
	#include "Copyright.h"
//

#import "ContestMacroSheet.h"
#include "ContestInterface.h"
#include "ContestManager.h"


@implementation ContestMacroSheet

@synthesize captionStore = _captionStore;
@synthesize messageStore = _messageStore;

- (id)initSheet
{
	NSRect rect ;
	
	self = [ super init ] ;
	if ( self ) {
	
		_messageStore = @""  ;
		_captionStore = _messageStore ;
		contestManager = nil ;
		[ self updateFromMessageObject:_messageStore titleObject:_captionStore ] ;

		if ( [ [NSBundle mainBundle] loadNibNamed:@"ContestMacroSheet" owner:self topLevelObjects:nil] ) {
			rect = [ view bounds ] ;
			[ self setFrame:rect display:NO ] ;
			[ [ self contentView ] addSubview:view ] ;
		}
	}
	return self ;
}

- (void)delegateTextChangesTo:(ContestManager*)manager
{
	contestManager = manager ;
	[ titleMatrix setDelegate:manager ] ;
	[ macroMatrix setDelegate:manager ] ;
}

- (void)setName:(NSString*)str
{
	[ contestSheetName setStringValue:str ] ;
}

- (NSString*)messages
{
	//[ messageStore release ] ;
	_messageStore = (NSString*)[  self getMessageObject ]  ;
	return _messageStore ;
}

- (NSString*)captions
{
	//[ captionStore release ] ;
	_captionStore = (NSString*) [ self getCaptionObject ]  ;
	return _captionStore ;
}

//  macro storage delimited by ~ characters
- (void)setMessages:(NSString*)mString
{
	NSString *old ;
	
	old = _messageStore ;
	_messageStore =  mString ;
	//if ( old ) [ old release ] ;
	[ self updateFromMessageObject:_messageStore titleObject:_captionStore ] ;
}

- (void)setCaptions:(NSString*)tString
{
	NSString *old ;
	
	old = _captionStore ;
	_captionStore =  tString ;
	//if ( old ) [ old release ] ;
	[ self updateFromMessageObject:_messageStore titleObject:_captionStore ] ;
}

//  button macros for contest
- (Boolean)executeButtonMacro:(char*)str modem:(MacroInterface*)macroInterface
{
	if ( str[0] == 'r' && str[1] == 'x' ) {
		//  add to end of stream
		excessTransmitMacros-- ;
		[ self appendToMessageBuf:[ NSString stringWithFormat:@"%c", 5 /*^E*/ ] ] ;
		return YES ;
	}	
	if ( str[0] == 't' && str[1] == 'x' ) {
		//  immediate
		[ self appendToMessageBuf:[ NSString stringWithFormat:@"%c", 6 /*^F*/ ] ] ;
		excessTransmitMacros++ ;
		[ macroInterface sendMessageImmediately ] ;
		return YES ;
	}
	//  v0.89 MacroScript
	if ( str[0] == 'a' ) {
		return [ self executeMacroScript:str ] ;
	}
	if ( str[0] == 's' && str[1] == 'l' ) {
		//  save file
		if ( contestManager ) [ contestManager actualSaveContest ] ;
		return YES ;
	}
	return NO ;
}

- (void)showMacroSheet:(NSWindow*)window
{
	controllingWindow = window ;
	[ NSApp beginSheet:self modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil ] ;
	//  [ NSApp runModalForWindow:self ] ;
	//  dont use modal mode so we can show dictionary
}

- (void)performDone
{
	[ (ContestInterface*)modem updateContestMacroButtons ] ;
	[ NSApp endSheet:self ] ;
	[ self orderOut:controllingWindow ] ;
}

@end
