//
//  Complex.h
//  diddles
//
//  Created by Kok Chen on 9/12/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import <complex.h>
#import <Accelerate/Accelerate.h>
#import "SamplingConstants.h"

typedef float complex Complex ;

typedef	Complex BasebandComplexArray[kBasebandBufferSize] ;
typedef	Complex BroadbandComplexArray[kDefaultBufferSize] ;

//	In vDSP.h
//	struct DSPSplitComplex {
//		float *realp ;
//		float *imagp ;
//	};
//	typedef struct DSPSplitComplex	DSPSplitComlex ;
