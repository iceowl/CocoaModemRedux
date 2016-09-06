//
//  Preferences.m
//  cocoaModem
//
//  Created by Kok Chen on Thu May 20 2004.
	#include "Copyright.h"
//

#import "Preferences.h"
#import "Plist.h"
#import "TextEncoding.h"
#import <CoreFoundation/CoreFoundation.h>


@implementation Preferences

/*  -------------------------------------------------------------------------
	
	1) Preferences init during app startup
		a) new empty dictionary created
	...
	
	2) Config initPreference called
		a) adds default items to dictionary
		b) calls Config to fetchPlist, this updates the defaulted items
	...
	
	3) cocoaModem applicationShouldTerminate called
		a) calls Config to savePlist
		b) application quits.
	------------------------------------------------------------------------ */

- (id)init
{
	NSString *bundleName, *plistPath ;
	char *s, str[128] ;
	int i ;

	self = [ super init ] ;
	if ( self ) {
		hasPlist = NO ;
		// create dictionary to hold preference data
		prefs = [ [ NSMutableDictionary alloc ] init ] ;
		//  make default pathname from bundle info
		bundleName = [ [ NSBundle mainBundle ] objectForInfoDictionaryKey:@"CFBundleIdentifier" ] ;
		strcpy( str, kPlistDirectory ) ;
		if ( bundleName ) {
			strcat( str, [ bundleName cStringUsingEncoding:NSASCIIStringEncoding] ) ;
			strcat( str, ".plist" ) ;
		}
		else {
			//  use default name if plist path is not in bundle
			strcat( str, kDefaultPlist ) ;
		}
		//  v0.76 - Bundle name has changed to use a dash instead of spaces; place the space back to keep using the old plist
		s = str ;
		for ( i = 0; i < 120; i++ ) {
			if ( *s == 0 ) break ;
			if ( *s == '-' ) *s = ' ' ;
			s++ ;
		}
		plistPath = [ NSString stringWithCString:str encoding:NSASCIIStringEncoding] ;
		path = [ [ NSString alloc ] initWithString:[ plistPath stringByExpandingTildeInPath ] ] ;
	}
	return self ;
}

// this is for creating a standalone disctionary (e.g., for exporting macros)
- (id)initWithPath:(NSString*)name
{
	self = [ super init ] ;
	if ( self ) {
		hasPlist = NO ;
		// create dictionary to hold preference data
		prefs = [ [ NSMutableDictionary alloc ] init ] ;
		[ prefs setObject:[ NSNumber numberWithInt:0 ] forKey:kNoOpenRouter ] ;
		//path = [ name retain ] ;
	}
	return self ;
}

- (void)dealloc
{
//	[ prefs release ] ;
//	[ path release ] ;
//	[ super dealloc ] ;
}

/* local */
//  remove key from old plist
- (void)remove:(NSString*)key
{
	[ prefs removeObjectForKey:key ] ;
}

//  Merge in plist data from .plist file
- (void)fetchPlist:(Boolean)importIfMissing
{	
	NSData *xmlData, *oldXmlData ;
	//NSString *errorString, *oldPlistPath, *oldpath ;
    NSString *oldPlistPath, *oldpath ;
	CFPropertyListRef plist ;
    CFPropertyListFormat theFormat = kCFPropertyListXMLFormat_v1_0;
	int button ;

	xmlData = [[NSData alloc] initWithContentsOfFile:path] ;
	if ( xmlData ) {
		//  get plist from XML data
        CFErrorRef eRef;
        CFDataRef dRef = CFDataCreate(kCFAllocatorDefault, [xmlData bytes], [xmlData length]);
      //  CFDataRef dRef = CFPropertyListCreateData(NULL, [xmlData bytes], kCFPropertyListXMLFormat_v1_0, 0, &eRef);
        
        
		//plist = (id)CFPropertyListCreateFromXMLData( kCFAllocatorDefault, (CFDataRef)xmlData, kCFPropertyListImmutable, (CFStringRef*)&errorString ) ;
        
        plist = CFPropertyListCreateWithData(kCFAllocatorDefault, dRef, kCFPropertyListImmutable, &theFormat, &eRef);
        
		if ( plist ) {
			// merge and overwrite default values
			[ prefs addEntriesFromDictionary:(__bridge NSDictionary *)(plist) ] ;
			CFRelease( plist ) ;
		}
		//  v0.76 fix leaked memory
	//	if ( errorString ) CFRelease( errorString ) ;
        if(dRef)CFRelease(dRef);
		hasPlist = YES ;
	}
	else {
		hasPlist = NO ;
        CFDataRef dRef = CFDataCreate(kCFAllocatorDefault, [oldXmlData bytes], [oldXmlData length]);
        CFErrorRef eRef;
		if ( importIfMissing ) {
			//  make default pathname from bundle info
			oldPlistPath = @"~/Library/Preferences/w7ay.cocoaModem.plist";
			oldpath = [ oldPlistPath stringByExpandingTildeInPath ] ;
			oldXmlData = [ NSData dataWithContentsOfFile:oldpath ] ;
			if ( oldXmlData ) {
				button =(int) [ [ NSAlert alertWithMessageText:NSLocalizedString( @"Import Preferences from older version of cocoaModem?", nil ) defaultButton:NSLocalizedString( @"OK", nil ) alternateButton:NSLocalizedString( @"Skip", nil ) otherButton:nil informativeTextWithFormat:@"" ] runModal ] ;
				if ( button == NSAlertDefaultReturn ) {
					// found 1.0 plist, make it the 2.0 plist
//					plist = (__bridge id)CFPropertyListCreateFromXMLData( kCFAllocatorDefault, (CFDataRef)oldXmlData, kCFPropertyListImmutable, (CFStringRef*)&errorString ) ;
                    plist = CFPropertyListCreateWithData(kCFAllocatorDefault, dRef, kCFPropertyListImmutable, &theFormat, &eRef);
					if ( plist ) {		
						[ prefs addEntriesFromDictionary:(__bridge NSDictionary *)(plist) ] ;
						CFRelease( plist ) ;
						hasPlist = YES ;
					}
				}
			}
		}
        if(dRef)CFRelease(dRef);
	}
}

//  Write preference out to .plist file.
//  The XML formatting is done by the NSMutableDictionary class upon a writeToFile call.
- (void)savePlist
{
	Boolean status ;
	
	status = [ prefs writeToFile:path atomically:YES ] ;
}

//  check if key is in dictionary
- (Boolean)hasKey:(NSString*)key
{
	return ( [ prefs objectForKey:key ] != nil ) ;
}

- (Boolean)booleanValueForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	
	if ( !obj || ![ obj isKindOfClass:[ NSNumber class ] ] ) return NO ;
	return [ obj boolValue ] ;
}


- (int)intValueForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	
	if ( !obj || ![ obj isKindOfClass:[ NSNumber class ] ] ) return 0 ;
	return [ obj intValue ] ;
}

- (void)incrementIntValueForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	int intval ;
	
	if ( obj && [ obj isKindOfClass:[ NSNumber class ] ] ) {
		intval = [ obj intValue ] ;
		[ self setInt:intval+1 forKey:key ] ;
	}
}

- (void)setBoolean:(Boolean)value forKey:(NSString*)key
{
	NSNumber *num ;
	
	num = [ NSNumber numberWithBool:value ] ;
	[ prefs setObject:num forKey:key ] ;
}

- (void)setInt:(int)value forKey:(NSString*)key
{
	NSNumber *num ;
	
	num = [ NSNumber numberWithInt:value ] ;
	[ prefs setObject:num forKey:key ] ;
}

- (float)floatValueForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	
	if ( !obj || ![ obj isKindOfClass:[ NSNumber class ] ] ) return 0 ;
	return [ obj floatValue ] ;
}

- (void)setFloat:(float)value forKey:(NSString*)key
{
	NSNumber *num ;
	
	num = [ NSNumber numberWithFloat:value ] ;
	[ prefs setObject:num forKey:key ] ;
}

- (NSString*)stringValueForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	
	if ( !obj || ![ obj isKindOfClass:[ NSString class ] ] ) return nil ;
	return ( (NSString*)obj ) ;
}

- (void)setString:(NSString*)obj forKey:(NSString*)key
{
	if ( obj == nil ) {
		// printf( "Preferences: bad string value for key %s\n", [ key cStringUsingEncoding:NSASCIIStringEncoding  ] ) ;
		return ;
	}
	[ prefs setObject:obj forKey:key ] ;
}

- (NSArray*)arrayForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	
	if ( !obj || ![ obj isKindOfClass:[ NSArray class ] ] ) return nil ;
	return ( (NSArray*)obj ) ;
}

- (void)setArray:(NSArray*)obj forKey:(NSString*)key
{
	if ( obj == nil ) {
		printf( "Preferences: bad array value for key %s\n", [ key cStringUsingEncoding:NSASCIIStringEncoding  ] ) ;
		return ;
	}
	[ prefs setObject:obj forKey:key ] ;
}

//	v0.78
- (NSDictionary*)dictionaryForKey:(NSString*)key
{
	id obj = [ prefs objectForKey:key ] ;
	
	if ( !obj || ![ obj isKindOfClass:[ NSDictionary class ] ] ) return nil ;
	return ( (NSDictionary*)obj ) ;
}

//  v0.78
- (void)setDictionary:(NSDictionary*)obj forKey:(NSString*)key
{
	if ( obj == nil ) {
		printf( "Preferences: bad dictionary value for key %s\n", [ key cStringUsingEncoding:NSASCIIStringEncoding ] ) ;
		return ;
	}
	[ prefs setObject:obj forKey:key ] ;
}

//	v0.72
- (NSObject*)objectForKey:(NSString*)key
{
	return [ prefs objectForKey:key ] ;
}

//  Color in our Plist is expressed as an array of three floating point (R,G,B) elements
- (NSColor*)colorValueForKey:(NSString*)key
{
	NSArray *color ;
	NSColor *rgb ;
	CGFloat r, g, b ;
	
	color = [ prefs objectForKey:key ] ;		//  should be an NSArray
	r = [ [ color objectAtIndex:0 ] floatValue ] ;
	g = [ [ color objectAtIndex:1 ] floatValue ] ;
	b = [ [ color objectAtIndex:2 ] floatValue ] ;
	rgb = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1 ];
	return rgb ;
}

//  Color in our Plist is expressed as an array of three floating point (R,G,B) elements
- (void)setColor:(NSColor*)color forKey:(NSString*)key
{
	NSNumber *r, *g, *b ;
	CGFloat red, green, blue, alpha ;
	
	[ color getRed:&red green:&green blue:&blue alpha:&alpha ] ;
	r = [ NSNumber numberWithFloat:red ] ;
	g = [ NSNumber numberWithFloat:green ] ;
	b = [ NSNumber numberWithFloat:blue ] ;
	[ prefs setObject:[ NSArray arrayWithObjects:r, g, b, nil ] forKey:key ] ;
}

//  Color in our Plist is expressed as an array of three floating point (R,G,B) elements
- (void)setRed:(float)red green:(float)green blue:(float)blue forKey:(NSString*)key
{
	NSNumber *r, *g, *b ;

	r = [ NSNumber numberWithFloat:red ] ;
	g = [ NSNumber numberWithFloat:green ] ;
	b = [ NSNumber numberWithFloat:blue ] ;
	[ prefs setObject:[ NSArray arrayWithObjects:r, g, b, nil ] forKey:key ] ;
}

- (void)removeKey:(NSString*)key
{
	[ prefs removeObjectForKey:key ] ;
}


@end
