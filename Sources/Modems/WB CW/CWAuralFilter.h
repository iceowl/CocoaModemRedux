//
//  CWAuralFilter.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 1/11/07.

#ifndef _CWAURALFILTER_H_
	#define _CWAURALFILTER_H_

	#import "CWDemodulator.h"
    #import "CMFSKPipeline.h"
    #import "CWPStruct.h"

	@interface CWAuralFilter : CWDemodulator {

	}
@property __block CMFSKPipeline *myPipeline;
@property __block CWPStruct     *p;

@property CWReceiver *cReceiver;


- (void)importData:(CMPipe*)pipe;


@end

#endif
