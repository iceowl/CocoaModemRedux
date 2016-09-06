//
//  AudioManager.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 11/5/09.
//  Copyright 2009 Kok Chen, W7AY. All rights reserved.
//

#import "AudioManager.h"
#import "Messages.h"


//  AudioDeviceStart and AudioDeviceStop does not allow the same AudioDeviceIOProc to be used more than once per AudioDeviceID.
//	Different modeminterfaces that uses the same device can therefore not subclass off the same base class that uses the same AudioDeviceIOProc.
//	AudioManager handles all AudioDeviceIOProc callbacks and issue AudioDeviceStart/AudioDeviceStop and demux the data from the different modems.
//	AudioManager also handles system device changes and forward the information to the clients of a device.

//  forward references
static OSStatus deviceListenerProc( AudioDeviceID inDeviceID, UInt32 channel, Boolean isInput, AudioDevicePropertyID property, void *client ) ;


@implementation AudioManager

@synthesize cachedDevice           = _cachedDevice;
@synthesize registeredAudioDevice  = _registeredAudioDevice;


//	Return RegisteredAudioDevice of AudioDeviceID, or nil, if device not registered.

// AT some point these should be turned into NSMutableDictionaries from NSMutableArrays...

- (RegisteredAudioDevice*)audioDeviceForID:(AudioDeviceID)devID
{
    for(int i = 0; i <[_cachedDevice count];i++){
        RegisteredAudioDevice *rd = (RegisteredAudioDevice*)[_cachedDevice objectAtIndex:i];
        if(rd.deviceID == devID ) {
            return rd;
        }
    }
    
    for(int i = 0; i <[_registeredAudioDevice count];i++){
        RegisteredAudioDevice *rd = (RegisteredAudioDevice*)[_registeredAudioDevice objectAtIndex:i];
        if(rd.deviceID == devID ) {
            return rd;
        }
    }
    
	return nil ;
}

//	A Core Audio input request comes to this (deviceInputProc) callback.
//	This then calls the modemSource(s) that are linked to the deviceID

static OSStatus deviceInputProc( AudioDeviceID devID, const AudioTimeStamp* now, const AudioBufferList* inBuf,
                                const AudioTimeStamp* time, AudioBufferList* bufOut, const AudioTimeStamp* inOutputTime,
                                void* user )


{
    
    
    RegisteredAudioDevice *ra = (__bridge RegisteredAudioDevice*)user;
    
	if ( ra != nil ) {
        
        @autoreleasepool {
            
            
            //  lock and copy current ModemSources registered to receive data from the DeviceID
            [ ra.lock lock ] ;
            if([ra.activeInputModemAudio count] > 0) {
                //  now submit data to the list of ModemSources (ModemAudio)
                for (int i = 0; i < [ra.activeInputModemAudio count]; i++ ) {
                    [ ra.activeInputModemAudio[i] inputArrivedFrom:devID bufferList:inBuf ] ;
                    
                }
            }
            [ ra.lock unlock ] ;
            
        }
	}
    
    return 0;
}

//	A Core Audio output request comes to this (deviceOutputProc) callback.


static  OSStatus deviceOutputProc( AudioDeviceID devID, const AudioTimeStamp* now, const AudioBufferList* unused,
                                  const AudioTimeStamp* time, AudioBufferList* output, const AudioTimeStamp* outputTime,
                                  void* user )
{
    
    @autoreleasepool {
        
        ModemAudio* thisDevice;
        
        RegisteredAudioDevice* ra = (__bridge RegisteredAudioDevice*)user;
        
        if ( ra != nil) {
            [ ra.lock lock];
            if(ra.activeOutputClients > 0){
                if(ra.activeOutputModemAudio){
                    for (int  i = 0; i < ra.activeOutputClients ; i++ ) {
                        if([ra.activeOutputModemAudio count]) {
                            thisDevice = (ModemAudio*)[ra.activeOutputModemAudio objectAtIndex:i];
                            if(thisDevice){
                                [ thisDevice accumulateOutputFor:devID bufferList:output accumulate:( i != 0 ) ] ;
                            }
                        }
                    }
                    [ ra.lock unlock];
                }
            }
            
        }
    }
    return noErr;
}


//	(Private API)
- (void)removePropertyListenerFor:(RegisteredAudioDevice*)audioDevice
{
    OSStatus status ;
    
    if ( audioDevice == nil ) return ;
    AudioObjectPropertyAddress theAddress = {kAudioObjectPropertyListenerRemoved,kAudioPropertyWildcardSection, kAudioObjectPropertyElementWildcard};
    status = AudioObjectRemovePropertyListener(audioDevice.deviceID, &theAddress, (AudioObjectPropertyListenerProc)deviceListenerProc, (__bridge void *)(self));
    //status = AudioDeviceRemovePropertyListener( audioDevice.deviceID, /*master*/0, kAudioPropertyWildcardSection, kAudioPropertyWildcardPropertyID, deviceListenerProc ) ;
    audioDevice.propertyListenerProc = nil ;
}

//	(Private API)
- (void)addPropertyListenerFor:(RegisteredAudioDevice*)audioDevice
{
    OSStatus status ;
    
    if ( audioDevice == nil ) return ;
    
    if ( audioDevice.propertyListenerProc != nil ) [ self removePropertyListenerFor:audioDevice ] ;
    
    AudioObjectPropertyAddress theAddress = {kAudioObjectPropertyListenerAdded,kAudioPropertyWildcardSection,kAudioObjectPropertyElementWildcard};
    status = AudioObjectAddPropertyListener(audioDevice.deviceID, &theAddress, (AudioObjectPropertyListenerProc)deviceListenerProc, (__bridge void *)(self));
    //status = AudioDeviceAddPropertyListener( audioDevice.deviceID, /*master*/0, kAudioPropertyWildcardSection, kAudioPropertyWildcardPropertyID, deviceListenerProc, (__bridge void *)(self) ) ;
    audioDevice.propertyListenerProc = (AudioDevicePropertyListenerProc*)deviceListenerProc ;
}

- (id)init
{
    
    self = [ super init ] ;
    if ( self ) {
        registeredAudioDevices = 0;
        
        _cachedDevice           = [[NSMutableArray alloc] initWithCapacity:MAXCASHEDDEVICES];
        _registeredAudioDevice  = [[NSMutableArray alloc] initWithCapacity:MAXREGISTEREDDEVICES];
        
        // RegisteredAudioDevice *a = [[RegisteredAudioDevice alloc] init];
        
        //        for (int i = 0; i < MAXCASHEDDEVICES; i++){
        //            [ _cachedDevice insertObject:a atIndex: i];}
        //        for (int i = 0; i < MAXREGISTEREDDEVICES; i++){
        //            [ _registeredAudioDevice insertObject:a atIndex: i];}
        
        
    }
    return self ;
}


- (void)dealloc

{
    int i ;
    RegisteredAudioDevice *cachedAudioDevice ;
    
    for ( i = 0; i < registeredAudioDevices; i++ ) {
        cachedAudioDevice = [_registeredAudioDevice objectAtIndex:i] ;
        if(cachedAudioDevice != nil) {
            if ( cachedAudioDevice.activeInputClients > 0 ) AudioDeviceStop( cachedAudioDevice.deviceID, deviceInputProc ) ;
            if ( cachedAudioDevice.activeOutputClients > 0 ) AudioDeviceStop( cachedAudioDevice.deviceID, deviceOutputProc ) ;
            //AudioDeviceRemoveIOProc( cachedAudioDevice.deviceID, deviceInputProc ) ;
            //AudioDeviceRemoveIOProc( cachedAudioDevice.deviceID, deviceOutputProc ) ;
            AudioDeviceDestroyIOProcID(cachedAudioDevice.deviceID, cachedAudioDevice.theIOProcID_Output);
            AudioDeviceDestroyIOProcID(cachedAudioDevice.deviceID, cachedAudioDevice.theIOProcID_Input);
            if ( cachedAudioDevice.propertyListenerProc != nil ) [ self removePropertyListenerFor:cachedAudioDevice ] ;
        }
        //	[ cachedAudioDevice.lock release ] ;
        free( (__bridge void *)(cachedAudioDevice) ) ;
    }
    //[ super dealloc ] ;
}

//	(Private API)
- (void)addClient:(ModemAudio*)client :(RegisteredAudioDevice*)dev :(NSMutableArray*)list
{
    
    
    if ( (int)dev.deviceID >= 256 ) {
        NSLog( @"AudioManager devID > 256! returning..." ) ;
        return ;
    }
    
    //  check if client is already in the list
    
    NSUInteger x = [list indexOfObject:client];
    if(x != NSNotFound){
        NSLog(@" client %@ already on list", client.deviceName);
        return;
    }
    //	[ dev.lock lock ] ;
    //	[list insertObject:client atIndex:inCount] ;
    //	*count = inCount+1 ;
    //	[ dev.lock unlock ] ;
    
    [list addObject:client];
    NSLog(@"object %@ added to list", client.deviceName);
}

//	(Private API)


- (void)removeClient:(ModemAudio*)client :(RegisteredAudioDevice*)dev :(NSMutableArray*)list
{
    
    
    int c = (int)[list count];
    if(c > 0) {
        NSUInteger x = [list indexOfObject:client];
        if(x != NSNotFound) {
            ModemAudio *mo = (ModemAudio*)[list objectAtIndex:x];
            NSString *o = mo.deviceName;
            [list removeObjectAtIndex:x];
            NSLog( @"Removed object %@ at index %d",o,(int)x) ;
        } else {
            NSLog(@" could not remove object %@ because it is not on the list",client.deviceName);
        }
    } else {
        NSLog(@" no objects in list and trying to remove one");
    }
    
    return;
    
    //	inCount = *count ;
    //	//  look for the client in the active list
    //
    //
    //
    //	for ( i = 0; i < inCount; i++ ) {
    //		if ( list[i] == client ) {
    //			//  found the entry to remove
    //			[ dev.lock lock ] ;
    //			inCount-- ;
    //			*count = ( inCount < 0 ) ? 0 : inCount ;
    //			for ( j = i; j < inCount; j++ ) list[j] = list[j+1] ;
    //			[ dev.lock unlock ] ;
    //			return ;
    //		}
    //	}
    //	NSLog( @"AudioManager -removeInputClient: client not found in active list?" ) ;
}

- (int)getDeviceInfo:(AudioDeviceID)devID streams:(DeviceStream*)streams isInput:(Boolean)isInput
{
    int i, j, n, m ;
    UInt32 datasize ;
    OSStatus status ;
    AudioBufferList audioBufferList ;
    AudioBuffer *audioBuffer ;
    DeviceStream *stream ;
    AudioObjectPropertyScope theScope = isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theConfigAddress = {kAudioDevicePropertyStreamConfiguration, theScope,kAudioObjectPropertyElementMaster};
    AudioObjectPropertyAddress theVolumeAddress = {kAudioDevicePropertyVolumeRangeDecibels, theScope,kAudioObjectPropertyElementMaster};
    n = 0 ;
    datasize = sizeof(AudioBufferList) ;
    status = AudioObjectGetPropertyData(devID, &theConfigAddress, 0, NULL, &datasize, &audioBufferList);
    CheckError(status, "AudioObjectGetProperty Data failed for kAudioDevicePropertyStreamConfiguration in AudioManager getDeviceInfo");
    //status = AudioDeviceGetPropertyInfo( devID, 0, isInput, kAudioDevicePropertyStreamConfiguration, &datasize, NULL ) ;
    if ( status == noErr  ) {
        //  status = AudioObjectGetPropertyData(devID, &theConfigAddress, 0, NULL, &datasize, &audioBufferList);
        //   CheckError(status, "AudioObjectGetPropertyData failed for kAudioDevicePropertyStreamConfiguration AudioManager getDeviceInfo");
        //status = AudioDeviceGetProperty( devID, 0, isInput, kAudioDevicePropertyStreamConfiguration, &datasize, &audioBufferList ) ;
        //if ( status == noErr) {
        //  limit to MAXSTREAMS
        n = audioBufferList.mNumberBuffers ;
        if ( n > 16 ) n = MAXSTREAMS ;
        for ( i = 0; i < n; i++ ) {
            stream = &streams[i] ;
            audioBuffer = &audioBufferList.mBuffers[i] ;
            m = audioBuffer->mNumberChannels ;
            if ( m > MAXCHANNELS ) m = MAXCHANNELS ;
            stream->channels = m ;
            //  first check if there is a master control
            datasize = sizeof( AudioValueRange ) ;
            status = AudioObjectGetPropertyData(devID, &theVolumeAddress, 0, NULL, &datasize, &stream->channelInfo[0].dbRange );
            // CheckError(status, "AudioObjectGetPropertyData failed for kAudioDevicePropertyVolumeRangeDecibels AudioManager getDeviceInfo");
            //status = AudioDeviceGetProperty( devID, 0, isInput, kAudioDevicePropertyVolumeRangeDecibels, &datasize, &stream->channelInfo[0].dbRange ) ;
            if(status == noErr) {
                stream->hasMasterControl = TRUE;
              //  NSLog(@"Stream has master control");
            }else {
                stream->hasMasterControl = FALSE ;
               // NSLog(@"stream doesn't have master control");
            }
            
            if ( stream->hasMasterControl == NO ) {
                for ( j = 0; j < m; j++ ) {
                    datasize = sizeof( AudioValueRange ) ;
                    AudioObjectPropertyAddress theVolumeAddress2 = {kAudioDevicePropertyVolumeRangeDecibels, theScope,j+1};
                    status = AudioObjectGetPropertyData(devID, &theVolumeAddress2, 0,NULL,&datasize,&stream->channelInfo[j].dbRange);
                    //CheckError(status, "AudioObjectGetPropertyData failed for kAudioDevicePropertyVolumeRangeDecibels AudioManager getDeviceInfo");
                    //status = AudioDeviceGetProperty( devID, j+1, isInput, kAudioDevicePropertyVolumeRangeDecibels, &datasize, &stream->channelInfo[j].dbRange ) ;
                    if ( status != noErr ) stream->channelInfo[j].dbRange.mMinimum = stream->channelInfo[j].dbRange.mMaximum = 0.0 ;
                }
            }
        }
        //}
    }
    return n ;
}

- (RegisteredAudioDevice*)registeredAudioDeviceForID:(AudioDeviceID)devID
{
    RegisteredAudioDevice *audioDevice = [ self audioDeviceForID:devID ] ;
    
    audioDevice = [ self audioDeviceForID:devID ] ;
    if ( audioDevice != nil ) return audioDevice ;
    
    audioDevice = [[RegisteredAudioDevice alloc] init];
    //  device not yet registered, create a RegisteredAudioDevice struct
    //audioDevice = (RegisteredAudioDevice*)malloc( sizeof(RegisteredAudioDevice) ) ;
    audioDevice.deviceID = devID ;
    audioDevice.inputClients = audioDevice.outputClients = 0 ;
    audioDevice.activeInputClients = audioDevice.activeOutputClients = 0 ;
    audioDevice.lock = [ [ NSLock alloc ] init ] ;
    audioDevice.propertyListenerProc = nil ;
    [ self addPropertyListenerFor:audioDevice ] ;
    
    audioDevice.inputStreams = [ self getDeviceInfo:devID streams:audioDevice.inputStream isInput:YES ] ;
    
    audioDevice.outputStreams = [ self getDeviceInfo:devID streams:audioDevice.outputStream isInput:NO ] ;
    
    
    if ( registeredAudioDevices < MAXCASHEDDEVICES ) [_cachedDevice addObject:audioDevice];
    //  now add CoreAudio procs for this device
    //AudioDeviceAddIOProc( devID, deviceInputProc, (__bridge void *)(self) ) ;
    //AudioDeviceAddIOProc( devID, deviceOutputProc, (__bridge void *)(self) ) ;
    
    AudioDeviceIOProcID theIdI;
    AudioDeviceIOProcID theIdO;
    
    
    
    OSStatus theError = AudioDeviceCreateIOProcID(devID, deviceInputProc, (__bridge void*)audioDevice, &theIdI);
    CheckError(theError, "Cant create IOProcID for input Proc");
    theError = AudioDeviceCreateIOProcID(devID, deviceOutputProc, (__bridge void*)audioDevice, &theIdO);
    CheckError(theError, "Cant create IOProcID for output Proc");
    [audioDevice setTheIOProcID_Output : theIdO];
    [audioDevice setTheIOProcID_Input : theIdI];
    
    [_registeredAudioDevice  addObject:audioDevice];
    registeredAudioDevices++;
    return audioDevice ;
}

- (float)sliderValueForDeviceID:(AudioDeviceID)devID isInput:(Boolean)isInput channel:(int)channel
{
    RegisteredAudioDevice *audioDevice ;
    DeviceStream *stream ;
    Float32 db ;
    UInt32 datasize ;
    OSStatus status ;
    int streams ;
    
    audioDevice = [ self audioDeviceForID:devID ] ;
    AudioObjectPropertyScope theScope = isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    if ( audioDevice == nil ) return NODBVALUE ;
    
    //  device had been in use, fetch the kAudioDevicePropertyVolumeDecibels
    
    if ( isInput ) {
        streams = audioDevice.inputStreams ;
        stream = audioDevice.inputStream ;
    }
    else {
        streams = audioDevice.outputStreams ;
        stream = audioDevice.outputStream ;
    }
    if ( streams <= 0 ) return NODBVALUE ;
    
    //  use stream[0] for now
    datasize = sizeof( Float32 ) ;
    if ( stream->hasMasterControl ) {
        AudioObjectPropertyAddress theVolumeAddress2 = {kAudioDevicePropertyVolumeRangeDecibels, theScope,0};
        status = AudioObjectGetPropertyData(devID, &theVolumeAddress2, 0,NULL,&datasize,&db);
        //status = AudioDeviceGetProperty( devID, 0, isInput, kAudioDevicePropertyVolumeDecibels, &datasize, &db ) ;
    }
    else {
        AudioObjectPropertyAddress theVolumeAddress2 = {kAudioDevicePropertyVolumeRangeDecibels, theScope,channel+1};
        status = AudioObjectGetPropertyData(devID, &theVolumeAddress2, 0,NULL,&datasize,&db);
        
        //status = AudioDeviceGetProperty( devID, channel+1, isInput, kAudioDevicePropertyVolumeDecibels, &datasize, &db ) ;
    }
    if ( status != noErr ) return NODBVALUE ;
    return db ;
}

- (void)audioDeviceRegister:(AudioDeviceID)devID modemAudio:(ModemAudio*)client
{
    Boolean isInputClient ;
    RegisteredAudioDevice *dev  = [ self registeredAudioDeviceForID:devID ] ;
    isInputClient = [ client isInput ] ;
    dev = [ self registeredAudioDeviceForID:devID ] ;
    
    if ( isInputClient ) {
        [ self addClient:client :dev :dev.inputModemAudio  ] ;
        [dev setInputClients:(int)[dev.inputModemAudio count]];
        
    }
    else {
        [ self addClient:client :dev :dev.outputModemAudio ] ;
        [dev setOutputClients:(int)[dev.outputModemAudio count]];
    }
}

- (void)audioDeviceUnregister:(AudioDeviceID)devID modemAudio:(ModemAudio*)client
{
    Boolean isInputClient ;
    
    isInputClient = [ client isInput ] ;
    RegisteredAudioDevice *dev = [ self registeredAudioDeviceForID:devID ] ;
    
    if ( isInputClient ) {
        [ self removeClient:client :dev : dev.inputModemAudio  ] ;
        // [ self removeClient:client :dev :dev.activeInputModemAudio];
        [dev setInputClients:(int)[dev.inputModemAudio count]];
        //  [dev setActiveInputClients:(int)[dev.activeInputModemAudio count]];
    }
    else {
        [ self removeClient :client :dev :dev.outputModemAudio] ;
        // [ self removeClient :client :dev :dev.activeOutputModemAudio];
        [dev setOutputClients:(int)[dev.outputModemAudio count]];
        //  [dev setActiveOutputClients:(int)[dev.activeOutputModemAudio count]];
    }
}

- (OSStatus)audioDeviceStart:(AudioDeviceID)devID modemAudio:(ModemAudio*)client
{
    OSStatus status;
    Boolean isRunning, isInputClient ;
    RegisteredAudioDevice *dev = [ self registeredAudioDeviceForID:devID ] ;
    isInputClient = [ client isInput ] ;
    dev = [ self registeredAudioDeviceForID:devID ] ;
    
    if ( isInputClient ) {
        if( dev.activeInputClients > 0 ) isRunning = TRUE;
        else isRunning = FALSE;
       // NSLog(@" adding %d as input client",devID);
        [ self addClient:client :dev :dev.activeInputModemAudio] ;
        [dev setActiveInputClients:(int)[dev.activeInputModemAudio count]];
        //  return if device is already running
        if ( isRunning ) return 0 ;
        status = AudioDeviceStart( dev.deviceID, dev.theIOProcID_Input ) ;
        CheckError(status, "Audio Device Start error input - AudioManager.m");
        if(status != noErr) {
            NSLog(@" device %d wont start on Input",dev.deviceID);
        }
    }
    else {
        
        if( dev.activeOutputClients > 0 ) isRunning = TRUE;
        else isRunning = FALSE;
     //   NSLog(@" adding %d as output client",devID);
        [ self addClient:client :dev :dev.activeOutputModemAudio ] ;
        [dev setActiveOutputClients:(int)[dev.activeOutputModemAudio count]];
        //  return if device is already running
        if ( isRunning ) return 0 ;
        status = AudioDeviceStart( dev.deviceID, dev.theIOProcID_Output ) ;
        CheckError(status, "Audio Device Start error output - AudioManager.m");
        if(status != noErr) {
            NSLog(@" device %d wont start on Output",dev.deviceID);
        }
        
    }
    
    
    return status;
}

- (OSStatus)audioDeviceStop:(AudioDeviceID)devID modemAudio:(ModemAudio*)client
{
    OSStatus status ;
    Boolean isRunning, isInputClient ;
    RegisteredAudioDevice *dev = [ self registeredAudioDeviceForID:devID ] ;
    
    isInputClient = [ client isInput ] ;
    
    if ( isInputClient ) {
        if( dev.activeInputClients > 0 ) isRunning = TRUE;
        else isRunning = FALSE;
     //   NSLog(@" removing %d as input client",devID);
        [ self removeClient:client :dev : dev.activeInputModemAudio] ;
        [dev setActiveInputClients:(int)[dev.activeInputModemAudio count]];
        //  after removal, do we still have active devices?
        //	if so, or it was already stopped, just return
        if ( !isRunning  || (dev.activeInputClients>0)) return 0 ;
        //  otherwise, stop the device
        status = AudioDeviceStop( dev.deviceID, dev.theIOProcID_Input ) ;
        CheckError(status, "Audio Device Stop error input - AudioManager.m");
        if(status != noErr) {
            NSLog(@" device %d wont stop on Input",dev.deviceID);
        }
        
    }
    else {
        if( dev.activeOutputClients > 0 ) isRunning = TRUE;
        else isRunning = FALSE;
      //  NSLog(@" removing %d as output client",devID);
        [ self removeClient:client :dev : dev.activeOutputModemAudio] ;
        [dev setActiveOutputClients:(int)[dev.activeOutputModemAudio count]];
        //  after removal, do we still have active devices?
        //	if so, or it was already stopped, just return
        if ( !isRunning  || (dev.activeOutputClients>0))  return 0;
        status = AudioDeviceStop( dev.deviceID, dev.theIOProcID_Output ) ;
        CheckError(status, "Audio Device Stop error output - AudioManager.m");
        if(status != noErr) {
            NSLog(@" device %d wont stop on output",dev.deviceID);
        }
        
    }
    return status ;
}

- (void)putCodecsToSleep
{
    int i ;
    RegisteredAudioDevice *cachedID ;
    
    //  check list of sound cards and stop any one that is running
    for ( i = 0; i < registeredAudioDevices; i++ ) {
        cachedID = [_registeredAudioDevice objectAtIndex:i] ;
        OSStatus status;
        if ( cachedID.activeInputClients > 0 ) {
            status = AudioDeviceStop( cachedID.deviceID, deviceInputProc ) ;
            CheckError(status, "Error stopping audio input device");
            if(status != noErr){
                NSLog(@"Error stopping active input device %d",cachedID.deviceID);
            }
        }
        if ( cachedID.activeOutputClients > 0 ) {
            status = AudioDeviceStop( cachedID.deviceID, deviceOutputProc ) ;
            CheckError(status, "Error stopping output device");
            if(status != noErr){
                NSLog(@"Error stopping active output device %d",cachedID.deviceID);
            }
        }
    }
}

- (void)wakeCodecsUp
{
    int i ;
    RegisteredAudioDevice *cachedID ;
    
    //  check list of sound cards and start any one that should be running
    for ( i = 0; i < registeredAudioDevices; i++ ) {
        
        if ( cachedID.activeInputClients > 0 ){
            OSStatus status =  AudioDeviceStart( cachedID.deviceID, deviceInputProc ) ;
            CheckError(status, "AudioDeviceStart error  for input in WakeCodecs up");
            if(status != noErr){
                NSLog(@"Error starting active input device %d",cachedID.deviceID);
            }
        }
        if ( cachedID.activeOutputClients > 0 ) {
            OSStatus status = AudioDeviceStart( cachedID.deviceID, deviceOutputProc ) ;
            CheckError(status, "AudioDeviceStart error for output  in WakeCodecs up");
            if(status != noErr){
                NSLog(@"Error starting active output device %d",cachedID.deviceID);
            }
        }
    }
}

//  get all modems that are registered even if they are not active
- (int)getRegisteredModemAudioListFor:(AudioDeviceID)deviceID isInput:(Boolean)isInput modemAudioList:(NSMutableArray*)audioList ;
{
    int n ;
    RegisteredAudioDevice *audioDevice ;
    
    audioDevice = [ self audioDeviceForID:deviceID ] ;
    if ( audioDevice == nil ) return 0 ;		//  no one has the deviceID registered
    
    if ( isInput ) {
        n = audioDevice.inputClients ;
        if ( audioList != nil ) audioList = audioDevice.inputModemAudio ;
    }
    else {
        n = audioDevice.outputClients ;
        if ( audioList != nil ) audioList = audioDevice.outputModemAudio ;
    }
    return n ;
}


- (int)getModemAudioListFor:(AudioDeviceID)deviceID isInput:(Boolean)isInput modemAudioList:(NSMutableArray*)audioList ;
{
    int n ;
    RegisteredAudioDevice *audioDevice ;
    
    audioDevice = [ self audioDeviceForID:deviceID ] ;
    if ( audioDevice == nil ) return 0 ;		//  no one has the deviceID registered
    
    if ( isInput ) {
        n = (int)[audioDevice.activeInputModemAudio count];
        if ( audioList != nil ) audioList = audioDevice.activeInputModemAudio ;
    }
    else {
        n = (int)[audioDevice.activeOutputModemAudio count] ;
        if ( audioList != nil ) audioList = audioDevice.activeOutputModemAudio ;
    }
    return n ;
}

//	(Private API)
- (void)muted:(AudioDeviceID)deviceID isInput:(Boolean)isInput
{
    int n ;
    
    n = [ self getModemAudioListFor:deviceID isInput:isInput modemAudioList:nil ] ;
    if ( n > 0 ) [ Messages alertWithMessageText:@"Warning: Another application has muted a sound card used by cocoaModem" informativeText:@"" ] ;
}

//	(Private API)
- (void)sourceChanged:(AudioDeviceID)deviceID isInput:(Boolean)isInput
{
    int i, n ;
    NSMutableArray *audioList ;
    
    n = [ self getRegisteredModemAudioListFor:deviceID isInput:isInput modemAudioList:audioList ] ;
    //  ask all ModemAudio with this AudioDeviceID to update their sources
    for ( i = 0; i < n; i++ ) [ audioList[i] fetchSourceFromCoreAudio ] ;
}

//	(Private API)
- (void)samplingRateChanged:(AudioDeviceID)deviceID isInput:(Boolean)isInput
{
    int i, n ;
    NSMutableArray *audioList ;
    
    n = [ self getRegisteredModemAudioListFor:deviceID isInput:isInput modemAudioList:audioList ] ;
    //  ask all ModemAudio with this AudioDeviceID to update their sources
    for ( i = 0; i < n; i++ ) {
        [ audioList[i] fetchSamplingRateFromCoreAudio ] ;
    }
}


//	(Private API)
- (void)audioLevelChanged:(AudioDeviceID)deviceID isInput:(Boolean)isInput
{
    int i, n ;
    NSMutableArray *audioList ;
    
    n = [ self getRegisteredModemAudioListFor:deviceID isInput:isInput modemAudioList:audioList ] ;
    //  ask all ModemAudio with this AudioDeviceID to update their sources
    for ( i = 0; i < n; i++ ) [ audioList[i] fetchDeviceLevelFromCoreAudio ] ;
}

//  AudioDeviceListenerProc for all registered devices end up here
static OSStatus deviceListenerProc( AudioDeviceID inDeviceID, UInt32 channel, Boolean isInput, AudioDevicePropertyID property, void *selfp )
{
    if ( property == 0 ) return 0 ;
    
    //  NOTE: when device sampling rate changes, the following can return (in this order)
    //	kAudioStreamPropertyPhysicalFormat						'pft '
    //	kAudioStreamPropertyVirtualFormat						'sfmt'
    //	kAudioDevicePropertyNominalSampleRate					'nsrt'
    //	kAudioDevicePropertyLatency								'ltnc'
    //	kAudioDevicePropertySafetyOffset						'saft'
    //	kAudioDevicePropertyDeviceIsRunningSomewhere			'gone'
    
    //  NOTE: when volume changes, the foillowing are returned
    //  kAudioDevicePropertyVolumeScalar						'volm'		(not always from Audio MIDI Setup)
    //  kAudioDevicePropertyVolumeDecibels						'vold'		(not always from Audio MIDI Setup)
    //	kAudioHardwareServiceDeviceProperty_VirtualMasterVolume	'vmvc'		defined in AudioToolbox/AudioServices.h
    //	AudioHardwareServiceDeviceProperty_VirtualMasterBalance	'vmbc'		defined in AudioToolbox/AudioServices.h
    
    //  NOTE: when source changes, the following are returned
    //  kAudioDevicePropertyDeviceHasChanged					'diff'
    //	kAudioDevicePropertyDataSource							'ssrc'
    
    //	NOTE: when bits/channels changes,
    //	kAudioStreamPropertyPhysicalFormat						'pft '
    //  kAudioDevicePropertyAvailableNominalSampleRates			'nsr#'
    //	kAudioStreamPropertyVirtualFormat						'sfmt'
    //	kAudioDevicePropertyStreamConfiguration					'slay'
    
    //	NOTE: when mute changes,
    //	kAudioDevicePropertyMute								'mute'
    
    //	NOTE: when sampling starts,
    //  kAudioDevicePropertyDeviceIsRunningSomewhere			'gone'
    //	kAudioDevicePropertyDeviceIsRunning						'goin'
    
    //	NOTE: when sampling stops,
    //	kAudioDevicePropertyDeviceIsRunning						'goin'
    //  kAudioDevicePropertyDeviceIsRunningSomewhere			'gone'
    
    
    switch ( property ) {
        case kAudioDevicePropertyMute:
            [ (__bridge AudioManager*)selfp muted:inDeviceID isInput:isInput ] ;
            return 0 ;
        case kAudioDevicePropertyDataSource:
            [ (__bridge AudioManager*)selfp sourceChanged:inDeviceID isInput:isInput ] ;
            return 0 ;
        case kAudioDevicePropertyNominalSampleRate:
            [ (__bridge AudioManager*)selfp samplingRateChanged:inDeviceID isInput:isInput ] ;
            return 0 ;
        case kAudioDevicePropertyVolumeDecibels:
        case 'vmvc':
            [ (__bridge AudioManager*)selfp audioLevelChanged:inDeviceID isInput:isInput ] ;
            return 0 ;
    }
    
    if ( 0 ) {
        char *s = (char*)&property ;
        NSLog( @"---- AudioManager:deviceListenerProc %c%c%c%c deviceID = %d isInput %d\n", s[3], s[2], s[1], s[0], (int)inDeviceID, isInput ) ;
    }
    return 0 ;
}

@end
