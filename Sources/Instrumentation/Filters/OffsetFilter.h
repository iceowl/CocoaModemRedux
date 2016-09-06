//
//  OffsetFilter.h
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/29/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FilterTypes.h"
#import "FIR.h"


@interface OffsetFilter : NSObject {
	int length ;
	float bandwidth ;
	FIR *iFilter, *qFilter ;
}

- (id)initWithPassband:(float)p offset:(float)offset quadrature:(Boolean)quadrature ;

@end
