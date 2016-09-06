//
//  FilterKernels.c
//
//  Created by Kok Chen on 10/24/05
//	Ported September 13, 2011
//
//	Copyright 2005,2011 Kok Chen, W7AY. All rights reserved.

#import "FilterKernels.h"
#import "FilterTypes.h"
#import <math.h>


double sincf( float x )
{
	if ( fabs( x ) < .0001 ) return 1.0 ;
	return sin( kPi*x )/( kPi*x ) ;		//  sin(pi.x)/(pi.x)
}

//	Impulse response for a brickwall lowpass filter
//	Bandwidth is normalized by the sampling rate (bandwidth/samplingRate)
double sinc( float f, int n, double bandwidth )
{
	double x, t ;
	
	t = n/2.0 ;
	x = 2.0*bandwidth*( f - t ) ;
	return sincf( x ) ;
}

//	sinc centered at f = 0
double centeredSinc( float f, int n, double bandwidth )
{
	double x ;
	
	x = 2*bandwidth*f ;
	if ( fabs( x ) < .0001 ) return 1.0 ;
	return sin( kPi*x )/( kPi*x ) ;		//  sin(pi.x)/(pi.x)
}

//	Raised Cosine for beta = 1.
double raisedCosine( float t, int n, double baudrate )
{
	double u, T, v, factor ;
	
	T = 1.0/( baudrate ) ;
	u = fabs( ( t - n/2.0 )/T ) ;
	
	if ( u < .0001 ) return 1.0 ; 
	
	v = kPi*u ;
	factor = ( fabs( u - 0.5 ) < .0001 ) ? ( 0.25*kPi ) : ( cos( v )/( 1.0 - 4.0*u*u ) ) ;  //  handle singularity
	
	return factor*( sin( v )/ v )  ;
}

//	Raised Cosine for beta between 0 and 1.
double generalRaisedCosine( float t, int n, double baudrate, double beta )
{
	double u, T, v, factor ;
	
	T = 1.0/( baudrate ) ;
	t = fabs( ( t - n/2.0 )/T ) ;
	u = beta*t ;
	
	if ( fabs( t ) < 1e-12 ) return 1.0 ; 
	
	v = kPi*u ;
	factor = ( fabs( u - 0.5 ) < 1e-12 ) ? ( 0.25*kPi ) : ( cos( v )/( 1.0 - 4.0*u*u ) ) ;  //  handle singularity
	
	v = kPi*t ;
	return factor*( sin( v )/ v )  ;
}

double raisedCosineInner( float t, int n, double baudrate )
{
	double u, T, v, factor ;
	
	T = 1.0/( baudrate ) ;
	
	u = ( t - n/2.0 )/T ;
	
	if ( fabs( u ) < .0001 ) return 1.0 ; 
	
	v = kPi*u ;
	factor = ( fabs( u - 0.5 ) < .0001 ) ? ( 0.25*kPi ) : ( cos( v )/( 1.0 - 4.0*u*u ) ) ;  //  handle singularity
	
	return factor*( sin( v )/ v )  ;
}

//	Recursive implementation of the "Extended Nyquist" kernel.
//	Order = 1 is Raised Cosine filter.
//	Converges to a Matched filter (rectangle the width of 1/baudrate) for large order.

double extendedNyquistRecur( int order, float t, int n, double baudrate )
{
	float offset ;
	
	if ( order <= 1 ) return raisedCosineInner( t, n, baudrate ) ;
	
	offset = 0.5/baudrate ;
	order-- ;

	return extendedNyquistRecur( order, t*2.0-offset, n*2, baudrate ) + extendedNyquistRecur( order, t*2.0+offset, n*2, baudrate ) ;
}

//	Recursive implementation of the "Extended Nyquist" kernel.
//	Order = 1 is Raised Cosine filter.
//	Converges to a Matched filter (rectangle the width of 1/baudrate) for large order.
double extendedNyquist( int order, float t, int n, double baudrate )
{
	return extendedNyquistRecur( order, t, n, baudrate ) ;
}
