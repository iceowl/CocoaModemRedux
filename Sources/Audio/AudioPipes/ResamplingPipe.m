//
//  ResamplingPipe.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 10/22/09.
//  Copyright 2009 Kok Chen, W7AY. All rights reserved.
//

#import "ResamplingPipe.h"
#import "ModemAudio.h"


@implementation ResamplingPipe

@synthesize basicDescription = _basicDescription;
@synthesize rateConverter    = _rateConverter;
@synthesize resampledBuffer  = _resampledBuffer;
@synthesize resampledBuffer2 = _resampledBuffer2;
@synthesize stereoBuffer     = _stereoBuffer;
@synthesize aspd             = _aspd;
@synthesize samplesToCollect = _samplesToCollect;
@synthesize collectedSamples = _collectedSamples;
@synthesize originalRequest  = _originalRequest;
@synthesize packetsPerBuffer = _packetsPerBuffer;
@synthesize maxPacketSize    = _maxPacketSize;
@synthesize channels         = _channels;

//	v0.90	convert data into stereo and keep AudioConverter working with Stereo

- (void)setNumberOfChannels:(int)ch
{
	//  v0.93c -- set up basic description with updated channels instead of stereo channels
	_channels = ch ;
	_basicDescription.mChannelsPerFrame = ch ;
	_basicDescription.mBytesPerFrame = 4 * _basicDescription.mChannelsPerFrame ;
	_basicDescription.mBytesPerPacket = 4 * _basicDescription.mChannelsPerFrame ;
	_basicDescription.mBitsPerChannel = 32 ;
	//  set up rate/channels that will cause an initialization when first use
	currentInputSamplingRate = currentOutputSamplingRate = -1 ;
    _aspd = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * 4);
}

//	(Private API)
- (void)finishInit:(float)rate channels:(int)ch
{
	inputSamplingRate = outputSamplingRate = rate ;
	
	_basicDescription.mSampleRate = rate ;
	_basicDescription.mFormatID = kAudioFormatLinearPCM ;
	_basicDescription.mFormatFlags = kLinearPCMFormatFlagIsFloat ;
#if __BIG_ENDIAN__
	_basicDescription.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian ;
#endif
	_basicDescription.mFramesPerPacket = 1 ;
	[ self setNumberOfChannels:ch ] ;			//  v0.93c
	_rateConverter = nil ;
	odd = NO ;
	_samplesToCollect = 512;
    _originalRequest  = 0;
    _packetsPerBuffer = 0;
    _collectedSamples = 0;
    _maxPacketSize    = 0;
    _stereoBuffer = malloc(sizeof(float) * SBUF * ch );
    _resampledBuffer = malloc(sizeof(float) * RBUF * ch);
    _resampledBuffer2 = malloc(sizeof(float) * RBUF * ch);
}

//	Add an AudioConverter to a DataPipe
- (id)initWithSamplingRate:(float)rate channels:(int)ch
{
	self = [ super initWithCapacity:16384*128*sizeof(float) ] ;
	if ( self ) {
        
		unbufferedTarget = nil ;
		useConstantOutputBufferSize = YES ;
		[ self finishInit:rate channels:ch ] ;
	}
	return self ;
}

//  this is used by ModemDest
- (id)initUnbufferedPipeWithSamplingRate:(float)rate channels:(int)ch target:(ModemAudio*)target
{
	self = [ super initWithCapacity:512*2*sizeof(float) ] ;			//  stereo 512 sample buffer
	if ( self ) {
		unbufferedTarget = target ;
		useConstantOutputBufferSize = YES ;
		[ self finishInit:rate channels:ch ] ;
	}
	return self ;
}

- (void)dealloc
{
    NSLog(@"Attempting to dealloc ResamplingPipe");
	if ( _rateConverter ) {
		AudioConverterDispose( _rateConverter ) ;
		_rateConverter = nil ;
	}
    free(_resampledBuffer);
    free(_resampledBuffer2);
    free(_stereoBuffer);
	//[ super dealloc ] ;
}

- (void)setInputSamplingRate:(float)rate
{
	inputSamplingRate = rate ;
}

- (void)setOutputSamplingRate:(float)rate
{
	outputSamplingRate = rate ;
}

//- (int)channels
//{
//	return _channels ;
//}


- (int)write:(float*)buf samples:(int)samples
{
	int written, i ;
	float *b, u ;
	
	if ( unbufferedTarget != nil ) return 0 ;		//  cannot write into an unbuffered resampling pipe
	
	if ( _channels == 1 ) {
		//	v0.93c - only write a single channel into the resampling pipe if mono
		b = _stereoBuffer ;
		if ( samples > 1024 ) samples = 1024 ;
		for ( i = 0; i < samples; i++ ) {
			u = buf[i] ;
			*b++ = u ;
		}
		written = [ self write:_stereoBuffer length:samples*sizeof( float ) ] ;
        return written / ( sizeof( float ) ) ;
	}
	//  stereo input
	written = [ self write:buf length:samples*_channels*sizeof( float ) ] ;
	return written / ( _channels*sizeof( float ) ) ;
}

//	AudioConverterInputDataProc (see CoreAudio AudioConverter documentation)
//
//  AudioConverterFillBuffer in readResampledData causes data to be read from this proc.
//  dataSize depends on the decimation ratio.
//	In the ressampleProc implementation, we block on multiple read( fdIn,... ) calls until we have all
//	of dataSize available.  And excess data that is unused is written into the resampleData
//
//  readThread will block here if there is no data in the pipe.

//static OSStatus resampleProc( AudioConverterRef converter, UInt32 *dataSize, void **outData, void *userData )

static OSStatus resampleProc(AudioConverterRef converter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription** aspd, void* userData)
{
	OSStatus    err = noErr;
    UInt32  bytesCopied = 0;
    
    ResamplingPipe *p ;
	
    //	alternate between two buffers
	p = (__bridge ResamplingPipe*)userData;
	//  limit return size of our buffer size
    
    
    // initialize in case of failure
    ioData->mBuffers[0].mData = NULL;
    ioData->mBuffers[0].mDataByteSize = 0;
    
    if(*ioNumberDataPackets) {
        
        
//        if(p->_resampledBuffer != NULL) {
//            free(p->_resampledBuffer);
//            p->_resampledBuffer = NULL;
//        }
        
        bytesCopied = *ioNumberDataPackets * p->_maxPacketSize ;
        
        if(p->_originalRequest == 0) p->_originalRequest = bytesCopied;
      //  p->_resampledBuffer = (void *)calloc(1, bytesCopied);
        
        void* buf = (void*)p->_resampledBuffer2;
        
        bytesCopied = [ p readData:buf length:bytesCopied ] ;	//  block here until all data arrives
        //
        
        
        // outData->mNumberBuffers = 1;
        ioData->mBuffers[0].mData = buf ;
        ioData->mBuffers[0].mDataByteSize = bytesCopied;
        // outData->mBuffers[0].mNumberChannels = p->_basicDescription.mChannelsPerFrame;
        
        p->_collectedSamples += bytesCopied;
        if(p->_collectedSamples >= p->_originalRequest) {
            p->_collectedSamples = 0;
        }
        
    }
    
    *ioNumberDataPackets = bytesCopied / p->_maxPacketSize;
    
	return err ;
}

//	data is fetched from the "target" in 512 sample chunks.
//	If the buffer runs out, another 512 sampels are pulled from the target.
//	In the unbuffered case here, we skip the pipe entirely.
//static OSStatus unbufferedResampleProc( AudioConverterRef converter, UInt32 *dataSize, void **outData, void *userData )
static OSStatus unbufferedResampleProc(AudioConverterRef converter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription** aspd, void* userData)
{
	ResamplingPipe *p ;
    OSStatus    err = noErr;
    UInt32  bytesCopied = 0;
    // int m;
    void  *buf = NULL;
    float *buf2 = NULL;
    
    int pSize = 0;
    int channels;
    
    
    
    //	alternate between two buffers
	p = (__bridge ResamplingPipe*)userData ;
	//  limit return size of our buffer size
    
    pSize = p->_maxPacketSize;
    channels = p->_channels;
    
    // initialize in case of failure
    ioData->mBuffers[0].mData = NULL;
    ioData->mBuffers[0].mDataByteSize = 0;
    
    if(*ioNumberDataPackets) {
        
        
        if ( p->useConstantOutputBufferSize == NO ) {
            
            
           // bytesCopied = *ioNumberDataPackets * pSize ;
           // p->_resampledBuffer = (float *)calloc(pSize, *ioNumberDataPackets * p->_channels);
            
            buf = (void*)p->_resampledBuffer2 ;
            
            //  For clients that can supply variable number of samples (or supplies zero filled buffer)
            //	The client should return the actual number of samples supplied if it is less than the requested number of samples
            //m = *ioNumberDataPackets/sizeof(float)/p->channels ;
            
            bytesCopied = [ p->unbufferedTarget needData:buf samples:*ioNumberDataPackets channels:channels ] * channels * sizeof(float) ;
        }
        else {
            
            
            buf2 = [p uRingBuffer : *ioNumberDataPackets];
            bytesCopied = *ioNumberDataPackets * pSize * channels;
            
        }
        
    }
    
    
    if(buf2 != NULL) {
         ioData->mBuffers[0].mData = p->_resampledBuffer2;
    }
    
    else {
        ioData->mBuffers[0].mData = buf;
    }
    
    
    ioData->mBuffers[0].mDataByteSize = bytesCopied;
    *ioNumberDataPackets = bytesCopied / (channels * sizeof(float));
    
    return err;
}


- (float*) uRingBuffer : (int) samplesToCollect  {
    
    
    int inBufferCount = 0;
    static int rsPointer = 0;
    
    
    if(rsPointer <= 0 || _resampledBuffer == NULL) {
        [ unbufferedTarget needData:_resampledBuffer samples:UBUFSAMPLES channels:_channels ];
        rsPointer = 0;
        
    }
    
    if(samplesToCollect <= (UBUFSAMPLES - rsPointer)){
        memcpy((void*)_resampledBuffer2,(void*)&(_resampledBuffer[rsPointer]),samplesToCollect * sizeof(float) * _channels);
        rsPointer += samplesToCollect;
        
    } else {
        memcpy( (void*)_resampledBuffer2,(void*) &(_resampledBuffer[rsPointer]), (UBUFSAMPLES-rsPointer) * sizeof(float) * _channels);
        inBufferCount += (UBUFSAMPLES - rsPointer) ;
        rsPointer = 0;
        
        [ unbufferedTarget needData:_resampledBuffer samples:UBUFSAMPLES channels:_channels ] ;
        
        
        memcpy((void*)&(_resampledBuffer2[inBufferCount]), (void*)_resampledBuffer, (samplesToCollect - inBufferCount) * sizeof(float) * _channels);
        rsPointer += (samplesToCollect - inBufferCount);
        
    }
    
    if(rsPointer >= UBUFSAMPLES) rsPointer = 0;
    
    return _resampledBuffer2;
    
}



- (void)setUseConstantOutputBufferSize:(Boolean)constant
{
	useConstantOutputBufferSize = constant ;
}

- (void)makeNewRateConverter
{
	AudioStreamBasicDescription in, out ;
	UInt32 quality ;
	OSStatus status ;
    
	if ( _rateConverter != nil) {
		//  a rate converter already exists
		AudioConverterReset( _rateConverter ) ;
		AudioConverterDispose( _rateConverter ) ;
		_rateConverter = nil ;
	}
	in = _basicDescription ;
	in.mSampleRate = inputSamplingRate ;
	out = _basicDescription ;
	out.mSampleRate = outputSamplingRate ;
	
	_collectedSamples = 0 ;			//  v0.85
    _originalRequest  = 0;
    _packetsPerBuffer = 0;
	
	//  create a SamplerateConverter for this read thread
	status = AudioConverterNew( &in, &out, &_rateConverter ) ;
    CheckError(status, "Error creating rate Converter");
	
	//  set up as high quality rate converter
	quality = kAudioConverterQuality_Max ;
	status = AudioConverterSetProperty( _rateConverter, kAudioConverterSampleRateConverterQuality, sizeof( UInt32 ), &quality ) ;
    CheckError(status, "Error setting converter property to max quality");
	currentInputSamplingRate = inputSamplingRate ;
	currentOutputSamplingRate = outputSamplingRate ;
}

//	return -1 if EOF
//	return number of samples otherwise
- (int)readResampledData:(float*)buf samples:(int)samples
{
	OSStatus status ;
	UInt32 audioConvertByteSize ;
	
    
    
	if ( [ self eof ] == YES ) return -1 ;
	
	if ( _rateConverter == nil || inputSamplingRate != currentInputSamplingRate || outputSamplingRate != currentOutputSamplingRate ) {
		//  need to create new rate converter
		[ self makeNewRateConverter ] ;
	}
    
    UInt32 size = sizeof(_maxPacketSize);
    CheckError(AudioConverterGetProperty(_rateConverter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &_maxPacketSize),
               "Couldn't get kAudioConverterPropertyMaximumOutputPacketSize");
    
    
    
    audioConvertByteSize = samples * _basicDescription.mChannelsPerFrame * sizeof(float);
    
    if(_maxPacketSize > audioConvertByteSize) audioConvertByteSize = _maxPacketSize;
    
    _packetsPerBuffer = audioConvertByteSize / _maxPacketSize;
    AudioBufferList outputBufferList;
    outputBufferList.mNumberBuffers = 1;
    outputBufferList.mBuffers[0].mNumberChannels = _basicDescription.mChannelsPerFrame;
    outputBufferList.mBuffers[0].mDataByteSize = audioConvertByteSize;
    outputBufferList.mBuffers[0].mData = (void*) buf;
    
    
	if ( unbufferedTarget != nil ) {
        
        status = AudioConverterFillComplexBuffer(_rateConverter, (AudioConverterComplexInputDataProc)unbufferedResampleProc , (__bridge void*)self, &_packetsPerBuffer, &outputBufferList, NULL);
        CheckError(status, "audio converter fill complex buffer - readResambledData resampling pipe - unbufferedResampleProc");
        //        if(status != noErr) {
        //            NSLog(@"audioConvertByteSize = %d : samples = %d ", audioConvertByteSize, samples);
        //        }
		//status = AudioConverterFillBuffer( rateConverter, unbufferedResampleProc, (__bridge void *)(self), &audioConvertByteSize, buf ) ;
	}
	else {
        status = AudioConverterFillComplexBuffer(_rateConverter, resampleProc , (__bridge void*)self, &_packetsPerBuffer, &outputBufferList, NULL);
        CheckError(status, "audio converter fill complex buffer - readResambledData resampling pipe - resampleProc");
		//status = AudioConverterFillBuffer( rateConverter, resampleProc, (__bridge void *)(self), &audioConvertByteSize, buf ) ;
        //if(status == noErr)NSLog(@"SUCCESS packetsPerBuffer = %d : mDataByteSize = %d ", audioConvertByteSize, outputBufferList.mBuffers[0].mDataByteSize);
	}
    
    if(status == noErr) {
        buf = outputBufferList.mBuffers[0].mData;
        return outputBufferList.mBuffers[0].mDataByteSize / (sizeof(float) * _basicDescription.mChannelsPerFrame); //	v0.92 was fixed to stereo in v0.90
    }
    
    buf =NULL;
    return 0;
    
	//return 0 ;
}

@end
