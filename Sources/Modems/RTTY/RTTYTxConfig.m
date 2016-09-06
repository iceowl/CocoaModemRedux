//
//  RTTYTxConfig.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 1/6/06.
#include "Copyright.h"


#import "RTTYTxConfig.h"
#import "Application.h"
#import "FSK.h"
#import "Messages.h"
#import "ModemDest.h"
#import "ModemEqualizer.h"
#import "Plist.h"
#import "RTTY.h"
#import "RTTYModulator.h"
#import "RTTYReceiver.h"
#import "RTTYRxControl.h"

@implementation RTTYTxConfig

@synthesize rttyRxControl = _rttyRxControl;
@synthesize configSet     = _configSet;
@synthesize afsk          = _afsk;
@synthesize fsk           = _fsk;
@synthesize transmitBPF   = _transmitBPF;
@synthesize currentHigh   = _currentHigh;
@synthesize currentLow    = _currentLow;
@synthesize myRig         = _myRig;

static float stopDuration[3] = { 1.0, 1.5, 2.0 } ;

/* local */
- (void)createTransmitBPF:(float)low high:(float)high
{
	float center, temp, w, t, x, f, baseband, sum, n ;
	int i ;
	
	//  place reasonable limits on tones
	if ( low < 600 ) low = 400 ;
	if ( high > 2750 ) high = 2750 ;
	
	if ( high < low ) {
		//  sanity check
		temp = high ;
		high = low ;
		low = temp ;
	}
	n = 128 ;
	center = ( low + high )*0.5 ;
	f = 0.5*center*n/CMFs ;
	w = 0.5*( high-low )*n/CMFs ;		//  bandwidth of sinc
	
	if ( fir ) free( fir ) ;
	fir = ( float* )malloc( sizeof( float )*n ) ;
	sum = 0 ;
	for ( i = 0; i < n; i++ ) {
		t = n/2 ;
		x = ( i - t )/t ;
		baseband = CMModifiedBlackmanWindow( i, n )*CMSinc( i, n, w ) ;
		sum += baseband ;
		fir[i] = baseband*cos( 2.0*CMPi*f*x ) ;
	}
	w = 2/sum ;
	for ( i = 0; i < n; i++ ) fir[i] *= w ;
	
	if ( _transmitBPF != nil ) CMDeleteFIR( _transmitBPF ) ;
	_transmitBPF = CMFIRFilter( fir, n ) ;
}

//  v0.67
- (CMTonePair*)transmitTonePair
{
	return [ _afsk toneFrequencies ] ;
}

//  v0.83
- (void)setBitsPerCharacter:(int)bits
{
	[ _afsk setBitsPerCharacter:bits ] ;
}

- (void)setupTonesFrom:(RTTYRxControl*)control lockTone:(Boolean)state
{
	float width, low, high ;
	int ilow, ihigh ;
	CMTonePair tonepair ;
	
	_rttyRxControl = control ;										// v0.50
	
	//  get tonepair with the order required by sideband and polarity
	tonepair = ( state ) ? [ control lockedTxTonePair ]  : [ control txTonePair ] ;
	
	[ _rttyRxControl transmitterTonePairChangedTo:&tonepair ] ;		//  v0.78
	
	//  set transmit tones
	[ _afsk setTonePair:&tonepair ] ;
	//  create a transmit band pass filter that covers up to 4th harmonic of signalling bits
	width = ( tonepair.baud/2 ) * 4 ;
	if ( tonepair.mark < tonepair.space ) {
		low = tonepair.mark - width ;
		high = tonepair.space + width ;
	}
	else {
		high = tonepair.mark + width ;
		low = tonepair.space - width ;
	}
	//  quantize to 0.1 Hz steps
	ilow = low*10 ;
	ihigh = high*10 ;
	if ( ilow != _currentLow || ihigh != _currentHigh ) {
		[ self createTransmitBPF:ilow*0.1 high:ihigh*0.1 ] ;
		_currentLow = ilow ;
		_currentHigh = ihigh ;
	}
}

//  NOTE:when RTTYTxControl is called, RTTYRxControl is not defined
- (void)awakeFromModem:(RTTYConfigSet*)set rttyRxControl:(RTTYRxControl*)control
{
	_rttyRxControl = nil ;
	rttyAuralMonitor = nil ;
	_configSet = set ;
	_myRig = [[NSApp delegate] myRig];
	_transmitBPF = nil ;
	fir = nil ;
	hasSetupDefaultPreferences = hasRetrieveForPlist = hasUpdateFromPlist = NO ;
	equalize = 1.0 ;
	_fsk = nil ;
	ook = 0 ;			//  v0.85
	usosState = YES ;
	_currentLow = _currentHigh = 0;
	//  set output to defaults
	if ( set.outputDevice != nil) {
		_currentLow = _currentHigh = 0 ;
		_afsk = [ [ RTTYModulator alloc ] init ] ;
		[ _afsk setModemClient:modemObj ] ;
        
		[ self setupModemDest:set.outputDevice controlView:soundOutputControls attenuatorView:soundOutputLevel ] ;
		[ modemDest setSoundLevelKey:set.outputLevel attenuatorKey:set.outputAttenuator ] ;
		//  color well changes
		[ self setInterface:transmitTextColor to:@selector(colorChanged) ] ;
		//  Transmit equalizer
		equalizer = [ [ ModemEqualizer alloc ] initSheetFor:set.outputDevice ] ;
	}
}

//  v0.78
- (void)setRTTYAuralMonitor:(RTTYAuralMonitor*)mon
{
	if ( _configSet.usesRTTYAuralMonitor == YES ) rttyAuralMonitor = mon ;
}

//  preferences maintainence, called from RTTY.m
//  setup default preferences (keys are found in Plist.h)
- (void)setupDefaultPreferences:(Preferences*)pref rttyRxControl:(RTTYRxControl*)control
{
	if ( hasSetupDefaultPreferences ) return ;		// already done (for interfaces with multiple receivers)
	hasSetupDefaultPreferences = YES ;
	
	_rttyRxControl = control ;
	
	if ( _configSet.stopBits ) [ pref setFloat:1.5 forKey:_configSet.stopBits ] ;
	[ self set:_configSet.sentColor fromRed:0.0 green:0.8 blue:1.0 into:pref ] ;
	[ modemDest setupDefaultPreferences:pref ] ;
	if ( equalizer ) [ equalizer setupDefaultPreferences:pref ] ;
}

- (void)updateColorsFromPreferences:(Preferences*)pref configSet:(RTTYConfigSet*)set
{
	//  set tx color
	[ transmitTextColor setColor:[ self getColor:set.sentColor from:pref ] ] ;
}

//  called when color well changes
- (void)colorChanged
{
	[ modemObj setTransmitTextColor:[ transmitTextColor color ] ] ;
}

//  called from RTTY.m
//  update all parameters from the plist (called after fetchPlist)
- (Boolean)updateFromPlist:(Preferences*)pref rttyRxControl:(RTTYRxControl*)control
{
	int index, version ;
	float stopValue  = 0.0;
    
	if ( hasUpdateFromPlist ) return YES ;		// already done (for interfaces with multiple receivers)
	hasUpdateFromPlist = YES ;
    
	_rttyRxControl = control ;
	
	[ self updateColorsFromPreferences:(Preferences*)pref configSet:_configSet ] ;
    
    
	if ( ![ modemDest updateFromPlist:pref ] ) {
		[ Messages alertWithMessageText:NSLocalizedString( @"RTTY settings needs to be reselected", nil ) informativeText:NSLocalizedString( @"Device removed", nil ) ] ;
	}
	if ( equalizer ) [ equalizer updateFromPlist:pref ] ;
    
	//  stop bits
	if ( _configSet.stopBits ) stopValue = [ pref floatValueForKey:_configSet.stopBits ] ;
	version = [ pref intValueForKey:kPrefVersion ] ;
	
	// fix bug in simple RTTY (not connected) stop value
	if ( stopValue < 1.1 && version == 2 ) stopValue = 1.5 ;
	
	index = 1 ;
	if ( stopValue < 1.1 ) index = 0 ; else if ( stopValue > 1.9 ) index = 2 ;
	if ( _configSet.stopBits ) {
		if ( stopBits ) [ stopBits selectCellAtRow:index column:0 ] ;
		if ( _afsk ) [ _afsk setStopBits:stopValue ] ;
	}
	return true ;
}

//  update preference dictionary for writing back into the plist file
- (void)retrieveForPlist:(Preferences*)pref rttyRxControl:(RTTYRxControl*)control
{
	int index ;
	
	if ( hasRetrieveForPlist ) return ;		// already done (for interfaces with multiple receivers)
	hasRetrieveForPlist = YES ;
	
	_rttyRxControl = control ;
    
	[ self set:_configSet.sentColor fromColor:[ transmitTextColor color ] into:pref ] ;
	//  rtty output prefs
	[ modemDest retrieveForPlist:pref ] ;
	if ( equalizer ) [ equalizer retrieveForPlist:pref ] ;
	// stop bits
	if ( stopBits ) {
		index =(int) [ stopBits selectedRow ] ;
		[ pref setFloat:stopDuration[index] forKey:_configSet.stopBits ] ;
	}
}

//  -------------- transmit stream ---------------------

//  v0.50
- (Boolean)startFSKTransmit
{
	float baudRate ;
	Boolean txInvert ;
	
	if ( _fsk == nil ) return NO ;
	
	if ( !isTransmit && !configOpen ) {
		baudRate = [ _rttyRxControl actualBaudRate ] ;
		txInvert = [ _rttyRxControl invertStateForTransmitter ] ;
		[ _fsk startSampling:baudRate invert:txInvert stopBits:(int)[ stopBits selectedRow ] ] ;
		if ( transmitButton ) {
			[ transmitButton setTitle:NSLocalizedString( @"Receive", nil ) ] ;
			[ transmitButton setState:NSOnState ] ;
		}
		isTransmit = YES ;
		return YES ;
	}
	isTransmit = NO ;
	[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
	if ( transmitButton ) {
		[ transmitButton setTitle:NSLocalizedString( @"Transmit", nil ) ] ;
		[ transmitButton setState:NSOffState ] ;
	}
	if ( configOpen ) {
		[ Messages alertWithMessageText:NSLocalizedString( @"Close Config Panel", nil ) informativeText:NSLocalizedString( @"Close Config Panel and try Again", nil ) ] ;
		[ modemObj flushAndLeaveTransmit ] ;
	}
	return NO ;
}

- (Boolean)startTransmit
{
	CMTonePair *tonepair ;
	float midFrequency ;
	
	if ( _fsk ) return [ self startFSKTransmit ] ;		// v0.50
	
	[ _afsk setOOK:ook invert:[ _rttyRxControl invertStateForTransmitter ] ] ;		//  v0.85
	
	//  adjust amplitude based on equalizer here
	if ( ook == 0 ) {
		[ _afsk setOutputScale:outputScale ] ;
		[ modemDest validateDeviceLevel ] ;
		tonepair = [ _afsk toneFrequencies ] ;
		midFrequency = ( tonepair->mark + tonepair->space )*0.5 ;
		equalize = [ equalizer amplitude:midFrequency ] ;
	}
	else {
		equalize = 1.0 ;								//  v0.85
		[ _afsk setOutputScale:0.75 ] ;
		[ modemDest setOOKDeviceLevel ] ;
	}
	if ( !isTransmit && !configOpen ) {
		toneIndex = 0 ;
		[ modemDest stopSampling ] ;
		[ _afsk appendString:"|" clearExistingCharacters:NO ] ;  //  send a long mark
		[ modemDest startSampling ] ;
		if ( transmitButton ) {
            _myRig = [[NSApp delegate] myRig];
            [ _myRig clickPttOn];
			[ transmitButton setTitle:NSLocalizedString( @"Receive", nil ) ] ;
			[ transmitButton setState:NSOnState ] ;
		}
		isTransmit = YES ;
		return YES ;
	}
	isTransmit = NO ;
    _myRig = [[NSApp delegate] myRig];
    [ _myRig clickPttOff];
	[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
	if ( transmitButton ) {
		[ transmitButton setTitle:NSLocalizedString( @"Transmit", nil ) ] ;
		[ transmitButton setState:NSOffState ] ;
	}
	if ( configOpen ) {
		[ Messages alertWithMessageText:NSLocalizedString( @"Close Config Panel", nil ) informativeText:NSLocalizedString( @"Close Config Panel and try Again", nil ) ] ;
		[ modemObj flushAndLeaveTransmit ] ;
	}
	return NO ;
}

//  v0.50
- (Boolean)stopFSKTransmit
{
	if ( isTransmit ) {
		isTransmit = NO ;
		[ _fsk stopSampling ] ;
		if ( transmitButton ) {
			[ transmitButton setTitle:NSLocalizedString( @"Transmit", nil ) ] ;
			[ transmitButton setState:NSOffState ] ;
		}
        _myRig = [[NSApp delegate] myRig];
        [ _myRig clickPttOff];
		[ _fsk clearOutput ] ;
		[ modemObj transmissionEnded ] ;
	}
	return NO ;
}

- (Boolean)stopTransmit
{
	if ( _fsk ) return [ self stopFSKTransmit ] ;		//  v0.50
	
	if ( isTransmit ) {
		isTransmit = NO ;
		[ modemDest stopSampling ] ;
		if ( transmitButton ) {
			[ transmitButton setTitle:NSLocalizedString( @"Transmit", nil ) ] ;
			[ transmitButton setState:NSOffState ] ;
		}
        [ _afsk clearOutput ] ;  //  v0.46
		[ modemObj transmissionEnded ] ;
        _myRig = [[NSApp delegate] myRig];
        [_myRig clickPttOff];

	}
	return NO ;
}

- (void)transmitCharacter:(int)ascii
{
	if ( ascii == 0x6 ) return ;				// ignore %[tx] for now
	if ( _fsk ) [ _fsk appendASCII:ascii ] ; else [ _afsk appendASCII:ascii ] ;		// v0.50
}

- (void)flushTransmitBuffer
{
	if ( _fsk ) [ _fsk clearOutput ] ; else [ _afsk clearOutput ] ;					// v0.50
}

//  v0.84	local usos state for FSK in turnOnTransmission
- (void)setUSOS:(Boolean)state
{
	[ [ self afskObj ] setUSOS:state ] ;
	usosState = state ;
}

//  accepts a button
//  returns YES if RTTY modemDest is Transmiting
- (Boolean)turnOnTransmission:(Boolean)inState button:(NSButton*)button fsk:(FSK*)inFSK
{
	Boolean state ;
	int fd = 0 ;
	
	//  check if we should use FSK
	_fsk = inFSK ;
	if ( _fsk ) {
		[ _fsk setUSOS:usosState ] ;													//  v0.84
		//  select fsk port and check if port is good
		fd = [ _fsk useSelectedPort ] ;
		if ( fd <= 0 ) _fsk = nil ;
	}
	ook = 0 ;																		//  v0.85
	transmitButton = button ;
	state = ( inState ) ? [ self startTransmit ] : [ self stopTransmit ] ;
	return state ;
}

- (Boolean)turnOnTransmission:(Boolean)inState button:(NSButton*)button fsk:(FSK*)inFSK ook:(int)inOOK
{
	Boolean state ;
	int fd = 0 ;
	
	//  check if we should use FSK
	_fsk = inFSK ;
	if ( _fsk ) {
		[ _fsk setUSOS:usosState ] ;													//  v0.84
		//  select fsk port and check if port is good
		fd = [ _fsk useSelectedPort ] ;
		if ( fd <= 0 ) _fsk = nil ;
	}
	
	//  v 0.85 check ook state 0 = afsk, fsk, 1, 2 = ook
	ook = inOOK ;
	transmitButton = button ;
	state = ( inState ) ? [ self startTransmit ] : [ self stopTransmit ] ;
	return state ;
}

/* local */
- (void)selectTestTone:(int)index
{
	if ( !toneMatrix ) return ;
	
	[ toneMatrix deselectAllCells ] ;
	[ toneMatrix selectCellAtRow:0 column:index ] ;
	if ( timeout != nil) {
		[ timeout invalidate ] ;
		timeout = nil ;
	}
	
	[ modemObj ptt:( index != 0 ) ] ;
	switch ( index ) {
        case 0:
            [ modemDest stopSampling ] ;
            [ self flushTransmitBuffer ] ;
            break ;
        case 4:
            toneIndex = index ;
            [ modemDest stopSampling ] ;
            [ _afsk appendString:"========" clearExistingCharacters:YES ] ;
            [ modemDest startSampling ] ;
            break ;
        case 5:
            toneIndex = index ;
            [ modemDest stopSampling ] ;
            [ _afsk appendString:"RYRYRYRY" clearExistingCharacters:YES ] ;
            [ modemDest startSampling ] ;
            break ;
        case 6:
            toneIndex = index ;
            [ modemDest stopSampling ] ;
            [ _afsk appendString:"\nthe quick brown fox jumps over the lazy dog. 589 73 qrz" clearExistingCharacters:YES ] ;
            [ modemDest startSampling ] ;
            break ;
        default:
            toneIndex = index ;
            // [modemDest setIsSampling:NO];
            [ modemDest startSampling ] ;
            break ;
	}
}

//  watchdog timer, turn test tone off
- (void)timedOut:(NSTimer*)timer
{
	timeout = nil ;
	[ self selectTestTone:0 ] ;
	[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
}

- (RTTYModulator*)afskObj
{
	return _afsk ;
}

- (void)stopSampling
{
	[ modemDest stopSampling ] ;
}

//  ---------------- ModemDest callbacks ---------------------

//  modemDest needs more data
- (int)needData:(float*)outbuf samples:(int)samples channels:(int)ch
{
	int i ;
	float *buf ;
	
	//  assume
	//  outputSamplingRate = 11025
	//  outputChannels = 1
    
	//  fetch next n bytes from the AFSK source
	
	//  v0.85 if OOK, do not bandpass
	buf = ( ook == 0 ) ? bpfBuf : outbuf ;
	
	assert( samples <= 512 ) ;
	switch ( toneIndex ) {
        case 0:
            //  normal transmission, index != 0 is for test tones
            //  fill diddles also echos character (if any) to the exchange view
            [ _afsk getBufferWithDiddleFill:buf length:samples ] ;
            break ;
        case 1:
        default:
            [ _afsk getBufferOfMarkTone:buf length:samples ] ;
            break ;
        case 2:
            [ _afsk getBufferOfSpaceTone:buf length:samples ] ;
            break ;
        case 3:
            [ _afsk getBufferOfTwoTone:buf length:samples ] ;
            break ;
        case 4:
        case 5:
        case 6:
            [ _afsk getBufferWithRepeatFill:buf length:samples ] ;
            break ;
	}
	
	//  apply bandpass filter and save into output
    
    if(_transmitBPF == nil) {
        
        // this is just to get the thing to stop crashing - I do not know if this is right.  We need the CORRECT transmit filter defined before this point.
        
        float low = 400.0 ;
        float high = 2750.0 ;
        [self createTransmitBPF:low high:high];
        
    }
    
    
	if ( ook == 0 && (_transmitBPF != nil) ) {
		// v 0.85 don't filter for OOK, data is already in outbuf
		CMPerformFIR( _transmitBPF, bpfBuf, samples, outbuf ) ;
	}
	
	//  v0.78 send unequalized output to auralMonitor
	//	v0.85 don't output if OOK since it is a on off tone keyed signal (use artificial signal in the RTTYAuralMonitor instead)
	
	if ( rttyAuralMonitor && ook == 0 ) [ rttyAuralMonitor newBandpassFilteredData:outbuf scale:outputScale fromReceiver:NO ] ;
    
	if ( equalizer && ook == 0 ) {
		//  v0.85 don't equalize if OOK
		for ( i = 0; i < samples; i++ ) outbuf[i] *= equalize ;
	}
	return 1 ; // output channels
}

- (void)setOutputScale:(float)value
{
	outputScale = value * [ modemObj outputBoost ] ;			//  allow 2 dB boost
	[ _afsk setOutputScale:outputScale ] ;
}

- (IBAction)openAuralMonitor:(id)sender
{
	//  override by subclasses that has an aural monitor
}

- (IBAction)testToneChanged:(id)sender
{
	int index ;
	
	toneMatrix = sender ;
	index = (int)[ toneMatrix selectedColumn ] ;
	[ self selectTestTone:index ] ;
	if ( index != 0 ) {
        timeout = [ NSTimer scheduledTimerWithTimeInterval:3*60 target:self selector:@selector(timedOut:) userInfo:self repeats:NO ] ;
    }
}

- (IBAction)stopBitsChanged:(id)sender
{
	int index ;
	
	index = (int)[ sender selectedRow ] ;
	[ _afsk setStopBits:stopDuration[index] ] ;
}

- (IBAction)openEqualizer:(id)sender
{
	[ equalizer showMacroSheetIn:window ] ;
}

@end
