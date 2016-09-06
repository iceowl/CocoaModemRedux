//
//  DualRTTY.h
//  cocoaModem
//
//  Created by Kok Chen on Sun May 30 2004.
//

#ifndef _DUALRTTY_H_
	#define _DUALRTTY_H_

	#include "RTTYInterface.h"
    #import "RTTYConfigSet.h"

	@class DualRTTYConfig ;


	@interface DualRTTY : RTTYInterface <NSTextViewDelegate> {
	
		IBOutlet id spectrum ;
		IBOutlet id waterfall ;

		IBOutlet id receiverA ;
		IBOutlet id configA ;

		IBOutlet id receiverB ;
		IBOutlet id configB ;

		IBOutlet id timeConstant ;
		IBOutlet id dynamicRange ;
		IBOutlet id channel ;
				
		IBOutlet id configTab ;
		
		IBOutlet id transmitSelect ;
		IBOutlet id contestTransmitSelect ;
		IBOutlet id restoreToneButton ;

		NSRect receiveFrame ;				//  frame of receive-only receiver
		NSRect transceiveFrame ;			//  frame of receive-transmit receiver
	}

@property RTTYConfigSet *setA, *setB;

	- (void)transmitSelectChanged ;

	//  config
	- (int)configChannelSelected ;
	
	- (void)showScope ;		//  v0.76

	@end

#endif
