//
//  GaussianFilter.h
//  Ported from cocoaModem 3.0
//
//  Created by Kok Chen on 8/27/10.
//  Copyright 2010, 2011 Kok Chen, W7AY. All rights reserved.
//

#import "Filter.h"


@interface GaussianFilter : Filter {

}
- (id)initWithBandwidth:(float)bandwidth gain:(float)gain ;

@end
