/*
 *  audioutils.c
 *  Sound
 *
 *  Created by kchen on Thu Jun 20 2002.
 *  Copyright (c) 2002, 2003, 2004 W7AY. All rights reserved.
 *
 */

/*
 Note: Audio Codec Result codes
 --------------------------------------------
 kAudioCodecNoError = 0,
 kAudioCodecUnspecifiedError = 'what',
 kAudioCodecUnknownPropertyError = 'who?',
 kAudioCodecBadPropertySizeError ='!siz',
 kAudioCodecIllegalOperationError = 'nope',
 kAudioCodecUnsupportedFormatError = '!dat',
 kAudioCodecStateError ='!stt',
 kAudioCodecNotEnoughBufferSpaceError = '!buf'
 */

#include "audioutils.h"
#include <unistd.h>
#include <CoreAudio/AudioHardware.h>

static AudioStreamInfo streamInfo[4096] ;		//  v0.78
static AudioDeviceInfo deviceInfo[4096] ;		//  v0.78

//	v0.78
void initAudioUtils()
{
	int i ;
    
	for ( i = 0; i < 4096; i++ ) {
		streamInfo[i].streamID = 0 ;
		deviceInfo[i].inputProc = deviceInfo[i].outputProc = nil ;
		deviceInfo[i].inputClient = deviceInfo[i].outputClient = nil ;
	}
}


//  enumerate AudioDeviceID's and return number of devices found in machine
int enumerateAudioDevices( AudioDeviceID* list, int n )
{
    UInt32 size ;
    int devices, status, i ;
    
    size = n * sizeof( AudioDeviceID ) ;
    
    
    AudioObjectPropertyAddress theAddress = {kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMaster};
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject,&theAddress,0,NULL, &size,list);
    CheckError(status, "AudioHardwarePropertyDevices error in enumerateAudioDevices");
    //status = AudioHardwareGetProperty( kAudioHardwarePropertyDevices, &size, list ) ;
    if(status != noErr) {
        for ( i = 0; i < 8; i++ ) {
            //  check a few times in case we need did not get a response from CoreAudio
            if ( status == noErr ) break ;
            usleep( 100000 ) ;
            size = n*sizeof( AudioDeviceID ) ;
            status = AudioObjectGetPropertyData(kAudioHardwarePropertyDefaultInputDevice,&theAddress,0,NULL, &size,list);
            CheckError(status, "AudioHardwarePropertyDevices waiting enumerateAudioDevices");
            //status = AudioHardwareGetProperty( kAudioHardwarePropertyDevices, &size, list ) ;
        }
    }
	if ( status != 0 ) {
        CheckError(status, "AudioHardwarePropertyDevices error in enumerateAudioDevices");
        return 0 ;
    }
	
    devices = size/sizeof( AudioDeviceID ) ;
    return devices ;
}

int getPhysicalFormatCount( int streamID )
{
 	UInt32 datasize ;
    
    AudioObjectPropertyAddress theAddress = {kAudioStreamPropertyPhysicalFormats,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMaster};
    OSStatus status = AudioObjectGetPropertyDataSize(streamID, &theAddress, 0, NULL, &datasize);
    CheckError(status, "Error get AudioStreamPropertyPhysicalFormats from getPhysicalFormatCount");
    
    //AudioStreamGetPropertyInfo( streamID, 0, kAudioStreamPropertyPhysicalFormats, &datasize, nil );
    
    return datasize/sizeof(AudioStreamBasicDescription) ;
}

int getActualFormatCount( int streamID )
{
 	UInt32 datasize ;
    Boolean dummy ;
    
    
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyStreamFormats,kAudioObjectPropertyScopeGlobal,0};
    OSStatus status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&dummy);
    CheckError(status, "Error get kAudioDevicePropertyStreamFormats from getActualFormatCount");
    // AudioStreamGetPropertyInfo( streamID, 0, kAudioDevicePropertyStreamFormats, &datasize, &dummy );
    
    return datasize/sizeof(AudioStreamBasicDescription) ;
}

void getDeviceParams( int streamID, Boolean isInput, DevParams *devParams )
{
	UInt32 datasize ;
	AudioStreamBasicDescription *formatsAvailable, *s ;
	int i, j, formats, err ;
    
	devParams->bitPairs = 0 ;
    
	//  fetch all formats, first find the number of formats
	formats = getPhysicalFormatCount( streamID ) ;
	
	datasize = formats*sizeof( AudioStreamBasicDescription ) ;
	formatsAvailable = ( AudioStreamBasicDescription*)malloc( datasize ) ;
	//  now fetch the formats
    
    AudioObjectPropertyAddress theAddress = {kAudioStreamPropertyPhysicalFormats,kAudioObjectPropertyScopeGlobal,0};
  //  OSStatus status = AudioObjectGetPropertyDataSize(streamID, &theAddress, 0, NULL, &datasize);
    OSStatus status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,formatsAvailable);
    CheckError(status, "Error get kAudioStreamPropertyPhysicalFormats from getDeviceParams");
    
    
	//AudioStreamGetProperty( streamID, 0, kAudioStreamPropertyPhysicalFormats, &datasize, formatsAvailable ) ;
    
	if ( datasize > 0 ) {
		err = 0 ;
		for ( i = 0; i < formats; i++ ) {
			s = &formatsAvailable[i] ;
			//  find unique channel/bit pairs
			for ( j = 0; j < devParams->bitPairs; j++ ) {
				if ( devParams->channelBitPair[j].bits == s->mBitsPerChannel && devParams->channelBitPair[j].channels == s->mChannelsPerFrame ) break ;
			}
			if ( j >= devParams->bitPairs ) {
				j = devParams->bitPairs ;
				devParams->channelBitPair[j].bits = s->mBitsPerChannel ;
				devParams->channelBitPair[j].channels = s->mChannelsPerFrame ;
				devParams->bitPairs++ ;
			}
		}
	}
	free( formatsAvailable ) ;
}

//  Stream (floating point samples bits) format of the stream containing the requested channel
int getFormatForStream( int streamID, int channel, AudioStreamExtendedDescription *streamDesc )
{
    UInt32 datasize ;
	AudioValueRange rates[64] ;
	int i ;
    
    datasize = sizeof( AudioStreamBasicDescription ) ;
    
    
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyStreamFormat,kAudioObjectPropertyScopeGlobal,channel};
    OSStatus status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&streamDesc->basic );
    CheckError(status, "Error get kAudioDevicePropertyStreamFormat from getFormatForStream");
    
    
    
    // AudioStreamGetProperty( streamID, channel, kAudioDevicePropertyStreamFormat, &datasize, &streamDesc->basic ) ;
	
	//  get sampling rates
	datasize = sizeof(AudioValueRange )*64 ;
    
    theAddress.mSelector = kAudioDevicePropertyAvailableNominalSampleRates;
    status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,rates);
    CheckError(status, "Error get kAudioDevicePropertyAvailableNominalSampleRates from getFormatForStream");
    
    
    // AudioStreamGetProperty( streamID, channel, kAudioDevicePropertyAvailableNominalSampleRates, &datasize, rates ) ;
	streamDesc->sampleRanges = datasize/sizeof(AudioValueRange ) ;
	
	for ( i = 0; i < streamDesc->sampleRanges; i++ ) {
		streamDesc->sampleRange[i].min = rates[i].mMinimum ;
		streamDesc->sampleRange[i].max = rates[i].mMaximum ;
	}
	return (int)datasize ;
}

//  Physical device (raw device bits) format of the stream containing the requested channel
int getPhysicalFormatForStream( int streamID, int channel, AudioStreamExtendedDescription *streamDesc )
{
    UInt32 datasize ;
	OSErr status ;
	AudioValueRange rates[64] ;
	int i ;
	
	//  v0.76 do GetPropertyInfo first
	datasize = 0 ;
    
    AudioObjectPropertyAddress theAddress = {kAudioStreamPropertyPhysicalFormat,kAudioObjectPropertyScopeGlobal,0};
    status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,nil );
    CheckError(status, "Error get kAudioStreamPropertyPhysicalFormat from getPhysicalFormatForStream receiver=nil");
    
    
    
	//status = AudioStreamGetPropertyInfo( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, nil );
	//  v0.78  bypass check if device actually returns stream PropertyInfo
	// assert( datasize == sizeof( AudioStreamBasicDescription ) ) ;
	
	datasize = sizeof( AudioStreamBasicDescription ) ;
    
    status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&streamDesc->basic );
    CheckError(status, "Error get kAudioStreamPropertyPhysicalFormat from getPhysicalFormatForStream receiver=&streamDesc->basic");
    
    //status = AudioStreamGetProperty( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, &streamDesc->basic ) ;
    
	//  get sampling rates
	streamDesc->sampleRanges = 0 ;
	datasize = 0 ;
    status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&streamDesc->basic );
    CheckError(status, "Error get kAudioStreamPropertyPhysicalFormat from getPhysicalFormatForStream receiver=&streamDesc->basic");
    
    theAddress.mSelector = kAudioDevicePropertyAvailableNominalSampleRates;
    status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,NULL );
    CheckError(status, "Error get kAudioDevicePropertyAvailableNominalSampleRates from getPhysicalFormatForStream receiver=NULL");
    //	status = AudioStreamGetPropertyInfo( streamID, 0, kAudioDevicePropertyAvailableNominalSampleRates, &datasize, NULL ) ;
	if ( status == 0 && datasize != 0 ) {
        status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,rates);
        CheckError(status, "Error get kAudioDevicePropertyAvailableNominalSampleRates from getPhysicalFormatForStream receiver=rates");
        
        // status = AudioStreamGetProperty( streamID, channel, kAudioDevicePropertyAvailableNominalSampleRates, &datasize, rates ) ;
		if ( status == 0 && datasize != 0 ) {
			streamDesc->sampleRanges = datasize/sizeof( AudioValueRange ) ;
			for ( i = 0; i < streamDesc->sampleRanges; i++ ) {
				streamDesc->sampleRange[i].min = rates[i].mMinimum ;
				streamDesc->sampleRange[i].max = rates[i].mMaximum ;
			}
			if ( streamDesc->sampleRanges != 0 ) return (int)streamDesc->sampleRanges ;
		}
	}
	return 0 ;
}

//  Set Stream (floating point) format of the stream containing the requested channel
void setFormatForStream( int streamID, int channel, AudioStreamExtendedDescription *streamDesc )
{
    //	int err ;
    
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyStreamFormat,kAudioObjectPropertyScopeGlobal,channel};
    OSStatus status = AudioObjectSetPropertyData(streamID,&theAddress,0,NULL, sizeof( AudioStreamBasicDescription ),&streamDesc->basic );
    CheckError(status, "Error SET kAudioDevicePropertyStreamFormat from setFormatForStream receiver=&streamDesc->basic ");
    
    
    
	
    //    err = AudioStreamSetProperty( streamID, nil, channel, kAudioDevicePropertyStreamFormat, sizeof( AudioStreamBasicDescription ), &streamDesc->basic ) ;
	usleep( 100000 ) ;
	//if ( err ) printf( "setFormatForStream, error code : %4.4s\n", (char*)&err ) ;
}

//  set buffer (frame) size for device (size is per channel)
int setBufferSize( int deviceID, Boolean isInput, int size )
{
	UInt32 datasize, data ;
	
	data = size ;
	datasize = sizeof( UInt32 ) ;
    
    
    AudioObjectPropertyScope theScope = isInput ? kAudioDevicePropertyScopeInput :kAudioDevicePropertyScopeOutput;
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyBufferFrameSize,theScope,0};
    OSStatus status = AudioObjectSetPropertyData(deviceID,&theAddress,0,NULL, datasize,&data );
    CheckError(status, "Error SET kAudioDevicePropertyBufferFrameSize from setBufferSize receiver=&streamDesc->&data ");
    
    
    
    
	//AudioDeviceSetProperty( deviceID, nil, 0, isInput, kAudioDevicePropertyBufferFrameSize, datasize, &data ) ;
	usleep( 100000 ) ;
    
    status = AudioObjectSetPropertyData(deviceID,&theAddress,0,NULL, datasize,&data );
    CheckError(status, "Error SET kAudioDevicePropertyBufferFrameSize from setBufferSize receiver=&streamDesc->&data ");
    
	//AudioDeviceGetProperty( deviceID, 0, isInput, kAudioDevicePropertyBufferFrameSize, &datasize, &data ) ;
	
	return data ;
}

//  set sampling rate, number of bits per sample and number of channels
Boolean setParamsForDevice( int streamID, Boolean isInput, float rate, int bits, int channels )
{
	UInt32 datasize ;
	Boolean writeEnable ;
	AudioStreamBasicDescription *formatsAvailable, *s, basic ;
	int i, err, formats ;
	
	//  check if we can write to device
	datasize = sizeof( Boolean ) ;
    
    AudioObjectPropertyAddress theAddress = {kAudioDevicePropertyStreamFormat,kAudioObjectPropertyScopeGlobal,0};
    OSStatus status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&writeEnable );
    CheckError(status, "Error get kAudioDevicePropertyStreamFormat from setParamsForDevice receiver=&writeEnable");
    
    
    
	//AudioStreamGetPropertyInfo( streamID, 0, kAudioDevicePropertyStreamFormat, &datasize, &writeEnable ) ;
	if ( !writeEnable ) return false ;
	
	//  fetch all formats (max of 16 Basic descriptions)
	datasize = sizeof(AudioStreamBasicDescription)*256 ;
	formatsAvailable = (AudioStreamBasicDescription*)malloc( datasize ) ;
    
    theAddress.mSelector = kAudioStreamPropertyPhysicalFormats;
    status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,(char*)formatsAvailable  );
    CheckError(status, "Error get kAudioStreamPropertyPhysicalFormats from setParamsForDevice receiver=(char*)formatsAvailable");
    
	//AudioStreamGetProperty( streamID, 0, kAudioStreamPropertyPhysicalFormats, &datasize, (char*)formatsAvailable ) ;
	
	formats = datasize/sizeof( AudioStreamBasicDescription ) ;
	err = 0 ;
    
	//  find the format and set both stream format and physical formats
	for ( i = 0; i < formats; i++ ) {
		s = &formatsAvailable[i] ;
		//  mSampleRate of 0.0 in formatsAvailable[i] means that we can select any of the available rates
		if ( ( rate == s->mSampleRate || s->mSampleRate < 1 ) && bits == s->mBitsPerChannel && channels == s->mChannelsPerFrame ) {
			//  fix sampling rate for the case it is flexible
			if ( s->mSampleRate < 1 ) s->mSampleRate = rate ;
			datasize = sizeof( AudioStreamBasicDescription ) ;
            
            theAddress.mSelector = kAudioStreamPropertyPhysicalFormat;
            status = AudioObjectSetPropertyData(streamID,&theAddress,0,NULL, datasize,s );
            CheckError(status, "Error Set kAudioStreamPropertyPhysicalFormat from setParamsForDevice receiver=s");
            
            
			//err = AudioStreamSetProperty( streamID, nil, 0,  kAudioStreamPropertyPhysicalFormat, datasize, s ) ;
			usleep( 10000 ) ;
			datasize = 0 ;
			//  v0.76 do GetPropertyInfo first
            status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,nil);
            CheckError(status, "Error Get kAudioStreamPropertyPhysicalFormat from setParamsForDevice receiver=nil");
            
            
			//AudioStreamGetPropertyInfo( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, nil );
			assert( datasize == sizeof( AudioStreamBasicDescription ) ) ;
            
            status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&basic);
            CheckError(status, "Error Get kAudioStreamPropertyPhysicalFormat from setParamsForDevice receiver=&basic");
            
			//AudioStreamGetProperty( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, &basic ) ;
			//  check if rate is properly set (2 sets needed in Jaguar with Rev3 iMic?)
			if ( basic.mSampleRate != rate ) {
				// re-set rate a second time
				basic.mSampleRate = rate ;
				datasize = sizeof( AudioStreamBasicDescription ) ;
                
                status = AudioObjectSetPropertyData(streamID,&theAddress,0,NULL, datasize,&basic);
                CheckError(status, "Error Set kAudioStreamPropertyPhysicalFormat from setParamsForDevice receiver=&basic");
                
				//AudioStreamSetProperty( streamID, nil, 0, kAudioStreamPropertyPhysicalFormat, datasize, &basic ) ;
				usleep( 10000 ) ;
				//  return false if failed second time too
				datasize = 0 ;
				//  v0.76 do GetPropertyInfo first
                status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,nil);
                CheckError(status, "Error Get kAudioStreamPropertyPhysicalFormat from setParamsForDevice receiver=nil");
                
                
                //AudioStreamGetPropertyInfo( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, nil );
                assert( datasize == sizeof( AudioStreamBasicDescription ) ) ;
                
                status = AudioObjectGetPropertyData(streamID,&theAddress,0,NULL, &datasize,&basic);
                CheckError(status, "Error Get kAudioStreamPropertyPhysicalFormat from setParamsForDevice receiver=&basic");
                
                
                //	AudioStreamGetPropertyInfo( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, nil );
                //	assert( datasize == sizeof( AudioStreamBasicDescription ) ) ;
                //	AudioStreamGetProperty( streamID, 0, kAudioStreamPropertyPhysicalFormat, &datasize, &basic ) ;
				if ( basic.mSampleRate != rate ) return false ;
			}
			break ;
		}
	}
	free( formatsAvailable ) ;
	return ( err == 0 ) ;
}



//  return AudioStreamInfo entry for the StreamID
//	If not, return an empty entry.  If there are no empty entries, return the first entry, which is used as a recycled cache.
AudioStreamInfo* infoForStream( AudioStreamID streamID )
{
	int index ;
	
	//  v0.78 change to 4096 elements
	index = ( (int)streamID ) % 4096 ;
	return &streamInfo[index] ;
}

// These aren't actually called anywhere...so I first tried to change them, and then later I commented them out...

//OSStatus audioDeviceChangeInputProc( AudioDeviceID deviceID, AudioDeviceIOProc proc, void *clientData )
//{
//	int index ;
//	AudioDeviceInfo *d ;
//
//	index = ( (int)deviceID ) % 4096 ;
//	d = &deviceInfo[index] ;
//
//	if ( d->inputProc == proc && clientData == d->inputClient ) return 0 ;
//
//	if ( d->inputProc != nil ) {
//        AudioDeviceDestroyIOProcID(deviceID, cachedAudioDevice.theIOProcID_Output);
//
//		//AudioDeviceRemoveIOProc( deviceID, proc ) ;
//		usleep( 200000 ) ;
//	}
//	d->inputProc = proc ;
//	d->inputClient = clientData ;
//
//    OSStatus theError = AudioDeviceCreateIOProcID(deviceID, proc, (__bridge void *)(self), &theIdI);
//
//	//AudioDeviceAddIOProc( deviceID, proc, clientData ) ;
//    
//    return theError;
//}
//
//OSStatus audioDeviceChangeOutputProc( AudioDeviceID deviceID, AudioDeviceIOProc proc, void *clientData )
//{
//	int index ;
//	AudioDeviceInfo *d ;
//
//	index = ( (int)deviceID ) % 4096 ;
//	d = &deviceInfo[index] ;
//
//	if ( d->outputProc == proc && clientData == d->outputClient ) return 0 ;
//	
//	if ( d->outputProc != nil ) AudioDeviceRemoveIOProc( deviceID, proc ) ;
//	d->outputProc = proc ;
//	d->outputClient = clientData ;
//	return AudioDeviceAddIOProc( deviceID, proc, clientData ) ;
//}
//
