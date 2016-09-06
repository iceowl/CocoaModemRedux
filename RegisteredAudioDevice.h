//
//  RegisteredAudioDevice.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import <Foundation/Foundation.h>
#import "ModemAudio.h"
#define	MAXSTREAMS	16
#define	MAXCHANNELS	16
#define NUMMODEMS   256



typedef struct {
	AudioValueRange dbRange ;
} DeviceChannel ;

typedef struct {
	int channels ;
	Boolean hasMasterControl ;
	DeviceChannel channelInfo[MAXCHANNELS] ;
} DeviceStream ;



@interface RegisteredAudioDevice : NSObject {

 
    //DeviceStream inputStream[MAXSTREAMS];
    //DeviceStream outputStream[MAXSTREAMS];
    
}

	@property AudioDeviceID deviceID ;
	//  actively sampling clients
	@property int activeInputClients ;
	//@property ModemAudio *activeInputModemAudio[256] ;
	@property int activeOutputClients ;
//	@property ModemAudio **activeOutputModemAudio ;
	
	//  all clients that need deviceListener
	@property int inputClients ;
//	@property ModemAudio **inputModemAudio ;
	@property int outputClients ;
//	@property ModemAudio **outputModemAudio ;
    
	//  stream info for deviceID
	@property int inputStreams ;
   // @property DeviceStream *inputStream;
	@property int outputStreams ;
	//@property DeviceStream *outputStream;
    
	@property (retain) NSLock *lock ;
	@property AudioDevicePropertyListenerProc *propertyListenerProc ;
    @property (retain) NSMutableArray *activeInputModemAudio;
    @property (retain) NSMutableArray *activeOutputModemAudio;
    @property (retain) NSMutableArray *inputModemAudio;
    @property (retain) NSMutableArray *outputModemAudio;
    @property DeviceStream *inputStream;
    @property DeviceStream *outputStream;
    @property AudioDeviceIOProcID  theIOProcID_Input;
    @property AudioDeviceIOProcID  theIOProcID_Output;

-(int) incrementInputClients;
-(int) decrementInputClients;
-(int) incrementOutputClients;
-(int) decrementOutputClients;
-(int) incrementActiveInputClients;
-(int) decrementActiveOutputClients;
-(int) incrementActiveOutputClients;
-(int) decrementActiveInputClients;
-(int) incrementInputStreams;
-(int) decrementInputStreams;
-(int) incrementOutputStreams;
-(int) decrementOutputStreams;


@end
