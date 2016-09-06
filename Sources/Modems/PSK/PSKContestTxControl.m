//
//  PSKContestTxControl.m
//  cocoaModem
//
//  Created by Kok Chen on 11/12/04.
//

#import "PSKContestTxControl.h"
#include "PSK.h"


@implementation PSKContestTxControl

- (id)initIntoView:(NSView*)view client:(Modem*)modem
{
	self = [ super init ] ;
	if ( self ) {
		receiver = nil ;
		psk = (PSK*)modem ;
		index = 0 ;
		if ( [ [NSBundle mainBundle] loadNibNamed:@"PSKContestTxControl" owner:self topLevelObjects:nil] ) {
			// loadNib should have set up controlView connection
			if ( view && controlView ) [ view addSubview:controlView ] ;
			index = (int)[ vfoMenu indexOfSelectedItem ] ;
			return self ;
		}
	}
	return nil ;
}

- (IBAction)flushBuffer:(id)sender
{
	if ( psk ) [ psk flushAndLeaveTransmit ] ;
}

@end
