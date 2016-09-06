/*
 *  FilterTypes.h
 *  Filter Library
 *
 *  Created by Kok Chen on 9/13/11.
 *  Copyright 2011 Kok Chen, W7AY. All rights reserved.
 *
 */
 
#import "Complex.h"
#import "SamplingConstants.h"
#import <Accelerate/Accelerate.h>

typedef __float_complex_t				vDSPComplex ;		//  must agree with Complex (change to double if Complex is double)

#define	kDefaultFloatBufferSize			( sizeof( float )*kDefaultBufferSize )
#define	kDefaultComplexBufferSize		( sizeof( Complex )*kDefaultBufferSize )
#define	kDefaultQuadratureBufferSize	( kDefaultFloatBufferSize*2 )

#define	cp2Pi							( kPi*2 )

#define	cmplx( a, b )					( a + I*b )
