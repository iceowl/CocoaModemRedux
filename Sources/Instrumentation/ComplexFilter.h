//
//  ComplexFilter.h
//  diddles
//
//  Created by Kok Chen on 10/11/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "Filter.h"

@interface ComplexFilter : Filter {
}

- (void)filterComplex:(Complex*)input to:(Complex*)output length:(int)length ;
- (void)filterSplitComplex:(DSPSplitComplex)input to:(Complex*)output length:(int)length ;

@end
