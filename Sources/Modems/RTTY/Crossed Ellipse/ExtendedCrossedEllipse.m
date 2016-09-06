//
//  ExtendedCrossedEllipse.m
//  cocoaModem
//
//  Created by Kok Chen on 8/20/05.
#include "Copyright.h"
//

#import "ExtendedCrossedEllipse.h"
#include "CoreFilter.h"
#include "modemTypes.h"


@implementation ExtendedCrossedEllipse

@synthesize fsk = _fsk;
@synthesize fskColor = _fskColor;
@synthesize lock = _lock;

//  this extends the CrossedEllipse indicator to include an FSK "spectra tune"
//  it was an integral part of CrossedEllipse.m but is stripped out to allow indicators
//	with no spectra tune.

- (void)preSetup
{
	int i ;
	
	[ super preSetup ] ;
	_fsk = nil ;
	_fskColor =  [ NSColor colorWithCalibratedRed:0.95 green:0 blue:0 alpha:1.0 ] ;
    
	for ( i = 0; i < 128; i++ ) avgfreq[i] = 0 ;
	spectrum = FFTSpectrum( 9, YES ) ;
    _lock = [[NSLock alloc] init];
    displayMux = 0;
}


- (void)postSetup:(int)mask r:(int)rshift g:(int)gshift b:(int)bshift a:(int)ashift
{
	int i ;
	UInt32 a, r, g, b, r0, g0, b0 ;
    
	//  make intensity map for FSK spectrum
	r0 = ( plotBackground >> rshift ) & mask ;
	g0 = ( plotBackground >> gshift ) & mask ;
	b0 = ( plotBackground >> bshift ) & mask ;
    
	a = mask <<= ashift ;
	if ( depth >= 24 ) {
		for ( i = 0; i < 256; i++ ) {
			r = i + r0 ;
			if ( r > 255 ) r = 255 ;
			r <<= rshift ;
			g = i + g0 ;
			if ( g > 255 ) g = 255 ;
			g <<= gshift ;
			b = i/2 + b0 ;
			if ( b > 255 ) b = 255 ;
			b <<= bshift ;
			intensity[i] = r + g + b + /* alpha */ a ;
		}
		for ( i = 0; i < 256; i++ ) {
			r = i/2 + r0 ;
			if ( r > 255 ) r = 255 ;
			r <<= rshift ;
			g = i/2 + g0 ;
			if ( g > 255 ) g = 255 ;
			g <<= gshift ;
			b = i/4 + b0 ;
			if ( b > 255 ) b = 255 ;
			b <<= bshift ;
			intensityFade[i] = r + g + b + /* alpha */ a ;
		}
	}
	else {
		for ( i = 0; i < 256; i++ ) {
			r = i/16 + r0 ;
			if ( r > 15 ) r = 15 ;
			r <<= rshift ;
			g = i/16 + g0 ;
			if ( g > 15 ) g = 15 ;
			g <<= gshift ;
			b = i/32 + b0 ;
			if ( b > 15 ) b = 15 ;
			b <<= bshift ;
			intensity[i] = r + g + b + /* alpha */ a ;
		}
		for ( i = 0; i < 256; i++ ) {
			r = i/32 + r0 ;
			if ( r > 15 ) r = 15 ;
			r <<= rshift ;
			g = i/32 + g0 ;
			if ( g > 15 ) g = 15 ;
			g <<= gshift ;
			b = i/64 + b0 ;
			if ( b > 15 ) b = 15 ;
			b <<= bshift ;
			intensityFade[i] = r + g + b + /* alpha */ a ;
		}
	}
}

- (void)setTonePair:(const CMTonePair*)tonepair
{
	NSBezierPath *oldfsk ;
	float avg, offset, half, mf, sf ;
    
	[ super setTonePair:tonepair ] ;
	
	mf = tonepair->mark ;
	sf = tonepair->space ;
	
	//  spectrum calibration
	//  128 samples == 2756 Hz, 2210 Hz is at 95.6
	avg = ( mf+sf )*0.5 ;
	offset = ( int )( ( avg-2210 )*128/2756 + 95.6 ) + 0.5 ;
	half = width/2 + 0.5 ;
	
	[ _lock lock ] ;
	oldfsk = _fsk ;
	_fsk = [ [ NSBezierPath alloc ] init ] ;
	[ _fsk moveToPoint:NSMakePoint( offset, half-scale ) ] ;
	[ _fsk lineToPoint:NSMakePoint( offset, half-scale-8 ) ] ;
	//if ( oldfsk ) [ oldfsk release ] ;
	[ _lock unlock ] ;
}



- (void)drawObjects : (NSRect) rect
{

    [self.image drawInRect:rect fromRect:NSZeroRect  operation:NSCompositeCopy fraction:1.0];
    [ self.scaleColor set ] ;
	[ self.axis stroke ] ;
	[ _fskColor set ] ;		//  not in base class
	[ _fsk stroke ] ;		//  not in base class
}


- (void)drawRect:(NSRect)rect
{
	[ super drawRect:rect ] ;
    //[ self drawObjects :rect ] ;
}


//  Extended Crossed Ellipse FSK spectrum
- (void)spectrum:(CMTappedPipe*)pipe
{
	CMDataStream *stream ;
	float *data, sum, norm ;
	int i, y, offset, width2 ;
	UInt32 spec[128], specFade[128], *pix  ;
	UInt16 *spix ;
	
	stream = [ pipe stream ] ;
	data = stream->array ;
	
	CMPerformFFT( spectrum, data, freq ) ;
	
	//  512 point transform, 128 samples == 2756 Hz
	norm = 0.001 ;
	for ( i = 0; i < 128; i++ ) {
		sum = freq[i+14] ;			// 2210 Hz is at (64+38.64)-14
		freq[i] = sum ;
		if ( sum > norm ) norm = sum ;
	}
	norm = 400.0/norm ;
	for ( i = 0; i < 128; i++ ) {
		avgfreq[i] = avgfreq[i]*0.8 + freq[i]*0.2 ;
		offset = avgfreq[i]*norm ;
		if ( offset > 255 ) offset = 255 ;
		spec[i] = intensity[offset] ;
		specFade[i] = intensityFade[offset] ;
	}
	
	//  display spectrum (two scanlines of memory, top line has persistence)
	//  width is 140, so supports a 128 wide spectrum
	y = (height-8)*width + ( width/2 ) - 64 ;
	width2 = 2*width ;
	if ( depth >= 24 ) {
		pix = &pixel[y] ;
		for ( i = 0; i < 128; i++ ) {
			pix[width] = spec[i] ;
			pix[0] = pix[width2] = specFade[i] ;
			pix++ ;
		}
	}
	else {
		spix = (UInt16*)pixel ;
		spix += y ;
		for ( i = 0; i < 128; i++ ) {
			spix[width] = spec[i] ;
			spix[0] = spix[width2] = specFade[i] ;
			spix++ ;
		}
	}
}




- (void)importDataInMainThread:(CMPipe*)pipe
{
    
    

	
	//  update data to mark and space filters
	if ( [ _lock tryLock ] ) {
		[ self importDataIIR:(CMTappedPipe*)pipe ] ;
	 	[ self spectrum:(CMTappedPipe*)pipe ] ;			//  not in base class
		//	v1.03 -- allocate new BitmapImageRep for Mountain Lion
		[ self.image removeRepresentation:self.bitmap ] ;
		//[ bitmap release ] ;
		[ self createNewImageRep:NO ] ;				//  create new NSBitmapImage rep with the local buffers
		[ self.image addRepresentation:self.bitmap ] ;
        
        
		if ( ( ++displayMux & 0x3 ) == 0 ) {
			//  use a smaller rect to keep refresh time down
			if ( displayMux > 16 ) {
				// once in a while, update the entire display to clean any crud
				displayMux = 0 ;
				[ self setNeedsDisplay:YES ] ;
			}
			else {
				
				[ self setNeedsDisplayInRect:currentRect ] ;
			}
		} else {
                [self setNeedsDisplayInRect:currentRect];
        }
		[ _lock unlock ] ;
	}

}

//  assume data is 11025, 1 channel
- (void)importData:(CMPipe*)pipe
{
	if ( !modem ) return ;
    if(!timer1) [self myCreateTimer:pipe];
    okToDraw = TRUE;
	//[ self performSelectorOnMainThread:@selector(importDataInMainThread:) withObject:pipe waitUntilDone:NO ] ;
}

-(dispatch_source_t) CreateDispatchTimer :(uint64_t) interval
                                         :(uint64_t) leeway
                                         :(dispatch_queue_t) queue
                                         :(dispatch_block_t) block {
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0, 0, queue);
    
    if (timer)    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    
    return timer;
    
}

-(void) myCreateTimer : (CMPipe*)pipe

{
    __block bool *w_okToDraw = &okToDraw;
    __block CMPipe* w_wPipe = pipe;
    __block ExtendedCrossedEllipse* bSelf = self; // capture so as to not have compiler complain about ARC retain cycles...dunno if this is going to be a problem.
    
    if(!ellipseQueue) ellipseQueue = dispatch_queue_create("com.owlhousetoys.ellipseTimer", DISPATCH_QUEUE_SERIAL);
    if((!timer1) && ellipseQueue) {
        // g_timerQueue = dispatch_queue_create("com.owlhousetoys.waterfallTimer", DISPATCH_QUEUE_SERIAL);
        // g_timerQueue = dispatch_get_current_queue();
        // g_timerQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        timer1 = [self  CreateDispatchTimer :100ull * NSEC_PER_MSEC
                                              :10ull * NSEC_PER_MSEC
                                              :ellipseQueue
                                              :gBlock = ^{
                                                  if(*w_okToDraw){
                                                      [bSelf importDataInMainThread:w_wPipe];
                                                      *w_okToDraw = FALSE;
                                                  }
                                                  // usleep(10);
                                              }];
        
        [gBlock copy]; // copy to heap so not sitting on stack with all those self vars...
    }
}

-(void)killEllipseTimer {
    
    if(timer1) dispatch_source_cancel(timer1);
   // if(g_timer2) dispatch_source_cancel(g_timer2);
    //    m_waterfallRunning = FALSE;
    //    usleep(20000);
}


-(void) dealloc {
    [self killEllipseTimer];
}




@end
