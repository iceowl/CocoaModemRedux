//
//  Filter.h
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/23/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "FIR.h"

@interface Filter : NSObject {
	FIR *fir ;
	int n ;
}

- (id)initWithBandwidth:(float)bw length:(int)length ;
- (id)initWithFilterLength:(int)length ;

- (int)filterLength ;
- (void)setKernel:(float*)kernel ;
- (void)setNormalizedKernel:(float*)kernel ;

- (void)filter:(float*)input to:(float*)output length:(int)length ;

//	(Private API).  
//	Components set to 1 for scalar, 2 for complex)
- (id)initWithBandwidth:(float)bw length:(int)length components:(int)comps ;
- (id)initWithFilterLength:(int)length components:(int)comps ;

@end
