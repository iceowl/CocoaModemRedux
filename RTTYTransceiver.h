//
//  RTTYTransceiver.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import <Foundation/Foundation.h>
#import "RTTYRxControl.h"
#import "RTTYReceiver.h"
#import "TextAttribute.h"
#import "Module.h"

@interface RTTYTransceiver : NSObject

   @property RTTYRxControl *control ;
   @property RTTYReceiver *receiver ;
   @property ExchangeView *view ;
   @property TextAttribute *textAttribute ;
   @property Boolean isAlive ;
   @property Module *transmitModule ;



@end
