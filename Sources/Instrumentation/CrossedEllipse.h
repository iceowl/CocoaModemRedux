//
//  CrossedEllipse.h
//  diddles
//
//  Created by Kok Chen on 10/7/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "Oscilloscope.h"
#import "CrossedEllipseFilter.h"
#import "CrossedEllipseChannel.h"
#import "Interpolate.h"
#import "NumericalOscillator.h"
//#import "RTTYPipeline.h"
//#import "TuningFilter.h"



//#define	kInterpolationSpan		8
//#define	kInterpolationFactor	8
//#define	kInterpolatedSize		( kBasebandBufferSize*kInterpolationFactor )
//
//#define	kPhosphorDecayMask		0x7f
//#define	kPhosphorDecay			( kPhosphorDecayMask+1 )
//
//typedef struct {
//	//  filters
//	CrossedEllipseFilter *filter ;
//	Interpolate *interpolate ;
//	//	interpolated data
//	Complex tail[kInterpolationSpan] ;		// tail of raw (3000 samples/sec) buffer
//	Complex data[kInterpolatedSize*2] ;		// double 24000 samples/sec buffer
//	Complex *p, *q ;						// "previous" and "current" pointers
//	//  plot sequences
//	NSBezierPath *path ;
//	NSPoint point[kPhosphorDecay] ;
//	Boolean penDown[kPhosphorDecay] ;
//	Boolean penstate ;
//	int gated[2] ;							// 00 to draw frame, 11 to ignore entire frame, 01 to ignore second half of frame 
//	NSPoint last ;
//	NSPoint crossPoint ;
//	int index ;
//	int previousFrameInhibit ;
//} CrossedEllipseChannel ;


@interface CrossedEllipse : Oscilloscope <PipelineProtocol> {
	IBOutlet NSSlider *aspectRatioSlider ;
	IBOutlet NSButton *crossTuneCheckbox ;
	NumericalOscillator *shiftOscillator, *pitchOscillator ;
	CrossedEllipseChannel *mark, *space ;
	ComplexFilter *roofingFilter ;
	TuningFilter *tuningFilter ;
	float aspectRatio ;
	float shiftFrequency ;
	float phaseShift ;
	Complex phaseCorrection ;
	int cycle, mux, pmux ;
	float dither[kInterpolatedSize] ;	//  cached dither noise
	Boolean embedCross ;
	NSColor *crossColor ;
	NSPoint sortedCrossPoint[2] ;
	NSBezierPath *crossPath[2] ;
	NSBezierPath *crossGraticule ;
	float ellipseScale, crossScale, agc, agcPower ;
}

- (void)setShift:(float)value ;
- (NSDictionary*)crossedEllipsePlist ;

@end
