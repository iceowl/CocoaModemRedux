//
//  CrossedEllipseFilter.h
//  diddles
//
//  Created by Kok Chen on 10/11/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "ComplexFilter.h"


@interface CrossedEllipseFilter : ComplexFilter {
	float shift ;
}

- (id)initWithShift:(float)freq length:(int)length ;

- (void)setShift:(float)value ;
- (float)shift ;

@end
