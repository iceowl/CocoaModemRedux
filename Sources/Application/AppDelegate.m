//
//  AppDelegate.m
//  cocoaModem
//
//  Created by Kok Chen on 7/26/05.
//	Renamed from AESupport.m 10/4/09.
	#include "Copyright.h"
//

#import "AppDelegate.h"
#import "Application.h"
#import "AudioManager.h"
#import "AuralMonitor.h"
#import "FSKHub.h"
#import "ModemManager.h"
#import "PSK.h"
#import "QSO.h"
#import "StdManager.h"
#import "TextEncoding.h"

@implementation AppDelegate

@synthesize auralMonitor = _auralMonitor;
@synthesize audioManager = _audioManager;
@synthesize stdManager   = _stdManager;
@synthesize myRig        = _myRig;

//  this is a subclass of NSScriptCommand, to intercept AppleScript commands
//  this is the deletgate of NSApplication and intercepts the Applescripts for the
//	application class.

//  this object is also a delegate of NSApplication

- (int)appLevel
{
	return 1 ;
}

- (id)initFromApplication:(Application*)app
{
	self = [ super init ] ;
	if ( self ) {
		isLite = NO ;
		windowIsVisible = YES ;
		application = app ;
		_stdManager = [ app stdManagerObject ] ;
        _audioManager = [app audioManager];
        _auralMonitor = application.auralMonitor;
        _myRig = application.myRig;
        
		[ [ NSApplication sharedApplication ] setDelegate:self ] ;
	}
	return self ;
}

- (Application*)application
{
	return application ;
}

//- (AuralMonitor*)auralMonitor
//{
//	return  application.auralMonitor  ;
//}
//
//- (AudioManager*)audioManager
//{
//	return application.audioManager ;
//}

- (Boolean)isLite
{
	return isLite ;
}

- (void)setIsLite:(Boolean)state
{
	isLite = state ;
}

- (Boolean)windowIsVisible
{
	return windowIsVisible ;
}

- (void)setWindowIsVisible:(Boolean)state
{
	windowIsVisible = state ;
}

//  called from Application (delegate of NSApplication)
- (BOOL)application:(NSApplication*)sender delegateHandlesKey:(NSString*)key 
{
	//printf( "delegateHandlesKey %s\n", [ key cStringUsingEncoding:NSASCIIStringEncoding  ] ) ;
	
	//  Classes
	if ( [ key isEqual:@"windowState" ] ) return YES ;
	if ( [ key isEqual:@"windowPosition" ] ) return YES ;
	if ( [ key isEqual:@"watchdogTimer" ] ) return YES ;
	if ( [ key isEqual:@"interactiveInterface" ] ) return YES ;
	if ( [ key isEqual:@"contestInterface" ] ) return YES ;
	if ( [ key isEqual:@"scriptVersion" ] ) return YES ;	
	if ( [ key isEqual:@"version" ] ) return YES ;	
	if ( [ key isEqual:@"rttyModem" ] ) return YES ;
	if ( [ key isEqual:@"dualRTTYModem" ] ) return YES ;
	if ( [ key isEqual:@"widebandRTTYModem" ] ) return YES ;
	if ( [ key isEqual:@"pskModem" ] ) return YES ;
	if ( [ key isEqual:@"hellModem" ] ) return YES ;
	if ( [ key isEqual:@"cwModem" ] ) return YES ;
	if ( [ key isEqual:@"mfskModem" ] ) return YES ;
	if ( [ key isEqual:@"qso" ] ) return YES ;
	if ( [ key isEqual:@"modemName" ] ) return YES ;		

	//  deprecated
	if ( [ key isEqual:@"modemMode" ] ) return YES ;		
	if ( [ key isEqual:@"pskModulation" ] ) return YES ;
	if ( [ key isEqual:@"qsoCall" ] ) return YES;
    if ( [ key isEqual:@"qsoName" ] ) return YES;
    if ( [ key isEqual:@"pskRxAOffset" ] ) return YES;
    if ( [ key isEqual:@"pskRxBOffset" ] ) return YES;
    if ( [ key isEqual:@"pskTxAOffset" ] ) return YES;
    if ( [ key isEqual:@"pskTxBOffset" ] ) return YES;

	return NO;
}

//  AppleScript Classes

- (QSO*)qso
{
	return  [ _stdManager qsoObject ] ;
}

- (ModemManager*)interactiveInterface
{
	return _stdManager ;
}

- (ModemManager*)contestInterface
{
	return _stdManager ;
}

- (ModemManager*)watchdogTimer
{
	return _stdManager ;
}

- (int)scriptVersion
{
	return 3 ;
}

- (NSString*)version
{
	return [ [ NSBundle mainBundle ] objectForInfoDictionaryKey:@"CFBundleVersion" ] ;
}

- (Modem*)rttyModem
{
	return [ _stdManager rttyModem ] ;
}

- (Modem*)widebandRTTYModem
{
	return [ _stdManager wfRTTYModem ] ;
}

- (Modem*)dualRTTYModem
{
	return [ _stdManager dualRTTYModem ] ;
}

- (Modem*)pskModem
{
	return [ _stdManager pskModem ] ;
}

- (Modem*)hellModem
{
	return [ _stdManager hellschreiberModem ] ;
}

- (Modem*)cwModem
{
	return [ _stdManager cwModem ] ;
}

- (Modem*)mfskModem
{
	return [ _stdManager mfskModem ] ;
}

- (NSString*)modemName
{
	return [ _stdManager selectedModemName ] ;
}

//  we are delegate to NSApplication
//  call application to execute termination code
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender
{
	return [ application terminate ] ;
}

- (Boolean)windowState
{
	return [ _stdManager windowState ] ;
}

- (void)setWindowState:(Boolean)state 
{
	[ _stdManager setWindowState:state ] ;
}

- (NSAppleEventDescriptor*)windowPosition 
{
	NSAppleEventDescriptor *desc ;
	NSPoint point ;
	int x, y ;
	
	point = [ _stdManager windowPosition ] ;
	x = point.x + 0.5 ;
	y = point.y + 0.5 ;
	
	desc = [ NSAppleEventDescriptor listDescriptor ] ;
	[ desc insertDescriptor:[ NSAppleEventDescriptor descriptorWithInt32:x ] atIndex:1 ] ;
	[ desc insertDescriptor:[ NSAppleEventDescriptor descriptorWithInt32:y ] atIndex:2 ] ;
	return desc ;
}

- (void)setWindowPosition:(NSAppleEventDescriptor*)point 
{
	NSAppleEventDescriptor *desc ;
	float x, y ;
	
	if ( [ point numberOfItems ] == 2 ) {
		desc = [ point descriptorAtIndex:1 ] ;
		x = [ desc int32Value ] ;
		desc = [ point descriptorAtIndex:2 ] ;
		y = [ desc int32Value ] ;
		[ _stdManager setWindowPosition:NSMakePoint( x, y ) ] ;
	}
}

//  the following supports the deprecated AppleScripts
- (int)modemMode
{
	return [ [ application interface ] modemMode ] ;
}

- (void)setModemMode:(int)mode
{
	//printf( "setModemMode to %c%c%c%c\n", ( mode >> 24 )&0xff,( mode >> 16 )&0xff,( mode >> 8 )&0xff,( mode )&0xff ) ;
	[ [ application interface ] setModemMode:mode ] ;
}

- (int)pskModulation
{
	return [ [ application interface ] pskModulation ] ;
}

- (void)setPskModulation:(int)modulation
{
	[ [ application interface ] setPskModulation:modulation ] ;
}

- (NSString*)qsoCall
{
	QSO *qso = [ _stdManager qsoObject ] ;
	
	if ( qso ) return [ qso callsign ] ;
	return @"" ;
}

- (void)setQsoCall:(NSString*)setstring
{
	QSO *qso = [ _stdManager qsoObject ] ;

	if ( qso ) [ qso setCallsign:setstring ] ;
}

- (NSString*)qsoName
{
	QSO *qso = [ _stdManager qsoObject ] ;

	if ( qso ) return [ qso opName ] ;
	return @"" ;
}

- (void)setQsoName:(NSString*)setstring
{
	QSO *qso = [ _stdManager qsoObject ] ;

	if ( qso ) [ qso setOpName:setstring ] ;
}

//  to be deprecated (moved to faces)
- (NSString*)pskRxAOffset
{
	float v = 0 ;
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;
	
	if ( psk ) v = [ psk getRxOffset:0 ] ;
	return [ NSString stringWithFormat:@"%f",v ] ;
}

//  to be deprecated (moved to faces)
- (NSString*)pskRxBOffset
{
	float v = 0 ;
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;
	
	if ( psk ) v = [ psk getRxOffset:1 ] ;
	return [ NSString stringWithFormat:@"%f",v ] ;
}

//  to be deprecated (moved to faces)
- (NSString*)pskTxAOffset
{
	float v = 0 ;
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;
	
	if ( psk ) v = [ psk getTxOffset:0 ] ;
	return [ NSString stringWithFormat:@"%f",v ] ;
}

//  to be deprecated (moved to faces)
- (NSString*)pskTxBOffset
{
	float v = 0 ;
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;
	
	if ( psk ) v = [ psk getTxOffset:1 ] ;
	return [ NSString stringWithFormat:@"%f",v ] ;
}

//  to be deprecated (moved to faces)
- (void)setPskRxAOffset:(NSString*)freq
{
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;

	if ( psk ) [ psk setRxOffset:0 freq:[ freq floatValue ] ] ;
}

//  to be deprecated (moved to faces)
- (void)setPskRxBOffset:(NSString*)freq
{
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;

	if ( psk ) [ psk setRxOffset:1 freq:[ freq floatValue ] ] ;
}

//  to be deprecated (moved to faces)
- (void)setPskTxAOffset:(NSString*)freq
{
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;

	if ( psk ) [ psk setTxOffset:0 freq:[ freq floatValue ] ] ;
}

//  to be deprecated (moved to faces)
- (void)setPskTxBOffset:(NSString*)freq
{
	PSK *psk = (PSK*)[ _stdManager pskModem ] ;

	if ( psk ) [ psk setTxOffset:1 freq:[ freq floatValue ] ] ;
}

@end
