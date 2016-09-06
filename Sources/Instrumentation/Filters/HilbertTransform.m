//
//  HilbertTransform.m
//  Ported from cocoaPath
//
//  Created by Kok Chen on 7/17/08.
//  Copyright 2008, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "HilbertTransform.h"

//  Hilbert transform pair.


@implementation HilbertTransform

//	Implementation uses Grand Central Dispatch to concurrently filter the I and Q components.

- (id)initWithPassband:(float)p
{
	self = [ super initWithPassband:p offset:100.0 quadrature:YES ] ;
	if ( self ) {
		temp.realp = (float*)malloc( 2048*sizeof( float ) ) ;
		temp.imagp = temp.realp+1024 ;
	}
	return self ;
}

- (id)init
{
	return [ self initWithPassband:3000.0 ] ;
}

- (void)dealloc
{
	free( temp.realp ) ;
	//[ super dealloc ] ;
}

//  Apply Hilbert transform to input buffer into a complex array
//	Note: total power from complex Hilbert transformed signal has 3 dB gain over scalar input.
- (void)filter:(float*)buffer samples:(int)samples complexResult:(Complex*)result
{
	//  The following creates a Grand Central Dispatch to do the following two calls in applyQuadratureFilter
	//    PerformFIR( iFilter, buffer, samples, resulti ) ;
	//    PerformFIR( qFilter, buffer, samples, resultq ) ;
	dispatch_queue_t queue = dispatch_get_global_queue (DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ) ;
	dispatch_apply( 2, queue, ^(size_t index ) {
		switch ( index ) {
		case 0:
			PerformFIR( iFilter, buffer, samples, temp.realp ) ;
			break ;
		case 1:
			PerformFIR( qFilter, buffer, samples, temp.imagp ) ;
			break ;
		}
	} ) ;	
	//  convert to packed complex
	vDSP_ztoc( &temp, 1, (DSPComplex*)result, 2, samples ) ;
}


@end
