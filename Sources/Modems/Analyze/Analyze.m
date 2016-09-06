//
//  Analyze.m
//  cocoaModem
//
//  Created by Kok Chen on 2/22/05.
	#include "Copyright.h"
//

#import "Analyze.h"
#include "AnalyzeConfig.h"
#include "AnalyzeScope.h"
#include "ExchangeView.h"
#include "Modem.h"
#include "ModemManager.h"
#include "ModemSource.h"
#include "Plist.h"
#include "RTTYConfig.h"
#include "RTTYStereoReceiver.h"
#include "RTTYRxControl.h"
#include "Spectrum.h"


@implementation Analyze

@synthesize a = _a;
@synthesize set = _set;

- (id)initIntoTabView:(NSTabView*)tabview manager:(ModemManager*)mgr
{
	[ mgr showSplash:@"Creating Analysis Modem" ] ;

	self = [ super initIntoTabView:tabview nib:@"Analyze" manager:mgr ] ;
		if ( self ) {
		[ rxctrl setupWithClient:self index:0 ] ;
        _a = [[RTTYTransceiver alloc] init]  ;
		_a.control = rxctrl ;
		_a.receiver = [ _a.control receiver ] ;
		[ (RTTYStereoReceiver*)_a.receiver setScope:scope ] ;
		_a.view = [ _a.control view ] ;
		_a.textAttribute = [ _a.control textAttribute ] ;
		[ _a.control setName:@"" ] ;

		[ _a.receiver setReceiveView:[ (RTTYRxControl*)rxctrl view ] ] ;
		
		manager = mgr ;
	}
	return self ;
}

- (void)awakeFromNib
{
    _set = [[RTTYConfigSet alloc] init];
    [_set initAll :
		2:	// stereo
		kAnalyzeInputDevice: 
		kAnalyzeOutputDevice: 
		kAnalyzeOutputLevel: 
		kAnalyzeOutputAttenuator: 
		kAnalyzeTone: 
		kAnalyzeMark: 
		kAnalyzeSpace:
		kAnalyzeBaud:
		nil:
		kAnalyzeSquelch:
		kAnalyzeActive:
		kAnalyzeStopBits:
		kAnalyzeMode:
		kAnalyzePrefs:
		kAnalyzeTextColor:
		kAnalyzeSentColor:
		kAnalyzeBackgroundColor:
		kAnalyzePlotColor:
		nil:
		nil:
		nil:
        nil :
        FALSE:
        nil
     ] ;
		
	self.ident = @"Analyze" ;
	[ self.modemTabItem setLabel:@"Analyze" ] ;

	[ config awakeFromModem:_set rttyRxControl:rxctrl txConfig:nil ] ;
	
	[ self initColors ] ;	
	//  prefs
	usos = robust = NO ;
	bell = YES ;
	thread = [ NSThread currentThread ] ;
}

static float timeConstants[] = { 0.2, 0.5, 1.5, 4.0 } ;
static float ranges[] = { 40.0, 60.0, 80.0 } ;

- (void)setupSpectrum
{
	int t, dr ;

	[ _a.control setSpectrumView:spectrum ] ;
	t = [ timeConstant indexOfSelectedItem ] ;
	dr = [ dynamicRange indexOfSelectedItem ] ;
	[ spectrum setTimeConstant:timeConstants[t] dynamicRange:ranges[dr] ] ;
	[ spectrum clearPlot ] ;
}

- (void)updateSourceFromConfigInfo
{
	[ manager showSplash:@"Updating Analysis sound source" ] ;
	[ _a.control setupRTTYReceiver ] ;
	[ self setupSpectrum ] ;
}

- (void)selectBandwidth:(int)index
{
	[ _a.receiver selectBandwidth:index ] ;
}

- (void)selectDemodulator:(int)index
{
	[ _a.receiver selectDemodulator:index ] ;
}

- (void)setVisibleState:(Boolean)visible
{
	[ config updateVisibleState:visible ] ;
	[ _a.receiver enableReceiver:visible ] ;
}

- (void)setupDefaultPreferences:(Preferences*)pref
{
	[ super setupDefaultPreferences:pref ] ;
	
	[ pref setString:@"Verdana" forKey:kAnalyzeFont ] ;
	[ pref setFloat:14.0 forKey:kAnalyzeFontSize ] ;
	
	[ (AnalyzeConfig*)config setupDefaultPreferences:pref rttyRxControl:_a.control ] ;
}

//  set up this Modem's setting from the Plist
- (Boolean)updateFromPlist:(Preferences*)pref
{
	NSString *fontName ;
	float fontSize ;
	
	[ super updateFromPlist:pref ] ;
	
	fontName = [ pref stringValueForKey:kAnalyzeFont ] ;
	fontSize = [ pref floatValueForKey:kAnalyzeFontSize ] ;
	[ _a.view setTextFont:fontName size:fontSize attribute:[ _a.control textAttribute ] ] ;

	plistHasBeenUpdated = YES ;						//  v0.53d
	return YES ;
}

//  retrieve the preferences that are in use
- (void)retrieveForPlist:(Preferences*)pref
{
	NSFont *font ;
	
	if ( plistHasBeenUpdated == NO ) return ;		//  v0.53d
	[ super retrieveForPlist:pref ] ;
	
	font = [ _a.view font ] ;
	[ pref setString:[ font fontName ] forKey:kAnalyzeFont ] ;
	[ pref setFloat:[ font pointSize ] forKey:kAnalyzeFontSize ] ;
}

- (IBAction)repeatButtonPushed:(id)sender
{
	repeatState = [ sender state ] ;
	[ (RTTYStereoReceiver*)_a.receiver setFileRepeat:repeatState ] ;
}

- (IBAction)spectrumOptionChanged:(id)sender
{
	[ self setupSpectrum ] ;
}

@end
