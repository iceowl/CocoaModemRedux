//
//  CWAuralFilter.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 1/11/07.
#include "Copyright.h"


#import "CWAuralFilter.h"
#import "CWMixer.h"
#import "CWMatchedFilter.h"
#import "CMFSKTypes.h"
#import "CWPStruct.h"


@implementation CWAuralFilter
@synthesize myPipeline = _myPipeline;
@synthesize p = _p;
@synthesize cReceiver  = _cReceiver;

//  copy of CMFSKPipeline
//typedef struct {
//	CMBandpassFilter *bandpassFilter, *originalBandpassFilter ;
//	CWMixer *mixer ;
//	CWMatchedFilter *matchedFilter, *originalMatchedFilter ;
//	CMATC *atc ;
//	MorseDecoder *decoder ;
//} CWPStruct ;
//


//  NOTE: the aural filter does not have a morse decoder pipeline
- (void)initPipelineStages:(CMTonePair*)pair decoder:(MorseDecoder*)decoder bandwidth:(float)bandwidth
{
    // _myPipeline = [[CMFSKPipeline alloc] init];
    _myPipeline = self.pipeline = [ [ CMFSKPipeline alloc] init];
    
    _p = [[CWPStruct alloc] init];
    tonePair = *pair ;
	// -- bandpass filter (none)
	_p.bandpassFilter = _myPipeline.originalBandpassFilter = nil ;
	//  -- CW mixer (mixes signal to I&Q baseband)
	[_p setMixer: [ [ CWMixer alloc ] init ]] ;
	[ _p.mixer setTonePair:&tonePair ] ;
    [ _p.mixer setAural:YES ] ;
	//  unused plug-ins aural filter
	_p.decoder = nil ;
	_p.atc = nil ;
	_p.matchedFilter = _p.originalMatchedFilter = nil ;
}

- (void)setCWBandwidth:(float)bandwidth
{
	//CWPStruct *p = (CWPStruct*)_pipeline;
    
	if ( _p.mixer ) [ _p.mixer setCWBandwidth:bandwidth ] ;
}

- (id)initFromReceiver:(CWReceiver*)cwReceiver
{
	//CMTonePair defaultTonePair = { 1500.0, 0.0, 45.45 } ;
    
    //	self = [ super init ] ;
	if ( self ) {
		receiver = (RTTYReceiver*)cwReceiver ;
        _cReceiver = cwReceiver;
		delegate = nil ;
		[ self initPipelineStages:&(defaultTonePair) decoder:nil bandwidth:100.0 ] ;
        _p.mixer.receiver = cwReceiver;
	}
	return self ;
}

- (void)dealloc
{
	//CWPStruct *p = (CWPStruct*)_pipeline;
	
	[ self setClient:nil ] ;
    //	[ p->mixer release ] ;
    //	free( _pipeline ) ;
    //	[ super dealloc ] ;
}

//  overide base class to change AudioPipe pipeline (assume source is normalized baud rate)
//		self = CWDemodulator (importData:)
//		. mixer
//		. aural monitor

- (void)setupDemodulatorChain
{
	//CWPStruct *p = (CWPStruct*)_pipeline;
    
	//  connect AudioPipes (only mixer is used)
    if(_p.mixer.receiver == nil) [ _p.mixer setReceiver:_cReceiver ] ;
}

- (void)importData:(CMPipe*)pipe
{
    [ _p.mixer importData:pipe ] ;
}


@end
