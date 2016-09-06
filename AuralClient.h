//
//  AuralClient.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>
#import "DestClient.h"

@interface AuralClient : NSObject

@property	DestClient *client ;
@property   AudioDevicePropertyListenerProc proc ;

@end
