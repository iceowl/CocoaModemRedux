//
//  Interpolate.m
//  diddles
//
//  Created by Kok Chen on 10/18/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "Interpolate.h"
#import "DSPWindow.h"

@implementation Interpolate

//	Interpolation filter with a sinc function (windowed by a Blackman window)

//	input should be [0:points-1]
//	offset should be {0..factor-1}
//	For each inpur set, in[0],...,in[points-1], output "factor" number of points at offset=0,1,2,...,factor-1
//	(-interpolate:a offset:factor-1 samples the input exactly)
- (float)interpolate:(float*)input offset:(int)offset
{
	int i ;
	float accum, *h ;
	
	accum = 0 ;
	h = &kernel[offset] ;
	for ( i = 0; i < points; i++ ) {
		accum = ( *h )*input[i] ;
		h += factor ;
	}
	return accum ;
}

//	samples is number of input samples
//	input array must be of size at least samples+points
//	output array must be of size at least samples*factor
- (void)interpolateArray:(float*)input into:(float*)output samples:(int)samples
{
	int i, j ;
	
	for ( i = 0; i < samples; i++ ) {
		for ( j = 0; j < factor; j++ ) *output++ = [ self interpolate:input offset:j ] ;
		input++ ;
	}
}

- (Complex)interpolateComplex:(Complex*)input offset:(int)offset
{
	int i ;
	Complex accum ;
	float *h ;
	
	accum = 0 ;
	h = &kernel[offset+factor*(points-1)] ;
	for ( i = 0; i < points; i++ ) {
		accum += ( *h )*input[i] ;
		h -= factor ;
	}
	return accum ;
}

//	samples is number of input samples
//	input array must be of size at least samples+points
//	output array must be of size at least samples*factor
- (void)interpolateComplexArray:(Complex*)input into:(Complex*)output samples:(int)samples
{
	int i, j ;
	
	for ( i = 0; i < samples; i++ ) {
		for ( j = 0; j < factor; j++ ) *output++ = [ self interpolateComplex:input offset:j ] ;
		input++ ;
	}
}

//  span is the number of input points used to interpolate for result
//	(this should be an even number to obtain a "center" sampling at the peak of the sinc().
//	factor is the interpolation factor (number of resulting points per input point)
//	Bandwidth is from DC to half the sampling rate.
- (id)initWithSpan:(int)inPoints factor:(int)inFactor
{
	int i, m ;
	
	self = [ super init ] ;
	if ( self ) {
		points = inPoints ;
		factor = inFactor ;
		m = inPoints*factor ;
		if ( m >= 256 ) return nil ;
		// ( n*factor+1 ) needs to be less than 256.
		for ( i = 0; i < m; i++ ) {
			kernel[i] = sincWindow( i+1, m, 4 )*blackmanWindow( i+1, m ) ;		// 4 cycle sinc window
		}
	}
	return self ;
}

@end
