//
//  SoundCardInfo.m
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import "SoundCardInfo.h"

@implementation SoundCardInfo



	@synthesize deviceID = _deviceID ;
	@synthesize streamID = _streamID ;
	@synthesize streamIndex  = _streamIndex;
	@synthesize name  = _name;

-(id) init {
    
    self = [super init];
    if(self) {
        _deviceID = 0;
        _streamID = 0;
    }
    
    return self;
    
}



@end
