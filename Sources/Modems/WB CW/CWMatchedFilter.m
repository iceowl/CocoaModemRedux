//
//  CWMatchedFilter.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 12/3/06.
#include "Copyright.h"


#import "CWMatchedFilter.h"
#import "MorseDecoder.h"
#import "Clears.h"
#import "CWReceiver.h"


@implementation CWMatchedFilter

@synthesize estimateSpeed    = _estimateSpeed;
@synthesize intervalConsumer = _intervalConsumer;
@synthesize intervalProducer = _intervalProducer;
@synthesize intervalBuffer   = _intervalBuffer;

#define	INTERWORD		1
#define	INTERELEMENT	2
#define	INTERCHARACTER	3
#define	DIT				4
#define	DASH			5

- (void)clearPipeline
{
	int i ;
	
	for ( i = 0; i < 32; i++ ) _intervalBuffer[i].interval = 10000 ;
	_intervalProducer = _intervalConsumer = 0 ;
	for ( i = 0; i < 4; i++ ) glitch[i].valid = NO ;
}

- (id)init
{
	self = [ super init ] ;
	if ( self ) {
		decoder = nil ;
		fast = NO ;
		cycle = 0 ;
		latency = 0 ;
		spacePrinted = YES ;
        running = FALSE;
        
        
        _intervalBuffer = (ElementType*)malloc(MAXINTERVALBUF * sizeof(ElementType));
		clearFloat( signal, 4096 ) ;
		
		//  initial match filter set for 20 wpm
		estimatedSpeed = 20 ;
		elementLength = ditLength = 18*92./estimatedSpeed ;
		interSymbolLength = dashLength = 3*elementLength ;
		[ self changeMatchedFilterToSpeed:estimatedSpeed force:YES ] ;
        
		decodePipeline = [ [ CWPipeline alloc ] initFromClient:self ] ;
		speedPipeline  = [ [ CWSpeedPipeline alloc ] initFromClient:self ] ;
		
		_estimateSpeed = [ [ NSConditionLock alloc ] initWithCondition:0 ] ;
		
		//[ NSThread detachNewThreadSelector:@selector(updateSpeed:) toTarget:self withObject:self ] ;
		[ self updateSpeed ];
        
		characterIndex = 0 ;
		[ self clearPipeline ] ;
		
		clearChar( character, 65 ) ;
		
	}
	return self ;
}

//  Sampled data from the complex mixer arrives here.
//  It is firt passed through a matched filter (matched to a dit), then resampled at 8:1 and placed in a ring buffer.
//
//	The data in the ring buffer are either passed to a threshold decoder, or after estimating the spectrum, are
//	passed to the speed estimating thread.

- (void)importData:(CMPipe*)pipe
{
	float *array ;
	CMDataStream *stream ;
	
	stream = [ pipe stream ] ;
	array = stream->array ;
	
    
    [ decodePipeline importArray:(float*)array ] ;
	[ speedPipeline importArray:(float*)array ] ;
	
    
	//  signal the speed estimating thread
	if ( cycle == 3 ) {
		[ _estimateSpeed lock ] ;
		[ _estimateSpeed unlockWithCondition:1 ] ;
	}
	cycle = ( cycle+1 )&0xf ;
}

- (void)newClick:(float)delta
{
	if ( fabs( delta ) > 30.0 ) {
		[ self clearPipeline ] ;
		if ( estimatedSpeed < 15 || estimatedSpeed > 30 ) {
			estimatedSpeed = 22 ;
			elementLength = ditLength = 18*92./estimatedSpeed ;
			interSymbolLength = dashLength = 3*elementLength ;
			[ self changeMatchedFilterToSpeed:estimatedSpeed force:YES ] ;
		}
	}
	cycle = 0 ;
	if ( receiver ) [ receiver setCWSpeed:0 limited:NO ] ;
}

//  since UI can be involved, -setCWSpeed: is performed in the main thread
- (void)updateInMainThread
{
	[ self changeMatchedFilterToSpeed:wpm force:NO ] ;
	if ( receiver ) [ receiver setCWSpeed:wpm limited:limited ] ;
}

//  Thread for speed estimation.
//  The estimateSpeed NSLock is unlocked by the data thread when a new spectrum is available.
- (void)updateSpeed
{
    if(running)return;
    running = TRUE;
    //	NSAutoreleasePool *pool ;
	__block float speed, change, ratio, trySpeed ;
	__block MorseTiming estimate ;
	__block CWMatchedFilter* cwSelf = self;
    //	pool = [ [ NSAutoreleasePool alloc ] init ] ;
    if(_speedFilterQueue == nil) _speedFilterQueue = dispatch_queue_create("com.owlhousetoys.CWSpeed", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(_speedFilterQueue,[ ^(void) {
        
        @autoreleasepool {
            
            while ( running ) {
                [ _estimateSpeed lockWhenCondition:1 ] ;
                [ _estimateSpeed unlockWithCondition:0 ] ;
                
                estimate = [ speedPipeline estimateMorseTiming ] ;
                speed = estimate.speed ;
                
                if ( speed > 4 && speed < 101 ) {
                    
                    //  if auto speed, try estimate the parameters
                    if ( chosenSpeed == 0 /* auto */ ) {
                        change = fabs( speed-wpm ) ;
                        wpm = ( change < 0.5 ) ? ( wpm*0.5 + speed*0.5 ) : speed ;
                        //  average it out a little
                        basicLength[0] = elementLength = elementLength*0.5 + estimate.interElement*0.5 ;
                        basicLength[1] = ditLength = estimate.dit ;
                        dashLength = estimate.dash ;
                        interSymbolLength = estimate.interSymbol ;
                        //  check to see if we really need to update
                        if ( fabs( estimatedSpeed - wpm ) > 0.25 ) {
                            limited = NO ;
                            [cwSelf updateInMainThread];
                            //[ self performSelectorOnMainThread:@selector(updateInMainThread) withObject:nil waitUntilDone:NO ] ;
                        }
                    }
                    else {
                        //  user selected speed
                        ratio = speed/chosenSpeed ;
                        if ( ratio > 1.0 ) ratio = 1.0/ratio ;
                        if ( ratio > 0.8 ) {
                            change = fabs( speed-wpm ) ;
                            wpm = ( change < 0.5 ) ? ( wpm*0.5 + speed*0.5 ) : speed ;
                            //  average it out a little
                            basicLength[0] = elementLength = elementLength*0.5 + estimate.interElement*0.5 ;
                            basicLength[1] = ditLength = estimate.dit ;
                            dashLength = estimate.dash ;
                            interSymbolLength = estimate.interSymbol ;
                            //  check to see if we really need to update
                            if ( fabs( estimatedSpeed - wpm ) > 0.25 ) {
                                limited = NO ;
                                [cwSelf updateInMainThread];
                                //[ self performSelectorOnMainThread:@selector(updateInMainThread) withObject:nil waitUntilDone:NO ] ;
                            }
                        }
                        else {
                            limited = YES ;
                            trySpeed = speed ;
                            if ( trySpeed > chosenSpeed/0.8 ) trySpeed = chosenSpeed/0.8 ; else if ( trySpeed < chosenSpeed*0.8 ) trySpeed = chosenSpeed*0.8 ;
                            elementLength = ditLength = 18*92./trySpeed ;
                            interSymbolLength = dashLength = 3*elementLength ;
                            change = fabs( trySpeed-wpm ) ;
                            wpm = ( change < 0.5 ) ? ( wpm*0.5 + trySpeed*0.5 ) : trySpeed ;
                            if ( fabs( estimatedSpeed - wpm ) > 0.25 ) {
                                [cwSelf updateInMainThread];
                                //[ self performSelectorOnMainThread:@selector(updateInMainThread) withObject:nil waitUntilDone:NO ] ;
                            }
                        }
                    }
                }
                usleep(10000);
            }
            
            running = FALSE;
        }
        
    } copy]);
    
    // original is not blocked ...
    //	[ pool release ] ;
}

- (void)newCharacter:(char*)string length:(int)length wordSpacing:(int)spacing
{
	if ( decoder ) [ decoder newCharacter:string length:length wordSpacing:spacing ] ;
}

- (int)interWord
{
	return elementLength*6 ;
}

//  A new Morse element is determined from the state (keyed or unkeyed) and duration (in units of 0.74 ms).
//  The local interElement, interWord, dit and dash are estimated and used to decide when a character is received.
- (void)updateDeglitchedMorseElement:(ElementType*)element pipe:(CWPipeline*)pipe
{
    char string[32] ;
    int count, i,  n, longElement, wordInterval ;
    float  u, v, sum ;
    Boolean flush ;
    

    ElementType *e ;
    int k,keyCount,lastUnkeyElement;
    float keyInterval[32];
    
	longElement = elementLength*2.0 ;
    
	_intervalBuffer[ _intervalProducer ] = *element ;
	_intervalProducer = ( _intervalProducer+1 ) & 0x1f ;
	
	//  find how many elements have not yet been processed
	n = _intervalProducer - _intervalConsumer ;
	if ( n < 0 ) n += MAXINTERVALBUF ;
	
	// v0.33 flush word, and add low latency
	if ( n < 10 && latency > 1 ) {		//  wait for at least 10 element-pairsbefore processing
		flush = ( element->state == 0 ) && ( element->interval > longElement*3/4 ) ;
		if ( !flush ) return ;
	}
    
	// now check for any long unkeyed element that has not been consumed
	keyCount = 0 ;
	k = _intervalConsumer ;
    //  if(_charFilterQueue == nil) _charFilterQueue = dispatch_queue_create("com.owlhousetoys.CWChar", DISPATCH_QUEUE_CONCURRENT);
    // dispatch_async(_charFilterQueue, [^(void) {
    //    @autoreleasepool {
    
    while ( 1 ) {
        
        if ( k == _intervalProducer ) {
           
            return ;
        }			//  did not find an intercharacter or interword element
        e = &_intervalBuffer[ k ] ;
        k = ( k+1 ) & 0x1f ;
        
        if ( e->state == 0 ) {
            
            lastUnkeyElement = e->interval ;
            if ( lastUnkeyElement > longElement ) {
                
                if ( keyCount <= 0 ) {
                    //  no keyed element... output a space if it has not already been emited
                    if ( !spacePrinted ) [ self newCharacter:"" length:0 wordSpacing:1 ] ;
                    spacePrinted = YES ;
                    //  long unkeyed element received with no keyed element, toss the interval
                    _intervalConsumer = k ;
                   
                    return ;
                }
                
                while ( _intervalBuffer[k].state == 0 ) {
                    if ( k == _intervalProducer ) {
                        return ;			//  did not find an intercharacter or interword element
                    }
                    lastUnkeyElement += _intervalBuffer[k].interval ;
                    k = ( k+1 ) & 0x1f ;
                    if ( lastUnkeyElement > elementLength*7 ){
                        break ;
                    }
                }
                break ;
            }
        }
        else {
            keyInterval[keyCount++] = e->interval ;			//  accumulate keyed intervals for decoding
        }
        //usleep(1000);
    }
    
    //    }
    
    //  } copy]);
    
    //  while(!exit){usleep(10000);}
    
    if ( keyCount <= 0 ) return ;							//  end of character not seen
    
    //  now check for the character spacing, e.g. take care of moderate Farnsworth spacing
    u = longElement*2.0 ;
    count = 0 ;
    sum = 0.0 ;
    for ( i = 0; i < 32; i++ ) {
        e = &_intervalBuffer[ i ] ;
        if ( e->interval < 5000.0 && e->interval > 12 ) {
            if ( e->state == 0 ) {
                if ( e->interval > longElement && e->interval < u ) {
                    sum += e->interval ;
                    count++ ;
                }
            }
        }
    }
    wordInterval = ( count > 0 ) ? 1.8*sum/count : elementLength*5.0 ;
    
    v = ( ditLength + dashLength )*0.5 ;
    for ( i = 0; i < keyCount; i++ ) {
        if ( keyInterval[i] < v ) n = '.' ; else n = '-' ;
        string[i] = n ;
    }
    string[keyCount] = 0 ;
    
    //  character retrieved, update the consumer pointer
    _intervalConsumer = k ;
    spacePrinted = ( lastUnkeyElement > wordInterval ) ;
    [ self newCharacter:string length:keyCount wordSpacing:spacePrinted ] ;
    //free(keyInterval);
}


//  callback from CWPipeline when a new Morse element is determined
- (void)updateMorseElement:(ElementType*)element pipe:(CWPipeline*)pipe
{
	int interval ;
	
	if ( pipe != decodePipeline || element->interval == 0 ) return ;
	
	//  v0.33
	if ( 1 || latency == 0 ) {
		[ self updateDeglitchedMorseElement:element pipe:pipe ] ;
		return ;
	}
	glitch[3] = *element ;
	
	//  glitch filter pipeline stage
	if ( glitch[0].valid ) {
		// send head element of glitch filter if it is valid
		if ( glitch[0].state != previousState ) {
			[ self updateDeglitchedMorseElement:&glitch[0] pipe:pipe ] ;
		}
		previousState = glitch[0].state ;
	}
    
	if ( glitch[1].valid && glitch[2].valid ) {
		interval = glitch[1].interval+glitch[2].interval ;
		if ( interval < ditLength ) {
			glitch[2] = glitch[3] ;
			glitch[2].interval += interval ;
			glitch[0].valid = glitch[1].valid = NO ;
			return ;
		}
	}
	glitch[0] = glitch[1] ;
	glitch[1] = glitch[2] ;
	glitch[2] = glitch[3] ;
}

- (void)changeCodeSpeedTo:(int)speed
{
	chosenSpeed = speed ;
	if ( speed <= 0 ) return ;
	//  if it is not auto speed, set matched filters for the chosen speed
	[ self changeMatchedFilterToSpeed:speed*1.0 force:YES ] ;
}

- (void)setLatency:(int)value
{
	latency = value ;
}

//  pick a matched filter for the code speed
- (void)changeMatchedFilterToSpeed:(float)speed force:(Boolean)forced
{
	if ( !forced && fabs( estimatedSpeed - speed ) < 0.25 ) return ;
    
	estimatedSpeed = speed ;
	[ decodePipeline updateFilter:331*(0.85)*5.0/estimatedSpeed ] ;
	[ speedPipeline  updateFilter:331*(0.30)*5.0/estimatedSpeed ] ;
}

- (void)setDecoder:(MorseDecoder*)client receiver:(CWReceiver*)rx
{
	decoder = client ;
	receiver = rx ;
}

- (void)setSquelch:(float)db fastQSB:(float)fastQSB slowQSB:(float)slowQSB
{
	[ decodePipeline setSquelch:db fastQSB:fastQSB slowQSB:slowQSB ] ;
	[ speedPipeline  setSquelch:db fastQSB:fastQSB slowQSB:slowQSB ] ;
}

- (int)elementLength
{
	return elementLength ;
}

@end
