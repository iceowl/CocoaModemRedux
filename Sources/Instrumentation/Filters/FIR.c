//
//  FIR.c
//	vDSP based FIR filter for scalar and complex data.
//	Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/23/2010.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.

#import "FIR.h"
#include <string.h>

//  Create a vDSP convolution structure for an FIR filter.
//  The array kernel should have width entries.
//	components = 1 : array of float, 
//	components = 2 : array of complex floats.
//	MAXCONTIGUOUSFILTERDATA determines how often the delay line has to me recopied.
FIR *FIRFilter( float *kernel, int taps, int components )
{
	FIR *fir ;
	int i, n ;
	
	assert( components == 1 || components == 2 ) ;
	
	fir = ( FIR* )malloc( sizeof( FIR ) ) ;
	fir->width = taps ;
	fir->components = components ;
		
	n = taps+MAXCONTIGUOUSFILTERDATA ;

	if ( components == 1 ) {
		fir->delayline[0] = fir->delayline[1] = ( float* )calloc( n, sizeof( float ) ) ;
	}
	else {
		fir->scalarInput = ( float* )calloc( MAXCONTIGUOUSFILTERDATA*2, sizeof( float ) ) ;
		fir->scalarOutput = &fir->scalarInput[MAXCONTIGUOUSFILTERDATA] ;
		//	Two delays lines allow for complex FIR.
		fir->delayline[0] = ( float* )calloc( n*2, sizeof( float ) ) ;
		fir->delayline[1] = fir->delayline[0] + n ;
	}
	fir->delaylineOffset[0] = fir->delaylineOffset[1] = 0 ;		//  pointers to where the active taps are currently aligned at
	
	//  reverse kernel to use convolution operator for filtering
	fir->kernel = ( float* )malloc( sizeof( float )*taps ) ;
	for ( i = 0; i < taps; i++ ) fir->kernel[taps-1-i] = kernel[i] ;
	return fir ;
}

//	change kernel
void setKernel( FIR *fir, float *kernel )
{
	return setScaledKernel( fir, kernel, 1.0 ) ;
}

void setScaledKernel( FIR *fir, float *kernel, float scale )
{
	int i, taps ;
	
	taps = fir->width ;
	for ( i = 0; i < taps; i++ ) fir->kernel[taps-1-i] = kernel[i]*scale ;
}

void DeleteFIR( FIR *fir )
{
	if ( !fir ) return ;
	
	if ( fir->components == 2 ) free( fir->scalarInput ) ;
	free( fir->kernel ) ;
	free( fir->delayline[0] ) ;
	free( fir ) ;
}

//  Apply FIR filter for array and length of array
//  inArray and outArray size should be the same size as samples
//	offset is 
static void PerformFloatFIR( FIR *fir, float *inArray, int samples, float *outArray, float *delayline, int *offset )
{
	int n, nf ;
	float *frame ;
	
	n = fir->width ;
	nf = n*sizeof( float ) ;
	//  check if there is space left in the delay line
	if ( ( *offset + samples ) > MAXCONTIGUOUSFILTERDATA ) {
		//  nope, need to shift the tail of the delay line to the head first
		memcpy( delayline, delayline + (*offset), nf ) ;
		*offset = 0 ;
	}
	if ( samples <= 1024 || samples <= n ) {
		//  Number of samples is shorter than 1024 or width of the FIR filter, append all of the input samples to the delay line.
		frame = delayline + (*offset) ;
		memcpy( frame+n, &inArray[0], samples*sizeof( float ) ) ;
		//  Filter the data in the delay line.
		vDSP_conv( frame, 1, &fir->kernel[0], 1, &outArray[0], 1, samples, n ) ;
		*offset += samples ;
	}
	else {
		//  Number of samples longer than 1024: we perform the FIR in two pieces, since copying data start to be expensive.
		frame = delayline + (*offset) ;
		memcpy( frame+n, &inArray[0], nf ) ;
		//  Filter the data in the delay line. 
		//	The delay line is 2*n in length, so we can compute n output samples
		vDSP_conv( frame, 1, &fir->kernel[0], 1, &outArray[0], 1, n, n ) ;
		//  Now filter rest of the data, using the input data directly instead of the delay line, we compute (samples-n) samples.
		vDSP_conv( &inArray[0], 1, &fir->kernel[0], 1, &outArray[n], 1, samples-n, n ) ;
		//  Finally, copy tail of data into the front of the delay line for next filter iteration.
		memcpy( delayline, &inArray[samples-n], nf ) ;
		*offset = 0 ;
	}
}

//	Note: inArray = (float*)( &complexArray[0] )
static void PerformComplexFIR( FIR *fir, float *inArray, int samples, float *outArray )
{
	int i, j ;
	float *scalarInput, *scalarOutput ;
	
	scalarInput = fir->scalarInput ;
	scalarOutput = fir->scalarOutput ;
	
	for ( j = 0, i = 0; i < samples; i++ ) {
		scalarInput[i] = inArray[j] ;
		j += 2 ;
	}
	PerformFloatFIR( fir, scalarInput, samples, scalarOutput, fir->delayline[0], &fir->delaylineOffset[0] ) ;
	inArray += 1 ;
	for ( j = 0, i = 0; i < samples; i++ ) {
		outArray[j] = scalarOutput[i] ;
		scalarInput[i] = inArray[j] ;
		j += 2 ;
	}
	PerformFloatFIR( fir, scalarInput, samples, scalarOutput, fir->delayline[1], &fir->delaylineOffset[1] ) ;
	outArray += 1 ;
	for ( j = 0, i = 0; i < samples; i++ ) {
		outArray[j] = scalarOutput[i] ;
		j += 2 ;
	}
}

//	Perform FIR filtering for up to MAXCONTIGUOUSFILTERLENGTH (4096) samples
static void PerformShortFIR( FIR *fir, float *inArray, int samples, float *outArray )
{
	if ( fir->components == 1 ) {
		PerformFloatFIR( fir, inArray, samples, outArray, fir->delayline[0], &fir->delaylineOffset[0] ) ;
		return ;
	}
	PerformComplexFIR( fir, inArray, samples, outArray ) ;
}


void PerformFIR( FIR *fir, float *inArray, int samples, float *outArray )
{
	int n, pass ;
	
	if ( samples <= MAXCONTIGUOUSFILTERDATA ) {
		PerformShortFIR( fir, inArray, samples, outArray ) ;
		return ;
	}
	//  Cut input into chunks of MAXCONTIGUOUSFILTERLENGTH (4096) samples
	for ( pass = 0; pass < 64; pass++ ) {
		//  for sanity, only allow up to 256k samples total
		n = samples ;
		if ( n > MAXCONTIGUOUSFILTERDATA ) n = MAXCONTIGUOUSFILTERDATA ;
		PerformShortFIR( fir, inArray, n, outArray ) ;
		samples -= n ;
		if ( samples <= 0 ) return ;
		inArray += 2*n ;
		outArray += 2*n ;
	}
}

void PerformSplitComplexFIR( FIR *fir, DSPSplitComplex input, int samples, Complex *output )
{
	int i, j ;
	float *scalarOutput, *outArray ;
	
	scalarOutput = fir->scalarOutput ;
	if ( samples > MAXCONTIGUOUSFILTERDATA ) {
		printf( "PerformSplitComplexFIR only implemented for n < 4096\n" ) ;
		exit( 0 ) ;
	}
	PerformFloatFIR( fir, input.realp, samples, scalarOutput, fir->delayline[0], &fir->delaylineOffset[0] ) ;
	outArray = (float*)&output[0] ;
	for ( j = 0, i = 0; i < samples; i++ ) {
		outArray[j] = scalarOutput[i] ;
		j += 2 ;
	}
	PerformFloatFIR( fir, input.imagp, samples, scalarOutput, fir->delayline[1], &fir->delaylineOffset[1] ) ;
	outArray += 1 ;
	for ( j = 0, i = 0; i < samples; i++ ) {
		outArray[j] = scalarOutput[i] ;
		j += 2 ;
	}



}

