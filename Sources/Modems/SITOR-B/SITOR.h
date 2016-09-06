//
//  SITOR.h
//  cocoaModem
//
//  Created by Kok Chen on Jan 11 2006.
//

    #ifndef _SITOR_H_
	#define _SITOR_H_

	#include "WFRTTY.h"
    #import "RTTYConfigSet.h"

	@interface SITOR : WFRTTY <NSTextViewDelegate>{
	}

    @property RTTYConfigSet *setA, *setB;
    @property (retain) NSThread *thread;
	
	@end

#endif
