//
//  RTTYDemodulator.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 2/27/07.


#ifndef _RTTYDEMODULATOR_H_
	#define _RTTYDEMODULATOR_H_

	#import "CMFSKDemodulator.h"
	#import "RTTYBaudotDecoder.h"
	#import "RTTYAuralMonitor.h"
    #import "CMFSKPipeline.h"

	@interface RTTYDemodulator : CMFSKDemodulator {
		RTTYBaudotDecoder *decoder ;
		RTTYAuralMonitor *auralMonitor ;
        
	}

    @property RTTYReceiver  *receiver;

	- (void)setPrintControl:(Boolean)state ;

	@end
#endif
