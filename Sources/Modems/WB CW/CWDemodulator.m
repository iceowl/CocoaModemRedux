//
//  CWDemodulator.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/2/06.
	#include "Copyright.h"
	
	
#import "CWDemodulator.h"
#import "CMFSKTypes.h"
#import "CWMixer.h"
#import "CWMatchedFilter.h"
#import "MorseDecoder.h"
#import "CWPStruct.h"
#import "CWReceiver.h"
#import "RTTYAuralMonitor.h"



@implementation CWDemodulator

@synthesize p = _p;
@synthesize cwReceiver = _cwReceiver;

//  copy of CMFSKPipeline
//typedef struct {
//	CMBandpassFilter *bandpassFilter;
//    CMBandpassFilter *originalBandpassFilter;
//	CWMixer *mixer;
//	CWMatchedFilter *matchedFilter;
//    CWMatchedFilter *originalMatchedFilter;
//	CMATC *atc ;
//	MorseDecoder *decoder;
//} CWPStruct ;


-(id) init {
     self = [super init];
    
    defaultTonePair.mark = 1500.0;
    defaultTonePair.space = 0.0;
    defaultTonePair.baud = 45.45  ;
	MorseDecoder *decoder ;
    decoder = [ [ MorseDecoder alloc ] initWithDemodulator:self ] ;
    [ self initPipelineStages:&defaultTonePair decoder:decoder bandwidth:100.0 ] ;

    
    _p  = [[CWPStruct alloc] initWithCMFSKPipeline:self.pipeline :decoder];
	//CWMatchedFilter *matchedFilter ;
	
	isRTTY = NO ;
	tonePair = defaultTonePair ;
	//p = malloc(sizeof( CWPStruct ));
	// -- bandpass filter (none)
	_p.bandpassFilter = _p.originalBandpassFilter = nil ;
	//  -- CW mixer (mixes signal to I&Q baseband
    _p.mixer = [ [ CWMixer alloc ] init ] ;
	[ _p.mixer setTonePair:&defaultTonePair ] ;
    [self.pipeline.mixer setTonePair:&defaultTonePair];
	[ _p.mixer setAural:NO ] ;
    [ _p.mixer setReceiver:_cwReceiver];
	// -- matched filter, change baud rate to match tone pair
	//matchedFilter = [ [ CWMatchedFilter alloc ] initDefaultFilterWithBaudRate:100.0 ] ;
	_p.matchedFilter = _p.originalMatchedFilter = [ [ CWMatchedFilter alloc ] initDefaultFilterWithBaudRate:100.0 ] ;
	//  -- Morse decoder, sends data back to -receivedCharacter: of self
	_p.decoder = decoder ;
	//  unused CW plug-ins
	_p.atc = nil ;
    

    
    return self;
    
    
}



- (void)initPipelineStages:(CMTonePair*)pair decoder:(MorseDecoder*)decoder bandwidth:(float)bandwidth
{
    
    
   // [super initPipelineStages:pair decoder:decoder atc:NULL bandwidth:bandwidth];
    
	//_p  = [[CWPStruct alloc] initWithCMFSKPipeline:self.pipeline :decoder];
    _p = [ [ CWPStruct alloc] init];
	//CWMatchedFilter *matchedFilter ;
	
	isRTTY = NO ;
	tonePair = *pair ;
	//p = malloc(sizeof( CWPStruct ));
	// -- bandpass filter (none)
	_p.bandpassFilter = _p.originalBandpassFilter = nil ;
	//  -- CW mixer (mixes signal to I&Q baseband
  	//_p.mixer = [ [ CWMixer alloc] init];
	[ _p.mixer setTonePair:pair ] ;
	[ _p.mixer setAural:NO ] ;
    [ _p.mixer setReceiver:_cwReceiver];
	// -- matched filter, change baud rate to match tone pair
	//matchedFilter = [ [ CWMatchedFilter alloc ] initDefaultFilterWithBaudRate:100.0 ] ;
	_p.matchedFilter = _p.originalMatchedFilter = [ [ CWMatchedFilter alloc ] initDefaultFilterWithBaudRate:100.0] ;
	//  -- Morse decoder, sends data back to -receivedCharacter: of self
	_p.decoder = decoder ;
	//  unused CW plug-ins
	_p.atc = nil ;
    
    return ;
}

- (void)setLatency:(int)value
{
	//CWPStruct *cwp = (CWPStruct*)self.pipeline;

	[ _p.matchedFilter setLatency:value ] ;
}

- (void)setCWBandwidth:(float)bandwidth
{
	//CWPStruct *cwp = (CWPStruct*)self.pipeline;

	//  use constant 250 Hz filter for automatic decoding
	//if ( _p.mixer ) [ _p.mixer setCWBandwidth:250.0 ] ;
    if ( _p.mixer ) [ _p.mixer setCWBandwidth:300.0 ] ;
    
}

- (void)useMatchedFilter:(CMPipe*)mf
{
	//  matched filter bank not used in CW mode
}


- (void)setTonePair:(const CMTonePair*)inTonePair
{
	
	tonePair = *inTonePair ;
	if ( _p.mixer ) [ _p.mixer setTonePair:&tonePair ] ;
	if ( _p.atc ) [ _p.atc setBitSamplingFromBaudRate:tonePair.baud ] ;
}

- (id)initFromReceiver:(CWReceiver*)cReceiver
{
	defaultTonePair.mark = 1500.0;
    defaultTonePair.space = 0.0;
    defaultTonePair.baud = 45.45  ;
	MorseDecoder *decoder ;
    
	//self = [ super init ] ;
	if ( self ) {
		receiver = (RTTYReceiver*)cReceiver ;
        _cwReceiver = cReceiver;
		delegate = nil ;
		decoder = [ [ MorseDecoder alloc ] initWithDemodulator:self ] ;
		[ self initPipelineStages:&defaultTonePair decoder:decoder bandwidth:100.0 ] ;
	}
	return self ;
}

- (void)dealloc
{
//	_p = (__bridge CWPStruct *)(_pipeline);
	
	[ self setClient:nil ] ;
    
}
- (void)setupDemodulatorChain
{
	//CWPStruct *cwp = (CWPStruct*)self.pipeline;

	//  connect AudioPipes
	[ _p.matchedFilter setDecoder:_p.decoder receiver:_cwReceiver ] ;
	[ _p.matchedFilter setClient:_p.decoder ] ;
	[ _p.mixer setClient:_p.matchedFilter ] ;
	[ _p.mixer setReceiver:_cwReceiver ] ;
}

- (void)newClick:(float)delta
{
	//CWPStruct *cwp = (CWPStruct*)self.pipeline;

	if ( _p.matchedFilter ) [ _p.matchedFilter newClick:delta ] ;
}

- (void)changeCodeSpeedTo:(int)speed
{
	//CWPStruct *cwp = (CWPStruct*)self.pipeline;

	if ( _p.matchedFilter ) [ _p.matchedFilter changeCodeSpeedTo:speed ] ;
}

- (void)changeSquelchTo:(float)squelch fastQSB:(float)fast slowQSB:(float)slow
{
	//CWPStruct *cwp = (CWPStruct*)self.pipeline;

	if ( _p.matchedFilter ) [ _p.matchedFilter setSquelch:squelch fastQSB:fast slowQSB:slow ] ;
}

- (void)importData:(CMPipe*)pipe
{	
	
	//  send data through the processing chain starting at the mixer
	if ( _p.mixer != nil ) {
        [ _p.mixer importData:pipe ] ;
    }
}

- (void)receivedCharacter:(int)c
{
	if ( delegate && [ delegate respondsToSelector:@selector(receivedCharacter:) ] ) [ delegate receivedCharacter:c ] ;
}

//  return a nil.
//  the BPF is no longer used in the CW mode
- (CMBandpassFilter*)makeFilter:(float)width
{
	return nil ;
}

- (void)makeDemodulatorActive:(Boolean)state
{
	if ( !isRTTY && _cwReceiver != nil ) [ [ _cwReceiver rttyAuralMonitor ] setDemodulatorActive:state ] ;
}


@end
