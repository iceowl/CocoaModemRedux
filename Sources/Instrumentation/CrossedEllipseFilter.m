//
//  CrossedEllipseFilter.m
//  diddles
//
//  Created by Kok Chen on 10/11/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "CrossedEllipseFilter.h"
#import "DSPWindow.h"
#import "FilterKernels.h"


@implementation CrossedEllipseFilter


//	(Private API)
//	Cosine response (comb) in the frequency domain.
//	With a lowpass filter to pass only three total lobes (positive and negative frequencies).
- (float*)makeKernel:(float)freq
{
	float *kernel, sum, w, baseband, h, bandwidth, dT ;
	int i ;

	shift = freq ;
	bandwidth = ( shift/kBasebandSamplingRate ) ;
	dT = 0.25/bandwidth ;
	w = 2*bandwidth ; 
	
	kernel = ( float* )calloc( n, sizeof( float ) ) ;
	sum = 0 ;
	for ( i = 0; i < n; i++ ) {
		//  The sinc functions create the finite impulses for the two Kronecker deltas at -dT and +dT that is passed by the filter.
		//	The deltas transforms into a cosine response in the frequency domain.
		h = sinc( i-dT, n, w ) + sinc( i+dT, n, w ) ;
		baseband = blackmanWindow( i, n )*h ;
		sum += baseband ;
		kernel[i] = baseband ;
	}
	for ( i = 0; i < n; i++ ) kernel[i] = kernel[i]/sum ;
	
	return kernel ;
}

//  Bandpass filter with zero at shift frequency
- (id)initWithShift:(float)freq length:(int)length
{
	float *kernel ;
	
	self = [ super initWithFilterLength:length ] ;
	if ( self ) {
		kernel = [ self makeKernel:freq ] ;
		[ self setKernel:kernel ] ;
		free( kernel ) ;
	}
	return self ;
}

- (void)updateKernelForShift:(float)shiftValue
{
	float *kernel ;
	
	if ( shiftValue == shift ) return ;
	kernel = [ self makeKernel:shiftValue ] ;
	[ self setKernel:kernel ] ;
	free( kernel ) ;
}

- (void)setShift:(float)shiftValue 
{
	[ self updateKernelForShift:shiftValue ] ;
}

- (float)shift
{
	return shift ;
}

@end
