//
//  NetAudioStruct.m
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import "NetAudioStruct.h"

@implementation NetAudioStruct

@synthesize  netSendObj     = _netSendObj ;
@synthesize  delegate       = _delegate ;
@synthesize  runState       = _runState ;
@synthesize  raisedCosine   = _raisedCosine;

-(id) init  {
    self = [super init];
    if(self){
        _raisedCosine = malloc(512*sizeof(float));
        for(int i=0;i<512;i++)_raisedCosine[i] = 0.0;
    }
    return self;
}


@end
