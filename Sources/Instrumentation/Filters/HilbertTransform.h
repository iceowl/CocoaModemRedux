//
//  HilbertTransform.h
//  Ported from cocoaPath and cocoaModem 3.0
//
//  Created by Kok Chen on 7/17/08.
//	Ported on 8/22/2010.
//  Copyright 2008, 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "OffsetFilter.h"

@interface HilbertTransform : OffsetFilter {
	DSPSplitComplex temp ;	//  temp buffer to hold split compex results from the quadrature filter
}

- (id)initWithPassband:(float)p ;
- (void)filter:(float*)buffer samples:(int)samples complexResult:(Complex*)result ;

@end
