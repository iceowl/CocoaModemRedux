//
//  AudioInterfaceDevice.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AudioInterfaceDevice : NSObject {
    
    
//        AudioDeviceID deviceID ;
//        AudioStreamID streamID ;
//        int streamIndex ;				//  v1.1 (fr cocoaModem v0.50) n-th stream of a device
//        Boolean isInput ;
//        NSString *name ;				//  v0.70 -- was char name[97]

}

@property (retain) NSString *name;
@property AudioDeviceID deviceID;
@property AudioStreamID streamID;
@property int streamIndex;
@property Boolean   isInput;


@end
