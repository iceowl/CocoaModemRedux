//
//  SamplingConstants.h
//  diddles
//
//  Created by Kok Chen on 9/12/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#define	kInternalSamplingRate			48000.0
#define	kDefaultBufferSize				512
#define	kPi								3.14159265358979
#define	kSqrt2							1.41421356237309

#define	k2Pi							( kPi*2 )

//	Decimate broadband to baseband 
//	With decimation factor of 16, the baseband sampling rate ( kInternalSamplingRate/kDecimationFactor ) is 3000 samples/second.
//	Each broadband kDefaultBufferSize is reduced to a kBasebandBufferSize of 32 samples (10.67 milliseconds).
//	Note: for kDefaultBufferSize = 512 and kDecimationFactor = 16, kBasebandBufferSize = 32.

#define	kDecimationFactor				( 16 )
#define	kBasebandSamplingRate			( kInternalSamplingRate/kDecimationFactor )
#define	kBasebandBufferSize				( kDefaultBufferSize/kDecimationFactor )
#define	kDecimatedSamples				( kDefaultBufferSize/kDecimationFactor )
#define	kDecimationFilterLength			( kDefaultBufferSize*3 )

//	Collect kBasebandBuffers at a time to create a baseband buffer size of 128 samples (42.66 milliseconds) 
//	Note: for kDefaultBufferSize = 512 and kDecimationFactor = 16, kExtendedBasebandBufferSize = 128.

#define	kBasebandBuffers				4
#define	kExtendedBasebandBufferSize		( kBasebandBuffers*kBasebandBufferSize )

typedef	float BroadbandArray[kDefaultBufferSize] ;
typedef	float ExtendedBasebandArray[kExtendedBasebandBufferSize] ;

