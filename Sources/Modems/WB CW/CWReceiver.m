//
//  CWReceiver.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/2/06.
	#include "Copyright.h"
	
#import "CWReceiver.h"
#import "CWAuralFilter.h"
#import "CWDemodulator.h"
#import "CWMonitor.h"
#import "CWRxControl.h"
#import "RTTYAuralMonitor.h"

//enum LockCondition {
//	kNoData,
//	kHasData
//} ;

@implementation CWReceiver

- (id)initReceiver:(int)index modem:(Modem*)modem
{
	CMTonePair defaultTones = { 1500, 0.0, 45.45 } ;
	//self = [super init];
	//self = [ super initReceiver:index modem:modem ] ;
	if ( self ) {
		uniqueID = index ;
		receiveView = nil ;
		//cwRxControl = nil;
		self.squelch = nil ;
		currentTonePair = defaultTones ;
		enabled = slashZero = sidebandState = NO ;
		self.demodulatorModeMatrix = nil ;					//  only used by RTTYReceiver
		self.bandwidthMatrix = nil ;							//  only used by RTTYReceiver
		appleScript = nil ;
		monitor = nil ;
		
		buffer = 0 ; 
		[ self changingStateTo:NO ] ;
		
		cwBandwidth = 100.0 ;
		cwFrequency = defaultTones.mark ;
		sidetoneFrequency = 689.0 ;
		sidetoneFilter = CMFIRBandpassFilter( sidetoneFrequency-cwBandwidth, sidetoneFrequency+cwBandwidth, CMFs, 64 ) ;
		
		vco = [ [ CMPCO alloc ] init ] ;
		[ vco setOutputScale:1.0 ] ;
		[ vco setCarrier:sidetoneFrequency ] ;
		
		//  local CMDataStream
        
		cmData.samplingRate = 11025.0 ;
		cmData.samples = 512 ;
		cmData.components = 1 ;
		cmData.channels = 1 ;
        self.data = &cmData;
		self.n_newData = [ [ NSConditionLock alloc ] initWithCondition:kNoData ] ;
		//[ NSThread detachNewThreadSelector:@selector(receiveThread:) toTarget:self withObject:self ] ;
        [self receiveThread];
		self.clickBufferLock = nil ;
		self.rttyAuralMonitor = [ [ RTTYAuralMonitor alloc] init];
		cwDemodulator = [ [ CWDemodulator alloc ] initFromReceiver:self ] ;
        demodulator = (RTTYDemodulator*)cwDemodulator;
		auralFilter = [ [ CWAuralFilter alloc ] initFromReceiver:self ] ;
		bandpassFilter = nil ;		
		[ self updateFilters ] ;
		
		return self ;
	}
	return nil ;
}

- (void)setupReceiverChain:(ModemConfig*)config monitor:(CWMonitor*)mon
{
	monitor = mon ;
	//  decoder
	[ cwDemodulator setupDemodulatorChain ] ;
	[ cwDemodulator setDelegate:self ] ;	//  demodulator calls back to receivedCharacter: delegate
	//  aural
	[ auralFilter setupDemodulatorChain ] ;
	[ auralFilter setDelegate:self ] ;	//  demodulator calls back to receivedCharacter: delegate
}

- (void)setCWSpeed:(float)wpm limited:(Boolean)limited
{
	int n ;
	
	n = wpm + 0.5 ;
	if ( cwRxControl ) [ cwRxControl setReportedSpeed:n limited:limited] ;
}

- (void)setMonitorEnable:(Boolean)state
{
	if ( cwRxControl ) [ cwRxControl setMonitorEnableButton:state ] ;
}

- (void)changeCodeSpeedTo:(int)speed
{
	[ (CWDemodulator*)cwDemodulator changeCodeSpeedTo:speed ] ;
}

- (void)newClick:(float)delta
{
	[ (CWDemodulator*)cwDemodulator newClick:delta ] ;
	[ auralFilter newClick:delta ] ;
}

- (void)setLatency:(int)value
{
	[ (CWDemodulator*)cwDemodulator setLatency:value ] ;
}

- (void)changeSquelchTo:(float)db fastQSB:(float)fast slowQSB:(float)slow
{
	[ (CWDemodulator*)cwDemodulator changeSquelchTo:db fastQSB:fast slowQSB:slow ] ;
}

- (void)changingStateTo:(Boolean)state
{
	//enabled = state;
}

- (void)received:(float*)inph quadrature:(float*)quad wide:(float*)wide samples:(int)n
{
	[ monitor push:inph quadrature:quad wide:wide samples:n ] ;		//  v0.78
}

- (void)setSidetoneFrequency:(float)freq
{
	sidetoneFrequency = freq ;
	[ self updateFilters ] ;
	[ vco setCarrier:sidetoneFrequency ] ;
}

//  called from CWMonitor when it needs another buffer for the sound device
- (void)needSidetone:(float*)outbuf inphase:(float*)inph quadrature:(float*)quad wide:(float*)wide samples:(int)n wide:(Boolean)iswide
{
	int i ;
	float x, y, intermediate[512] ;
	CMAnalyticPair pair ;
	
	if ( iswide ) {
		// wideband request
		memcpy( outbuf, wide, sizeof( float )*n ) ;
		return ;
	}
	//  narrowband request
	for ( i = 0; i < n; i++ ) {
		x = inph[ i ] ;
		y = quad[ i ] ;
		//  sidetone oscillator
		pair = [ vco nextVCOPair ] ;
		intermediate[i] = x*pair.re + y*pair.im ;
	}	
	CMPerformFIR( sidetoneFilter, intermediate, 512, outbuf ) ;
}

- (void)updateFilters
{
	float low, high ;
	
	low = sidetoneFrequency-cwBandwidth ;
	if ( low < 100 ) low = 100 ;
	high = sidetoneFrequency+cwBandwidth ;
	if ( high > 2800 ) high = 2800 ;
	CMUpdateFIRBandpassFilter( sidetoneFilter, low, high ) ;
}

- (void)rxTonePairChanged:(RTTYRxControl*)control
{
	CMTonePair tonePair ;
	
	cwRxControl = (CWRxControl*)control ;
	tonePair = [ control rxTonePair ] ;
	cwFrequency = tonePair.mark ;
	[ self updateFilters ] ;
	//  set mixer tones
	[ cwDemodulator setTonePair:&tonePair ] ;
	[ auralFilter setTonePair:&tonePair ] ;
}

//  set bandpass filter bandwidth for the receiver and any filters in the demodulator
- (void)setCWBandwidth:(float)bandwidth
{
	cwBandwidth = bandwidth ;
	[ self updateFilters ] ;
	if ( cwDemodulator ) [ (CWDemodulator*)cwDemodulator setCWBandwidth:cwBandwidth ] ;
	if ( auralFilter ) [ auralFilter setCWBandwidth:cwBandwidth ] ;
}

//  if the waterfall is clicked, the CWRxControl sends data here
- (void)importData:(CMPipe*)pipe
{
	CMDataStream *stream ;
	float *array;
    float *buf;

	//  send data to aural filter pipeline
	[ auralFilter importData:pipe ] ;

	//  check if we have a click buffer by looking to see if a lock exists
	if ( self.clickBufferLock != nil ) {
		if ( [ self.clickBufferLock tryLock ] ) {
			[ self.n_newData lockWhenCondition:kNoData ] ;
			//  copy data into tail of clickBuffer
			stream = [ pipe stream ] ;
			array = stream->array ;
			//  copy another 512 samples into the click buffer (memcpy has problems with auto release pools?)
			buf = self.clickBuffer[clickBufferProducer] ;
			memcpy( buf, array, 512*sizeof( float ) ) ;
			//  run the receive thread
			cmData.userData = stream->userData ;
			cmData.sourceID = stream->sourceID ;
			// signal receiveThread of new block of data that new data has arrived
            clickBufferProducer = ( clickBufferProducer+1 ) & 0x1ff ; // 512 click buffers
			[ self.n_newData unlockWithCondition:kHasData ] ;
			[ self.clickBufferLock unlock ] ;
		}
	}
	else {
		//  no click buffer -- simply use input stream
		[ cwDemodulator importData:pipe ] ;
	}
}


@end
