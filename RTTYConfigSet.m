//
//  RTTYConfigSet.m
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import "RTTYConfigSet.h"

@implementation RTTYConfigSet
@synthesize channel             = _channel;
@synthesize  inputDevice        = _inputDevice;			// kRTTYInputDevice
@synthesize  outputDevice       = _outputDevice;		// kRTTYOutputDevice
@synthesize  outputLevel        = _outputLevel;			// kRTTYOutputLevel
@synthesize  outputAttenuator   = _outputAttenuator ;	// kRTTYOutputAttenuator
@synthesize  tone               = _tone ;				// kRTTYTone
@synthesize  mark               = _mark;				// kRTTYMark
@synthesize  space              = _space ;				// kRTTYSpace
@synthesize  baud               = _baud;				// kRTTYBaud
@synthesize  controlWindow      = _controlWindow;		// nil, or kDualRTTYMainControlWindow
@synthesize  squelch            = _squelch;				// kRTTYSquelch
@synthesize  active             = _active;				// kRTTYActive
@synthesize  stopBits           = _stopBits ;			// kRTTYStopBits
@synthesize  sideband           = _sideband;			// kRTTYMode
@synthesize  rxPolarity         = _rxPolarity ;			// kRTTYRxPolarity
@synthesize  txPolarity         = _txPolarity ;			// kRTTYTxPolarity
@synthesize  prefs              = _prefs ;				// kRTTYPrefs
@synthesize  textColor          = _textColor;			// kRTTYTextColor
@synthesize  sentColor          = _sentColor;			// kRTTYSentColor
@synthesize  backgroundColor    = _backgroundColor ;		// kRTTYBackgroundColor
@synthesize  plotColor          = _plotColor ;			// kRTTYPlotColor
@synthesize  vfoOffset          = _vfoOffset ;			// nil, or kWFRTTYOffset
@synthesize  fskSelection       = _fskSelection ;		// nil, or kRTTYFSKSelection
@synthesize  usesRTTYAuralMonitor = _usesRTTYAuralMonitor ;
@synthesize  auralMonitor       = _auralMonitor;		// nil, or name of sub dictionary


-(void) initAll
:   (int)        channel
 :  (NSString*)  inputDevice 			// kRTTYInputDevice
 :  (NSString*)  outputDevice 	// kRTTYOutputDevice
 :  (NSString*)  outputLevel 			// kRTTYOutputLevel
 :  (NSString*)  outputAttenuator 	// kRTTYOutputAttenuator
 :  (NSString*)  tone 			// kRTTYTone
 :  (NSString*)  mark 				// kRTTYMark
 :  (NSString*)  space 				// kRTTYSpace
 :  (NSString*)  baud 			// kRTTYBaud
 :  (NSString*)  controlWindow 		// nil, or kDualRTTYMainControlWindow
 :  (NSString*)  squelch 				// kRTTYSquelch
 :  (NSString*)  active 				// kRTTYActive
 :  (NSString*)  stopBits 			// kRTTYStopBits
 :  (NSString*)  sideband 			// kRTTYMode
 :  (NSString*)  rxPolarity 			// kRTTYRxPolarity
 :  (NSString*)  txPolarity 			// kRTTYTxPolarity
 :  (NSString*)  prefs 				// kRTTYPrefs
 :  (NSString*)  textColor 			// kRTTYTextColor
 :  (NSString*)  sentColor 			// kRTTYSentColor
 :  (NSString*)  backgroundColor 		// kRTTYBackgroundColor
 :  (NSString*)  plotColor 			// kRTTYPlotColor
 :  (NSString*)  vfoOffset 			// nil, or kWFRTTYOffset
 :  (NSString*)  fskSelection 		// nil, or kRTTYFSKSelection
 :		(bool)     usesRTTYAuralMonitor
 :  (NSString*)  auralMonitor {
    
    _channel = channel;
    _inputDevice  =  inputDevice;
    _outputDevice =  outputDevice;
    _outputLevel  =  outputLevel;
    _outputAttenuator =  outputAttenuator; 	// kRTTYOutputAttenuator
    _tone =  tone; 			// kRTTYTone
    _mark =  mark; 				// kRTTYMark
    _space = space; 				// kRTTYSpace
    _baud =  baud; 			// kRTTYBaud
    _controlWindow = controlWindow; 		// nil, or kDualRTTYMainControlWindow
    _squelch = squelch; 				// kRTTYSquelch
    _active =  active; 				// kRTTYActive
    _stopBits =  stopBits; 			// kRTTYStopBits
    _sideband = sideband; 			// kRTTYMode
    _rxPolarity = rxPolarity; 			// kRTTYRxPolarity
    _txPolarity = txPolarity; 			// kRTTYTxPolarity
    _prefs =  prefs; 				// kRTTYPrefs
    _textColor = textColor; 			// kRTTYTextColor
    _sentColor = sentColor; 			// kRTTYSentColor
    _backgroundColor =  backgroundColor; 		// kRTTYBackgroundColor
    _plotColor =  plotColor; 			// kRTTYPlotColor
    _vfoOffset =  vfoOffset; 			// nil, or kWFRTTYOffset
    _fskSelection = fskSelection; 		// nil, or kRTTYFSKSelection
    _usesRTTYAuralMonitor = usesRTTYAuralMonitor;
    _auralMonitor = auralMonitor;
}// nil, or name of sub dictionary


@end
