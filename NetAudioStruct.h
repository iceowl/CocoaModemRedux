//
//  NetAudioStruct.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import <Foundation/Foundation.h>
#import "NetAudio.h"
#import "NetSend.h"

typedef enum {
    kNetAudioIdle,
    kNetAudioStarted,
    kNetAudioRunning,
    kNetAudioStopped
} NetAudioRunState ;

typedef enum {
    kWaitForCommand,
    kCommandAvailable
} LockCondition ;


@interface NetAudioStruct : NSObject {
    
}

    @property NetSend *netSendObj ;
    @property id delegate ;
    @property NetAudioRunState runState ;
    @property float *raisedCosine;

@end
