//
//  ModemDest.m
//  cocoaModem
//
//  Created by Kok Chen on Sun Aug 01 2004.
	#include "Copyright.h"
//

#import "ModemDest.h"
#import "Application.h"
#import "AudioManager.h"
#import "Config.h"
#import "DestClient.h"
#import "Modem.h"
#import "ModemConfig.h"
#import "ModemManager.h"
#import "Messages.h"
#import "Plist.h"
#import "PTT.h"
#import "PTTHub.h"
#import "TextEncoding.h"
#include <math.h>
#import "ResamplingPipe.h"
#import "AuralMonitor.h"


@implementation ModemDest

@synthesize outputLevelKey = _outputLevelKey;
@synthesize mostRecentlyUsedDevice = _mostRecentlyUsedDevice;
@synthesize attenuatorKey = _attenuatorKey;

//  As a AudioPipe destination, this object is accessed through the the importData: method


- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

//  Init Modem sound destination and sets the interface controls into the given view
//  The client must provide a target with methods 
//
//  - (int)needData:(float*)outbuf samples:(int)n			//  returns 2 if stereo output, 1 for mono output
//  - (void)enableDestinationStream:(Boolean)enable
//  - (void)setOutputScale:(float)value ;

- (id)initIntoView:(NSView*)view device:(NSString*)name level:(NSView*)level client:(DestClient*)inClient pttHub:(PTTHub*)hub
{
	self = [ super init ] ;
	if ( self ) {
		initRate = initCh = initBits = 0 ;
		deviceState = DISABLED ;
		self.isInput = NO ;
		_mostRecentlyUsedDevice = @"" ;
		rateChangeBusy = NO ;
		client = inClient ;
		_outputLevelKey = nil ;
			
		resamplingPipeChannels = 1 ;
		self.resamplingPipe = [ [ ResamplingPipe alloc ] initUnbufferedPipeWithSamplingRate:11025.0 channels:resamplingPipeChannels target:self ] ;
		[ self.resamplingPipe setInputSamplingRate:11025.0 ] ;
		[ self.resamplingPipe setOutputSamplingRate:11025.0 ] ;

		[self setDeviceName: [ [ NSString alloc ] initWithString:name ] ];
		if ( [ [NSBundle mainBundle] loadNibNamed:( hub != nil ) ? @"ModemDest" : @"SimpleModemDest" owner:self topLevelObjects:nil] ) {
			// loadNib should have set up controlView connectionw
			if ( controlView && view ) {
			
				//  set up connections for super class
				[self setSoundCardMenu: outputMenu ];
				[self setSourceMenu: outputDestMenu ];
				[self setSamplingRateMenu:outputSamplingRateMenu] ;
				[self setChannelMenu:outputChannel] ;
				[self setParamString:outputParam ];

				[ view addSubview:controlView ] ;
				if ( level && levelView ) [ level addSubview:levelView ] ;
				// PTT menu
				ptt = ( hub ) ? [ [ PTT alloc ] initWithHub:hub menu:pttMenu ] : nil ;
				//  actions
				[ self setInterface:outputMenu to:@selector(outputMenuChanged) ] ;
				[ self setInterface:outputLevel to:@selector(outputLevelChanged) ] ;
				[ self setInterface:outputAttenuator to:@selector(updateAttenuator) ] ;
				[ self setInterface:outputDestMenu to:@selector(sourceMenuChanged) ] ;
				[ self setInterface:outputChannel to:@selector(channelChanged) ] ;
				[ self setInterface:outputSamplingRateMenu to:@selector(samplingRateChanged) ] ;
				
				return self ;
			}
		}
	}
	return nil ;
}

- (id)initIntoView:(NSView*)view device:(NSString*)name level:(NSView*)level client:(DestClient*)inClient channels:(int)ch
{
	self = [ super init ] ;
	if ( self ) {
		initRate = initCh = initBits = 0 ;
		deviceState = DISABLED ;
		self.isInput = outputMuted = NO ;
		_mostRecentlyUsedDevice = @"" ;
		rateChangeBusy = NO ;
		client = inClient ;
		_outputLevelKey = nil ;
			
		resamplingPipeChannels = ch ;
		self.resamplingPipe = [ [ ResamplingPipe alloc ] initUnbufferedPipeWithSamplingRate:11025.0 channels:resamplingPipeChannels target:self ] ;
		[ self.resamplingPipe setInputSamplingRate:11025.0 ] ;
		[ self.resamplingPipe setOutputSamplingRate:11025.0 ] ;

		[self setDeviceName: [ [ NSString alloc ] initWithString:name ]] ;
		
		if ( [ [NSBundle mainBundle] loadNibNamed:@"SimpleModemDest" owner:self topLevelObjects:nil] ) {
			// loadNib should have set up controlView connectionw
			if ( controlView && view ) {
			
				//  set up connections for super class
				[self setSoundCardMenu: outputMenu ];
				[self setSourceMenu: outputDestMenu ];
				[self setSamplingRateMenu:outputSamplingRateMenu] ;
				[self setChannelMenu:outputChannel] ;
				[self setParamString:outputParam ];
                
				[ view addSubview:controlView ] ;
				if ( level && levelView ) [ level addSubview:levelView ] ;
				// PTT menu
				ptt = nil ;
				//  actions
				[ self setInterface:outputMenu to:@selector(outputMenuChanged) ] ;
				[ self setInterface:outputLevel to:@selector(outputLevelChanged) ] ;
				[ self setInterface:outputAttenuator to:@selector(updateAttenuator) ] ;
				[ self setInterface:outputDestMenu to:@selector(sourceMenuChanged) ] ;
				[ self setInterface:outputChannel to:@selector(channelChanged) ] ;
				[ self setInterface:outputSamplingRateMenu to:@selector(samplingRateChanged) ] ;
				
				return self ;
			}
		}
	}
	return nil ;
}

- (void)setMute:(Boolean)state
{
	outputMuted = state ;
}

- (PTT*)ptt
{
	return ptt ;
}

//	start input sound card
- (Boolean)startSoundCard
{
	if ( super.selectedSoundCard == nil ) return NO ;			//  sanity check
	if ( self.isSampling == YES ) return YES ;				//  already running
	
	if ( self.audioManager == nil ) {
		self.audioManager = [ [ NSApp delegate ] audioManager ] ;
		if (self.audioManager == nil ) return NO ;
        //return NO;
	}
	[ self.startStopLock lock ] ;							//  wait for any previous start/stop to complete
	[ self.resamplingPipe makeNewRateConverter ] ;
	self.isSampling = ( [ self.audioManager audioDeviceStart:super.selectedSoundCard.deviceID modemAudio:self ] == 0 ) ;
	[ self.startStopLock unlock ] ;
	
	return ( self.isSampling == YES ) ;
}

//	start input sound card
- (Boolean)stopSoundCard
{
	if ( super.selectedSoundCard == nil ) return NO ;			//  sanity check
	if ( self.isSampling == NO ) return YES ;

	if ( self.audioManager == nil ) {
        return NO ;
	}
	[ self.startStopLock lock ] ;
	self.isSampling = ( [ self.audioManager audioDeviceStop:super.selectedSoundCard.deviceID modemAudio:self ] != 0 ) ;
	[ self.startStopLock unlock ] ;
	
	return ( self.isSampling == NO ) ;
}

- (void)actualSamplingRateSetTo:(float)rate
{
	//  Switch the resampling pipe.
	//	Input (from modem) of the ResamplingPipe stays at 11025 s/s.
	[ self.resamplingPipe setOutputSamplingRate:rate ] ;
}

//	(Private API)
- (void)turnSamplingOn:(Boolean)state
{
	if ( state == YES ) {
		if ( self.isSampling == NO ) {
			//  first set sampling rate and source, in case we came here from a different modem interface
			[ self samplingRateChanged ] ;			
			[ self sourceMenuChanged ] ;
			[ self startSoundCard ] ;
		}
	}
	else {
		if ( self.isSampling == YES ) [ self stopSoundCard ] ;		//  stop sound card only if it is running
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
			if ( started ) {
				[ self turnSamplingOn:YES ] ;
				action = turnedOn ;
			}
		}
		break ;
	case ENABLED:
		if ( newState == ENABLED ) {
			if ( started == YES ) {
				[ self turnSamplingOn:YES ] ;
				action = turnedOn ;
			}
			else {
				[ self turnSamplingOn:NO ] ;
				action = turnedOff ;
			}
		}
		else {
			deviceState = newState ;
		}
		break ;
	case RUNNING:
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
	if ( deviceState == ENABLED && started == YES ) {
		if ( action != turnedOn ) [ self turnSamplingOn:YES ] ;
		return ;
	}
}

- (void)startSampling
{
	started = YES ;
	[ self changeDeviceStateTo:deviceState ] ;  // update state
}

- (void)enableOutput:(Boolean)enable
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

//  set output sound level key for preference
- (void)setSoundLevelKey:(NSString*)key attenuatorKey:(NSString*)attenuator
{
	//if ( outputLevelKey ) [ outputLevelKey release ] ;
	_outputLevelKey = [ [ NSString alloc ] initWithString:key ] ;

	//if ( attenuatorKey ) [ attenuatorKey release ] ;
	_attenuatorKey = [ [ NSString alloc ] initWithString:attenuator ] ;
}

- (void)updateAttenuator
{
	float value, dB ;
	
	dB = [ outputAttenuator floatValue ] ;
	//value = 0.707*pow( 10.0, dB/20.0 ) ;			// -3.0 dB FS peak
	//value = 0.8414*pow( 10.0, dB/20.0 ) ;			// -1.5 dB FS peak
	value = 0.8913*pow( 10.0, dB/20.0 ) ;			// v0.88 -1.5 dB FS peak instead of -3 dB (note: RTTY filter needs 6% headroom)
	[ client setOutputScale:value ] ;
}


//  v0.76 -- toggle device's sampling state if the output device changes while being active
- (void)changeToNewOutputDevice:(int)index destination:(int)dest refreshSamplingRateMenu:(Boolean)refreshSamplingRateMenu
{
	Boolean wasRunning = self.isSampling ;
	NSString *newDeviceName = [ [ outputMenu selectedItem ] title ] ;

	if ( wasRunning == YES ) {
		//  stop sampling before switching devices
		[ self stopSampling ] ;
	}	
	if ( [ _mostRecentlyUsedDevice isEqualToString:newDeviceName ] == NO ) {
		//[ mostRecentlyUsedDevice release ] ;
		_mostRecentlyUsedDevice = newDeviceName ;
	}
	if ( wasRunning == YES ) {
		//  resume sampling
		[ self startSampling ] ;
	}
}

//  new audio output device selected
- (void)outputMenuChanged
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

//  output level control changed
//	Note: slider is a scalar value between 0.1 and 1.0 (min = 0 in Core Audio and max = 1)
- (void)outputLevelChanged
{
	[self setScalarSlider: outputLevel] ;
	[ self setDeviceLevelFromSlider ] ;
}

//	used by AMConfig and CWMonitor
- (NSSlider*)outputLevel 
{
	return outputLevel ;
}

- (void)setupDefaultPreferences:(Preferences*)pref
{
	float level, attenuator ;
	
	[ pref setString:@"*" forKey:[ self.deviceName stringByAppendingString:kOutputName ] ] ;
	[ pref setString:@"*" forKey:[ self.deviceName stringByAppendingString:kOutputSource ] ] ;
	[ pref setString:@"11025" forKey:[ self.deviceName stringByAppendingString:kOutputSamplingRate ] ] ;
	[ pref setString:@"VOX" forKey:[ self.deviceName stringByAppendingString:kPTTMenu ] ] ;
	[ pref setInt:0 forKey:[ self.deviceName stringByAppendingString:kOutputChannel ] ] ;
	level = 0.0 ;
	if ( outputLevel ) level = [ outputLevel floatValue ] ;
	if ( _outputLevelKey ) [ pref setFloat:level forKey:_outputLevelKey ] ;

	attenuator = 0.0 ;
	if ( outputAttenuator ) attenuator = [ outputAttenuator floatValue ] ;
	if ( _attenuatorKey ) [ pref setFloat:attenuator forKey:_attenuatorKey ] ;
}

- (Boolean)updateFromPlist:(Preferences*)pref updateAudioLevel:(Boolean)updateLevel
{
	Boolean ok ;
	NSString *name, *menuName, *key ;
	float level ;
	int i, destItems, selectedDeviceIndex, sourceIndex ;
	//  make sure there is at least one usable item
	if ( [ outputMenu numberOfItems ] < 1 ) return NO ;
	
	ok = YES ;
	sourceIndex = 0 ;
	//  choose output device from Plist and set up other menus
	name = [ pref stringValueForKey:[ self.deviceName stringByAppendingString:kOutputName ] ] ;
	
	//  try to select it from the sound card menu
	selectedDeviceIndex = [ self selectSoundCard:name ] ;
	if ( selectedDeviceIndex < 0 ) {
		//  name in Plist no longer found
		ok = NO ;
		channel = 0 ;
		if ( [ outputMenu numberOfItems ] > 0 ) [ outputMenu selectItemAtIndex:0 ] ;
		if ( [ outputDestMenu numberOfItems ] > 0 ) [ outputDestMenu selectItemAtIndex:0 ] ;
	}
	else {		
		//  sound card choosen, -selectSoundCard should also have set up the source menu
		//  now try to select the input source if there is more than one
		if ( [ outputDestMenu numberOfItems ] > 1 ) {
			name = [ pref stringValueForKey:[ self.deviceName stringByAppendingString:kOutputSource ] ] ;
			sourceIndex = [ self selectSource:name ] ;
			if ( sourceIndex < 0 ) {
				ok = NO ;
				//  could not find source?  Find alternate mappings
				// "Internal speakers" and "Headphones" are interchangable for built-in audio
				destItems = (int)[ outputDestMenu numberOfItems ] ;
				for ( i = 0; i < destItems; i++ ) {
					menuName = [ [ outputDestMenu itemAtIndex:i ] title ] ;
					if ( [ name isEqualToString:@"Internal speakers" ] && [ menuName isEqualToString:@"Headphones" ] ) break ;
					if ( [ name isEqualToString:@"Headphones" ] && [ menuName isEqualToString:@"Internal speakers" ] ) break ;
				}
				if ( i < destItems ) ok = YES ; else i = 0 ;
				[ outputDestMenu selectItemAtIndex:i ] ;
			}
		}
		//  select channel
		channel = [ pref intValueForKey:[ self.deviceName stringByAppendingString:kOutputChannel ] ] ;
		[ self selectChannel:channel ] ;
	}

	if ( updateLevel == YES ) {
		if ( outputLevel && _outputLevelKey ) {
			level = [ pref floatValueForKey:_outputLevelKey ] ;
			[ outputLevel setFloatValue:level ] ;
			[ self outputLevelChanged ] ;
			[ Messages logMessage:"%s set to %.3f", [ _outputLevelKey cStringUsingEncoding:NSASCIIStringEncoding], level ] ;
		}
	}
	else {
		[ self fetchDeviceLevelFromCoreAudio ] ;
	}
	if ( outputAttenuator && _attenuatorKey ) {
		level = [ pref floatValueForKey:_attenuatorKey ] ;
		[ outputAttenuator setFloatValue:level ] ;
		[ Messages logMessage:"%s set to %.0f dB", [ _attenuatorKey cStringUsingEncoding:NSASCIIStringEncoding], level ] ;
		[ self updateAttenuator ] ;
	}
	if ( ptt ) {
		NSString *key = [ self.deviceName stringByAppendingString:kPTTMenu ] ;
		[ ptt selectItem:[ pref stringValueForKey:key ] ] ;
	}
	if ( super.selectedSoundCard != nil ) {
		// 0.53a sampling rate option
		if ( self.audioManager == nil || [ self.audioManager audioDeviceForID:super.selectedSoundCard.deviceID ] == nil ) {
			key = [ self.deviceName stringByAppendingString:kOutputSamplingRate ] ;
			name = [ pref stringValueForKey:key ] ;
			if ( name ) {
				[ outputSamplingRateMenu selectItemWithTitle:name ] ;
				[ Messages logMessage:"Updating output sampling rate %s from plist", [ name cStringUsingEncoding:NSASCIIStringEncoding  ] ] ;		//  v0.62
				[ self samplingRateChanged ] ;				//  v0.53b get the rate into the modem
			}
		}
		[ self fetchSamplingRateFromCoreAudio ] ;	//  v0.78 this forces the AudioConverter rates to be set and also when device is already registered
	}
	_mostRecentlyUsedDevice = [ outputMenu titleOfSelectedItem ] ;
	return ok ;
}

//  set up this SoundHub from settings in the Plist
- (Boolean)updateFromPlist:(Preferences*)pref
{
	return [ self updateFromPlist:pref updateAudioLevel:YES ] ;
}

//   v0.86
- (void)retrieveForPlist:(Preferences*)pref updateAudioLevel:(Boolean)updateLevel
{
	float level, scalarLevel ;
	NSString *selectedTitle ;
    NSString *devName = [[NSString alloc] initWithString:self.deviceName];
    NSString *kPTT    = [devName stringByAppendingString:kPTTMenu];
    NSString *kOut    = [devName stringByAppendingString:kOutputName];
    NSString *kOutS   = [devName stringByAppendingString:kOutputSource];
    NSString *kOutC   = [devName stringByAppendingString:kOutputChannel];
	
	//  v 0.85 reset audio level just in case it was set to OOK
	//  v 0.86 don;t update aural channel
	if ( updateLevel ) scalarLevel = [ self validateDeviceLevel ] ;
	
	if ( ptt ) [ pref setString:[ ptt selectedItem ] forKey:kPTT] ;
	if(outputMenu)[ pref setString:[ outputMenu titleOfSelectedItem ] forKey:kOut ] ;
	if(outputDestMenu)[ pref setString:[ outputDestMenu titleOfSelectedItem ] forKey:kOutS ] ;
	if(channel)[ pref setInt:channel forKey:kOutC ] ;
	
	selectedTitle = [ outputSamplingRateMenu titleOfSelectedItem ] ;
	if ( selectedTitle ) [ pref setString:selectedTitle forKey:[ self.deviceName stringByAppendingString:kOutputSamplingRate ] ] ;

	if ( outputLevel && _outputLevelKey ) {
		//level = [ outputLevel floatValue ] ;
		[ pref setFloat:scalarLevel forKey:_outputLevelKey ] ;		//  v0.85
	}
	if ( outputAttenuator && _attenuatorKey ) {
		level = [ outputAttenuator floatValue ] ;
		[ pref setFloat:level forKey:_attenuatorKey ] ;
	}
}

- (void)retrieveForPlist:(Preferences*)pref
{
	[ self retrieveForPlist:(Preferences*)pref updateAudioLevel:YES ] ;
}

//  AudioOutputPort callbacks -- ask client for data
//  needData should return 1 for mono buffer. 2 for stereo buffer.
- (int)needData:(float*)outbuf samples:(int)n channels:(int)ch
{
    AuralMonitor *uu = (AuralMonitor*)client;
    int yy =  [ uu needData:outbuf samples:n channels:ch ] ;
	return yy;
}

//  delegate for destination panel
- (BOOL)windowShouldClose:(id)sender
{
	return YES ;
}

@end
