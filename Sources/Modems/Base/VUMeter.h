//
//  VUMeter.h
//  cocoaModem
//
//  Created by Kok Chen on 1/31/05.
//

    #ifndef _VUMETER_H_
	#define _VUMETER_H_
    #define NUMELEMENTS 9
	#import <Cocoa/Cocoa.h>
	#include "CoreFilter.h"
    #import "VUElement.h"


//	#include "VUSegment.h"
//
//	typedef struct {
//		VUSegment *segment ;
//		Boolean state ;
//		NSColor *onColor ;
//	} VUElement ;

	@interface VUMeter : CMPipe {
		IBOutlet id matrix ;
		IBOutlet id background ;
		
		//  vu meter
		//VUElement *vu[NUMELEMENTS] ;
		//NSColor *vuOffColor ;
		float vuLevel ;
		
		NSLock *overrunLock ;
	}

    @property (retain)  NSMutableArray *vu;
    @property (retain)  NSColor *vuOffColor;

	- (void)setup ;

	@end

#endif
