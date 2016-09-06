//
//  CrossedEllipseChannel.m
//  diddles
//
//  Created by Joe Mastroianni on 12/10/13.
//
//

#import "CrossedEllipseChannel.h"

@implementation CrossedEllipseChannel {
    
}

@synthesize filter      = _filter;
@synthesize interpolate = _interpolate;
//	//	interpolated data
@synthesize tail        = _tail;//[kInterpolationSpan] ;		// tail of raw (3000 samples/sec) buffer
@synthesize data        = _data;//[kInterpolatedSize*2] ;		// double 24000 samples/sec buffer
@synthesize p           = _p;
@synthesize q           = _q;						// "previous" and "current" pointers
//	//  plot sequences
@synthesize path        = _path;
@synthesize point       = _point;//[kPhosphorDecay] ;
@synthesize penDown     = _penDown;//[kPhosphorDecay] ;
@synthesize penstate    = _penstate;
@synthesize gated       = _gated;//[2] ;							// 00 to draw frame, 11 to ignore entire frame, 01 to ignore second half of frame
@synthesize last        = _last;
@synthesize crossPoint  = _crossPoint;
@synthesize index       = _index;
@synthesize previousFrameInhibit  = _previousFrameInhibit;

-(id) init  {
    
    self = [super init];
    if(self ) {
        
        _tail = malloc(sizeof(Complex) * kInterpolationSpan);
        _data = malloc(sizeof(Complex) * kInterpolatedSize*2);
        _point = malloc(kPhosphorDecay * sizeof(CGPoint));
        _penDown = malloc(sizeof(Boolean) * kPhosphorDecay);
        _gated  = malloc(sizeof(int) * 4);
        
    }
    
    return self;
}

-(void) dealloc {
    
    free(_tail);
    free(_data);
    free(_point);
    free(_penDown);
}


@end
