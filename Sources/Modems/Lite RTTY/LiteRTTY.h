//
//  LiteRTTY.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 11/2/07.

	#import <Cocoa/Cocoa.h>
	#import "WFRTTY.h"
    #import "RTTYConfigSet.h"


	@interface LiteRTTY : WFRTTY <NSWindowDelegate> {
		IBOutlet NSButton* txLockButton ;
		IBOutlet id oscilloscope ;
		Boolean controlWindowOpen ;
	}

@property RTTYConfigSet *setA;
	
	- (IBAction)openControlWindow:(id)sender ;
	- (IBAction)openSpectrumWindow:(id)sender ;
	
	- (void)showControlWindow:(Boolean)state ;
	
	- (void)drawSpectrum:(CMPipe*)pipe ;
	- (void)changeMarkersInSpectrum:(RTTYRxControl*)inControl ;
	

	@end
