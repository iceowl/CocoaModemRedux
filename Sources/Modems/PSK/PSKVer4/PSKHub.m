//
//  PSKHub.m
//  cocoaModem 2.0  v0.57b
//
//  Created by Kok Chen on 10/18/08.
//  Copyright 2008 Kok Chen, W7AY. All rights reserved.
//

#import "PSKHub.h"
#import "PSK.h"
#import "PSKDemodulator.h"
#import "PSKReceiver.h"
#import "Waterfall.h"
#import <AudioUnit/AudioUnitProperties.h>

#define	REMOVECOUNT		6		// defer removal from LitPSKDemodulator list (in case of QSB)

@implementation PSKHub

@synthesize outDescription     = _outDescription;
@synthesize basicDescription   = _basicDescription;
@synthesize rateConverter      = _rateConverter;
@synthesize poolBusy           = _poolBusy;
@synthesize pskDemodulatorLock = _pskDemodulatorLock;
@synthesize audBuffer          = _audBuffer;
@synthesize maxPacketSize      = _maxPacketSize;
@synthesize audioStream        = _audioStream;
@synthesize pself              = _pself;
@synthesize pResampleBuffer    = _pResampleBuffer;


//  local
//  set up AudioConverter to resample from 11025 to 8000 samples per second
- (void)setupResampler
{
	//AudioStreamBasicDescription basicDescription, outDescription ;
	OSStatus status ;
	
	_basicDescription.mSampleRate = 11025 ;
	_basicDescription.mFormatID = kAudioFormatLinearPCM ;
	_basicDescription.mFormatFlags = kLinearPCMFormatFlagIsFloat ;
//#if __BIG_ENDIAN__
//	_basicDescription.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian ;
//#endif
	_basicDescription.mFramesPerPacket = 1 ;
	_basicDescription.mChannelsPerFrame = 1 ;
	_basicDescription.mBytesPerFrame = 4 * _basicDescription.mChannelsPerFrame ;
	_basicDescription.mBytesPerPacket = 4 * _basicDescription.mChannelsPerFrame ;
	_basicDescription.mBitsPerChannel = 32 ;
    
    _outDescription.mFormatID = kAudioFormatLinearPCM ;
	_outDescription.mFormatFlags = kLinearPCMFormatFlagIsFloat ;
//#if __BIG_ENDIAN__
//	_outDescription.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian ;
//#endif
	_outDescription.mFramesPerPacket = 1 ;
	_outDescription.mChannelsPerFrame = 1 ;
	_outDescription.mBytesPerFrame = 4 * _basicDescription.mChannelsPerFrame ;
	_outDescription.mBytesPerPacket = 4 * _basicDescription.mChannelsPerFrame ;
	_outDescription.mBitsPerChannel = 32 ;
	_outDescription.mSampleRate = 8000 ;
    
	//  create a SamplerateConverter for this read thread
	status = AudioConverterNew( &_basicDescription, &_outDescription, &_rateConverter ) ;
    CheckError(status, "AudioConverterNew failed in PSKHub");
	//  set up as high quality rate converter
	UInt32 quality = kAudioConverterQuality_Max ;
	status = AudioConverterSetProperty( _rateConverter, kAudioConverterSampleRateConverterQuality, sizeof( UInt32 ), &quality ) ;
    CheckError(status, "AudioConverterSetProperty failed in PSKHub");
	//  create a pipe for the input data and read thread to pull the resampled data
	//[ NSThread detachNewThreadSelector:@selector(readThread:) toTarget:self withObject:self ] ;
    [ self readThread: _pself];
}

- (id)initHub
{
	self = [ super init ] ;
	if ( self ) {
		_poolBusy = [ [ NSLock alloc ] init ] ;
		_pskDemodulatorLock = [ [ NSLock alloc ] init ] ;
		//dataPipe = [ [ DataPipe alloc ] initWithCapacity:2048*sizeof(float) ] ;
        dataPipe  = [ [ DataPipe alloc ] initWithCapacity:16384*128*sizeof(float)];
		receiver = nil ;
		hasBrowser = NO ;
		enabled = NO ;
		running = FALSE;
		//  main demodulator
		mainDemodulator = [ [ PSKDemodulator alloc ] init ] ;
		[ mainDemodulator setDelegate:self ] ;
        _audioStream = malloc(RBUF);
        _pResampleBuffer = malloc(RBUF);
        _pself = self;
        //[ self setupResampler ] ;
	}
	return self ;
}

- (void)dealloc
{
	AudioConverterReset( _rateConverter ) ;
	AudioConverterDispose( _rateConverter ) ;
	//[ dataPipe release ] ;
	//[ pskDemodulatorLock release ] ;
	//[ poolBusy release ] ;
	
	//[ super dealloc ] ;
}

- (void)setPSKModem:(PSK*)modem index:(int)index
{
	if ( mainDemodulator ) [ mainDemodulator setPSKModem:modem index:index ] ;
}

//  callback only used by PSKBrowserHub
- (void)newFFTBuffer:(float*)inSpectrum
{
}

- (Boolean)demodulatorEnabled
{
	return [ mainDemodulator isEnabled ] ;
}

- (void)enableReceiver:(Boolean)state
{
	enabled = state ;
	[ mainDemodulator enableReceiver:state ] ;
}

//  wait for demodulator to go completely quiescent before releasing it
- (void)delayedRelease:(NSTimer*)timer
{
	LitePSKDemodulator *u ;
	
	u = [ timer userInfo ] ;
	//[ u release ] ;
}


- (void)setReceiveFrequency:(float)tone
{
	[ mainDemodulator setReceiveFrequency:tone ] ;
}

- (void)setPSKMode:(int)mode
{
	[ mainDemodulator setPSKMode:mode ] ;
}

- (void)selectFrequency:(float)freq fromWaterfall:(Boolean)fromWaterfall
{
	[ mainDemodulator selectFrequency:freq fromWaterfall:fromWaterfall ] ;
}

- (float)receiveFrequency
{
	return [ mainDemodulator receiveFrequency ] ;
}

- (void)setDelegate:(PSKReceiver*)delegate
{
	receiver = delegate ;
	[ mainDemodulator setDelegate:receiver ] ;
}

//  New resampled data buffer (at 8000 s/s) arrives.
- (void)sendBufferToDemodulators:(float*)buffer samples:(int)samples
{
	assert( samples == 512 ) ;
	[ mainDemodulator newDataBuffer:buffer samples:samples ] ;
}

//  ------------------------------------------------------------------------
//	AudioConverterInputDataProc (see CoreAudio AudioConverter documentation)
//
//  AudioConverterFillBuffer in the readThread causes data to be read from this proc.
//  readThread will block here if there is no data in the pipe.

//static OSStatus inputResampleProc( AudioConverterRef converter, UInt32 *dataSize, void **outData, void *userData )

static OSStatus inputResampleProc(AudioConverterRef converter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription** aspd, void* userData)
{
    
	ReadThreadStruct *obj = (ReadThreadStruct*)(userData) ;
    DataPipe *dp = (__bridge DataPipe*)obj->readData;
	
	// block here waiting for data
	[ dp readData:(void*)(obj->audioStream) length:512*obj->maxPacketSize ] ;
    
	ioData->mBuffers[0].mData =(void*)( obj->audioStream);
    ioData->mBuffers[0].mDataByteSize = 512*obj->maxPacketSize;
	*ioNumberDataPackets = 512;
    
	return noErr;
}

//  This thread runs constantly (but is blocked in the inputResampleProc when data is stopped (nothing coming input -importBuffer).
- (void)readThread : (id) client
{
    
    UInt32 size = sizeof(_maxPacketSize);
    CheckError(AudioConverterGetProperty(_rateConverter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &_maxPacketSize),
               "Couldn't get kAudioConverterPropertyMaximumOutputPacketSize");
    
    
    
    if(running) {
        NSLog(@"already running read thread for pskHub - exiting");
        return;
    }
    
    
    __block UInt32 outputSamples = 512;
    __block AudioBufferList outputBufferList;
    __block UInt32 audioConvertByteSize;
    
    audioConvertByteSize = 512 * _basicDescription.mChannelsPerFrame * sizeof(float);
    
    if(_maxPacketSize > audioConvertByteSize) audioConvertByteSize = _maxPacketSize;
    
    __block UInt32 _packetsPerBuffer = audioConvertByteSize / _maxPacketSize;
    
    
    
    audioConvertByteSize = 512*sizeof( float )*_outDescription.mChannelsPerFrame ;
    outputBufferList.mBuffers[0].mNumberChannels = _outDescription.mChannelsPerFrame;
	//  Loop continuously requesting data at 8000 s/s.
	//  This thread will block in the inputResampleProc
	//  When a complete buffer is received, it is sent to -hasNewdata
    
    if(g_PSKHubQueue == nil) g_PSKHubQueue = dispatch_queue_create("com.owlhousetoys.PSKHub", DISPATCH_QUEUE_CONCURRENT);
    NSLog(@"PSKHub read thread started for PSKHub");
    
    
    outputBufferList.mNumberBuffers              = 1;
    outputBufferList.mBuffers[0].mDataByteSize   = outputSamples*sizeof(float);
    outputBufferList.mBuffers[0].mData           = _pResampleBuffer;
    
    rStruct.audioStream = _audioStream;
    rStruct.maxPacketSize = _maxPacketSize;
    rStruct.readData = (void*)CFBridgingRetain(dataPipe);
    
    dispatch_async(g_PSKHubQueue, [^(void) {
    
    while ( 1 ) {
        //  get rate converted data and send to client
        OSStatus status = AudioConverterFillComplexBuffer(_rateConverter, (AudioConverterComplexInputDataProc)inputResampleProc,(void*)&rStruct, &_packetsPerBuffer, &outputBufferList, NULL);
        CheckError(status, "audio converter fill complex buffer - readThread PSKHub inputResampleProc");
        //if(status != noErr) NSLog(@" fill complex buffer failed in PSKHub read Thread %d",status);
        //status = AudioConverterFillBuffer( rateConverter, inputResampleProc, (__bridge void *)(self), &audioConvertByteSize, inputBuffer ) ;
        if ( status == noErr ) {
            int samples = audioConvertByteSize / sizeof( float ) ;
            [ _pself sendBufferToDemodulators:(float*)outputBufferList.mBuffers[0].mData samples:samples ] ;
        }
        
    }
    NSLog(@"PSKHub read thread exit");
        
    } copy]);
        
        
    
     //dispatch_async_f(g_PSKHubQueue,(void*)CFBridgingRetain(self),_rb(outputBufferList,&audioConvertByteSize,(void*)CFBridgingRetain(self),_rateConverter, inputResampleProc));
	//[ pool release ] ;
    
	//[ NSThread exit ] ;
}


- (Boolean)isEnabled
{
	return [ mainDemodulator receiverEnabled ] ;
}

//  How it works:
//
//  Data comes here from PSKReceiver as 512 floating point packets at 11025 (CMFs) samples/second.
//  we simply write the 512 floating point samples into the resampling pipe.
//  This will be subsequently be picked up by a waiting -inputResampleProc that is initiated when the readThread calls AudioConverter.
//	The readThread is blocked by the inputResamplingProc, which in turn is blocked waiting for a buffer write from here.
//	The readThread receives 8000 s/s data, which it then send to the demodulators.
- (void)importData:(CMDataStream*)stream
{
	//CMDataStream *stream ;
	
	if ( ![ self isEnabled ] ) return ;
    
	[ _poolBusy lock ] ;
	//stream = [ pipe stream ] ;
	[ dataPipe write:stream->array length:512*sizeof( float ) ] ;
	[ _poolBusy unlock ] ;
}

@end
