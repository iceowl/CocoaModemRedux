//
//  CrossedEllipseChannel.h
//  diddles
//
//  Created by Joe Mastroianni on 12/10/13.
//
//

#import <Foundation/Foundation.h>
#import "Interpolate.h"
#import "CrossedEllipseFilter.h"

#define	kInterpolationSpan		8
#define	kInterpolationFactor	8
#define	kInterpolatedSize		( kBasebandBufferSize*kInterpolationFactor )

#define	kPhosphorDecayMask		0x7f
#define	kPhosphorDecay			( kPhosphorDecayMask+1 )




@interface CrossedEllipseChannel : NSObject {
    
}

//typedef struct {
//	//  filters
@property	CrossedEllipseFilter *filter ;
@property	Interpolate *interpolate ;
//	//	interpolated data
@property	Complex *tail;//[kInterpolationSpan] ;		// tail of raw (3000 samples/sec) buffer
@property	Complex *data;//[kInterpolatedSize*2] ;		// double 24000 samples/sec buffer
@property	Complex *p, *q ;						// "previous" and "current" pointers
//	//  plot sequences
@property	NSBezierPath *path ;
@property	CGPoint *point;//NSPoint *point;//[kPhosphorDecay] ;
@property	Boolean *penDown;//[kPhosphorDecay] ;
@property	Boolean penstate ;
@property	int *gated;//[2] ;							// 00 to draw frame, 11 to ignore entire frame, 01 to ignore second half of frame
@property	NSPoint last ;
@property	NSPoint crossPoint ;
@property	int index ;
@property	int previousFrameInhibit ;
//} CrossedEllipseChannel ;


@end
