//
//  ComplexFilter.m
//  diddles
//
//  Created by Kok Chen on 10/11/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "ComplexFilter.h"


@implementation ComplexFilter

//	ComplexFilter (2 components) with no kernel (kernel is set using -setKernel)
- (id)initWithFilterLength:(int)length
{
	return [ self initWithFilterLength:length components:2 ] ;
}

//	Base class of a complex lowpass filter.
//	Note: bandwidth = cutoffFrequency / samplingRate
- (id)initWithBandwidth:(float)bw length:(int)length
{
	return [ self initWithBandwidth:bw length:length components:2 ] ;
}

- (void)filterComplex:(Complex*)input to:(Complex*)output length:(int)length
{
	PerformFIR( fir, (float*)( &input[0] ), length, (float*)( &output[0] ) ) ;
}

- (void)filterSplitComplex:(DSPSplitComplex)input to:(Complex*)output length:(int)length
{
	PerformSplitComplexFIR( fir, input, length, output ) ;
}

//	this was reserved fro the scalr case (base class Filter)
- (void)filter:(float*)input to:(float*)output
{
	NSLog( @"Use filter:to:length: instead of filter:to:" ) ;
}

@end
