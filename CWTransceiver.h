//
//  CWTransceiver.h
//  Cocoa Modem Redux
//
//  Created by Joe Mastroianni on 11/27/13.
//  Copyright (c) 2013 Joe Mastroianni. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CWRxControl.h"
#import "RTTYTransceiver.h"
#import "CWReceiver.h"

@interface CWTransceiver : RTTYTransceiver {
    
}
@property CWRxControl *control ;
@property CWReceiver *receiver ;
//@property ExchangeView *view ;
//@property TextAttribute *textAttribute ;
//@property Boolean isAlive ;
//@property Module *transmitModule ;


@end
