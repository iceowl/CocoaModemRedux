//
//  hamAlert.h
//  wsjtx
//
//  Created by Joe Mastroianni on 10/26/13.
//  Copyright (c) 2013 Joe Mastroianni. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface hamAlert : NSObject {
    

}

@property (retain)  NSTextView  *accessory;
@property (retain)  NSFont      *font;
@property (retain)  NSDictionary *textAttributes;
@property (retain)  NSAlert     *theAlert;


-(void) raiseAlert : (NSString*)a : (NSString*)b;

@end
