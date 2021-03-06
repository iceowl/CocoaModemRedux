//
//  FSK.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 2/12/08.
//  Copyright 2008 Kok Chen, W7AY. All rights reserved.
//

#import "FSK.h"
#import "Application.h"
#import "FSKHub.h"
#import "FSKMenu.h"
#import "RTTY.h"

@implementation FSK

@synthesize interfaces = _interfaces;

- (id)initWithHub:(FSKHub*)fskHub menu:(NSPopUpButton*)fskMenu modem:(RTTY*)client
{
	DigitalInterfaces *digitalInterfaces ;
	NSArray *keyers ;
	MicroKeyer *keyer ;
	Application *application ;
	int i, n, digiKeyers, microKeyers, menuItems ;

	self = [ super init ] ;
	if ( self ) {
        
        _interfaces = [[NSMutableArray alloc] initWithCapacity:NUMINTERFACES];
        
        for(int y = 0;y < NUMINTERFACES;y++) [_interfaces insertObject: [[Interfaces alloc]init] atIndex:y];
		modem = client ;
		menu = fskMenu ;
		hub = fskHub ;
		selectedPort = 0 ;
		
		application = [ NSApp delegate ] ;	
		digitalInterfaces = [ application digitalInterfaces ] ;
		[ menu removeAllItems ] ;
		
		[ menu addItemWithTitle:kAFSKMenuTitle ];
        Interfaces *ifr = [_interfaces objectAtIndex:0];
		ifr.type = kAFSKType ;
		ifr.keyer = nil ;
		ifr.enabled = YES ;
		
		[ [ menu menu ] addItem:[ NSMenuItem separatorItem ] ] ;
        ifr = [_interfaces objectAtIndex:1];
		ifr.type = kSeparatorType ;
		ifr.keyer = nil ;
		ifr.enabled = NO ;
		
		digiKeyers = [ digitalInterfaces numberOfDigiKeyers ] ;
		microKeyers = [ digitalInterfaces numberOfMicroKeyers ] ;
		
		if ( digiKeyers <= 1 && microKeyers <= 1 ) {
			[ menu addItemWithTitle:kDigiKeyerMenuTitle ] ;
			keyer = [ digitalInterfaces digiKeyer ] ;
            ifr = [_interfaces objectAtIndex:2];
			if ( keyer == nil ) {
                
				ifr.type = kBadType ;
				ifr.keyer = nil ;
				ifr.enabled = NO ;
			}
			else {
				ifr.type = kFSKType ;
				ifr.keyer = keyer ;
				ifr.enabled = YES ;
			}
			
			[ menu addItemWithTitle:kMicroKeyerMenuTitle ] ;	
			keyer = [ digitalInterfaces microKeyer ] ;
            ifr = [_interfaces objectAtIndex:3];
			if ( keyer == nil ) {
				ifr.type = kBadType ;
				ifr.keyer = nil ;
				ifr.enabled = NO ;
			}
			else {
				ifr.type = kFSKType ;
				ifr.keyer = keyer ;
				ifr.enabled = YES ;
			}
			menuItems = 4 ;
		}
		else {
			menuItems = 2 ;
			keyers = [ digitalInterfaces microHAMKeyers ] ;
			n = (int)[ keyers count ] ;
            ifr = [_interfaces objectAtIndex:menuItems];
			for ( i = 0; i < n; i++ ) {
				//  list each keyer that is FSK capable
				keyer = [ keyers objectAtIndex:i ] ;
				if ( [ keyer isMicroKeyer ] || [ keyer isDigiKeyer ] ) {
					[ menu addItemWithTitle:[ NSString stringWithFormat:@"%@ %s", kFSKShortMenuTitle, [ keyer keyerID ] ] ] ;
					ifr.type = kFSKType ;
					ifr.keyer = keyer ;
					ifr.enabled = YES ;
					menuItems++ ;
				}
			}
		}
        ifr = [_interfaces objectAtIndex:menuItems];
		[ [ menu menu ] addItem:[ NSMenuItem separatorItem ] ] ;
		ifr.type = kSeparatorType ;
		ifr.keyer = nil ;
		ifr.enabled = NO ;
		menuItems++ ;
		
        ifr = [_interfaces objectAtIndex:menuItems];
		[ menu addItemWithTitle:kDigiKeyerOOKMenuTitle ] ;
		ifr.type = kPFSKType ;
		ifr.keyer = nil ;
		ifr.enabled = YES ;
		menuItems++ ;
		
        ifr = [_interfaces objectAtIndex:menuItems];
		[ menu addItemWithTitle:kOOKMenuTitle ] ;
		ifr.type = kOOKType ;
		ifr.keyer = nil ;
		ifr.enabled = YES ;
	}
	return self ;
}

// NSMenuValidation for FSK menus; called by RTTYConfig to validate its menus
- (BOOL)validateAfskMenuItem:(NSMenuItem*)item
{
	int i, n ;
	
	n = (int)[ menu numberOfItems ] ;
	for ( i = 0; i < n; i++ ) {
		if ( item == [ menu itemAtIndex:i ] ) {
           Interfaces *ifr = [_interfaces objectAtIndex:i];
			return ifr.enabled ;
		}
	}
	return YES ;
}

- (int)fskPortForName:(NSString*)title
{
	NSMenu *items ;
	int n ;
	MicroKeyer *keyer ;
	
	items = [ menu menu ] ;
	n = (int)[ items indexOfItemWithTitle:title ] ;
	if ( n < 0 ) return 0 ;
	 Interfaces *ifr = [_interfaces objectAtIndex:n];
	keyer = ifr.keyer ;
	if ( keyer == nil ) return 0 ;

	return [ keyer fskWriteDescriptor ] ;
}

//  v0.89
- (int)controlPortForName:(NSString*)title
{
	NSMenu *items ;
	int n ;
	MicroKeyer *keyer ;
	
	items = [ menu menu ] ;
	n = (int)[ items indexOfItemWithTitle:title ] ;
	if ( n < 0 ) return 0 ;
	 Interfaces *ifr = [_interfaces objectAtIndex:n];
	keyer = ifr.keyer ;
	if ( keyer == nil ) return 0 ;

	return [ keyer controlWriteDescriptor ] ;
}

//	v0.90
- (Boolean)checkAvailability:(NSString*)title
{
	NSMenu *items ;
	int n ;
	
	items = [ menu menu ] ;
	n = (int)[ items indexOfItemWithTitle:title ] ;
	if ( n < 0 ) return NO ;
	 Interfaces *ifr = [_interfaces objectAtIndex:n];
	return ifr.enabled ;
}

- (int)selectedFSKPort
{
	return [ self fskPortForName:[ menu titleOfSelectedItem ] ] ;
}

//  set fd to port selected by menu (or 0 if error)
- (int)useSelectedPort 
{
	selectedPort = [ self selectedFSKPort ] ;
	return selectedPort ;
}

//  v0.87
- (void)setKeyerMode:(int)mode controlPort:(int)port
{
	if ( port ) [ hub setKeyerMode:mode controlPort:port ] ; 
}

//  streams

- (void)startSampling:(float)baudrate invert:(Boolean)invertTx stopBits:(int)stopIndex
{
	if ( selectedPort > 0 ) {
		[ hub startSampling:selectedPort baudRate:baudrate invert:invertTx stopBits:stopIndex modem:modem ] ;
	}
}

- (void)stopSampling
{
	if ( selectedPort > 0 ) [ hub stopSampling ] ;
}

- (void)clearOutput
{
	[ hub clearOutput ] ;
}

- (void)appendASCII:(int)ascii
{
	[ hub appendASCII:ascii ] ;
}

- (void)setUSOS:(Boolean)state
{
	[ hub setUSOS:state ] ;
}

@end
