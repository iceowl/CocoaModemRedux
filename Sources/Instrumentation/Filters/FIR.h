/*
 *  FIR.h
 *  Adapted from cocoaModem 2.0
 */

#import <Carbon/Carbon.h>
#import "Complex.h"
#import <Accelerate/Accelerate.h>

#define	MAXCONTIGUOUSFILTERDATA	4096

typedef float complex Complex ;

typedef struct {
	int width ;
	int components ;
	float *kernel ;
	float *delayline[2] ;
	int delaylineOffset[2] ;
	float *scalarInput ;
	float *scalarOutput ;
} FIR ;
	
FIR *FIRFilter( float *kernel, int taps, int components ) ;
void setKernel( FIR *fir, float *kernel ) ;
void setScaledKernel( FIR *fir, float *kernel, float scale ) ;
void DeleteFIR( FIR *fir ) ;

// filter one buffer
void PerformFIR( FIR *fir, float *inArray, int inLength, float *outArray ) ;

//  filter input DSPSplitComplex into Complex output
void PerformSplitComplexFIR( FIR *fir, DSPSplitComplex input, int samples, Complex *output ) ;
