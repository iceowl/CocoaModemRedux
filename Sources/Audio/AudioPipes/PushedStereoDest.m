//
//  PushedStereoDest.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 11/1/09.
//  Copyright 2009 Kok Chen, W7AY. All rights reserved.
//

#import "PushedStereoDest.h"
#import "ResamplingPipe.h"
#import "DestClient.h"
#import "AuralMonitor.h"

@implementation PushedStereoDest

- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

- (id)initIntoView:(NSView*)view device:(NSString*)name level:(NSView*)level client:(DestClient*)inClient 
{
	self = [ super initIntoView:view device:name level:level client:inClient channels:2 ] ;
	
	//  use a pushed reampling pipe instead
	[ self.resamplingPipe setUseConstantOutputBufferSize:NO ] ;

	return self ;
}

- (int)needData:(float*)outbuf samples:(int)n channels:(int)ch
{
    
    
    // THIS NEEDS FIXING!!!
   
	if ( client ) {
        return  [(AuralMonitor*)client needData:outbuf samples:n channels:ch ];
     //  return [client needData:outbuf samples:n];
    }
	NSLog(@"PushedStereoDest needData called and there's no apparent method or client");
	memset( outbuf, 0, sizeof( float )*n*ch ) ;
	return n ;
}


@end
