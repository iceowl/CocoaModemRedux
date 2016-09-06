//
//  ModemSource.m
//  cocoaModem
//
//  Adapted from PrototypeSource.m on Jul 29 2004
//  Created by Kok Chen on Wed May 26 2004.
#include "Copyright.h"
//

#import "ModemSource.h"
#import "AIFFSource.h"
#import "Application.h"
#import <AudioToolbox/AudioToolbox.h>
#import "AudioManager.h"
#import "Config.h"
#import "Messages.h"
#import "ModemConfig.h"
#import "TextEncoding.h"
#import "Plist.h"
#import "ResamplingPipe.h"



@implementation ModemSource

@synthesize soundFileTimer = _soundFileTimer;
@synthesize readQueue      = _readQueue;


//  The ModemSource is an CMPipe source.
//  ModemSource gets waveform data from two places, a CoreAudio soundcard or an AIFF/WAV file (AIFFSource)

//  This function receives calls from the CoreAudio when a buffer is received from the device.
//	Data is written into the ResamplingPipe for resampling to 11025 s/s
//
//  NOTE: samples must be multiples of 512
//	In the current implementation of buffer sizes, 256 stereo samples are received per deviceInputProc call.


- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

//  init ModemSource and sets the interface controls into the given view
//  file extra are controls for substituting a file for the sound source (set extra to nil if not needed)
//
//  Device States
#define DISABLED	0		// caused by enableInput:NO
#define ENABLED		1		// caused by enableInput:YES
#define RUNNING		2		// caused by started and ENABLED

- (id)initIntoView:(NSView*)view device:(NSString*)name fileExtra:(NSView*)extra playbackSpeed:(int)speed channel:(int)ch client:(CMPipe*)client
{
	self = [ super init ] ;
	if ( self ) {
		channel = ch ;
		self.isInput = YES ;
		delegate = nil ;
		started = hasReadThread = NO ;
		
		self.resamplingPipe = [ [ ResamplingPipe alloc ] initWithSamplingRate:11025.0 channels:2 ] ;	// v0.90 set to 2 channels always
		[ self.resamplingPipe setInputSamplingRate:11025.0 ] ;
		[ self.resamplingPipe setOutputSamplingRate:11025.0 ] ;
        
		//  insert an AIFFSource in between us and the client so AIFF files can be inserted
		sourcePipe = [ [ AIFFSource alloc ] init] ;
        [sourcePipe pipeWithClient:client];
		[ sourcePipe setSamplingRate:CMFs ] ;
		[ self setClient:sourcePipe ] ;
        
		playbackSpeed = speed ;
		periodic = YES ;
		_soundFileTimer = nil ;
		deviceState = DISABLED ;
		//[self setDbSlider:nil ];
		[self setDeviceName :[ [ NSString alloc ] initWithString:name ] ];
		if ( [ [NSBundle mainBundle] loadNibNamed:@"ModemSource" owner:self topLevelObjects:nil ] ) {
			
			//  set up connections for super class
			[ self setSoundCardMenu:inputMenu ];
			[self setSourceMenu:inputSourceMenu ];
			[self setSamplingRateMenu:inputSamplingRateMenu ];
			[self setChannelMenu:inputChannel ];
			[self setParamString:inputParam ];
			
			// loadNib should have set up controlView connections
			if ( view && controlView ) [ view addSubview:controlView ] ;
			if ( extra && fileView ) [ extra addSubview:fileView ] ;
			// actions
			[ self setInterface:inputMenu to:@selector(inputMenuChanged) ] ;
			[ self setInterface:inputSourceMenu to:@selector(sourceMenuChanged) ] ;
			[ self setInterface:inputChannel to:@selector(channelChanged) ] ;
			[ self setInterface:inputSamplingRateMenu to:@selector(samplingRateChanged) ] ;
			if ( ch > 1 ) {
				//  stereo, don't show channel selection
				[ inputChannel setHidden:YES ] ;
			}
			return self ;
		}
	}
	return nil ;
}

- (void)setPeriodic:(Boolean)state
{
	periodic = state ;
	if ( state == NO && _soundFileTimer ) {
		[ _soundFileTimer invalidate ] ;
		_soundFileTimer = nil ;
	}
}

- (void)setFileRepeat:(Boolean)doRepeat
{
	[ sourcePipe setFileRepeat:doRepeat ] ;
}

- (void)registerInputPad:(NSTextField*)pad
{
	[self setDbPad: pad] ;
}

//	(Private API)
//  this routine is called periodically by NSTimer, simulating the importData from AudioHubChannel
//  everytime this routine is called, it submits the next 512 sound samples to the appropriate AudioPipe
- (void)nextMonoSoundFileFrame:(NSTimer*)timer
{
	ModemSource *p ;
	int offset, stride ;
    
	if ( self.outputClient == nil ) {
		[ timer invalidate ] ;
		NSLog( @"mono output client missing for ModemSource\n" ) ;
		return ;
	}
	p = (ModemSource*)[ timer userInfo ] ;
	p.data->samples = 512 ;
	
	stride = [ sourcePipe soundFileStride ] ;
	//  if file is mono, fetch left (mono) channel even if right channel is requested
	offset = ( p->channel != RIGHTCHANNEL /* LEFTCHANNEL or BOTHCHANNEL */ || stride <= 1 ) ? 0 : 1 ;
    
	//  the following causes the sourcePipe to export data to this object (importData:)
	if ( [ sourcePipe insertNextFileFrameWithOffset:offset ] ) [ timer invalidate ] ;
}

//	(Private API)
//  this routine is called periodically by NSTimer, simulating the importData from AudioHubChannel
//  everytime this routine is called, it submits the next 512 stereo sound samples to the client AudioPipes
- (void)nextStereoSoundFileFrame:(NSTimer*)timer
{
	ModemSource *p ;
    
	if ( self.outputClient == nil ) {
		[ timer invalidate ] ;
		return ;
	}
	p = (ModemSource*)[ timer userInfo ] ;
	p.data->samples = 512 ;
	
	if ( [ sourcePipe insertNextStereoFileFrame ] ) [ timer invalidate ] ;
}

//  hasNewData for 11025 samples/second.  Assume number of samples are BUFLEN (512) in size
//  Also change the LRLRLR stream to a LLLLL...RRRRRR stream for stereo channel.
- (void)hasNew11025Data:(float*)inbuf
{
	int i ;
	
	//  check if device return only a single channel
	if ( self.channels == 1 ) {
		//  v0.93 mono channel from ResamplingPipe is copied into split stereo channels
		for ( i = 0; i < 512; i++ ) {
			self.clientBuffer[i] = self.clientBuffer[i+512] = inbuf[i] ;
		}
	}
	else {
		//  the base channel is the even channel of a stereo pair of channels
		//  for a stereo device, baseChannel is 0.
		inbuf += baseChannel ;
		//  copy the two channels of data
		for ( i = 0; i < 512; i++ ) {
			self.clientBuffer[i] = inbuf[0] ;
			self.clientBuffer[i+512] = inbuf[1] ;
			inbuf += self.channels ;
		}
	}
	//  update our (CMTappedPipe) data source info
	self.data->samplingRate = 11025.0 ;
	self.data->array = &(self.clientBuffer[channel*512]) ;
	self.data->samples = 512 ;
	self.data->components = 1 ;
	self.data->channels = 1 ;
    
	[ sourcePipe importData:self offset:0 ] ;
	if ( tapClient ) [ tapClient importData:self ] ;
}

//  v0.57b reduce autorelease flush from 3000 cycles (1 minute) to 500 cycles
//	this used to feed hasNewData of the AudioInput port.
//  It is blocked waiting for data from the AudioConverter
- (void)readThread
{
    if(hasReadThread) {
        NSLog(@"read thread already started, now exiting readThreadStart");
        return;
    }
    NSLog(@"modem source read thread started for %@", self.deviceName);
    //	NSAutoreleasePool *pool = [ [ NSAutoreleasePool alloc ] init ] ;
    
    
    if(_readQueue == nil) _readQueue = dispatch_queue_create("com.owlhousetoys.read", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(_readQueue,[^(void){
        @autoreleasepool {
            
            hasReadThread = TRUE;
            while ( ![ self.resamplingPipe eof ] ) { // hasReadThread can be set outside this routine to kill it....
                //  NOTE: uses decimation even when input sampling rate 11025 s/s
                //	This gives the system more sound card buffering.
                
                [ self.resamplingPipe readResampledData:[self resampledBuffer] samples:512 ] ;
                
                [ self hasNew11025Data:[self resampledBuffer] ] ;
                
                usleep(10000);
            }
            //  mark so that next time we need a ReadThread, it is recreateds
            NSLog(@"Modem Source resampled read thread exit for %@",self.deviceName);
            hasReadThread = FALSE;
        }
    } copy]);
    
    //   while(hasReadThread){usleep(10000);} // block like the original
    
	//[ pool release ] ;
	//[ NSThread exit ] ;
}

void CheckError  (OSStatus error , const char*  operation) {
	if (error == noErr) return;
	
	char errorString[20] = "                    ";
	// see if it appears to be a 4-char-code
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	} else {
		// no, format it as an integer
		sprintf(errorString, "%d", (int)error);
	}
	fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
	
	//exit(1);
}


//	start input sound card
- (Boolean)startSoundCard
{
	UInt32 datasize ;
	AudioStreamBasicDescription asbd, psbd ;
    OSStatus status;
	
	datasize = sizeof( AudioStreamBasicDescription ) ;
	asbd.mChannelsPerFrame = 2 ;
    
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyStreamFormat,kAudioObjectPropertyScopeGlobal,0};
    
    status = AudioObjectGetPropertyData(self.selectedSoundCard.streamID, &theAddress, 0, NULL, &datasize, &asbd);
    //AudioStreamGetProperty( selectedSoundCard->streamID, 0, kAudioDevicePropertyStreamFormat, &datasize, &asbd ) ;
    CheckError(status, "kAudioStreamPropertyPhysicalFormat error for asbd in startSoundCard");
	[ self.resamplingPipe setNumberOfChannels:asbd.mChannelsPerFrame ] ;
	
	
	datasize = sizeof( AudioStreamBasicDescription ) ;
	psbd.mChannelsPerFrame = 2 ;
    status = AudioObjectGetPropertyData(self.selectedSoundCard.streamID, &theAddress, 0, NULL, &datasize, &psbd);
    // AudioStreamGetProperty( selectedSoundCard->streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, &psbd ) ;
    CheckError(status, "kAudioStreamPropertyPhysicalFormat error for psbd in startSoundCard");
    
	//  0.93d  don't change channels/bits, but just report it
	[ self.paramString setStringValue:[ NSString stringWithFormat:@"%d ch/%d", (int)asbd.mChannelsPerFrame, (int)psbd.mBitsPerChannel ] ] ;
    
	if ( self.selectedSoundCard == nil ) return NO ;			//  sanity check
	if ( self.isSampling == YES ) return YES ;				//  already running
	
	if ( self.audioManager == nil ) {
		//_audioManager = [ [ NSApp delegate ] audioManager ] ;
		return NO ;
	}
	[ self.startStopLock lock ] ;							//  wait for any previous start/stop to complete
	if ( hasReadThread == NO ) {
		//  create read thread only when needed
		//[ NSThread detachNewThreadSelector:@selector(readThread:) toTarget:self withObject:self ] ;
        [self readThread];
		hasReadThread = YES ;
	}
	self.isSampling = ( [ self.audioManager audioDeviceStart:self.selectedSoundCard.deviceID modemAudio:self ] == 0 ) ;
	
	[ self.startStopLock unlock ] ;
	return self.isSampling ;
}

//	start input sound card
- (Boolean)stopSoundCard
{
	if ( self.selectedSoundCard == nil ) return NO ;			//  sanity check
	if ( self.isSampling == NO ) return YES ;
    
	if ( self.audioManager == nil ) {
		return NO ;
	}
	[ self.startStopLock lock ] ;
	self.isSampling = ( [ self.audioManager audioDeviceStop:self.selectedSoundCard.deviceID modemAudio:self ] != 0 ) ;
    
	[ self.startStopLock unlock ] ;
	return ( self.isSampling == NO ) ;
}

- (void)actualSamplingRateSetTo:(float)rate
{
	//  Switch the resampling pipe to convert data into.
	//	Output (to modem) if ResamplingPipe stays at 11025 s/s.
	[ self.resamplingPipe setInputSamplingRate:rate ] ;
}

//	(Private API)
- (void)turnSamplingOn:(Boolean)state
{
	if ( self.selectedSoundCard == nil ) return ;
	
	if ( state == YES ) {
		if ( self.isSampling == NO ) {
			//  first set sampling rate and source, in case we came here from a different modem interface
			[ self samplingRateChanged ] ;
			[ self sourceMenuChanged ] ;
			[ self startSoundCard ] ;
		}
	}
	else {
		if ( self.isSampling == YES ) [ self stopSoundCard ] ;
	}
}

#define	doNothing	0
#define	turnedOn	1
#define	turnedOff	2

- (void)changeDeviceStateTo:(int)newState
{
	int action = doNothing ;
    
	switch ( deviceState ) {
        case DISABLED:
            if ( newState == ENABLED ) {
                deviceState = ENABLED ;
                if ( [ sourcePipe soundFileActive ] == NO && started == YES ) {
                    [ self turnSamplingOn:YES ] ;
                    action = turnedOn ;
                }
            }
            break ;
        case ENABLED:
            if ( newState == ENABLED ) {
                //  normal start/stop sampling (while device is enabled)
                if ( [ sourcePipe soundFileActive ] == NO && started == YES ) {
                    [ self turnSamplingOn:YES ] ;
                    action = turnedOn ;
                }
                if ( started == NO ) {
                    [ self turnSamplingOn:NO ] ;
                    action = turnedOff ;
                }
            }
            else {
                deviceState = newState ;
            }
            break ;
        case RUNNING:
            if ( [ sourcePipe soundFileActive ] == YES ) {
                [ self turnSamplingOn:NO ] ;
                action = turnedOff ;
                break ;
            }
            if ( newState == DISABLED ) {
                [ self turnSamplingOn:NO ] ;
                action = turnedOff ;
                deviceState = DISABLED ;
                break ;
            }
            if ( started == NO ) {
                [ self turnSamplingOn:NO ] ;
                action = turnedOff ;
                deviceState = ENABLED ;
                break ;
            }
            break ;
	}
	if ( deviceState == ENABLED && started == YES  && [ sourcePipe soundFileActive ] == NO ) {
		if ( action != turnedOn ) [ self turnSamplingOn:YES ] ;
		return ;
	}
	//  added v0.21
	if ( deviceState == DISABLED && [ sourcePipe soundFileActive ] == NO ) {
		if ( action != turnedOff ) [ self turnSamplingOn:NO ] ;
		return ;
	}
	if ( deviceState == RUNNING && [ sourcePipe soundFileActive ] == YES ) {
		if ( action != turnedOff ) [ self turnSamplingOn:NO ] ;
		return ;
	}
}

- (void)fileSpeedChanged:(int)newSpeed
{
	playbackSpeed = newSpeed ;
}

- (void)registerDeviceSlider:(NSSlider*)slider
{
	[self setDbSlider:slider ];
}

//	Note: source level is in db
- (void)setDeviceLevel:(NSSlider*)slider
{
	[self setDbSlider:slider ];
	[ self setDeviceLevelFromSlider ] ;
}

- (void)setPadLevel:(NSTextField*)pad
{
	[self setDbPad:pad];
	[ self setDeviceLevelFromSlider ] ;
}

//	(Private API)
- (void)startSoundFile:(NSString*)filename
{
	float t ;
	
	if ( [ sourcePipe soundFileActive ] ) {
		[ self soundFileStarting:filename ] ;
		self.data->array = nil ;
		self.data->samplingRate = [ sourcePipe samplingRate ] ;
		self.data->components = [ sourcePipe soundFileStride ] ;
		self.data->channels = 2 ;
		//  assume 512 samples at ( 11025 samples per second * playbackSpeed )
		t = 512.0/( self.data->samplingRate*playbackSpeed ) ;
        
		switch ( channel ) {
            default:
            case LEFTCHANNEL:
            case RIGHTCHANNEL:
                _soundFileTimer = [ NSTimer scheduledTimerWithTimeInterval:t target:self selector:@selector(nextMonoSoundFileFrame:) userInfo:self repeats:periodic ] ;
                break ;
            case 2:
                _soundFileTimer = [ NSTimer scheduledTimerWithTimeInterval:t target:self selector:@selector(nextStereoSoundFileFrame:) userInfo:self repeats:periodic ] ;
                break ;
		}
		if ( !periodic ) _soundFileTimer = nil ;
	}
}

//  get the next sound file frame in 1 ms
- (void)nextSoundFrame
{
	if ( !periodic && [ sourcePipe soundFileActive ] == YES ) {
		switch ( channel ) {
            default:
            case LEFTCHANNEL:
            case RIGHTCHANNEL:
                [ NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(nextMonoSoundFileFrame:) userInfo:self repeats:periodic ] ;
                break ;
            case 2:
                [ NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(nextStereoSoundFileFrame:) userInfo:self repeats:periodic ] ;
                break ;
		}
	}
}

//  pass pipe to destinations
- (void)importData:(CMPipe*)inPipe
{
	[ sourcePipe importData:inPipe offset:channel&0x1 ] ;		// v0.50 multichannel -- map channel to 0 or 1
	if ( tapClient ) [ tapClient importData:inPipe ] ;
}

/* local */
- (void)stopSoundFile
{
	if ( _soundFileTimer ) {
		[ _soundFileTimer invalidate ] ;
		_soundFileTimer = nil ;
	}
	[ sourcePipe stopSoundFile ] ;
	[ self changeDeviceStateTo:deviceState ] ;  // update state
	[ self soundFileStopped ] ;
}

- (void)startSampling
{
	started = YES ;
	[ self changeDeviceStateTo:deviceState ] ;  // update state
}

- (void)enableInput:(Boolean)enable
{
	int newState ;
	
	newState = deviceState ;
	
	if ( enable ) {
		if ( deviceState == DISABLED ) newState = ENABLED ;
	}
	else {
		newState = DISABLED ;
	}
	[ self changeDeviceStateTo:newState ] ;
}

- (void)stopSampling
{
	started = NO ;
	[ self changeDeviceStateTo:deviceState ] ;  // update state
}

//  new audio input device selected
- (void)inputMenuChanged
{
	Boolean wasSampling = NO ;
	
	//  if the device is running. Turn sampling off first
	if ( self.isSampling ) {
		wasSampling = YES ;
		[ self stopSampling ] ;
	}
	[ self changeDeviceStateTo:DISABLED ] ;
	[ super soundCardChanged ] ;
	[ self changeDeviceStateTo:ENABLED ] ;
    
	//  resume sampling if we switch while sampling.
	if ( wasSampling ) [ self startSampling ] ;
}

- (IBAction)openFile:(id)sender
{
	NSArray *fileTypes ;
	NSString *path ;
	
	if ( _soundFileTimer ) {
		[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
		return ;
	}
	[ self stopSampling ] ;
	//fileTypes = [ NSArray arrayWithObjects:@"aif", @"aiff", @"wav", nil ] ; // as of 10.8 WAV file playback cannot be done this way we would have to restructure the playback to get it to work...
	fileTypes = [ NSArray arrayWithObjects:@"aif", @"aiff", nil ] ;
	path = [ sourcePipe openSoundFileWithTypes:fileTypes ] ;
	if ( path ) {
		//  if soundFile.active, starts the timer fired sound file data, if not, the A/D converter is restarted
		if ( [ sourcePipe soundFileActive ] ) {
			[ self startSoundFile:path ] ;
		}
	}
	[ self startSampling ] ;
}

- (Boolean)fileRunning
{
	return [ sourcePipe soundFileActive ] ;
}

- (IBAction)stopFile:(id)sender
{
	[ self stopSoundFile ] ;
	if ( !_soundFileTimer ) {
		[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
		return ;
	}
	[ self changeDeviceStateTo:deviceState ] ;
}

- (void)setupDefaultPreferences:(Preferences*)pref
{
	[ pref setString:@"*" forKey:[ self.deviceName stringByAppendingString:kInputName ] ] ;
	[ pref setString:@"*" forKey:[ self.deviceName stringByAppendingString:kInputSource ] ] ;
	[ pref setString:@"11025" forKey:[ self.deviceName stringByAppendingString:kInputSamplingRate ] ] ;
	[ pref setInt:channel forKey:[ self.deviceName stringByAppendingString:kInputChannel ] ] ;
	[ pref setFloat:0.0 forKey:[ self.deviceName stringByAppendingString:kInputPad ] ] ;
	[ pref setFloat:0.0 forKey:[ self.deviceName stringByAppendingString:kInputSlider ] ] ;
}

//  set up this ModemSource from settings in the Plist
- (Boolean)updateFromPlist:(Preferences*)pref
{
	Boolean ok ;
	NSString *name ;
	int sourceIndex, selectedDeviceIndex ;
	float pad, slider ;
    
	//  make sure there is at least one usable item
	if ( [ inputMenu numberOfItems ] < 1 ) return NO ;
    
	ok = YES ;
	sourceIndex = 0 ;
	//  get input sound card name from Plist
	name = [ pref stringValueForKey:[ self.deviceName stringByAppendingString:kInputName ] ] ;
	
	//  try to select it from the sound card menu
	selectedDeviceIndex = [ self selectSoundCard:name ] ;
	if ( selectedDeviceIndex < 0 ) {
		//  name in Plist no longer found
		ok = NO ;
		channel = 0 ;
		if ( [ inputMenu numberOfItems ] > 0 ) [ inputMenu selectItemAtIndex:0 ] ;
		if ( [ inputSourceMenu numberOfItems ] > 0 ) [ inputSourceMenu selectItemAtIndex:0 ] ;		// v0.52
	}
	else {
		//  sound card choosen, -selectSoundCard should also have set up the source menu
		//  now try to select the input source if there is more than one
		if ( [ inputSourceMenu numberOfItems ] > 1 ) {
			name = [ pref stringValueForKey:[ self.deviceName stringByAppendingString:kInputSource ] ] ;
			sourceIndex = [ self selectSource:name ] ;
			if ( sourceIndex < 0 ) {
				ok = NO ;
				[ inputSourceMenu selectItemAtIndex:0 ] ;
			}
		}
		//  select channel
		channel = [ pref intValueForKey:[ self.deviceName stringByAppendingString:kInputChannel ] ] ;
		[ self selectChannel:channel ] ;
	}
	
	// v0.52 sanity check channel
	int menuItems =  (int)[ inputChannel numberOfItems ] ;
	if ( channel >= 0 && channel < menuItems ) // 0.52
		[ inputChannel selectItemAtIndex:channel ] ;		// v0.50 allow multi-channel
    
	//  setup input pad
	pad = [ pref floatValueForKey:[ self.deviceName stringByAppendingString:kInputPad ] ] ;
	if ( self.dbPad ) {
		[ self.dbPad setStringValue:[ NSString stringWithFormat:@"%d", (int)pad ] ] ;
		[ Messages logMessage:"Updating input pad to %d from plist", (int)pad ] ;
	}
	
	NSString *key = [ self.deviceName stringByAppendingString:kInputSlider ] ;
	slider = [ pref floatValueForKey:key ] ;
	
	if ( self.dbSlider != nil ) {
		[ self.dbSlider setFloatValue:slider ] ;
		[ Messages logMessage:"Updating input attenuator to %.1f from plist", slider ] ;
	}
	[ self setDeviceLevelFromSlider ] ;
    
	if ( self.selectedSoundCard != nil ) {
		if ( self.audioManager == nil || [ self.audioManager audioDeviceForID:self.selectedSoundCard.deviceID ] == nil ) {
			// 0.53a sampling rate option
			NSString *rateString = [ pref stringValueForKey:[ self.deviceName stringByAppendingString:kInputSamplingRate ] ] ;
			[ Messages logMessage:"Updating input sampling rate %s from plist", [ rateString cStringUsingEncoding:NSASCIIStringEncoding ] ] ;		//  v0.62
			if ( rateString ) [ inputSamplingRateMenu selectItemWithTitle:rateString ] ;
			[ self samplingRateChanged ] ;			//  v0.62
		}
		[ self fetchSamplingRateFromCoreAudio ] ;	//  v0.78 this forces the AudioConverter rates to be set and also when device is already registered
	}
	return ok ;
}

- (void)retrieveForPlist:(Preferences*)pref
{
	NSString *selectedTitle ;
	
	[ pref setString:[ inputMenu titleOfSelectedItem ] forKey:[ self.deviceName stringByAppendingString:kInputName ] ] ;
	[ pref setString:[ inputSourceMenu titleOfSelectedItem ] forKey:[ self.deviceName stringByAppendingString:kInputSource ] ] ;
	[ pref setInt:channel forKey:[ self.deviceName stringByAppendingString:kInputChannel ] ] ;
	
	selectedTitle = [ inputSamplingRateMenu titleOfSelectedItem ] ;
	if ( selectedTitle ) [ pref setString:selectedTitle forKey:[ self.deviceName stringByAppendingString:kInputSamplingRate ] ] ;
	
	//  retrieve pad value from device (AudioInputPort, AudioSoundChannel)
	if ( self.dbPad ) [ pref setFloat:[ self.dbPad floatValue ] forKey:[ self.deviceName stringByAppendingString:kInputPad ] ] ;
	if ( self.dbSlider ) [ pref setFloat:[ self.dbSlider floatValue ] forKey:[ self.deviceName stringByAppendingString:kInputSlider ] ] ;
}

- (id)delegate
{
	return delegate ;
}

- (void)setDelegate:(id)inDelegate
{
	delegate = inDelegate ;
}

// delegate method
- (void)soundFileStarting:(NSString*)filename
{
	if ( delegate && [ delegate respondsToSelector:@selector(soundFileStarting:) ] ) [ delegate soundFileStarting:filename ] ;
}

//  delegate method
- (void)soundFileStopped
{
	if ( delegate && [ delegate respondsToSelector:@selector(soundFileStopped) ] ) [ delegate soundFileStopped ] ;
}

- (void)dealloc
{
    //	[ deviceName release ] ;
    //	[ sourcePipe release ] ;
    //	[ super dealloc ] ;
}

@end
