//
//  DSPWindow.c
//  From cocoaModem 2.0
//
//  Created by Kok Chen on 10/24/05
//	Ported September 13, 2011
//
//	Copyright 2005,2011 Kok Chen, W7AY. All rights reserved.

#import "DSPWindow.h"
#import "FilterTypes.h"
#import <math.h>


//	See http://en.wikipedia.org/wiki/Window_function

double hammingWindow( float x, int n )
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return 0.54 - 0.46*( cos( 2*kPi*x/n ) ) ;
}

double hannWindow( float x, int n )
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return 0.5*( 1 - cos( 2*kPi*x/n ) ) ;
}

//	cycles parameter is the number of cycles of the sinc in the window length n
//	The main lobe is considered to be one cycle.
double sincWindow( float f, int n, double cycles )
{
	double x, t ;
	
	t = n/2.0 ;
	x = ( f - t )*cycles/t ;
	if ( fabs( x ) < .0001 ) return 1.0 ;
	return sin( kPi*x )/( kPi*x ) ;		//  sin(pi.x)/(pi.x)
}

double blackmanWindow( float x, int n ) 
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return ( .42 - .5*cos(2*kPi*x/n) + .08*cos( 4*kPi*x/n ) ) ;
}

double blackmanHarrisWindow( float x, int n ) 
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return ( .35875 - .48829*cos(2*kPi*x/n) + .14128*cos( 4*kPi*x/n ) - .01168*cos( 6*kPi*x/n ) ) ;
}

double blackmanNuttallWindow( float x, int n ) 
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return ( .3635819 - .4891775*cos(2*kPi*x/n) + .1365995*cos( 4*kPi*x/n ) - .0106411*cos( 6*kPi*x/n ) ) ;
}

//	sigma <= 0.5
double gaussianWindow( float x, int n, float sigma )
{
	float u ;
	
	n = n/2 ;
	u = ( x-n )/( sigma*n ) ;
	return exp( -0.5*u*u ) ;
}

double flatTopWindow( float x, int n ) 
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return ( 1 - 1.93*cos(2*kPi*x/n) + 1.29*cos( 4*kPi*x/n ) - 0.388*cos( 6*kPi*x/n ) + .032*cos( 6*kPi*x/n ) ) ;
}

//  half cycle raised sine
double sineWindow( float x, int n ) 
{
	if ( x < 0 || x >= n ) return 0.0 ;
	return ( sin( kPi*x/n ) ) ;
}

//	Generate an odd lengthed (2n-1) Blackman Harris kernel 
//	Caller needs to free the returned array when no longer in use.
float *blackmanHarrisKernel(float passband, int halfwidth )
{
	float *kernel, s, t, u, v, w, dcgain ;
	int i, length ;
	
	length = halfwidth*2 ;
	kernel = (float*)malloc( length*sizeof( float ) ) ;
	
	//  generate a baseband lowpass FIR filter that is 1/2 the needed bandwidth
	s = k2Pi/( length-1 ) ;
	u = k2Pi*passband*0.5/kInternalSamplingRate ;
	
	kernel[halfwidth-1] = 1.0 ;
	kernel[length-1] = 0.0 ;
	dcgain = kernel[halfwidth-1] ;

	for ( i = 1; i < halfwidth; i++ ) {
		t = u*i ;
		v = sin(t)/t ;
		//  generate Blackman-Harris window
		t = s*(halfwidth-i) ;
		w = 0.35875 - 0.48829*cos(t) + 0.14128*cos(2*t) - 0.01168*cos( 3*t ) ;
		dcgain += 2.0*( kernel[halfwidth-1-i] = kernel[halfwidth-1+i] = v*w ) ;
	}
	//  computed dc gain (should approach kInternalSamplingRate/passband)
	for ( i = 0; i < length; i++ ) kernel[i] /= dcgain ;
	
	return kernel ;
}
