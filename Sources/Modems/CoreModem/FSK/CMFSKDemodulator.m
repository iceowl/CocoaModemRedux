//
//  CMFSKDemodulator.m
//  CoreModem
//
//  Created by Kok Chen on 10/24/05.
	#include "Copyright.h"

#import "CMFSKDemodulator.h"
#import "CMATC.h"
#import "CMBaudotDecoder.h"
#import "RTTYAuralMonitor.h"
#import "RTTYMixer.h"
#import "RTTYReceiver.h"
#import "CMFSKMatchedFilter.h"
#import "CMFSKTypes.h"
#import "CMFSKPipeline.h"

@implementation CMFSKDemodulator

@synthesize pipeline = _pipeline;

//  Initialize default filters
- (void)initPipelineStages:(CMTonePair*)pair decoder:(CMBaudotDecoder*)decoder atc:(CMPipe*)atc bandwidth:(float)bandwidth
{
	_pipeline  = [[CMFSKPipeline alloc] init];
	CMFSKMatchedFilter *matchedFilter ;
	
	isRTTY = YES ;
	tonePair = *pair ;
    //_pipeline = ( void* )malloc( sizeof( CMFSKPipeline ) );
   // _pipeline = [[CMFSKPipeline alloc] init];
	
	
	// -- bandpass filter
	_pipeline.bandpassFilter = _pipeline.originalBandpassFilter = [ self makeFilter:bandwidth ] ;
	
	// -- matched filter, change baud rate to match tone pair
	matchedFilter = [ [ CMFSKMatchedFilter alloc ] initDefaultFilterWithBaudRate:tonePair.baud ] ;
	[ matchedFilter setDataRate:tonePair.baud ] ;
	_pipeline.matchedFilter = _pipeline.originalMatchedFilter = matchedFilter ;
	
	//  -- RTTY mixer
	_pipeline.mixer = [ [ RTTYMixer alloc ] init ] ;
	[ _pipeline.mixer setTonePair:&tonePair ] ;
	[ _pipeline.mixer setDemodulator:self ] ;				//  v0.78
	//[ _pipeline.mixer setAuralMonitor: [ receiver rttyAuralMonitor ] ] ;
	//  -- adaptive thresholder
	_pipeline.atc = [[CMATC alloc] init] ;
	[ _pipeline.atc setInvert:sidebandState ] ;
	[ _pipeline.atc setBitSamplingFromBaudRate:tonePair.baud ] ;
	
	//  -- Baudot decoder, sends data back to -receivedCharacter: of self
	_pipeline.decoder = decoder ;

}

- (id)initFromReceiver:(RTTYReceiver*)rcvr
{
	CMTonePair defaultTonePair = { 2125.0, 2295.0, 45.45 } ;
	CMBaudotDecoder *decoder ;
	CMATC *atc ;

	self = [ super init ] ;
	if ( self ) {
		isRTTY = YES ;
		delegate = nil ;
	//	receiver = rcvr ;
		decoder = [ [ CMBaudotDecoder alloc ] initWithDemodulator:self ] ;
		atc = [ [ CMATC alloc ] init ] ;
		[ self initPipelineStages:&defaultTonePair decoder:decoder atc:atc bandwidth:306.35 ] ;
	}
	return self ;
}

- (id)initSuper
{
	self = [ super init ] ;
	return self ;
}

-(id) init {
    
    self = [super init];
    if(self)_pipeline  = [[CMFSKPipeline alloc] init];
    return self;
}

- (void)dealloc
{
//	CMFSKPipeline *p = (__bridge CMFSKPipeline*)_pipeline;
	
	[ self setClient:nil ] ;
//	[ p.decoder release ] ;
//	[ p.atc release ] ;
//	[ p.mixer release ] ;
//	if ( p.bandpassFilter == p.originalBandpassFilter ) [ p->bandpassFilter release ] ;
//	if ( p->matchedFilter == p->originalMatchedFilter ) [ p->matchedFilter release ] ;
	//free(_pipeline ) ;
//	[ super dealloc ] ;
}

//- (RTTYReceiver*)receiver
//{
//	return receiver ;
//}

- (Boolean)isRTTY
{
	return isRTTY ;
}

- (CMFSKMixer*)mixer
{
	return  _pipeline.mixer ;
}

//- (void)makeDemodulatorActive:(Boolean)state
//{
//	if ( isRTTY && receiver != nil ) [ [ receiver rttyAuralMonitor ] setDemodulatorActive:state ] ;
//}

- (void)replaceDecoderWith:(CMBaudotDecoder*)decoder
{
	if ( decoder ) {
		//if ( p.decoder ) [ p->decoder release ] ;
		[_pipeline setDecoder:decoder] ;
	}
}

//  overide base class to change AudioPipe pipeline (assume source is normalized baud rate)
//		self (importData:)
//		. bandpassFilter
//		. mixer
//		. matchedFilter
//		. ATC
//		. BaudotDecoder
//		. self (receivedCharacter:)

- (void)setupDemodulatorChain
{

	//  connect AudioPipes
	[ _pipeline.atc setClient:_pipeline.decoder ] ;
	[ _pipeline.matchedFilter setClient:_pipeline.atc ] ;
	[ _pipeline.mixer setClient:_pipeline.matchedFilter ] ;
	[ _pipeline.bandpassFilter setClient:_pipeline.mixer ] ;
	[ self setClient:_pipeline.bandpassFilter ] ;			//  importData is exported to bandpassFilter by base class
}

//  v0.88d
- (void)setConfig:(ModemConfig*)config
{
    [ _pipeline.mixer setConfig:config ] ;
}

- (void)setBitsPerCharacter:(int)bits
{
	[ _pipeline.atc setBitsPerCharacter:bits ] ;
}

- (void)importData:(CMPipe*)pipe
{
	
	//  send data through the processing chain starting at the bandpass filter
	if ( _pipeline.bandpassFilter ) [ _pipeline.bandpassFilter importData:pipe ] ;
}

//  v0.76 tap client (used by RTTYMonitor) is now the matched filter output
- (void)setTap:(CMPipe*)tap
{
	[_pipeline.matchedFilter setTap:tap ] ;
}

//  NOTE: this is no longer called
- (void)exportData
{
	if ( self.outputClient ) {
		if ( self.isPipelined ) [ self.outputClient importPipelinedData:self ] ; else [ self.outputClient importData:self ] ;
	}
}

//  return a CMBandpassFilter that has passband centered around the current mark and space carriers.
- (CMBandpassFilter*)makeFilter:(float)width
{
	float lower, upper, delta, shift ;
	CMBandpassFilter *f ;
	
	if ( tonePair.mark < tonePair.space ) {
		lower = tonePair.mark ;
		upper = tonePair.space ;
	}
	else {
		lower = tonePair.space ;
		upper = tonePair.mark ;
	}
	shift = upper - lower ;
	delta = ( width - shift )*0.5 ;
	if ( delta < 0.0 ) delta = 0.0 ;
	
	f = [ [ CMBandpassFilter alloc ] initLowCutoff:lower-delta highCutoff:upper+delta length:256 ] ;
	[ f setUserParam:delta ] ;
	return f ;
}

//  retrieves userParam from bandpass filter and update passband based on current mark and space
- (void)updateFilter:(CMBandpassFilter*)f
{
	float lower, upper, delta ;
	
	if ( tonePair.mark < tonePair.space ) {
		lower = tonePair.mark ;
		upper = tonePair.space ;
	}
	else {
		lower = tonePair.space ;
		upper = tonePair.mark ;
	}
	delta = [ f userParam ] ;
	if ( delta < 0.0 ) delta = 0.0 ;
	[ f updateLowCutoff:lower-delta highCutoff:upper+delta ] ;
}

- (void)setDelegate:(id)inDelegate
{
	delegate = inDelegate ;
}

- (id)delegate
{
	return delegate ;
}

//  called from Baudot decoder when a new character is decoded
- (void)receivedCharacter:(int)c
{
	if ( delegate && [ delegate respondsToSelector:@selector(receivedCharacter:) ] ) [ delegate receivedCharacter:c ] ;
}

- (void)useMatchedFilter:(CMPipe*)mf
{
	CMPipe *old ;
	
	
	if ( _pipeline.matchedFilter == mf ) return ;
	old = _pipeline.matchedFilter ;
	[ mf setClient:_pipeline.atc ] ;
	[ _pipeline.mixer setClient:mf ] ;
	_pipeline.matchedFilter = (CMFSKMatchedFilter*)mf ;
	//[ old release ] ;
}

- (void)useBandpassFilter:(CMPipe*)bpf
{
	CMPipe *old ;
	
	if ( _pipeline == nil || _pipeline.bandpassFilter == bpf ) return ;
	old = _pipeline.bandpassFilter ;
	[ bpf setClient:_pipeline.mixer ] ;
	[ self setClient:bpf ] ;
	_pipeline.bandpassFilter = (CMBandpassFilter*)bpf ;
//	[ old release ] ;
}

//  set up the tone pair and baud rate parameters of the demodulator
- (void)setTonePair:(const CMTonePair*)inTonePair
{
	
	tonePair = *inTonePair ;
	if ( _pipeline.mixer ) [ _pipeline.mixer setTonePair:&tonePair ] ;
	if ( _pipeline.atc ) [ _pipeline.atc setBitSamplingFromBaudRate:tonePair.baud ] ;
}

- (void)setEqualizer:(int)index
{
	if ( _pipeline.atc ) [ _pipeline.atc setEqualize:index ] ;
}

//  unshift-on-space, pass it on to the Baudot decoder
- (void)setUSOS:(Boolean)state
{

	if ( _pipeline != nil ) [ _pipeline.decoder setUSOS:state ] ;
}

- (void)setBell:(Boolean)state
{
	

	if ( _pipeline != nil ) [ _pipeline.decoder setBell:state ] ;
}

- (void)setLTRS:(Boolean)state
{
	
	
	if ( _pipeline.decoder ) [ _pipeline.decoder setLTRS ] ;
}

- (void)setSquelch:(float)value
{
	if ( _pipeline.atc ) [_pipeline.atc setSquelch:value ] ;
}

- (CMPipe*)baudotWaveform
{
	return  _pipeline.atc ;
}

- (CMPipe*)atcWaveform
{
	return [ _pipeline.atc atcWaveformBuffer ] ;
}

- (void)makeDemodulatorActive:(Boolean)state
{
	if ( isRTTY && receiver != nil ) [ [ receiver rttyAuralMonitor ] setDemodulatorActive:state ] ;
}


@end
