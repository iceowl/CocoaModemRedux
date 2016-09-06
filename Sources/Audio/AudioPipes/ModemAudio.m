//
//  ModemAudio.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 10/19/09.
//  Copyright 2009 Kok Chen, W7AY. All rights reserved.
//

#define kLeftChannel	1
#define kRightChannel	2
#define	ookLevel		0.9

#import "ModemAudio.h"
#import "Application.h"
#import "AudioManager.h"
#import "Messages.h"
#import "TextEncoding.h"
#import "audioutils.h"



@implementation ModemAudio

@synthesize deviceName      = _deviceName;
@synthesize startStopLock   = _startStopLock;
@synthesize dbPad           = _dbPad;
@synthesize dbSlider        = _dbSlider;
@synthesize scalarSlider    = _scalarSlider;
@synthesize soundCardMenu   = _soundCardMenu;
@synthesize sourceMenu      = _sourceMenu;
@synthesize samplingRateMenu = _samplingRateMenu;
@synthesize channelMenu     = _channelMenu;
@synthesize paramString     = _paramString;
@synthesize info            = _info;
@synthesize selectedSoundCard = _selectedSoundCard;
@synthesize audioManager    = _audioManager;
@synthesize isInput         = _isInput;
@synthesize resampledBuffer = _resampledBuffer;
@synthesize clientBuffer    = _clientBuffer;
@synthesize pipeBuffer      = _pipeBuffer;
@synthesize resamplingPipe  = _resamplingPipe;
@synthesize channels        = _channels;
@synthesize isSampling      = _isSampling;


- (id)init
{
	int i ;
	//SoundCardInfo *s ;
	
	self = [ super init ] ;
	if ( self ) {
		
        _audioManager = [[NSApp delegate]audioManager];
		_isInput = YES ;
		_channels = 2 ;											// 1 for mono devices
		channel = 0 ;											// left
		_isSampling = restartSamplingOnWakeup = started = NO ;
		savedIOProc = nil ;
		_selectedSoundCard = nil ;
		previousDeviceID = 0 ;
		previousSamplingRate = 0.0 ;
		_dbSlider = _scalarSlider = nil ;
		nonOOKLevel = 0.95 ;
		_dbPad = nil ;
		currentDB = dBmin = dBmax = 0 ;							//  v0.88d
        
        _info = [[NSMutableArray alloc] initWithCapacity:MAXDEVICES];
		for ( i = 0; i < MAXDEVICES; i++ ) {
			_info[i]  = [[SoundCardInfo alloc] init];
//			info[i].streamID = 0 ;
//			info[i].deviceID = 0 ;
		}
		resamplingPipeChannels = 2 ;		
		_startStopLock = [ [ NSLock alloc ] init ] ;
        
        _resampledBuffer = malloc(2 * BUFLEN * sizeof(float));
        _pipeBuffer = malloc(2 * BUFLEN * sizeof(float));
        _clientBuffer =  malloc(2 * BUFLEN * sizeof(float));
	}
   // NSLog(@"instance of Modem Audio created");
	return self ;
}

-(void) dealloc {
    NSLog(@"Attempting to Dealloc Modem Audio");
    free(_resampledBuffer);
    free(_pipeBuffer);
    free(_clientBuffer);
}

//  v0.85
- (int)channel
{
	return channel ;
}

//- (Boolean)isInput
//{
//	return _isInput ;
//}

//  subclass (ModemSource or ModemDest) should override this  
- (void)deviceHasChanged:(short)code deviceID:(AudioDeviceID)inDeviceID
{
}



// return number of devices found (limited by maxdev)
-(int) discoverSoundCards :( NSMutableArray*) cardInfo : (int) maxdev : (Boolean) isInput

{
    NSString *name, *refname ;
	NSRange searchRange ;
	CFStringRef cfname = NULL ;
	AudioDeviceID list[MAXDEVICES];
    AudioDeviceID device = 0;
    AudioStreamID stream[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} ;
 	char cname[129] ;
	int devices, count, i, j, k, n, streams;
	UInt32 datasize ;
    SoundCardInfo *d, *e ;
	
    for(i = 0; i < MAXDEVICES; i++) {
        list[i] = 0;
    }
    
	count = 0 ;
    memset(cname,0,129);
    devices = enumerateAudioDevices( list, MAXDEVICES ) ;
    
    AudioObjectPropertyScope theScope = isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;

    for ( i = 0; i < devices; i++ ) {
        device = list[i] ;
 		//  check if device responds to a CFName call
		datasize = sizeof(CFStringRef) ;
        AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyDeviceNameCFString,theScope,kAudioObjectPropertyElementMaster};
        CheckError(AudioHardwareServiceGetPropertyData(device, &theAddress, 0, NULL, &datasize, &cfname),"Couldn't get Audio Hardware Service Channel Name in Modem Audio");
		//status = AudioDeviceGetPropertyInfo( device, 0, false, kAudioObjectPropertyName, &datasize, NULL ) ;
		if ( datasize != 0 && cfname != NULL) {
			//datasize = sizeof( CFStringRef ) ;
          // CheckError(AudioObjectGetPropertyData(kAudioObjectSystemObject,&theAddress,0,NULL, &datasize,&cfname), "Couldn't get Audio Object Property Channel in Modem Audio");
			//status = AudioDeviceGetProperty( device, 0, false, kAudioObjectPropertyName, &datasize, &cfname ) ;
			name = [ NSString stringWithString:(__bridge NSString*)cfname] ;
		 	cfname = NULL;
            //if(cfname != nil)CFRelease( cfname ) ;
		}
		else {
			//  use old cStringUsingEncoding:NSASCIIStringEncoding  call (RME FireFace 400), convert to NSString
			datasize = 128 ;
            AudioObjectPropertyAddress theAddress2 = {kAudioDevicePropertyDeviceName,theScope,kAudioObjectPropertyElementMaster};
            CheckError(AudioObjectGetPropertyData(device,&theAddress2,0,NULL, &datasize,cname), "Couldn't get Audio Object Property Device Name in Modem Audio");

			//CheckError(AudioDeviceGetProperty( device, 0, false, kAudioDevicePropertyDeviceName, &datasize, cname ),"Couldn't get Audio Device property in Modem Audio") ;
			name = [ NSString stringWithCString:cname encoding:NSASCIIStringEncoding ] ;
        }

		//  check for number of streams for device
        AudioObjectPropertyAddress theAddress3 = {kAudioDevicePropertyStreams,theScope,kAudioObjectPropertyElementMaster};
        AudioObjectGetPropertyDataSize(device, &theAddress3, 0, NULL, &datasize);
     //    CheckError(AudioObjectGetPropertyData(device,&theAddress3,0,NULL, &datasize,&writable), "Couldn't get Audio Object Property Stream is Writable  in Modem Audio");
        CheckError(AudioObjectGetPropertyData(device,&theAddress3,0,NULL, &datasize,stream), "Couldn't get Audio Object Property Stream stream in Modem Audio");
		//CheckError(AudioDeviceGetPropertyInfo( device, 0, isInput, kAudioDevicePropertyStreams, &datasize, stream),"Couldn't get audio device property info in Modem Audio")
	//	CheckError(AudioDeviceGetProperty( device, 0, isInput, kAudioDevicePropertyStreams, &datasize, stream ),"Couldn't get Audio Device Property in Modem Audio") ;
		streams = datasize/sizeof( AudioStreamID ) ;
        
		if ( streams ) {
			for ( j = 0; j < streams; j++ ) {
				if ( count < maxdev ) {
                    SoundCardInfo *sci = [[SoundCardInfo alloc] init];
                    [sci setStreamIndex:j];
                    [sci setDeviceID:device];
                    [sci setStreamID:stream[j]];
                    NSString *theName = [[NSString alloc] initWithString:name];
                    [sci setName:theName];
					sci.deviceID = device ;
					sci.streamID = stream[j] ;
					sci.name = [ [ NSString alloc ] initWithString:name ] ;
                    [cardInfo removeObjectAtIndex:count];
                    [_info insertObject:sci atIndex:count];
					count++ ;
				}
			}
		}
    }
	//  now modify names for devices with the same name and device with multiple streams
	for ( i = 0; i < count-1; i++ ) {
		d = [_info objectAtIndex:i] ;
		//  modify devices that have the same name 
		for ( j = i+1; j < count; j++ ) {
			e = [_info objectAtIndex:j] ;
			if ( [ d.name isEqualToString:e.name ] ) {
				n = 1 ;
				refname = d.name ;
				//  shorten name if possible
				name = [ NSString stringWithString:d.name ] ;
				searchRange = [ name rangeOfString:@"(" ] ;
				if ( searchRange.location != NSNotFound ) {
					name = [ [ name substringToIndex:searchRange.location ] stringByTrimmingCharactersInSet:[ NSCharacterSet whitespaceCharacterSet ] ] ;
				}
				//  change duplicate names to "name (1)", "name (2)" etc.
				for ( k = i; k < count; k++ ) {
					e = [_info objectAtIndex:k] ;
					if ( [ refname isEqualToString:e.name ] ) {
						//[ e->name autorelease ] ;
						e.name = [ name stringByAppendingFormat:@" (%d)", n++ ] ;
					}
				}
				break ;
			}
		}
	}
    return count ;
}

//  (Private API)
//  set menu with names in deviceList
- (void)setMenuTo:(NSMutableArray*)deviceList menu:(NSPopUpButton*)menu
{
	NSMenuItem *item ;
	int i, j, n ;
	
	[ menu removeAllItems ] ;
	if ( soundcards == 0 ) {
		[ menu addItemWithTitle:@"" ] ;
		[ menu setEnabled:false ] ;
		return ;
	}
	[ menu setEnabled:true ] ;
	j = 0 ;
	for ( i = 0; i < soundcards; i++ ) {
		[ menu addItemWithTitle:((SoundCardInfo*)[deviceList objectAtIndex:i]).name ] ;
		n = (int)[ menu numberOfItems ] ;
		if ( n > j ) {
			//  ignore repeated names (NSPopUpButton cannot handle it)
			item = (NSMenuItem*)[ menu itemAtIndex:j ] ;
			[ item setTag:i ] ;			// set tag to menu index
			j++ ;
		}
	}
}

//  return index of source menu if successful, -1 if not successful 
- (int)sourceMenuChanged
{
	UInt32 dataSource, datasize ;
	OSStatus status ;
	NSMenuItem *item ;
	int index ;
	
	index = (int)[ _sourceMenu indexOfSelectedItem ] ;
	if ( index < 0 || _selectedSoundCard == nil ) return -1 ;
	
	//  don't set source if there is only one (tag would not exist)
	if ( [ _sourceMenu numberOfItems ] <= 1 ) return 0 ;
	
	//  NOTE: datasource was saved in the source menu by -updateSourceMenu 
	item = (NSMenuItem*)[ _sourceMenu itemAtIndex:index ] ;
	dataSource = (unsigned int)[ item tag ] ;
	datasize = sizeof( UInt32 ) ;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyDataSource,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMaster};
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&dataSource);
    CheckError(status, "Property Data Source error sourceMenuChanged");
	//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, 0, isInput, kAudioDevicePropertyDataSource, datasize, &dataSource );
	if ( status != 0 ) {
		NSLog( @"cannot set sound card source/destination? %d", (int)dataSource ) ;
		return -1 ;
	}
	return index ;
}

//	switch source to the one with the name passed in
//  return index of source menu if successful, -1 if not successful
- (int)selectSource:(NSString*)name
{
	[ _sourceMenu selectItemWithTitle:name ] ;
	return [ self sourceMenuChanged ] ;				//  try switching Core Audio to it
}

//	update source menu from CoreAudio
//	select the default source
- (int)updateSourceMenu
{
	int i, index, sources ;
	OSStatus status ;
	UInt32 datasize, defaultIndex, dataSource[16], defaultSourceID ;
	NSMenuItem *item ;
	AudioDeviceID devID ;
	AudioValueTranslation transl ;
	CFStringRef cfname ;
	
    memset(dataSource, 0, sizeof(UInt32)*16);
	index = (int)[ _soundCardMenu indexOfSelectedItem ] ;
	[ _sourceMenu removeAllItems ] ;
	
	if ( index < 0 ) {
		// no device found
		[ _sourceMenu addItemWithTitle:@"Default" ] ;
		[ _sourceMenu setEnabled:NO ] ;
		return 0 ;
	}
	[ _sourceMenu setEnabled:YES ] ;
	devID = ((SoundCardInfo*)[_info objectAtIndex:index]).deviceID ;

	// get sources (up to 16)
	datasize = 16*sizeof( UInt32 ) ;
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyDataSources,theScope,kAudioObjectPropertyElementMaster };
    status = AudioObjectGetPropertyData(devID, &theAddress, 0, NULL, &datasize, &dataSource);
    CheckError(status, "kAudioDevicePropertyDataSources error devID-dataSource updateSourceMenu Master");
    
    
	//status = AudioDeviceGetProperty( devID, 0, isInput, kAudioDevicePropertyDataSources, &datasize, &dataSource[0] ) ;
	sources = datasize/sizeof( UInt32 ) ;
	
	if ( status != 0 || sources < 0 ) {
		// no sources found
		[ _sourceMenu addItemWithTitle:@"Default" ] ;
		[ _sourceMenu setEnabled:NO ] ;
		return 0 ;
	}
	//  set up default sourceID
	defaultIndex = 0 ;
	datasize = sizeof( UInt32 ) ;
    theAddress.mSelector = kAudioDevicePropertyDataSource;
    theAddress.mElement = 0;
    status = AudioObjectGetPropertyData(devID,&theAddress,0,NULL, &datasize,&defaultSourceID);
    
    CheckError(status, "kAudioDevicePropertyDataSource error devID-defaultSourceID updateSourceMenu");

    
//	status = AudioDeviceGetProperty( devID, 0, isInput, kAudioDevicePropertyDataSource, &datasize, &defaultSourceID ) ;
	
	if ( status != 0 ) {
		// problem getting sources
		[ _sourceMenu addItemWithTitle:@"Default" ] ;
		[ _sourceMenu setEnabled:NO ] ;
		return 0 ;
	}

	for ( i = 0; i < sources; i++ ) {
		//  find the source with the name that is passed in
		transl.mInputData = &dataSource[i] ;
		transl.mInputDataSize = sizeof( UInt32 ) ;
		transl.mOutputData = &cfname ;
		transl.mOutputDataSize = sizeof( CFStringRef ) ;
		datasize = sizeof( AudioValueTranslation ) ;
        theAddress.mSelector = kAudioDevicePropertyDataSourceNameForIDCFString;
        status = AudioObjectGetPropertyData(devID,&theAddress,0,NULL, &datasize,&transl);
        CheckError(status, "Property Data Source error nameforIDCFString devID-transl updateSourceMenu");
		//status = AudioDeviceGetProperty( devID, 0, isInput, kAudioDevicePropertyDataSourceNameForIDCFString, &datasize, &transl ) ;	//  v0.70  Kanji name for source
		if ( status == 0 && datasize == sizeof( AudioValueTranslation ) ) {
			// found a data source source, set value to source ID
			[ _sourceMenu addItemWithTitle:(__bridge NSString*) cfname] ;
			item = (NSMenuItem*)[ _sourceMenu itemAtIndex:i ] ;
			[ item setTag:dataSource[i] ] ;									// set tag to sourceID
			if ( dataSource[i] == defaultSourceID ) defaultIndex = i ;
			//if(cfname != nil ) CFRelease( cfname ) ;
		}
	}
	
	//  default microKEYER II to external line input
	if ( [ [ _soundCardMenu titleOfSelectedItem ] isEqualToString:@"microHAM CODEC" ] ) defaultIndex = 1 ;

	//  select menu item corresponding to the default sourceID
	[ _sourceMenu selectItemAtIndex:defaultIndex ] ;
	[ self sourceMenuChanged ] ;
	
	return defaultIndex ;
}

//  possibly some other app has changed the source for the device in use -- simply track it with our source menu
- (void)fetchSourceFromCoreAudio
{
	NSMenuItem *item ;
	OSStatus status ;
	UInt32 datasize, sourceID ;
	int i, sources ;
	
	if ( _selectedSoundCard == nil ) return ;
	
	datasize = sizeof( UInt32 ) ;
    
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyDataSource,theScope,kAudioObjectPropertyElementMaster};
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&sourceID);
    CheckError(status, "Property Data Source error data source _selectedSoundCard-sourceID fetchSourcefromCoreAudio");
    
	//status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyDataSource, &datasize, &sourceID ) ;
	
	if ( status != 0 ) return ;
	
	//  check if sourceMenu is already correct
	item = (NSMenuItem*)[ _sourceMenu selectedItem ] ;
	if ( [ item tag ] == sourceID ) return ;

	sources = (int)[ _sourceMenu numberOfItems ] ;
	for ( i = 0 ; i < sources; i++ ) {
		item = (NSMenuItem*)[ _sourceMenu itemAtIndex:i ] ;
		if ( sourceID == [ item tag ] ) {
			[ _sourceMenu selectItemAtIndex:i ] ;
			return ;
		}
	}
}

- (Boolean)samplingRateChanged
{
	UInt32 datasize ;
	OSStatus status ;
	int rateIndex ;
	Float64 rate, currentRate ;
	
	if ( _selectedSoundCard == nil ) return NO ;
	
	rateIndex = (int)[ _samplingRateMenu indexOfSelectedItem ] ;
	if ( rateIndex < 0 ) return NO ;
	
	datasize = sizeof( Float64 ) ;
	rate = [ [ _samplingRateMenu titleOfSelectedItem ] intValue ] ;
	
	//  v0.78b  setting sampling rate is slow, so do a getProperty to check id we really need to change the sampling rate.
    
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyNominalSampleRate,theScope,kAudioObjectPropertyElementMaster};
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&currentRate   );
    CheckError(status, "Property Data error nominal sample rate soundCard-current rate samplingratechanged");

    
	//status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyNominalSampleRate, &datasize, &currentRate ) ;
	if ( status == 0 && rate == currentRate ) return YES ;

	datasize = sizeof( Float64 ) ;
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&rate   );
    CheckError(status, "Property Data error nominal sample rate soundCard-rate samplingratechanged");

//	status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, 0, isInput, kAudioDevicePropertyNominalSampleRate, datasize, &rate ) ;
	
	return ( status == 0 ) ;
}

static int selectableSampleRate[6] = { 11025, 16000, 32000, 44100, 48000, 96000 } ;

//	(Private API)
//	Find available sampling rate ranges and check against the 6 rates we allow.
- (void)updateSamplingRateMenu
{
	AudioValueRange range[64] ;
	UInt32 datasize ;
	OSErr status ;
	int i, j, sampleRanges, defaultIndex, currentIndex ;
	float low, high ;
	Boolean usable[6] ;

	[ _samplingRateMenu removeAllItems ] ;
	if ( _selectedSoundCard == nil ) return ;
	
	datasize = 0 ;
    datasize = sizeof( AudioValueRange )*64 ;
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyAvailableNominalSampleRates,theScope,0};
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,range );
    CheckError(status, "kAudioDevicePropertyAvailableNominalSampleRates - error - update samplingratemenu - datasize->NULL");

    
    
	//status = AudioDeviceGetPropertyInfo( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyAvailableNominalSampleRates, &datasize, NULL ) ;
	if ( status == 0 && datasize != 0 ) {
		if ( datasize > sizeof( AudioValueRange )*64 ) datasize = sizeof( AudioValueRange )*64 ;
        status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,range );
        CheckError(status, "kAudioDevicePropertyAvailableNominalSampleRates - error - samplingratemenu - datasize->range");

		//status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyAvailableNominalSampleRates, &datasize, range ) ;
		if ( status == 0 ) {
			sampleRanges = datasize/sizeof( AudioValueRange ) ;
			if ( sampleRanges > 0 ) {
				for ( j = 0; j < 6; j++ ) usable[j] = NO ;
				for ( i = 0; i < sampleRanges; i++ ) {
					low = range[i].mMinimum, high = range[i].mMaximum ;
					for ( j = 0; j < 6; j++ ) {
						if ( low <= selectableSampleRate[j] && high >= selectableSampleRate[j] ) usable[j] = YES ;
					}
				}
				defaultIndex = currentIndex = 0 ;
				for ( j = 0; j < 6; j++ ) {
					if ( usable[j] ) {
						if ( j == 1 ) defaultIndex = currentIndex ;
						[ _samplingRateMenu addItemWithTitle:[ NSString stringWithFormat:@"%d", selectableSampleRate[j] ] ] ;
						currentIndex++ ;
					}
				}
				[ _samplingRateMenu selectItemAtIndex:defaultIndex ] ;
				return ;
			}
		}
	}
	//	add a single 44100 s/s rate if there are errors
	[ _samplingRateMenu addItemWithTitle:@"44100" ] ;
	[ _samplingRateMenu selectItemAtIndex:0 ] ;
}

//  override this to accept sample rate changes
- (void)actualSamplingRateSetTo:(float)rate
{
	NSLog( @"subclass need to implement -actualSamplingRateSetTo" ) ;
}

- (void)updateChannelMenu
{
	DevParams devParams ;
	ChannelBitPair *bitpair ;
	int index, i, besti ;
	
	[ _channelMenu removeAllItems ] ;

	index = (int)[ _soundCardMenu indexOfSelectedItem ] ;
	if ( index < 0 || ((SoundCardInfo*)_info[index]).streamID <= 0 ) {
		[ _channelMenu addItemWithTitle:@"" ] ;
		[ _channelMenu selectItemAtIndex:0 ] ;
		[ _channelMenu setHidden:YES ] ;
		[ _paramString setStringValue:@"" ] ;
		return ;
	}
	getDeviceParams( ((SoundCardInfo*)_info[index]).streamID, _isInput, &devParams ) ;
	
	//  find best channels/depth (more channels are better)
	deviceBitPair.channels = deviceBitPair.bits = 0 ;
	besti = 0 ;
	for ( i = 0; i < devParams.bitPairs; i++ ) {
		bitpair = &devParams.channelBitPair[i] ;
		if ( devParams.channelBitPair[i].channels > deviceBitPair.channels ) {
			//  bitpair with more channels found
			deviceBitPair = *bitpair ;
			besti = i ;
		}
		else {
			if ( bitpair->channels == deviceBitPair.channels ) {
				//  equal number of channels, chose the one with more bits
				if ( bitpair->bits > deviceBitPair.bits ) {
					deviceBitPair = *bitpair ;
					besti = i ;
				}
			}
		}
	}
	[ _paramString setStringValue:[ NSString stringWithFormat:@"%d ch/%d", deviceBitPair.channels, deviceBitPair.bits ] ] ;
	
	
	if ( deviceBitPair.channels <= 1 ) {
		[ _channelMenu addItemWithTitle:@"" ] ;
		[ _channelMenu setEnabled:NO ] ;
	}
	else {
		[ _channelMenu setEnabled:YES ] ;
		if ( deviceBitPair.channels == 2 ) {
			//  stereo
			[ _channelMenu addItemWithTitle:@"L" ] ;
			[ _channelMenu addItemWithTitle:@"R" ] ;
		}
		else {
			//  multichannel
			for ( i = 0; i < deviceBitPair.channels; i++ ) {
				[ _channelMenu addItemWithTitle:[ NSString stringWithFormat:@"%d", i+1 ] ] ;
			}
		}
		channel = baseChannel = 0 ;
		[ _channelMenu selectItemAtIndex:channel ] ;
	}
}

//	Note: for stereo 0 = left, 1 = right
//		multichannel 0 = first channel, 1 = second channel, etc.
//	Return index of channel menu (or 0 if failed)
- (int)channelChanged
{
	int index ;
	
	index = (int)[ _channelMenu indexOfSelectedItem ] ;

	if ( index < 0 ) index = 0 ;	
	channel = index ;
	
	//  assume channel 2 of a 3-channel menu to be a stereo channel (not currently used, but can be used for I/Q)
	if ( channel == 2 && [ _channelMenu numberOfItems ] == 3 ) index = channel = 0 ;
	
	//  baseChannel is the lower of the two channels that is being received.
	//	In the case of a stereo device, the baseChannel is 0.  
	//	In the case of a multichannel device, it is an even numbered channel.
	baseChannel = channel & 0xfffe ;
	
	//  now adjust level
	[ self setDeviceLevelFromSlider ] ;
	
	return index ;
}

- (int)selectChannel:(int)channelIndex
{
	[ _channelMenu selectItemAtIndex:channelIndex ] ;
	return [ self channelChanged ] ;
}

- (float)samplingRateForDeviceID:(AudioDeviceID)devID
{
	OSStatus status ;
	UInt32 datasize ;
	Float64 rate ;

	datasize = sizeof( Float64 ) ;
    
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyNominalSampleRate,theScope,kAudioObjectPropertyElementMaster};
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&rate   );
    CheckError(status, "Property Data Source error nominal sample rate soundCard- rate samplingRateForDeviceID");

    
    
//	status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyNominalSampleRate, &datasize, &rate ) ;

	if ( status != 0 ) return 0.0 ;
	return rate ;
}

//  possibly some other app has changed the source for the device in use -- simply track it with our source menu
- (void)fetchSamplingRateFromCoreAudio
{
	float rate ;
	int nRate ;
	
	if ( _selectedSoundCard == nil ) return ;
	
	rate = [ self samplingRateForDeviceID:_selectedSoundCard.deviceID ] ;
	if ( rate < 7990.0 ) return ;
	
	//  check if we already agree with system (system sends two 'nsrt')
	//  if ( fabs( [ [ samplingRateMenu titleOfSelectedItem ] floatValue ] - rate ) < 10.0 ) return ;  -- was causing false negatives
	if ( fabs( previousSamplingRate - rate ) < 10.0 ) return ;
	
	nRate = rate ;
	previousSamplingRate = nRate ;
	
	[ _samplingRateMenu selectItemWithTitle:[ NSString stringWithFormat:@"%d", nRate ] ] ;
	[ self actualSamplingRateSetTo:rate ] ;
}

- (Boolean)getDBRange:(AudioValueRange*)dbRange
{
	UInt32 datasize ;
	OSStatus status ;
	
	if ( _selectedSoundCard == nil ) return NO ;

	datasize = sizeof( AudioValueRange ) ;
    
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeRangeDecibels,theScope,channel+kLeftChannel};
    status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,dbRange   );
    CheckError(status, "Property Data Source error nominal sample rate channel+kleftChannel soundCard-dbRange getDBRange");

    
    
	//status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeRangeDecibels, &datasize, dbRange ) ;

	if ( status != noErr ) {
		//  check master channel if stereo channel did not work
		datasize = sizeof( AudioValueRange ) ;
        theAddress.mElement = 0;
        status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,dbRange   );
        CheckError(status, "Property Data error nominal sample rate  for channel 0 soundCard-dbRange getDBRange");

		//status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyVolumeRangeDecibels, &datasize, dbRange ) ;
	}
	dBmin = dbRange->mMinimum ;
	dBmax = dbRange->mMaximum ;
	return ( status == noErr ) ;
}

//  fetch dB value and dB range to set slider
- (void)fetchDeviceLevelFromCoreAudio
{
	Float32 db ;
	AudioValueRange range ;
	UInt32 datasize ;
	OSStatus status ;
	
	if ( _dbSlider != nil ) {
		datasize = sizeof( Float32 ) ;
        
        AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
        AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeDecibels,theScope,channel+kLeftChannel};
        status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&db   );
        CheckError(status, "Property Data Source error fetchDeviceLevelFromCoreAudio volumeDecebels _selectedSoundCard-db  both channels");
        

        
		//status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, &datasize, &db ) ;

		if ( status != noErr ) {
			//  check master channel if stereo channel did not work
			datasize = sizeof( Float32 ) ;
            
            theAddress.mElement = 0;
            status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&db   );
            CheckError(status, "Property Data Source error fetchDeviceLevelFromCoreAudio volumeDecebels _selectedSoundCard-db  master channel only");

            
		//	status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyVolumeDecibels, &datasize, &db ) ;
		}
		if ( status == noErr && [ self getDBRange:&range ] == YES ) {
			db = db - range.mMaximum ;
			if ( _dbPad ) {
				db += [ _dbPad floatValue ] ;
				if ( db > 0 ) db = 0 ;
			}
			[ _dbSlider setFloatValue:db ] ;
		}
	}
	if ( _scalarSlider != nil ) {
		datasize = sizeof( Float32 ) ;
        
        AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
        AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeScalar,theScope,channel+kLeftChannel};
        status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&db   );
        CheckError(status, "Property Data Source error fetchDeviceLevelFromCoreAudio volume scalar _selectedSoundCard-db  both channels");

        
        
	//	status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeScalar, &datasize, &db ) ;

		if ( status != noErr ) {
			//  check master channel if stereo channel did not work
			datasize = sizeof( Float32 ) ;
            
            theAddress.mElement = 0;
            status = AudioObjectGetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, &datasize,&db   );
            CheckError(status, "Property Data Source error fetchDeviceLevelFromCoreAudio volume scalar _selectedSoundCard-db  master channel only");

            
		//	status = AudioDeviceGetProperty( _selectedSoundCard.deviceID, 0, isInput, kAudioDevicePropertyVolumeScalar, &datasize, &db ) ;
		}
		if ( status == noErr ) {
			[ _scalarSlider setFloatValue:db ] ;
		}
	}
}

//  (Private API)
- (OSStatus)setScalarAudioLevel:(float)value 
{
	Float32 scalar ;
	UInt32 datasize ;
	OSStatus status ;

	scalar = currentLevel = value ;
	if ( _selectedSoundCard == nil ) return noErr ;
	
	status = noErr ;
	datasize = sizeof( Float32 ) ;
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeScalar,theScope,kLeftChannel};

	//  try setting individual channel(s) first
	if (self.channels == 2 ) {
        
         status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID,&theAddress,0,NULL, datasize,&scalar);
        CheckError(status, "SetPropertyDataError  SetScalarAudioLevel kLeftChannel");
        theAddress.mElement = kRightChannel;
        status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &scalar);
        CheckError(status, "SetPropertyDataError  SetScalarAudioLevel kRightChannel");
        
        
		//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kLeftChannel, isInput, kAudioDevicePropertyVolumeScalar, datasize, &scalar ) ;
		//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kRightChannel, isInput, kAudioDevicePropertyVolumeScalar, datasize, &scalar ) ;
	} else {
        theAddress.mElement = channel+kLeftChannel;
        status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &scalar);
        CheckError(status, "SetPropertyDataError  SetScalarAudioLevel channel+kLeftChannel");
	//	status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeScalar, datasize, &scalar ) ;
	}
	if ( status != noErr ) {
		//  try master control if individual channel does not work
        theAddress.mElement = 0;
        status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &scalar);
        CheckError(status, "SetPropertyDataError  SetScalarAudioLevel master = 0");
		//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, 0, isInput, kAudioDevicePropertyVolumeScalar, datasize, &scalar ) ;
	}
	return status ;
}

//  v0.85
- (void)setOOKDeviceLevel
{
	if ( fabs( currentLevel-ookLevel ) < 0.0001 ) return ;
	[ self setScalarAudioLevel:ookLevel ] ;
}

- (float)validateDeviceLevel
{
	if ( fabs( currentLevel-nonOOKLevel ) < 0.0001 ) return nonOOKLevel ;
	
	[ self setScalarAudioLevel:nonOOKLevel ] ;
	return nonOOKLevel ;
}

// v0.88d
- (void)changeDeviceGain:(int)direction
{
	Float32 dB ;
	UInt32 datasize ;
	OSStatus status ;
	
	// direction +ve -> increase gain

	if ( dBmin == dBmax ) return ;
	
	dB = currentDB + ( direction*0.5 ) ;	
	if ( dB >= dBmax || dB <= dBmin ) return ;	
	currentDB = dB ;
			
	datasize = sizeof( Float32 ) ;
	//  try setting individual channel(s) first
    
    AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeDecibels,theScope,kLeftChannel};

    
	if ( _channels == 2 ) {
        
        status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &dB);
        CheckError(status, "SetPropertyDataError  changeDeviceGain kLeftChannel");

		//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
		if ( status == noErr ) {
            theAddress.mElement = kRightChannel;
            status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &dB);
            CheckError(status, "SetPropertyDataError  changeDeviceGain kRightChannel");

        }//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kRightChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
	}
	else {
        theAddress.mElement = channel+kLeftChannel;
        status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &dB);
        CheckError(status, "SetPropertyDataError  changeDeviceGain channel+kLeftChannel");

	//	status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
	}
	if ( status != noErr ) {
		//  try master control if individual channel does not work
        theAddress.mElement = 0;
        status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &dB);
        CheckError(status, "SetPropertyDataError  changeDeviceGain master =0");

		//status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, 0, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
	}
}

//	Set level from either the dBSlider or the scalarSlider
//	note: scalar level (0 = min, 1 = max)
- (void)setDeviceLevelFromSlider
{
	Float32 db, scalar ;
	int idb ;
	AudioValueRange range ;
	UInt32 datasize ;
	OSStatus status, status2 ;
    
    status = status2 = 12345;
	
	if ( _selectedSoundCard == nil || ( _dbSlider == nil && _scalarSlider == nil ) ) return ;
	
	//  first check range
	if ( [ self getDBRange:&range ] == NO || ( range.mMaximum - range.mMinimum ) < 0.1 ) {
		if ( _dbSlider ) {
			[ _dbSlider setEnabled:NO ] ;
			[ _dbSlider setFloatValue:0.0 ] ;
		}
		if ( _scalarSlider ) {
			[ _scalarSlider setEnabled:NO ] ;
			[ _scalarSlider setFloatValue:1.0 ] ;
		}
	}
	//  round pad to an int
	if ( _dbPad ) {
		idb = [ _dbPad floatValue ] + 0.1 ;
		if ( idb < 0 ) idb = 0 ;
		[ _dbPad setIntValue:idb ] ;
	}
		
	if ( _dbSlider ) {
		db = range.mMaximum + [ _dbSlider floatValue ] ;
		if ( _dbPad ) db -= [ _dbPad intValue ] ;
		if ( db < range.mMinimum ) db = range.mMinimum ;
		
		currentDB = db ;
		dBmin = range.mMinimum ;
		dBmax = range.mMaximum ;

		datasize = sizeof( Float32 ) ;
        
        AudioObjectPropertyScope theScope = self.isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
        AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyVolumeDecibels,theScope, kLeftChannel};

        if ( _channels == 2 ) {
            
            status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &db);
          //  CheckError(status, "kAudioDevicePropertyVolumeDecibels  setDeviceLevelFromSlider kLeftChannel");
            
            //status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
            if ( status == noErr ) {
            //    NSLog(@"kleftChannel worked");
                datasize = sizeof( Float32 ) ;
                theAddress.mElement =  kAudioChannelLabel_Right;
                status2 = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &db);
               // CheckError(status2, "kAudioDevicePropertyVolumeDecibels  setDeviceLevelFromSlider kLeftChannel worked but not kRightChannel");
                
            }
            
            if(!((status == noErr) || (status2 ==noErr))){
                datasize = sizeof( Float32 ) ;
                theAddress.mElement =  kAudioObjectPropertyElementMaster;
                status2 = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &db);
               // CheckError(status2, "kAudioDevicePropertyVolumeDecibels  setDeviceLevelFromSlider left or right didn't work tried element Master and failed");
                if(status2 == noErr) NSLog(@"setting vol on element master worked");
            }
            
            
            //status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kRightChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
        }
        else {
            datasize = sizeof( Float32 ) ;
            theAddress.mElement = channel+kLeftChannel;
            status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &db);
           // CheckError(status, "kAudioDevicePropertyVolumeDecibels  setDeviceLevelFromSlider channel+kLeftChannel");
            
            //	status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
        }
        if ( (status != noErr) && (status2 != noErr) ) {
            datasize = sizeof( Float32 ) ;
            //  try master control if individual channel does not work
            theAddress.mElement = kAudioObjectPropertyElementMaster;
            status = AudioObjectSetPropertyData(_selectedSoundCard.deviceID, &theAddress, 0, NULL, datasize, &db);
          //  CheckError(status, "kAudioDevicePropertyVolumeDecibels  setDeviceLevelFromSlider master =0");
            
            //status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, 0, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &dB ) ;
        }

        
        
        
		//  try setting individual channel(s) first
//		if ( channels == 2 ) {
//			status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &db ) ;
//			if ( status == noErr ) status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, kRightChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &db ) ;
//		}
//		else {
//			status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, channel+kLeftChannel, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &db ) ;
//		}
//		if ( status != noErr ) {
//			//  try master control if individual channel does not work
//			status = AudioDeviceSetProperty( _selectedSoundCard.deviceID, nil, 0, isInput, kAudioDevicePropertyVolumeDecibels, datasize, &db ) ;
//		}
		//  if already minimum, Core Audio will not call us back if set again to minimum
		if ( db <= range.mMinimum ) [ self fetchDeviceLevelFromCoreAudio ] ;
		
		[ _dbSlider setEnabled:( status == noErr || status2 == noErr ) ] ;
	}
		
	if ( _scalarSlider ) {
		scalar = [ _scalarSlider floatValue ] ;
		if ( scalar < 0 ) scalar = 0 ; else if ( scalar > 1 ) scalar = 1 ;
		
		nonOOKLevel = scalar ;									//  v0.85
		status = [ self setScalarAudioLevel:nonOOKLevel ] ;		//  v0.85
		[ _scalarSlider setEnabled:( status == noErr || status2 == noErr) ] ;
	}		
}

- (void)registerLevelSlider:(NSSlider*)slider isScalar:(Boolean)useScalar
{
	if ( useScalar ) _scalarSlider = slider ; else _dbSlider = slider ;
}

//	update sound card menu from CoreAudio
//	default to first menu item but don't select sound card yet (returns menu index (0 always) )
- (int)updateSoundCardMenu
{
	soundcards = [self discoverSoundCards: _info: MAXDEVICES: _isInput ] ;
	[ _soundCardMenu removeAllItems ] ;
	if ( soundcards <= 0 ) {
		// no device
		[ _soundCardMenu addItemWithTitle:@"Default" ] ;
		[ _soundCardMenu setEnabled:NO ] ;
		return 0 ;
	}	
	[ self setMenuTo:_info menu:_soundCardMenu ] ;
	[ _soundCardMenu setEnabled:YES ] ;
	[ _soundCardMenu selectItemAtIndex:0 ] ;

	return 0 ;
}

//  select sound card pointed to by sound card menu
- (int)soundCardChanged
{
	SoundCardInfo *newSelection ;
	int selectedDevice ;
	
	selectedDevice = (int)[ _soundCardMenu indexOfSelectedItem ] ;
	if ( selectedDevice < 0 ) {
		_selectedSoundCard = nil ;
		return -1 ;
	}
	
	//  refresh source menu. sampling rate menu and ask audioManager to act as listener
	newSelection = _info[selectedDevice] ;
	_selectedSoundCard = newSelection ;
	
	//  v0.78b
	if ( _selectedSoundCard != nil && previousDeviceID != _selectedSoundCard.deviceID ) {
		if ( previousDeviceID != 0 ) {
			//  unregister old self...
            NSLog(@"unregistering %d", previousDeviceID);
			[_audioManager audioDeviceUnregister:previousDeviceID modemAudio:self ] ;
		}
		//  ...previousDeviceIDand replace with new DeviceID
        NSLog(@"registering %d", _selectedSoundCard.deviceID);
		[_audioManager audioDeviceRegister:_selectedSoundCard.deviceID modemAudio:self ] ;
		previousDeviceID = _selectedSoundCard.deviceID ;
	}

	//  update source menu with this selected sound card
	[ self updateSourceMenu ] ;	
	//  ...update sampling rate menu
	[ self updateSamplingRateMenu ] ;
	//  ...L/R channel and bit depth
	[ self updateChannelMenu ] ;
	//  ... set dB slider
	[ self setDeviceLevelFromSlider ] ;
	//	... clear dB pad value
	if ( _dbPad ) [ _dbPad setIntValue:10 ] ;
	
	//  switch to actual sampling rate
	[ self fetchSamplingRateFromCoreAudio ] ;
	
	return selectedDevice ;
}

//	return index of selected sound card menu item, or -1 if not found
- (int)selectSoundCard:(NSString*)name
{
	if ( _soundCardMenu == nil || [ _soundCardMenu numberOfItems ] < 1 ) return -1 ;
	
	[ _soundCardMenu selectItemWithTitle:name ] ;
	return [ self soundCardChanged ] ;
}

- (void)setupSoundCards
{
	[ self updateSoundCardMenu ] ;
	[ self updateSourceMenu ] ;
	[ self updateSamplingRateMenu ] ;
	[ self updateChannelMenu ] ;	
}

//  start data sampling
//	override by ModemSource or ModemDest
//- (Boolean)startSoundCard
//{
//	return NO ;
//}
//
////  stop data sampling
////	override by ModemSource or ModemDest
//- (Boolean)stopSoundCard
//{
//	return NO ;
//}

- (void)applicationTerminating 
{
}
	
- (int)needData:(float*)outbuf samples:(int)n channels:(int)ch
{
	NSLog( @"ModemAudio: needData called?? should be handled by ModemDest" ) ;
	return 0 ;
}

- (void)inputArrivedFrom:(AudioDeviceID)device bufferList:(const AudioBufferList*)input
{
   // AudioBuffer *audiobuffer ;
	int streamIndex, samples ;
	 AudioBuffer *audiobuffer ;
    
    if ( _resamplingPipe != nil ) {
		streamIndex = _selectedSoundCard.streamIndex ;
		if ( streamIndex >= input->mNumberBuffers ) streamIndex = 0 ;
		audiobuffer = ( AudioBuffer* )( &( input->mBuffers[ streamIndex ] ) ) ;
		//	setup number of channels
		_channels = audiobuffer->mNumberChannels ;
		//  write bytes into data pipe (note: 512 stereo samples is 4096 bytes)
		samples = audiobuffer->mDataByteSize/( sizeof( float )*audiobuffer->mNumberChannels ) ;
		if ( ( samples%256 ) != 0 ) [ Messages logMessage:"Device input received %d samples; should be a multiple of 256", samples ] ;
		[ _resamplingPipe write:input->mBuffers[streamIndex].mData samples:samples ] ;
        
	}
    
    
    
    return;
}

- (void)accumulateOutputFor:(AudioDeviceID)device bufferList:(const AudioBufferList*)output accumulate:(Boolean)accumulate
{
	AudioBuffer *audiobuffer ;
    float *mdata, *pbuf = NULL, v ;
    int i, samples, streamIndex, deviceChannels, pipeChannels ;
	
	if ( outputMuted ) return ;
	
	streamIndex = _selectedSoundCard.streamIndex ;
	if ( streamIndex >= output->mNumberBuffers ) streamIndex = 0 ;				// sanity check
	audiobuffer = ( AudioBuffer* )( &( output->mBuffers[ streamIndex ] ) ) ;
	
	//	setup number of channels
	_channels = deviceChannels = audiobuffer->mNumberChannels ;
	pipeChannels = resamplingPipeChannels ;

	mdata = ( float* )audiobuffer->mData ;
	samples = audiobuffer->mDataByteSize/deviceChannels/sizeof( float ) ;

	if ( deviceChannels != pipeChannels ) {
		pbuf = _pipeBuffer ;
		samples = [ _resamplingPipe readResampledData:pbuf samples:samples ] ;
		_pipeBuffer = pbuf;
		memset( mdata, 0, audiobuffer->mDataByteSize ) ;		//  first clear all of destination buffer		
		mdata = &mdata[ baseChannel + channel ] ;
		
		if ( accumulate == YES ) {
			if ( pipeChannels == 1 ) {
				//  mono pipe in multichannel device
				for ( i = 0; i < samples; i++ ) {
					v = pbuf[i] ;
					mdata[0] += v ;								//  v0.85  write into only one channel
					//mdata[1] += v ;							//  write into both device channels				
					mdata += deviceChannels ;
				}
			}
			else {
				if ( deviceChannels >= 2 ) {
					//  stereo pipe in multichannel device
					for ( i = 0; i < samples; i++ ) {
						mdata[0] += pbuf[0] ;
						mdata[1] += pbuf[1] ;
						mdata += deviceChannels ;
						pbuf += 2 ;
					}
				}
				else {
					//  stereo pipe in single channel device, mix to output
					for ( i = 0; i < samples; i++ ) {
						mdata[0] += ( pbuf[0] + pbuf[1] )*0.5 ;
						mdata++ ;
						pbuf += 2 ;
					}
				}
			}
		}
		else {
			if ( pipeChannels == 1 ) {
				//  mono pipe in multichannel device
				for ( i = 0; i < samples; i++ ) {
					v = pbuf[i] ;
					mdata[0] = v ;		//  v0.85  write into only one channel
					//mdata[1] = v ;		//  write into both device channels				
					mdata += deviceChannels ;
				}
			}
			else {
				if ( deviceChannels >= 2 ) {
					//  stereo pipe in multichannel device
					for ( i = 0; i < samples; i++ ) {
						mdata[0] = pbuf[0] ;
						mdata[1] = pbuf[1] ;
						mdata += deviceChannels ;
						pbuf += 2 ;
					}
				}
				else {
					//  stereo pipe in single channel device, mix to output
					for ( i = 0; i < samples; i++ ) {
						mdata[0] = ( pbuf[0] + pbuf[1] )*0.5 ;
						mdata++ ;
						pbuf += 2 ;
					}
				}
			}
		}
	}
	else {
		//  pipe and device has the same number of channels
		[ _resamplingPipe readResampledData:mdata samples:samples ] ;
	}
}

@end
