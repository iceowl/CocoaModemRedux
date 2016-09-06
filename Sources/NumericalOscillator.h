//
//  NumericalOscillator.h
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/9/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FilterTypes.h"

@interface NumericalOscillator : NSObject {
	double phase ;
	double dPhase ;
	double frequency ;
	
	float *phaseArray ;
	float *frequencyArray ;
	Complex *quadratureArray ;
}

@property (readwrite, assign) double phase ;

- (id)initWithFrequency:(double)f ;
- (void)setFrequency:(double)value ;
- (void)setFrequency:(double)value offsetCorrection:(float)correction ;

- (float)nextSample ;
- (void)getSamples:(float*)buffer ;
- (void)getUnalignedSamples:(float*)buffer ;				//  use this if buffer array is not aligned for vecLib

- (Complex)nextQuadratureSample ;
- (void)getQuadratureSamples:(Complex*)buffer ;
- (void)getQuadratureSamples:(Complex*)buffer samples:(int)length ;

@end
