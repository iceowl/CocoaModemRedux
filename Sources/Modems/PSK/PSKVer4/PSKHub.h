//
//  PSKHub.h
//  cocoaModem 2.0  v0.57b
//
//  Created by Kok Chen on 10/18/08.
//  Copyright 2008 Kok Chen, W7AY. All rights reserved.
//

#define RBUF 8192*2

#import <Cocoa/Cocoa.h>
#import "DataPipe.h"
#import "PSKDemodulator.h"
#import "PSKBrowserTable.h"
#import "LitePSKDemodulator.h"
#import <AudioToolbox/AudioConverter.h>

@class PSK ;
@class PSKAuralMonitor ;
@class PSKReceiver ;
@class PSKHub;
//enum HubLockCondition {
//	kNoHubData,
//	kHasHubData
//} ;

typedef struct  {
    void *readData;
    float *audioStream;
    UInt32 maxPacketSize;
}ReadThreadStruct;

dispatch_queue_t g_PSKHubQueue;


@interface PSKHub : NSObject {
	Boolean hasBrowser ;
	PSKDemodulator *mainDemodulator ;
	PSKReceiver *receiver ;
	DataPipe *dataPipe ;
	NSLock *poolBusy ;	
	NSLock *pskDemodulatorLock ;		//  v0.66
		
	//  resampler
	AudioConverterRef rateConverter ;
	AudioStreamBasicDescription basicDescription, outDescription ;
   	//  states
	Boolean enabled ;
    Boolean running;
    ReadThreadStruct   rStruct;
    
    //__block PSKHub* pself;
}

@property  (retain) NSLock *poolBusy,*pskDemodulatorLock;
@property AudioConverterRef rateConverter;
@property AudioStreamBasicDescription basicDescription, outDescription;
@property AudioBuffer *audBuffer;
@property UInt32    maxPacketSize;
@property float  *audioStream;
@property (copy) __block PSKHub* pself;
@property  float  *pResampleBuffer;

void  CheckError  (OSStatus error , const char*  operation);

- (id)initHub ;
- (void)setDelegate:(PSKReceiver*)who ;
- (void)setPSKModem:(PSK*)modem index:(int)index ;
- (void)importData:(CMDataStream*)stream ;

- (Boolean)isEnabled ;
- (void)setupResampler ;
- (void)sendBufferToDemodulators:(float*)buffer samples:(int)samples ;

- (Boolean)demodulatorEnabled ;
- (void)enableReceiver:(Boolean)state ;
- (void)setReceiveFrequency:(float)tone ;
- (void)setPSKMode:(int)mode ;
- (void)selectFrequency:(float)freq fromWaterfall:(Boolean)fromWaterfall ;
- (float)receiveFrequency ;
- (void) readThread : (id) client;


@end
