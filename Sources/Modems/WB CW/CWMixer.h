//
//  CWMixer.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/3/06.


    #ifndef _CWMIXER_H_
	#define _CWMIXER_H_

	#import "CoreModemTypes.h"
	#import "CMPipe.h"
	#import "CMFIR.h"

    CMDDA g_mark, g_space ; // these have to be global to operate over multi threads ... I need to do something smarter JM

	@class CWReceiver ;
	
	@interface CWMixer : CMPipe {
		float analyticSignal[1024] ;	// split complex signal, 512 samples
		//  local oscillators
		
		CMDataStream mixerStream ;
		CMFIR *iFilter, *qFilter ;
		CMFIR *iFilter256, *qFilter256 ;
		CMFIR *iFilter512, *qFilter512 ;
		CMFIR *iFilter768, *qFilter768 ;
		CMFIR *iFilter1024, *qFilter1024 ;
		float iIF[512], qIF[512] ;
		//CWReceiver *receiver ;
		// aural path?
		Boolean isAural ;
        CMDDA mark, space ; // these have to be global to operate over multi threads ... I need to do something smarter JM

	}

    @property CWReceiver *receiver;

	- (void)setTonePair:(const CMTonePair*)tonepair ;

	//- (void)setReceiver:(CWReceiver*)cwReceiver ;
	- (void)setCWBandwidth:(float)bandwidth ;
    - (CMAnalyticPair) update : (CMDDA*) dda ;
	- (void)setAural:(Boolean)state ;
			
	@end

#endif
