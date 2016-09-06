//
//  RegisteredAudioDevice.m
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import "RegisteredAudioDevice.h"

@implementation RegisteredAudioDevice

@synthesize deviceID ;

//  actively sampling clients
@synthesize activeInputClients  = _activeInputClients;
//@property ModemAudio *activeInputModemAudio[256] ;
@synthesize activeOutputClients = _activeOutputClients  ;
//	@property ModemAudio **activeOutputModemAudio ;

//  all clients that need deviceListener
@synthesize inputClients = _inputClients;
//	@property ModemAudio **inputModemAudio ;
@synthesize outputClients = _outputClients;
//	@property ModemAudio **outputModemAudio ;

//  stream info for deviceID
@synthesize inputStreams = _inputStreams ;
//@synthesize inputStream;
@synthesize outputStreams = _outputStreams;
//@synthesize outputStream;

@synthesize lock ;
@synthesize propertyListenerProc ;
@synthesize activeInputModemAudio  = _activeInputModemAudio;
@synthesize activeOutputModemAudio = _activeOutputModemAudio;
@synthesize inputModemAudio        = _inputModemAudio;
@synthesize outputModemAudio       = _outputModemAudio;
@synthesize theIOProcID_Input      = _theIOProcID_Input;
@synthesize theIOProcID_Output     = _theIOProcID_Output;
@synthesize inputStream            = _inputStream;
@synthesize outputStream           = _outputStream;


-(id) init {
    
    self = [super init];
    if(self) {
        _activeInputModemAudio  = [[NSMutableArray alloc] initWithCapacity:NUMMODEMS];
        _activeOutputModemAudio = [[NSMutableArray alloc] initWithCapacity:NUMMODEMS];
        _inputModemAudio        = [[NSMutableArray alloc] initWithCapacity:NUMMODEMS];
        _outputModemAudio       = [[NSMutableArray alloc] initWithCapacity:NUMMODEMS];
 
        
//        for (int i = 0; i < NUMMODEMS; i++) {
//            [ _activeInputModemAudio insertObject:[[ModemAudio alloc]init] atIndex: i];
//            [ _activeOutputModemAudio insertObject:[[ModemAudio alloc]init] atIndex: i];
//            [ _inputModemAudio insertObject:[[ModemAudio alloc]init] atIndex: i];
//            [ _outputModemAudio insertObject:[[ModemAudio alloc]init] atIndex: i];
//        }
        

        
        
        _inputStream  = (DeviceStream*)malloc(MAXSTREAMS*sizeof(DeviceStream));
        _outputStream = (DeviceStream*)malloc(MAXSTREAMS*sizeof(DeviceStream));
//        for(int i = 0;i<MAXSTREAMS;i++){
//        _inputStream[i] = *(DeviceStream*)malloc(sizeof(DeviceStream));
//            for(int j = 0;j<MAXCHANNELS;j++) {
//                _inputStream[i].channelInfo[j] = *(DeviceChannel*)malloc(sizeof(DeviceChannel));
//            }
//        _outputStream[i] = *(DeviceStream*)malloc(sizeof(DeviceStream));
//        }
        _theIOProcID_Input = _theIOProcID_Output = NULL;
        _activeInputClients = _activeOutputClients = _inputStreams = _outputStreams = 0;
        _inputClients = _outputClients  = 0;
        
    }
    
    return self;
    
    
}

-(void) dealloc {
    NSLog(@"attempting to dealloc RegisteredAudioDevice");
    free(_inputStream);
    free(_outputStream);
}

-(int) incrementInputStreams {
    return _inputStreams++;
}

-(int)incrementOutputStreams {
    return _outputStreams++;
}

-(int)decrementInputStreams {
    _inputStreams--;
    if(_inputStreams<0)_inputStreams = 0;
    return _inputStreams;
}

-(int)decrementOutputStreams {
    _outputStreams--;
    if(_outputStreams < 0)_outputStreams = 0;
    return _outputStreams;
}

- (int) incrementInputClients {
    return _inputClients++;
}

-(int) incrementOutputClients{
    return _outputClients++;
}
-(int) incrementActiveOutputClients{
    return _activeOutputClients++;
}
-(int) incrementActiveInputClients{
    return _activeInputClients++;
}

- (int) decrementInputClients {
    
    _inputClients--;
    if(_inputClients<0) _inputClients = 0;
    
    return _inputClients;
}

-(int) decrementOutputClients{
    _outputClients--;
    if(_outputClients < 0)_outputClients = 0;
    return _outputClients;
}
-(int) decrementActiveOutputClients{
    
    _activeOutputClients--;
    if(_activeOutputClients < 0) _activeOutputClients = 0;
    
    return _activeOutputClients;
}
-(int) decrementActiveInputClients{
    
    _activeInputClients--;
    if(_activeInputClients < 0) _activeInputClients = 0;
    
    return _activeInputClients;
}



@end
