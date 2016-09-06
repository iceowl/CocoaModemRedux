//
//  CWTxConfig.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 1/5/07.
	#include "Copyright.h"
	

#import "CWTxConfig.h"
#import "Application.h"
#import "CWModulator.h"
#import "Messages.h"
#import "Modem.h"
#import "ModemDest.h"
#import "ModemEqualizer.h"


@implementation CWTxConfig

@synthesize myRig = _myRig;

- (void)awakeFromModem:(RTTYConfigSet*)set rttyRxControl:(RTTYRxControl*)control
{
	self.rttyRxControl = control ;
	self.configSet = set ;
	
	self.transmitBPF = nil ;
	fir = nil ;
	hasSetupDefaultPreferences = hasRetrieveForPlist = hasUpdateFromPlist = NO ;
	equalize = 1.0 ;
	rttyAuralMonitor = nil ;		//  v0.78
	
	//  set output to defaults
	if ( set.outputDevice ) {
		self.currentLow = self.currentHigh = -1 ;
		self.afsk = [ [ CWModulator alloc ] init ] ;
		[ self.afsk setModemClient:modemObj ] ;
		[ self setupModemDest:set.outputDevice controlView:soundOutputControls attenuatorView:soundOutputLevel ] ;
		[ modemDest setSoundLevelKey:set.outputLevel attenuatorKey:set.outputAttenuator ] ;

		//  color well changes
		[ self setInterface:transmitTextColor to:@selector(colorChanged) ] ;
		//  Transmit equalizer
		equalizer = [ [ ModemEqualizer alloc ] initSheetFor:set.outputDevice ] ;
	}
}

//  -------------- transmit stream ---------------------
- (Boolean)startTransmit
{
	CMTonePair *tonepair ;
	float midFrequency ;

	//  adjust amplitude based on equalizer here
	tonepair = [ self.afsk toneFrequencies ] ;
	midFrequency = ( tonepair->mark )*0.5 ;
	equalize = [ equalizer amplitude:midFrequency ] ;
	[ (CWModulator*)self.afsk setGain:equalize ] ;
	
	if ( ook ) [ modemDest setOOKDeviceLevel ] ; else [ modemDest validateDeviceLevel ] ;
	
	if ( !isTransmit && !configOpen ) {
		toneIndex = 0 ;
		[ modemDest stopSampling ] ;
		[ modemDest startSampling ] ;
		if ( transmitButton ) {
			[ transmitButton setTitle:NSLocalizedString( @"Receive", nil ) ] ;
			[ transmitButton setState:NSOnState ] ;
            _myRig = [[NSApp delegate] myRig];
            [ _myRig clickPttOn];
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

- (void)transmitCharacter:(int)ascii
{
	if ( ascii == 0x5 ) {								// %[rx]
		[ (CWModulator*)self.afsk insertEndOfTransmit ] ;				//  v0.37 modified insertEndOfTransmit so it does not switch over immediately
	return ;
	}
	if ( ascii == 0x6 ) return ;						//  ignore %[tx] for now
	
	[ self.afsk appendASCII:ascii ] ;			//  send character on to modulator
}

- (void)holdOff:(int)milliseconds
{
	[ (CWModulator*)self.afsk holdOff:milliseconds ] ;
}

- (Boolean)bufferEmpty
{
	return [ (CWModulator*)self.afsk bufferEmpty ] ;
}

- (void)flushTransmitBuffer
{
	[ self.afsk clearOutput ] ;
}

- (void)setSpeed:(float)speed
{
	[ (CWModulator*)self.afsk setSpeed:speed ] ;
}

- (void)setCarrier:(float)freq
{
	[ (CWModulator*)self.afsk setCarrier:freq ] ;
}

- (void)setRisetime:(float)t weight:(float)w ratio:(float)r farnsworth:(float)f
{
	[  (CWModulator*)self.afsk setRisetime:t weight:w ratio:r farnsworth:f ] ;
}

//	v0.85
- (void)setModulationMode:(int)index
{
	ook = ( index != 0 ) ;
	[  (CWModulator*)self.afsk setModulationMode:index ] ;
}

- (int)needData:(float*)outbuf samples:(int)samples channels:(int)ch
{
	return [  (CWModulator*)self.afsk needData:outbuf samples:samples ] ;
}

/* local */
- (void)selectTestTone:(int)index
{
	float freq ;
	
	if ( !toneMatrix ) return ;
	
	[ (CWModulator*)self.afsk selectTestTone:index ] ;
	
	[ toneMatrix deselectAllCells ] ;
	[ toneMatrix selectCellAtRow:0 column:index ] ;
	if ( timeout ) {
		[ timeout invalidate ] ;
		timeout = nil ;
	}
	switch ( index ) {
	case 0:
		[ modemDest stopSampling ] ;
		[ modemObj ptt:NO ] ;
		toneIndex = 0 ;
		break ;
	default:
		toneIndex = index ;
		freq = [ testFreq floatValue ] ;
		[ (CWModulator*)self.afsk setTestFrequency:freq ] ;
		[ modemObj ptt:YES ] ;
		[ modemDest startSampling ] ;
		break ;
	}
}

//  watchdog timer, turn test tone off
- (void)timedOut:(NSTimer*)timer
{
	timeout = nil ;
	[ self selectTestTone:0 ] ;
}

- (IBAction)openAuralMonitor:(id)sender
{
	Application *application ;
	AuralMonitor *auralMonitor ;
	
	application = [ [ NSApp delegate ] application ] ;	
	if ( application ) {
		//  fetch the common aural monitor
		auralMonitor = [ application auralMonitor ] ;
		if ( auralMonitor ) [ auralMonitor showWindow ] ;
	}	
}

- (IBAction)testToneChanged:(id)sender 
{
	int index ;
	
	toneMatrix = sender ;
	index = (int)[ toneMatrix selectedColumn ] ;
	[ self selectTestTone:index ] ;
	if ( index != 0 ) timeout = [ NSTimer scheduledTimerWithTimeInterval:3*60 target:self selector:@selector(timedOut:) userInfo:self repeats:NO ] ;
}

@end
