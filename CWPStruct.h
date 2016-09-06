//
//  CWPStruct.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>
#import "CMBandpassFilter.h"
#import "CWMixer.h"
#import "CWMatchedFilter.h"
#import "CMATC.h"

@interface CWPStruct : NSObject {}
//typedef struct {
@property	CMBandpassFilter *bandpassFilter, *originalBandpassFilter ;
@property	CWMixer *mixer ;
@property	CWMatchedFilter *matchedFilter, *originalMatchedFilter ;
@property	CMATC *atc ;
@property	MorseDecoder *decoder ;
//} CWPStruct ;
//
-(id) initWithCMFSKPipeline : (CMFSKPipeline*) pipe : (MorseDecoder*) morse;


@end


