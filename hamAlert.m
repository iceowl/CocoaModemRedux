//
//  hamAlert.m
//  wsjtx
//
//  Created by Joe Mastroianni on 10/26/13.
//  Copyright (c) 2013 Joe Mastroianni. All rights reserved.
//

#import "hamAlert.h"

@implementation hamAlert

@synthesize accessory = _accessory;
@synthesize theAlert  = _theAlert;
@synthesize font      = _font;
@synthesize textAttributes = _textAttributes;

-(id) init {
    
    self = [super init];
    if(self) {
        _accessory = [[NSTextView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 200.0, 15.0)];
        _font      = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        _textAttributes  = [NSDictionary dictionaryWithObject:_font forKey:NSFontAttributeName];
        
        [_accessory setEditable:NO];
        [_accessory setDrawsBackground:NO];
        
        _theAlert = [[NSAlert alloc] init];
        
    }
    
    return self;
}

-(void) raiseAlert : (NSString*) s1  :(NSString*) s2{
    if(s1 == nil) s1 = @"";
    if(s2 == nil) s2 = @"";
     _theAlert = [[NSAlert alloc] init];
    [_theAlert setMessageText:s1];
    [_theAlert setInformativeText:s2];
    [_theAlert setAccessoryView:_accessory];
    [_theAlert runModal];
    //[_theAlert release];
    fflush(stdout);
    fflush(stderr);
    
}


@end
