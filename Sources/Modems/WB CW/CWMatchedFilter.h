//
//  CWMatchedFilter.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/3/06.


#ifndef _CWMATCHEDFILTER_H_
	#define _CWMATCHEDFILTER_H_

	#import "CoreModem.h"
	#import "CWSpeedPipeline.h"
	
	@class CWReceiver ;
	@class MorseDecoder ;
	
	#define	MAXINTERVALBUF	32

	@interface CWMatchedFilter : CMFSKMatchedFilter {
		MorseDecoder *decoder ;
		CWReceiver *receiver ;
		Boolean fast ;
		
		float signal[4096] ;
		int cycle ;
		
		CWPipeline *decodePipeline ;
		CWSpeedPipeline *speedPipeline ;
		
		//ElementType intervalBuffer[MAXINTERVALBUF] ;
		//int intervalConsumer, intervalProducer ;
		int previousState ;
		
		ElementType glitch[4] ;
	
		float estimatedSpeed ;
		int latency ;				// 0 - no deglitch, 1 = don't wait for 6 elements before processing
		
		//NSConditionLock *estimateSpeed ;
		int chosenSpeed ;
        __block bool running;
		__block float wpm ;
		__block Boolean limited ;
		
		//	running estimate of element timing
		float elementLength, interSymbolLength, ditLength, dashLength, basicLength[2] ;
		char character[65] ;
		int characterIndex ;
		__block Boolean spacePrinted ;
        
        dispatch_queue_t   _speedFilterQueue;
        dispatch_queue_t   _charFilterQueue;
	}

@property NSConditionLock *estimateSpeed;
@property int intervalConsumer;
@property int intervalProducer;
@property ElementType *intervalBuffer;

	
	- (void)setDecoder:(MorseDecoder*)decode receiver:(CWReceiver*)rx ;
	
	- (void)updateMorseElement:(ElementType*)element pipe:(CWPipeline*)pipe ;
	- (int)interWord ;
	
	- (void)setSquelch:(float)v fastQSB:(float)fast slowQSB:(float)slow ;
	- (void)setLatency:(int)value ;
	- (void)changeCodeSpeedTo:(int)speed ; 
	- (void)changeMatchedFilterToSpeed:(float)speed force:(Boolean)forced ;
	- (void)newClick:(float)delta ;
	
	- (int)elementLength ;


	@end

#endif
