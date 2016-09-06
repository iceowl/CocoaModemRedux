//
//  RTTY.h
//  cocoaModem
//
//  Created by Kok Chen on Sun May 30 2004.
//

    #ifndef _RTTY_H_
	#define _RTTY_H_

	#include "RTTYInterface.h"
    #import "RTTYConfigSet.h"

	@interface RTTY : RTTYInterface {
		IBOutlet id ctrl ;
	}

    @property RTTYConfigSet *set;
    @property NSThread  *thread;
	//  floating scope
	- (void)showScope ;
	- (void)hideScopeOnDeactivation:(Boolean)hide ;
	
	@end

#endif
