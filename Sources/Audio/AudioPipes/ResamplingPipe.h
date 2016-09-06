//
//  ResamplingPipe.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 10/22/09.
//  Copyright 2009 Kok Chen, W7AY. All rights reserved.
//

#import "DataPipe.h"
#import <CoreAudio/CoreAudioTypes.h>
#import <AudioToolbox/AudioConverter.h>

#define SBUF 2048
#define RBUF 8192*2
#define UBUFSAMPLES 512

@class ModemAudio ;

@interface ResamplingPipe : DataPipe {
//	AudioStreamBasicDescription basicDescription ;
//	AudioConverterRef rateConverter ;

//	int channels ;
	int cycle ;
	
	Boolean odd ;
	Boolean useConstantOutputBufferSize ;
//	float stereoBuffer[2048] ;										//  v0.90
//	float resampledBuffer[8192*2] ;									//  double buffer it
//	int remainingSamples ;											//  for unbuffered buffer
	ModemAudio *unbufferedTarget ;
	Boolean pushed ;
	float inputSamplingRate, currentInputSamplingRate ;
	float outputSamplingRate, currentOutputSamplingRate ;
}

@property  AudioStreamBasicDescription basicDescription;
@property  AudioStreamPacketDescription *aspd;
@property  AudioConverterRef rateConverter;
@property  float *stereoBuffer;
@property  float *resampledBuffer;
@property  float *resampledBuffer2;
@property  int   samplesToCollect;
@property  int   collectedSamples;
@property  int   originalRequest;
@property  UInt32 packetsPerBuffer;
@property  UInt32 maxPacketSize;
@property  int   channels;

void  CheckError  (OSStatus error , const char*  operation);

- (id)initWithSamplingRate:(float)rate channels:(int)ch ;
- (id)initUnbufferedPipeWithSamplingRate:(float)rate channels:(int)ch target:(ModemAudio*)target ;

- (void)setUseConstantOutputBufferSize:(Boolean)constant ;

- (void)setInputSamplingRate:(float)rate ;
- (void)setOutputSamplingRate:(float)rate ;

- (int)write:(float*)data samples:(int)samples ;
- (int)readResampledData:(float*)data samples:(int)samples ;

- (int)channels ;
- (void)setNumberOfChannels:(int)ch ;
- (void)makeNewRateConverter ;

@end
