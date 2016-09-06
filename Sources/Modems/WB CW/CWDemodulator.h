//
//  CWDemodulator.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/2/06.


    #ifndef _CWDEMODULATOR_H_
	#define _CWDEMODULATOR_H_

	#import "CoreModem.h"
    #import "CWPStruct.h"


	@class CWReceiver ;
	
	@interface CWDemodulator : CMFSKDemodulator {
        
        CMTonePair defaultTonePair;
        
	}

    @property __block CWPStruct *p;
    @property CWReceiver *cwReceiver;

	- (id)initFromReceiver:(CWReceiver*)cwReceiver ;
	- (void)setCWBandwidth:(float)bandwidth ;
	- (void)setLatency:(int)value ;
	- (void)changeCodeSpeedTo:(int)speed ;
	- (void)changeSquelchTo:(float)squelch fastQSB:(float)fast slowQSB:(float)slow ;
	- (void)newClick:(float)delta ;
    - (void)setTonePair:(const CMTonePair*)inTonePair;

	@end

#endif
