//
//  OffsetFilter.m
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/29/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "OffsetFilter.h"
#import "DSPWindow.h"


@implementation OffsetFilter



//	Create a lowpass filter with a DC cut with passband from <offset> Hz to <offset>+p Hz
//	Filtering is performed by FIR.c (which uses vDSP framework).
- (id)initWithPassband:(float)p offset:(float)offset quadrature:(Boolean)quadrature
{
	int i, n ;
	float t, u, *lpfKernel, *iKernel, *qKernel ;
	
	self = [ super init ] ;
	if ( self ) {
		
		//  correct the fequency axis to create an equivalent bandwidth at 3 dB points instead of 6 dB points (FIR design)
		bandwidth = p + ( ( 4000.0-p )*.001*0.001401 + 1 )*37.6755 ;	

		//  use length that is factor of 4 for Altivec
		length = 512 ;
		n = length/2 ;
		lpfKernel = blackmanHarrisKernel( bandwidth, n ) ; 
		
		//  Shift the LPF up by half the bandwidth, using in-phase and quadrature shifting carriers
		//  The result is a pair of lowpass Hilbert transform FIR kernels
		iKernel = (float*)malloc( ( length )*sizeof( float ) ) ;
		iKernel[n-1] = lpfKernel[n-1]*2 ;
		iKernel[length-1] = 0 ;
		qKernel = nil ;
		if ( quadrature ) {
			qKernel = (float*)malloc( ( length )*sizeof( float ) ) ;
			qKernel[n-1] = qKernel[length-1] = 0.0 ;
		}
		//  Shift the LPF up by half the bandwidth, using inphase and quadrature shifting carriers
		//  The result is a pair of lowpass Hilbert transform FIR kernels
		//  Note: 100 Hz offset from DC gives 0.06 dB amplitude balance within the 3dB bandwidth of the bandpass filter
		u = k2Pi*(bandwidth*0.5 + offset)/kInternalSamplingRate ;  //  offset phasor frequency
		for ( i = 0; i < n; i++ ) {
			t = u*( i+1 ) ;
			iKernel[n-1-i] = ( iKernel[n+i] = lpfKernel[n+i] * cos(t)*2 ) ;
			if ( quadrature ) qKernel[n-1-i] = -( qKernel[n+i] = lpfKernel[n+i] * sin(t)*2 ) ;
		}				
		iFilter = FIRFilter( iKernel, length, 1 ) ;
		free( iKernel ) ;
		if ( quadrature ) {
			qFilter = FIRFilter( qKernel, length, 1 ) ;	
			free( qKernel ) ;
		}
		free( lpfKernel ) ;
	}
	return self ;
}

- (void)dealloc
{
	DeleteFIR( iFilter ) ;
	if ( qFilter ) DeleteFIR( qFilter ) ;
	//[ super dealloc ] ;
}

@end
