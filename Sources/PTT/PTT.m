//
//  PTT.m
//  cocoaPTT
//
//  Created by Kok Chen on 2/26/06.
	#include "Copyright.h"
	
#import "PTT.h"
#include "PTTPlist.h"
#include <sys/ioctl.h>
#include <unistd.h>
#include <sys/errno.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include "SerialPort.h"
#include "microKEYER.h"


@implementation PTT

@synthesize stream  = _stream;
@synthesize path    = _path;
@synthesize plistPath = _plistPath;
@synthesize prefs   = _prefs;

static int rtsMap[] = { 1, 0, 2 } ;			//  correspondence between pref button and useRTS variable

- (void)alertMessage:(NSString*)msg informativeText:(NSString*)info
{
	[ [NSAlert alertWithMessageText:msg defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:[NSString stringWithString:info]] runModal] ;
}

- (id) init {
    self = [super init];
    if(self){
        
        _stream = [[NSMutableArray alloc] initWithCapacity:PTTSIZE];
        _path   = [[NSMutableArray alloc] initWithCapacity:PTTSIZE];
        
        for(int i = 0;i<PTTSIZE;i++) {
            [_stream addObject:@""];
        }
        
        
    }
    return self;
}

- (void)newPort:(int)i
{
	PTTDevice *old ;
	NSString *pathi, *streami ;
	char msg[256] ;
	
	old = ptt ;
	pathi = _path[i] ;
	streami = _stream[i] ;
	//  open as serial port
	ptt = [ [ SerialPort alloc ] initWithDevice:pathi name:streami allowRead:allowRead ] ;
	if ( ptt ) {
		//  v1.8 -- close and open again, in case port was left opened
		[ ptt close ] ;
		//[ ptt release ] ;
		ptt = [ [ SerialPort alloc ] initWithDevice:pathi name:streami allowRead:allowRead ] ;
	}
//	if ( old ) [ old release ] ;
	
	if ( !ptt ) {
		sprintf( msg, "Serial port named \"%s\" cannot be opened for use.", [ _stream[i] UTF8String ] ) ;
		[ self alertMessage:@"Cannot open port." informativeText:[ NSString stringWithUTF8String:msg ] ] ;
	}
	[ self setUnkey ] ;		// 1.3
}

- (void)awakeFromNib
{
    
    CFPropertyListFormat theFormat = kCFPropertyListXMLFormat_v1_0;
	NSString *bundleName, *errorString, *selectedStream ;
	NSData *xmlData ;
	NSRect frame ;
	char str[128] ;
	CFPropertyListRef plist ;
	int i ;
	
	frame = [ window frame ] ;
	frame.size.height = 60 ;
	frame.size.width = 160 ;
	[ window setFrame:frame display:YES ] ;
	[ (NSPanel*)window setFloatingPanel:NO ] ;
	[ window setHidesOnDeactivate:NO ] ; 
	[ window orderFront:self ] ; 
		
	//  initial preference value
	useRTS = 1 ;
	allowRead = NO ;
	activeHigh = YES ;
	_prefs = [ [ NSMutableDictionary alloc ] init ] ;
	[ _prefs setObject:[ NSNumber numberWithInt:1 ] forKey:kPrefVersion ] ;
	[ _prefs setObject:[ NSNumber numberWithInt:1 ] forKey:kActiveHigh ] ;
	[ _prefs setObject:[ NSNumber numberWithInt:1 ] forKey:kUseRTS ] ;
	[ _prefs setObject:[ NSNumber numberWithInt:1 ] forKey:kDisableRead ] ;
	[ _prefs setObject:[ window stringWithSavedFrame ] forKey:kWindowPosition ] ;
	[ _prefs setObject:@"" forKey:kPortName ] ;
	
	ptt = nil ;
	ports = [ self findPorts ] ;
	
	for ( i = 0; i < ports; i++ ) {
		[ serialPortMenu addItemWithTitle:_stream[i] ] ;
	}
	
	//  ---- update prefs from plist file ----
	bundleName = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey:@"CFBundleIdentifier" ] ;
	strcpy( str, kPlistDirectory ) ;
	if ( bundleName ) {
		strcat( str, [ bundleName UTF8String ] ) ;
		strcat( str, ".plist" ) ;
		//[ bundleName release ] ;
	}
	_plistPath = [ [ NSString stringWithUTF8String:str ] stringByExpandingTildeInPath ]  ;
	//xmlData = [ NSData dataWithContentsOfFile:plistPath ] ;
	//plist = (__bridge id)CFPropertyListCreateFromXMLData( kCFAllocatorDefault, (__bridge CFDataRef)xmlData, kCFPropertyListImmutable, &errorString ) ;
    
    xmlData = [[NSData alloc] initWithContentsOfFile:_plistPath] ;
	if ( xmlData ) {
		//  get plist from XML data
        CFErrorRef eRef;
        CFDataRef dRef = CFDataCreate(kCFAllocatorDefault, [xmlData bytes], [xmlData length]);
        //  CFDataRef dRef = CFPropertyListCreateData(NULL, [xmlData bytes], kCFPropertyListXMLFormat_v1_0, 0, &eRef);
        
        
		//plist = (id)CFPropertyListCreateFromXMLData( kCFAllocatorDefault, (CFDataRef)xmlData, kCFPropertyListImmutable, (CFStringRef*)&errorString ) ;
        
        plist = CFPropertyListCreateWithData(kCFAllocatorDefault, dRef, kCFPropertyListImmutable, &theFormat, &eRef);
        
		if ( plist ) {
			// merge and overwrite default values
			[ _prefs addEntriesFromDictionary:(__bridge NSDictionary *)(plist) ] ;
			//CFRelease( plist ) ;
		}
		//  v0.76 fix leaked memory
        //	if ( errorString ) CFRelease( errorString ) ;
        

	}

    
    
    
    
//	if ( plist ) {
//		// merge and overwrite default values
//		[ prefs addEntriesFromDictionary:plist ] ;
//	}
	//[ plist release ] ;
	
	//  update from prefs after reading plist
	[ window setFrameFromString:[ _prefs objectForKey:kWindowPosition ] ] ;
	selectedStream = [ _prefs objectForKey:kPortName ] ;
	
	useRTS = [ [ _prefs objectForKey:kUseRTS ] intValue ] ;
	[ rtsPrefMatrix selectCellAtRow:rtsMap[ useRTS ] column:0 ] ;
	
	activeHigh = ( [ [ _prefs objectForKey:kActiveHigh ] intValue ] > 0 ) ;
	[ activePrefMatrix selectCellAtRow:(activeHigh) ? 0 : 1 column:0 ] ;

	allowRead = ( [ [ _prefs objectForKey:kDisableRead ] intValue ] == 0 ) ;
	[ disableReadCheckbox setState:( allowRead ) ? NSOffState : NSOnState ] ;
	
	if ( selectedStream == nil || [ selectedStream length ] <= 0 ) {			//  v1.7
		[ self alertMessage:@"Serial port not yet selected." informativeText:@"Please open the Preferences panel to select the serial port." ] ;
	}
	else {
		//  select the stream from plist file
		[ serialPortMenu selectItemWithTitle:selectedStream ] ;
		//  check if the selected item is the same as the item in prefs
		if ( ![ selectedStream isEqualToString:[ serialPortMenu titleOfSelectedItem ] ] ) {
			[ self alertMessage:@"Original serial port not found." informativeText:@"Please open the Preferences panel to select a new serial port." ] ;
		}
		else {
			//  open port that was selected when cocoaPTT last quit
			i = [ serialPortMenu indexOfSelectedItem ] - 1 ;
			if ( i >= 0 ) [ self newPort:i ] ;
		}
	}
	[ [ NSApplication sharedApplication ] setDelegate:self ] ;		// to delegate terminate
	
	[ self setUnkey ] ;		//  setUnkey to make sure activeLow devices are set properly
	
	[ serialPortMenu setAction:@selector(portChanged) ] ;
	[ serialPortMenu setTarget:self ] ;
	[ keyButton setAction:@selector(keyChanged) ] ;
	[ keyButton setTarget:self ] ;
	[ activePrefMatrix setAction:@selector(prefChanged) ] ;
	[ activePrefMatrix setTarget:self ] ;
	[ rtsPrefMatrix setAction:@selector(prefChanged) ] ;
	[ rtsPrefMatrix setTarget:self ] ;
	[ disableReadCheckbox setAction:@selector(prefChanged) ] ;
	[ disableReadCheckbox setTarget:self ] ;
}

- (BOOL)application:(NSApplication*)sender delegateHandlesKey:(NSString*)key 
{
	if ( [ key isEqual:@"keyState" ] ) return YES ;		

	return NO;
}

- (int)keyState
{
	return ( [ keyButton state ] == NSOnState ) ? 1 : 0 ;
}

- (void)setKeyState:(int)state
{
	if ( state ) [ self setKey ] ; else [ self setUnkey ] ;
}

- (void)portChanged
{
	int i ;
	
	i = [ serialPortMenu indexOfSelectedItem ] ;
	if ( i == 0 ) {
		//if ( ptt ) [ ptt release ] ;
	}
	else {
		if ( i > 0 ) {
			[ self newPort:i-1 ] ;
		}
	}
}

- (Boolean)setKey
{
	if ( [ ptt setKey:useRTS active:activeHigh ] ) {
		[ keyButton setState:NSOnState ] ;
		[ keyButton setTitle:@"Unkey" ] ;
		[ keyLight setBackgroundColor:[ NSColor redColor ] ] ;
		return YES ;
	}
	else {
		[ keyButton setState:NSOffState ] ;
		[ keyButton setTitle:@"Key" ] ;
		[ keyLight setBackgroundColor:[ NSColor grayColor ] ] ;
		return NO ;
	}
}

- (Boolean)setUnkey
{
	[ keyButton setState:NSOffState ] ;
	[ keyButton setTitle:@"Key" ] ;
	[ keyLight setBackgroundColor:[ NSColor grayColor ] ] ;

	if ( ![ ptt setUnkey:useRTS active:activeHigh ] ) {
		[ keyLight setBackgroundColor:[ NSColor grayColor ] ] ;
		return NO ;
	}
	return YES ;
}

- (void)keyChanged
{
	if ( [ keyButton state ] == NSOnState ) [ self setKey ] ; else [ self setUnkey ] ;
}

- (void)prefChanged
{
	activeHigh = ( [ activePrefMatrix selectedRow ] == 0 ) ;
	useRTS = rtsMap[ [ rtsPrefMatrix selectedRow ] ] ;		//  row 0 = RTS, row 1 = DTR, row 2 = both
	allowRead = ( [ disableReadCheckbox state ] == NSOffState ) ;
	[ self setUnkey ] ;
}

- (int)findPorts
{
    kern_return_t kernResult ; 
    mach_port_t masterPort ;
	io_iterator_t serialPortIterator ;
	io_object_t modemService ;
    CFMutableDictionaryRef classesToMatch ;
	CFTypeRef cfString ;
	int count ;

    kernResult = IOMasterPort( MACH_PORT_NULL, &masterPort ) ;
    if ( kernResult != KERN_SUCCESS ) return 0 ;
	
    classesToMatch = IOServiceMatching( kIOSerialBSDServiceValue ) ;
    if ( classesToMatch == NULL ) return 0 ;

	// get iterator for serial ports (including modems)  v1.4
	//CFDictionarySetValue( classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDRS232Type) ) ;
	CFDictionarySetValue( classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes) ) ;
    kernResult = IOServiceGetMatchingServices( masterPort, classesToMatch, &serialPortIterator ) ;    
    
	// walk through the iterator
	count = 0 ;
	while ( ( modemService = IOIteratorNext( serialPortIterator ) ) ) {
        cfString = IORegistryEntryCreateCFProperty( modemService, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0 ) ;
        if ( cfString ) {
			_stream[count] = [ NSString stringWithString:(__bridge NSString*)cfString ] ;
            CFRelease( cfString ) ;
			cfString = IORegistryEntryCreateCFProperty( modemService, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0 ) ;
			if ( cfString )  {
				_path[count] = [ NSString stringWithString:(__bridge NSString*)cfString ] ;
				CFRelease( cfString ) ;
				count++ ;
			}
		}
        IOObjectRelease( modemService ) ;
    }
	IOObjectRelease( serialPortIterator ) ;
	return count ;
}

- (IBAction)openPref:(id)sender
{
	[ prefPanel orderFront:self ] ; 	
}

- (IBAction)openControl:(id)sender
{
	[ window orderFront:self ] ;
}

//  clean up and save Plist
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender
{
	if ( ptt ) {
		[ _prefs setObject:[ ptt name ] forKey:kPortName ] ;
		// restore attributes and close serial port
		//  don't restore tcsetattr( fd, TCSANOW, &originalTTYAttrs) ;
		//[ ptt release ] ;
	}
	//  update prefs before writing it out
	[ _prefs setObject:[ window stringWithSavedFrame ] forKey:kWindowPosition ] ;
	[ _prefs setObject:[ NSNumber numberWithInt:( activeHigh ) ? 1 : 0 ] forKey:kActiveHigh ] ;
	[ _prefs setObject:[ NSNumber numberWithInt:useRTS ] forKey:kUseRTS ] ;
	
	[ _prefs setObject:[ NSNumber numberWithInt:( ( allowRead ) ? 0 : 1 ) ] forKey:kDisableRead ] ;
	[ _prefs writeToFile:_plistPath atomically:YES ] ;

	return NSTerminateNow ;
}

@end
