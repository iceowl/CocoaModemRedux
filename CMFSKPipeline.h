//
//  CMFSKPipeline.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>
#import "CMBandpassFilter.h"
#import "CMFSKMixer.h"
#import "CMFSKMatchedFilter.h"
#import "CMATC.h"
#import "CMBaudotDecoder.h"

@interface CMFSKPipeline : NSObject

//typedef struct {
@property	CMBandpassFilter *bandpassFilter, *originalBandpassFilter ;
@property	CMFSKMixer *mixer ;
@property	CMFSKMatchedFilter *matchedFilter, *originalMatchedFilter ;
@property	CMATC *atc ;
@property 	CMBaudotDecoder *decoder ;
//} CMFSKPipeline ;


@end
