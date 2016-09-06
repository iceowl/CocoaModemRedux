//
//  NumericalOscillator.m
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/9/10.
//  Copyright 2010 Kok Chen, W7AY. All rights reserved.
//

#import "NumericalOscillator.h"

@implementation NumericalOscillator

@synthesize phase ;

//	Note: ouput a signal with a 1.0 peak amplitide

//  Change frequency phase continuously
//	Assumes frequency changes right after the previous sample was fetched. 
//	see -setFrequency:offsetCorrection: for changing frequency anywhere between the previous sampling point and the next sampling point
- (void)setFrequency:(double)value
{
	if ( fabs( frequency - value ) < .01 ) return ;
	frequency = value ;
	dPhase = k2Pi*value/kInternalSamplingRate ;
}

//	correction term (between 0 and 1) is the actual time location where the frequency has changed.
//	if correction is 1, the frequency is assumed to have changed right after the previous sample.
//	if correction is 0, the frequency is assumed to have changed right at the next sample.
- (void)setFrequency:(double)value offsetCorrection:(float)correction
{
	float accurateDPhase, newDPhase ;
	
	if ( correction > 1 ) correction = 1 ; else if ( correction < 0 ) correction = 0 ;
	
	frequency = value ;
	newDPhase = k2Pi*value/kInternalSamplingRate ;
	accurateDPhase = correction*dPhase + ( 1-correction )*newDPhase ;
	dPhase = newDPhase ;
	phase = phase - dPhase + accurateDPhase ;		// the next time dPhase is applied, the phase will bcome phase + accurateDPhase.
}

//	(Private API)
-(void)getPhaseArray:(float*)array length:(int)length
{
	int i ;
	
	for ( i = 0; i < length; i++ ) {
		array[i] = phase ;
		phase += dPhase ;
		if ( phase >= k2Pi ) phase -= k2Pi ;
	}
}

- (float)nextSample
{
	double p ;
	
	p = phase ;
	phase += dPhase ;
	if ( phase >= k2Pi ) phase -= k2Pi ;
	return sin( phase ) ;
}

//	NOTE: call -getUnalignedSamples if the buffer was not allocated using malloc (and therefore the properly aligned for vecLib).
- (void)getSamples:(float*)buffer
{
	int length = kDefaultBufferSize ;
	
	[ self getPhaseArray:phaseArray length:length ] ;
	vvsinf( buffer, phaseArray, &length ) ;
}

- (void)getUnalignedSamples:(float*)buffer
{
	[ self getSamples:frequencyArray ] ;
	memcpy( buffer, frequencyArray, kDefaultFloatBufferSize ) ;
}

- (Complex)nextQuadratureSample
{
	double p ;
	Complex u ;
	
	p = phase ;
	phase += dPhase ;
	if ( phase >= k2Pi ) phase -= k2Pi ;
	u = cos( phase ) + I*sin( phase ) ;
	return u ;
}

- (void)getQuadratureSamples:(Complex*)buffer samples:(int)length
{
	[ self getPhaseArray:phaseArray length:length ] ;
	vvcosisinf( (vDSPComplex*)buffer, phaseArray, &length ) ;
}

- (void)getQuadratureSamples:(Complex*)buffer
{
	[ self getQuadratureSamples:buffer samples:kDefaultBufferSize ] ;
}

- (id)init
{
	return [ self initWithFrequency:1000.0 ] ;
}

- (id)initWithFrequency:(double)f
{
	self = [ super init ] ;
	if ( self ) {
		frequency = 0 ;
		[ self setFrequency:f ] ;
		[ self setPhase:0 ] ;
		
		phaseArray = (float*)malloc( kDefaultFloatBufferSize ) ;
		quadratureArray = (Complex*)malloc( kDefaultComplexBufferSize ) ;
		frequencyArray = (float*)quadratureArray ;
	}
	return self ;
}

- (void)dealloc
{
	free( phaseArray ) ;
	free( quadratureArray ) ;
	//[ super dealloc ] ;
}

@end
