 //
//  CWRxControl.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/2/06.
	#include "Copyright.h"


#import "CWRxControl.h"
#import "CWConfig.h"
#import "CWMonitor.h"
#import "CWReceiver.h"
#import "CWWaterfall.h"
#import "Oscilloscope.h"
#import "Plist.h"
#import "WBCW.h"

@implementation CWRxControl


- (id)initIntoView:(NSView*)view client:(Modem*)modem index:(int)index
{
  //  NSLog(@"CWRxControl Init into view for client %@",modem.class);
	self = [ super init ] ;
	if ( self ) {
		previousReportedSpeed = 0 ;
		if ( [ [NSBundle mainBundle] loadNibNamed:@"CWRxControl" owner:self topLevelObjects:nil ] ) {
			// loadNib should have set up controlView connection
			if ( view && controlView ) {
				[ view addSubview:controlView ] ;
				if ( auxWindow ) [ auxWindow setTitle: (index == 0) ? NSLocalizedString( @"CW Main", nil ) : NSLocalizedString( @"CW Sub", nil ) ] ;
				[ self setupWithClient:modem index:index ] ;
				if ( activeIndicator ) [ activeIndicator setBackgroundColor:[ NSColor grayColor ] ] ;
				//NSLog(@"CWRXControl initted into View - INDEX = %d",index);
			} else {
               // NSLog(@"view = %@  controlView = %@ ... should EXIT - see CWRxControl.m",view,controlView) ;
            }
		}
	}
	return self ;
    
}

- (void)awakeFromNib
{
//	spectrumView = nil ;
//	waterfall = nil ;
//	monitor = nil ;
	tonePair.mark = 0.0 ;							//  not demodulating until clicked
	tonePair.space = tonePair.baud = 0.0 ;			//  space and baud not used in CW mode
	sideband = 0 ;
	rxPolarity = txPolarity = 0 ;
	activeTransmitter = cwEnabled = NO ;
	vfoOffset = ritOffset = 0 ;
	txLocked = NO ;
//	monitor = nil ;
	
    
    
    
	[ self setInterface:inputAttenuator to:@selector(inputAttenuatorChanged) ] ;
	[ self setInterface:bandwidthMenu to:@selector(bandwidthChanged) ] ;
	[ self setInterface:wideButton to:@selector(widenessChanged) ] ;
	[ self setInterface:levelSlider to:@selector(levelChanged) ] ;
	[ self setInterface:panoButton to:@selector(widenessChanged) ] ;
	[ self setInterface:monitorButton to:@selector(monitorEnableChanged) ] ;
	[ self setInterface:speedMenu to:@selector(speedChanged) ] ;
	[ self setInterface:cwSquelchSlider to:@selector(cwSquelchChanged) ] ;
	[ self setInterface:latencyMenu to:@selector(latencyChanged) ] ;
    
    
  //  NSLog(@"CWRxcontrol awake from NIB create");
    
}

- (void)setupWithClient:(Modem*)modem index:(int)index
{
	uniqueID = index ;
	self.client = (RTTY*)modem ;
	[ self setupDefaultFilters ] ;
	[ self speedChanged ] ;				//  set up default wpm
	
	self.receiver = [ [ CWReceiver alloc ] initReceiver:index modem:modem ] ;
	[ self.receiver setReceiveView:exchangeView ] ;
}

- (void)setupCWReceiverWithMonitor:(CWMonitor*)sidetone
{
	cwMonitor = sidetone ;
	[ (CWReceiver*)self.receiver setupReceiverChain:self.config monitor:sidetone ] ;		//  v0.88d (remove cast for config from CMTappedPipe)
	[ self.config setClient:self ] ;
}

- (void)newClick:(float)delta
{
	[ (CWReceiver*)self.receiver newClick:delta ] ;
}

- (void)enableCWReceiver:(Boolean)state
{
	if ( cwEnabled == state ) return ;
	
	cwEnabled = state ;
	[ (CWReceiver*)self.receiver changingStateTo:state ] ;
	if ( cwMonitor ) [ cwMonitor enableSidetone:state index:uniqueID ] ;
}

//  audio source starts at config and is routed here first
//	the data is sent to the receiver and the tuning and any spectrum display
- (void)importData:(CMPipe*)pipe
{
	if ( !self.receiver || ![ self.receiver enabled ] ) return ;
	
	//  send data through the processing chain if waterfall has been clicked
	//	receiver buffers the data in the click buffer and then sends it to the demodulator
	if ( self.receiver  && cwEnabled ) [ self.receiver importData:pipe ] ;
	
	//  send data to waterfall display
	if ( self.waterfall ) [ self.waterfall importData:pipe ] ;
}


//  mark tone of tonepair is used in CW mode as the CW frequency 
- (void)setTonePair:(const CMTonePair*)tonepair
{
	CMTonePair rxTonepair ;
	
	tonePair = *tonepair ;
	
	//  send frequencies to receiver
	if ( self.receiver ) [ self.receiver rxTonePairChanged:self ] ;
	//  and to config if we are the selected transmitter
	if ( activeTransmitter ) [ (CWConfig*)self.config txTonePairChanged:self ] ;
	//  set cross ellipse filters
	if ( tuningView ) {
		rxTonepair = [ self rxTonePair ] ;
		[ tuningView setTonePair:&rxTonepair ] ;
	}
	if ( self.waterfall ) {
		[ self.waterfall setSideband:sideband ] ;
		[ self.waterfall setTonePairMarker:tonepair index:uniqueID ] ;
		[ self.waterfall setRITOffset:ritOffset ] ;
		if ( txLocked ) {
			//  tx locked
			[ self.waterfall setTransmitTonePairMarker:&lockedTonePair index:uniqueID ] ;
		}
	}
	if ( self.config ) [ (RTTYConfig*)self.config setTonePairMarker:tonepair ] ;
}

- (void)lockTonePairToCurrentTone
{
	lockedTonePair = [ self rxTonePair ] ;
}

- (void)setFrequency:(float)freq
{
	CMTonePair tempTonePair ;
	
	tempTonePair.mark = freq ;
	tempTonePair.space = tempTonePair.baud = 0.0 ;			//  CW has no space tone
	[ self setTonePair:&tempTonePair ] ;
}

- (void)setupDefaultFilters
{
	[ self setTuningIndicatorState:YES ] ;
	//  receive views
	receiveTextAttribute = [ exchangeView newAttribute ] ;
	[ exchangeView setDelegate:self.client ] ;
}

- (void)fetchTonePairFromMemory
{
	//  no tone pair memory in CW mode
}

- (void)latencyChanged
{
	int latency ;
	
	latency = (int)[ [ latencyMenu selectedItem ] tag ] ;
	[ (CWReceiver*)self.receiver setLatency:latency ] ;
}

- (void)bandwidthChanged
{
	float bandwidth ;
	
	bandwidth = [ [ bandwidthMenu selectedItem ] tag ] ;
	[ (CWReceiver*)self.receiver setCWBandwidth:bandwidth ] ;
}

- (void)widenessChanged
{
	Boolean isWide ;
	Boolean isPano ;
	
	isWide = ( [ wideButton state ] == NSOnState ) ;
	[ (WBCW*)self.client enableWide:isWide index:uniqueID ] ;
	
	if ( isWide ) {
		[ panoButton  setEnabled:YES ] ;
		isPano = ( [ panoButton state ] == NSOnState ) ;
		[ (WBCW*)self.client enablePano:isPano index:uniqueID ] ;
	}
	else {
		[ panoButton setEnabled:NO ] ;
	}
}

- (void)cwSquelchChanged
{
	float v, qsb, limit ;
	
	limit = -2.25 ;
	v = [ cwSquelchSlider floatValue ] ;
	if ( v > limit ) [ cwSquelchSlider setFloatValue:limit ] ;
	
	//qsb = [ qsbSlider floatValue ] ;
	qsb = -30.0 ;		// fixed 30 dB depth
	if ( qsb > limit ) qsb = limit ;
	// [ qsbSlider setFloatValue:limit ] ;

	v = [ cwSquelchSlider floatValue ] ;
	[ (WBCW*)self.client changeSquelchTo:v fastQSB:qsb slowQSB:qsb*0.32 index:uniqueID ] ;
}

- (void)monitorEnableChanged
{
	Boolean isEnable, panoEnabled ;
	
	if ( !monitorButton ) return ;
	
	isEnable = ( [ monitorButton state ] == NSOnState ) && ( [ monitorButton isEnabled ] ) ;
	
	[ bandwidthMenu setEnabled:isEnable ] ;
	[ wideButton setEnabled:isEnable ] ;
	panoEnabled = isEnable && ( [ wideButton state ] == NSOnState ) ;
	[ panoButton  setEnabled:panoEnabled ] ;
	[ levelSlider  setEnabled:isEnable ] ;

	[ (WBCW*)self.client enableMonitor:isEnable index:uniqueID ] ;
}

- (void)setMonitorEnableButton:(Boolean)state
{
	if ( monitorButton ) {
		[ monitorButton setEnabled:state ] ;
		[ self monitorEnableChanged ] ;
	}
}

- (void)speedChanged
{
	int speed ;
	
	speed = (int)[ [ speedMenu selectedItem ] tag ] ;
	[ reportSpeed setStringValue:@"Speed" ] ;
	previousReportedSpeed = 0 ;
	[ (WBCW*)self.client changeSpeedTo:speed index:uniqueID ] ;
}

- (void)setReportedSpeed:(int)wpm limited:(Boolean)limited
{
	if ( wpm != previousReportedSpeed ) {
		previousReportedSpeed = wpm ;
		if ( wpm == 0 ) [ reportSpeed setStringValue:@" . . . " ] ;
		else {
			[ reportSpeed setStringValue:[ NSString stringWithFormat:( (limited) ? @"%d* wpm" : @"%d wpm" ), wpm ] ] ;
		}
	}
}

- (void)levelChanged
{
	float v = [ levelSlider floatValue ] ;
	
	[ (WBCW*)self.client monitorLevel:pow( 10.0, v/20.0 ) index:uniqueID ] ;
}

- (void)updateTonePairInformation
{
	int previous ;
	
	//  sideband
	previous = sideband ;
	sideband = (int)[ sidebandMenu indexOfSelectedItem ] ;
	[ (WBCW*)self.client sidebandChanged:sideband index:uniqueID ] ;
	[ self setTonePair:&tonePair ] ;
	
	//  update waterfall sideband
	if ( sideband != previous && self.waterfall ) {
		CMTonePair pair = { 0.0, 0.0, 45.45 } ;
		[ self.waterfall setSideband:sideband ] ;
		[ self.waterfall setTonePairMarker:&pair index:uniqueID ] ;
	}
}

- (CMTonePair)rxTonePair
{
	CMTonePair adjusted ;
	
	adjusted = tonePair ;
	adjusted.mark += ritOffset ;		// RIT
	return adjusted ;
}

- (CMTonePair)txTonePair
{
	return tonePair ;
}

//  Plist support
- (void)setupDefaultPreferences:(Preferences*)pref config:(ModemConfig*)cfg
{
	[ self setupBasicDefaultPreferences:pref config:cfg ] ;
	[ pref setInt:0 forKey:( uniqueID == 0 ) ? kWBCWMainMonitor : kWBCWSubMonitor ] ;
	[ pref setInt:100 forKey:( uniqueID == 0 ) ? kWBCWMainBandwidth : kWBCWSubBandwidth ] ;
	[ pref setFloat:[ cwSquelchSlider floatValue ] forKey:( uniqueID == 0 ) ? kWBCWMainSquelch : kWBCWSubSquelch ] ;		
	[ pref setFloat:0.0 forKey:( uniqueID == 0 ) ? kWBCWMainSidetoneLevel : kWBCWSubSidetoneLevel ] ;
}

- (void)updateFromPlist:(Preferences*)pref config:(ModemConfig*)cfg 
{
	int state, value ;
	float dB ;
	
	[ self updateBasicFromPlist:pref config:cfg ] ;
	state = [ pref intValueForKey:( uniqueID == 0 ) ? kWBCWMainMonitor : kWBCWSubMonitor ] ;
	[ cwSquelchSlider setFloatValue:[ pref floatValueForKey:( uniqueID == 0 ) ? kWBCWMainSquelch : kWBCWSubSquelch ] ] ;
	[ self cwSquelchChanged ] ;
	[ monitorButton setState:( state != 0 ) ? NSOnState : NSOffState ] ;
	[ self monitorEnableChanged ] ;
	value = [ pref intValueForKey:( uniqueID == 0 ) ? kWBCWMainBandwidth : kWBCWSubBandwidth ] ;
	[ bandwidthMenu selectItemWithTag:value ] ;
	[ self bandwidthChanged ] ;
	
	dB = [ pref floatValueForKey:( uniqueID == 0 ) ? kWBCWMainSidetoneLevel : kWBCWSubSidetoneLevel ] ;
	[ levelSlider setFloatValue:dB ] ;
	[ self levelChanged ] ;
}

- (void)retrieveForPlist:(Preferences*)pref config:(ModemConfig*)cfg
{
	[ self retrieveBasicForPlist:pref config:cfg ] ;
	[ pref setInt:( [ monitorButton state ] == NSOnState ) ? 1 : 0 forKey:( uniqueID == 0 ) ? kWBCWMainMonitor : kWBCWSubMonitor ] ;
	[ pref setFloat:[ cwSquelchSlider floatValue ] forKey:( uniqueID == 0 ) ? kWBCWMainSquelch : kWBCWSubSquelch ] ;		
	[ pref setInt:(int)[ [ bandwidthMenu selectedItem ] tag ]  forKey:( uniqueID == 0 ) ? kWBCWMainBandwidth : kWBCWSubBandwidth ] ;
	[ pref setFloat:[ levelSlider floatValue ] forKey:( uniqueID == 0 ) ? kWBCWMainSidetoneLevel : kWBCWSubSidetoneLevel ] ;
}

//  AppleScript support
- (Boolean)invertStateForTransmitter
{
	return NO ;
}

- (void)setInvertStateForTransmitter:(Boolean)state
{
	//  do nothing in CW
}
	
@end
