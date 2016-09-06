//
//  CWPStruct.m
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import "CWPStruct.h"

@implementation CWPStruct
@synthesize bandpassFilter              = _bandpassFilter;
@synthesize originalMatchedFilter       = _originalMatchedFilter;
@synthesize originalBandpassFilter      = _originalBandpassFilter;
@synthesize mixer                       = _mixer;
@synthesize matchedFilter               = _matchedFilter;
@synthesize atc                         = _atc;
@synthesize decoder                     = _decoder;


-(id) initWithCMFSKPipeline : (CMFSKPipeline*) pipe : (MorseDecoder*) morse{
    self = [super init];
    if(self) {
        _bandpassFilter         = pipe.bandpassFilter;
        _originalBandpassFilter = pipe.bandpassFilter;
        _originalMatchedFilter  = nil;
        _mixer                  = nil;
        _atc                    = pipe.atc;
        _decoder                = morse;
        
    }
    
    
    return self;
}

-(id) init {
    
    self = [ super init ];
    if(self) {
        _bandpassFilter         = nil;
        _originalBandpassFilter = nil;
        _originalMatchedFilter  = nil;
        _mixer                  = [ [ CWMixer alloc] init];
        _atc                    = nil;
        _decoder                = nil;
    }
    return self;

}


//typedef struct {
//	CMBandpassFilter *bandpassFilter, *originalBandpassFilter ;
//	CWMixer *mixer ;
//	CWMatchedFilter *matchedFilter, *originalMatchedFilter ;
//	CMATC *atc ;
//	MorseDecoder *decoder ;
//} CWPStruct ;
//

@end
