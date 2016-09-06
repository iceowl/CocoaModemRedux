//
//  RTTYConfigSet.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>

@interface RTTYConfigSet : NSObject

//	typedef struct {
@property	int channel ;					// LEFTCHANNEL
@property 	NSString *inputDevice ;			// kRTTYInputDevice
@property 	NSString *outputDevice ;		// kRTTYOutputDevice
@property 	NSString *outputLevel ;			// kRTTYOutputLevel
@property 	NSString *outputAttenuator ;	// kRTTYOutputAttenuator
@property 	NSString *tone ;				// kRTTYTone
@property 	NSString *mark ;				// kRTTYMark
@property 	NSString *space ;				// kRTTYSpace
@property 	NSString *baud ;				// kRTTYBaud
@property 	NSString *controlWindow ;		// nil, or kDualRTTYMainControlWindow
@property 	NSString *squelch ;				// kRTTYSquelch
@property 	NSString *active ;				// kRTTYActive
@property 	NSString *stopBits ;			// kRTTYStopBits
@property 	NSString *sideband ;			// kRTTYMode
@property 	NSString *rxPolarity ;			// kRTTYRxPolarity
@property 	NSString *txPolarity ;			// kRTTYTxPolarity
@property 	NSString *prefs ;				// kRTTYPrefs
@property 	NSString *textColor ;			// kRTTYTextColor
@property 	NSString *sentColor ;			// kRTTYSentColor
@property 	NSString *backgroundColor ;		// kRTTYBackgroundColor
@property 	NSString *plotColor ;			// kRTTYPlotColor
@property 	NSString *vfoOffset ;			// nil, or kWFRTTYOffset
@property 	NSString *fskSelection ;		// nil, or kRTTYFSKSelection
@property   bool     usesRTTYAuralMonitor ;
@property 	NSString *auralMonitor ;		// nil, or name of sub dictionary
//	} RTTYConfigSet ;

-(void) initAll
:  (int)        channel
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
:	   (bool)   usesRTTYAuralMonitor
:  (NSString*)  auralMonitor ;


@end
