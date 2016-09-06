//
//  CWTxConfig.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 1/5/07.

#ifndef _CWTXCONFIG_H_
	#define _CWTXCONFIG_H_

	#import "RTTYTxConfig.h"


	@interface CWTxConfig : RTTYTxConfig {
		//  test tone
		IBOutlet id testFreq ;
	}

@property rigClass_link *myRig;

	- (IBAction)testToneChanged:(id)sender ;
	
	- (void)setCarrier:(float)freq ;
	- (void)setRisetime:(float)t weight:(float)w ratio:(float)r farnsworth:(float)f ;
	- (void)setModulationMode:(int)index ;		//  v0.85
	- (void)setSpeed:(float)speed ;
	- (void)holdOff:(int)milliseconds ;
	- (Boolean)bufferEmpty ;
    - (int)needData:(float*)outbuf samples:(int)samples channels:(int)ch;


	@end

#endif
