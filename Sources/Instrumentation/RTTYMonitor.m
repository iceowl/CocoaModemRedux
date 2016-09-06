//
//  RTTYMonitor.m
//  cocoaModem
//
//  Created by Kok Chen on Sat Jun 05 2004.
	#include "Copyright.h"
//

#import "RTTYMonitor.h"
#include "Oscilloscope.h"


@implementation RTTYMonitor

@synthesize connection = _connection;

//  RTTYMonitor is an AudioDest

- (id)init
{
	int i ;
	
	self = [ super init ] ;
	if ( self ) {
		currentStyle = 0 ;
        _connection = [[NSMutableArray alloc] initWithCapacity:MAXCON];
		for ( i = 0; i < 8; i++ ) {
            Connection *c = [[Connection alloc] init];
			c.pipe = nil ;
			c.enableBaudotMarkers = NO ;
			c.index = i ;
            [_connection insertObject:c atIndex:i];
		}
		selected = nil ;
		
		if ( [ [NSBundle mainBundle] loadNibNamed:@"Monitor" owner:self topLevelObjects:nil] ) {
			// loadNib should have set up scopeView connection
			if ( scopeView ) {
				[ [ scopeView window ] setLevel:NSNormalWindowLevel ] ;
				[ [ scopeView window ] setHidesOnDeactivate:NO ] ;
				return self ;
			}
		}
	}
	return nil ;
}

static NSString *freqLabel[] = { @"500", @"1000", @"1500", @"2000", @"2500" } ;

//  (Private API)
- (void)changeStyleTo:(int)index
{
//	NSButton *button ;
	NSTextField *text ;
	int i ;
	
//	button = [ styleArray selectedCell ] ;
	
	[ styleArray deselectAllCells ] ;
	[ styleArray selectCellAtRow:0 column:index ] ;
	
	for ( i = 0; i < 5; i++ ) {
		text = [ specLabel cellAtRow:0 column:i ] ;
		[ text setStringValue:( index == 0 ) ? freqLabel[i] : @"" ] ;
	}
	currentStyle = index ;
	[ scopeView setDisplayStyle:index plotColor:nil ] ;
}

//  (Private API)
- (void)changeSourceTo:(int)index
{
    Connection *c = [_connection objectAtIndex:index];
	if (c.pipe == nil ) {
		[ sourceArray deselectSelectedCell ] ;
		[ [ NSNotificationCenter defaultCenter ] postNotificationName:@"SysBeep" object:nil ] ;
		return ;
	}
	//  remove old connection
	if ( selected ) [ selected.pipe setTap:nil ] ;

	//  set new connection
	selected = c ;
	[ selected.pipe setTap:self ] ;
	[ sourceArray deselectAllCells ] ;
	[ sourceArray selectCellAtRow:0 column:index ] ;
	enableBaudotMarkers =c.enableBaudotMarkers ;
	timebase = c.timebase ;
}

- (void)connect:(int)index to:(CMTappedPipe*)pipe title:(NSString*)name baudotMarkers:(Boolean)baudot timebase:(int)inTimebase
{
	NSMatrix *matrix ;
	NSButton *button ;
	
	//  remove old connection
	if ( selected ) [ selected.pipe setTap:nil ] ;
	
	matrix = sourceArray ;
	button = [ matrix cellAtRow:0 column:index ] ;
	[ button setTitle:name ] ;
    
    Connection *c = [_connection objectAtIndex:index];
    
	c.pipe = pipe ;
	c.enableBaudotMarkers = baudot ;
	c.timebase = inTimebase ;
	[ self changeSourceTo:index ] ;
}

//  data arrived from sound source
- (void)importData:(CMPipe*)pipe
{
	if ( scopeView && [ [ scopeView window ] isVisible ] ) {
		self.data = [ pipe stream ] ;
		[ scopeView addData:self.data isBaudot:enableBaudotMarkers timebase:timebase ] ;
	}
	// rtty monitor has no destination
}

- (void)setTitle:(NSString*)title
{
	[ [ scopeView window ] setTitle:title ] ;
}

- (void)setTonePairMarker:(const CMTonePair*)tonepair
{
	[ scopeView setTonePairMarker:tonepair ] ;
}

- (void)showWindow
{
	if ( scopeView ) [ [ scopeView window ] orderFront:self ] ;
}

- (void)setPlotColor:(NSColor*)color
{
	[ scopeView setDisplayStyle:currentStyle plotColor:color ] ;
}

- (void)hideScopeOnDeactivation:(Boolean)hide
{
	[ [ scopeView window ] setHidesOnDeactivate:hide ] ;
}

- (IBAction)styleChanged:(id)sender ;
{
	NSButton *button ;
	
	button = [ styleArray selectedCell ] ;
	[ self changeStyleTo:(int)[ button tag ] ] ;
}

- (IBAction)sourceChanged:(id)sender
{
	NSButton *button ;
	int index ;
	
	button = [ sender selectedCell ] ;
	index = (int)[ button tag ] ;
	
	//  default style
	switch ( index ) {
	case 0:
	case 1:
		[ self changeStyleTo:0 ] ;		//  spectrum
		[ [ styleArray cellAtRow:0 column:0 ] setEnabled:YES ] ;
		break ;
	case 2:
	case 3:
	case 4:
		[ self changeStyleTo:1 ] ;		//  waveform
		[ [ styleArray cellAtRow:0 column:0 ] setEnabled:NO ] ;
		break ;
	}
	[ self changeSourceTo:index ] ;

}

@end
