//
//  SoundCardInfo.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

//#import "CoreFilter.h"
#import "AudioDeviceTypes.h"
//#import "ResamplingPipe.h"

#import <Foundation/Foundation.h>

@interface SoundCardInfo : NSObject

	@property AudioDeviceID deviceID ;
	@property AudioStreamID streamID ;
	@property int streamIndex ;
	@property (retain) NSString *name ;


@end
