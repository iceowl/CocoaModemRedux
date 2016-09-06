//
//  GaussianFilter.m
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/27/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "GaussianFilter.h"


@implementation GaussianFilter

//	 Gaussian filter given a 2-sigma bandwidth (16,000 samples/sec)
- (id)initWithBandwidth:(float)bandwidth gain:(float)gain
{
	float *kernel, a, b, r, v ;
	int i ;
	
	self = [ super initWithFilterLength:256 ] ;
	if ( self ) {
		//  adjust based on measured values for a and b
		if ( bandwidth < 1 ) bandwidth = 1 ;
		r = 200/bandwidth ;
		a = 0.1488485*r*gain ;
		b = 648.455658*2.0*r*r ;

		kernel = ( float* )calloc( n, sizeof( float ) ) ;
		for ( i = 0; i < n; i++ ) {
			v = i - n*0.5 ;
			kernel[i] = a*exp( - v*v/( b ) ) ;
		}
		[ self setKernel:kernel ] ;		
		free( kernel ) ;
	}
	return self ;
}

- (id)init
{
	return [ self initWithBandwidth:200.0 gain:1.0 ] ;
}

@end
