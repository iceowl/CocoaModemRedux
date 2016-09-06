//
//  Filter.m
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/23/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "Filter.h"
#import "DSPWindow.h"
#import "FilterKernels.h"
#import "SamplingConstants.h"

@implementation Filter

//	(Private API)
//	Filter with no kernel (kernel is set using -setKernel)
//	components set to 1 for scalar filter, 2 for complex filter.
- (id)initWithFilterLength:(int)length components:(int)comps
{
	float *kernel ;	
	
	self = [ super init ] ;
	if ( self ) {
		n = length ;
		kernel = ( float* )calloc( n, sizeof( float ) ) ;
		fir = FIRFilter( kernel, n, comps ) ;
		free( kernel ) ;
	}
	return self ;
}

- (id)initWithFilterLength:(int)length
{
	return [ self initWithFilterLength:length components:1 ] ;
}

- (void)setKernel:(float*)kernel
{
	setKernel( fir, kernel ) ;
}

//	same as setKernel but normalizing
- (void)setNormalizedKernel:(float*)kernel
{
	int i ;
	float sum ;
	
	sum = 0 ;
	for ( i = 0; i < n; i++ ) sum += kernel[i] ;
	setScaledKernel( fir, kernel, 1/( sum+0.00001 ) ) ;
}

- (int)filterLength
{
	return n ;
}

//	(Private API)
- (id)initWithBandwidth:(float)bw length:(int)length components:(int)comps
{
	float *kernel, sum, baseband ;
	int i ;

	self = [ super init ] ;
	if ( self ) {
		n = length ;
		sum = 0 ;
		kernel = ( float* )calloc( n, sizeof( float ) ) ;
		for ( i = 0; i < n; i++ ) {
			baseband = blackmanWindow( i, n )*sinc( i, n, bw ) ;
			sum += baseband ;
			kernel[i] = baseband ;
		}
		//	normalize gain
		for ( i = 0; i < n; i++ ) kernel[i] = kernel[i]/sum ;		
		fir = FIRFilter( kernel, n, comps ) ;
		free( kernel ) ;
	}
	return self ;
}

//	Base class of a complex lowpass filter.
//	Note: bandwidth = cutoffFrequency / samplingRate
- (id)initWithBandwidth:(float)bw length:(int)length
{
	return [ self initWithBandwidth:bw length:length components:1 ] ;
}

//	Base class of a simple lowpass filter (2400 Hz when sampling rate id 48000) and length 256.
- (id)init
{
	return [ self initWithBandwidth:0.05 length:256 ] ;
}

- (void)dealloc
{
	DeleteFIR( fir ) ;
	//[ super dealloc ] ;
}

- (void)filter:(float*)input to:(float*)output length:(int)length
{
	PerformFIR( fir, input, length, output ) ;
}

@end
