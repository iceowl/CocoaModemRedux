//
//  MFSK.h
//  cocoaModem 2.0
//
//  Created by Kok Chen on 2/15/06.

#ifndef _MFSK_H_
	#define	_MFSK_H_
	#import <Cocoa/Cocoa.h>
	
	#include "ContestInterface.h"

	@class VUMeter ;
	@class MFSKDemodulator ;
	@class MFSKModulator ;
	@class MFSKReceiver ;
	

	@interface MFSK : ContestInterface {
        
		IBOutlet id waterfall ;
		IBOutlet NSButton* transmitButton ;
		IBOutlet id transmitLight ;
		
		IBOutlet id inputAttenuator ;
		IBOutlet id vuMeter ;

		IBOutlet id mfskIndicator ;
		IBOutlet id mfskIndicatorLabel ;
		
		IBOutlet id mfskAFCBox ;
		IBOutlet id mfskLatencyBox ;
		
		IBOutlet id mfskModeMenu ;
		IBOutlet id exchangeTabView ;
		
		IBOutlet id dominoFECMenu ;
		IBOutlet id dominoReceiveView ;
		IBOutlet id dominoReceiveBox ;
		IBOutlet id dominoReceiveTextField ;
		IBOutlet NSButton* dominoReceiveCheckbox ;
		IBOutlet NSButton* dominoSendCheckbox ;
		IBOutlet id dominoSendField ;
		IBOutlet NSButton* dominoSmoothScrollCheckbox ;
		IBOutlet NSButton* dominoBeaconEchoCheckbox ;

		IBOutlet NSButton* softDecodeCheckbox ;
		IBOutlet id afcTabView ;
		IBOutlet id afcSlider ;
		IBOutlet id latencySlider ;
		IBOutlet id txTrackSlider ;
		IBOutlet id squelchSlider ;

		IBOutlet NSTextField* rxFreqField ;
		IBOutlet NSTextField* txFreqField ;
		IBOutlet NSButton* txTransferButton ;
		
		//NSThread *thread ;
		
		int mfskMode ;		//  0 = MFSK16, 16 = DominoEX16, etc
		
		MFSKReceiver *receiver ;
		MFSKReceiver *mfsk16Receiver ;
		MFSKReceiver *domino5Receiver, *domino11Receiver, *domino22Receiver ;
		MFSKReceiver *domino4Receiver, *domino8Receiver, *domino16Receiver ;

		MFSKModulator *modulator ;
		MFSKModulator *mfsk16Modulator ;
		MFSKModulator *dominoModulator ;
		
		MFSKDemodulator *demodulator ;
		Boolean enabled, active ;
		
		//	waterfall
		float displayedRxFrequency, displayedTxFrequency ;
		
		//  demodulator
		float vfoOffset ;
		int sideband ;
		float displayedFrequency, clickedFrequency ;
		Boolean frequencyDefined ;
				
		//  Prefs
		Boolean sidebandState ;
		// transmit
		//NSLock *transmitViewLock ;
		//NSTimer *transmitBufferCheck ;
		int indexOfUntransmittedText ;
		Boolean echoBeacon ;
	}

@property (retain) NSTimer  *transmitBufferCheck;
@property (retain) NSLock   *transmitViewLock;
@property (retain) NSThread *thread;
@property (retain) NSTimer  *timeout;

	- (IBAction)flushTransmitStream:(id)sender ;
	- (IBAction)waterfallRangeChanged:(id)sender ;

	//  for CER testing
	- (IBAction)openFile:(id)sender ;
	
	- (MFSKDemodulator*)demodulator ;
	- (MFSKReceiver*)receiver ;
	
	- (void)transmittedPrimaryCharacter:(int)c ;
	- (void)transmittedSecondaryCharacter:(int)c ;
	
	- (void)applyRxFreqOffset:(float)offset ;
	- (void)setRxFrequency:(float)freq ;
	- (void)setTxFrequency:(float)freq ;
	- (void)setTxFrequencyFromRxFrequency ;
	- (float)receiveFrequency ;
	- (float)transmitFrequency ;
	- (Boolean)checkIfCanTransmit ;
	- (void)setOutputScale:(float)value ;
	
	- (void)changeTransmitLight:(int)state ;
	
	- (void)flushOutput ;
	- (void)displayCharacter:(int)c ;
	- (void)displayPrimary:(int)c ;			//  v0.73
	- (void)displaySecondary:(int)c ;		//  v0.73
	
	- (VUMeter*)vuMeter ;
	- (void)selectAlternateSideband:(Boolean)state ;
	- (void)setWaterfallOffset:(float)freq sideband:(int)polarity ;

	@end	

#endif
