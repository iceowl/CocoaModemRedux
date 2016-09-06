//
//  Interpolate.h
//  diddles
//
//  Created by Kok Chen on 10/18/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Complex.h"
typedef float complex Complex ;

@interface Interpolate : NSObject {
	float kernel[256] ;
	int points ;
	int factor ;
}

- (id)initWithSpan:(int)n factor:(int)factor ;

- (float)interpolate:(float*)input offset:(int)offset ;
- (void)interpolateArray:(float*)input into:(float*)output samples:(int)samples ;

- (Complex)interpolateComplex:(Complex*)input offset:(int)offset ;
- (void)interpolateComplexArray:(Complex*)input into:(Complex*)output samples:(int)samples ;

@end
