//
//  AuralMonitor.m
//  cocoaModem 2.0
//
//  Created by Kok Chen on 10/31/09.
//  Copyright 2009 Kok Chen, W7AY. All rights reserved.
//

#import "AuralMonitor.h"
#import "Plist.h"
#import "Preferences.h"
#import "AuralBuffer.h"

@implementation AuralMonitor

@synthesize auralBuffer = _auralBuffer;
@synthesize activeClient = _activeClient;

//  (Private API)
- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

- (id)init
{
	self = [ super init ] ;
	if ( self ) {
		clients = 0 ;
		stereoBlend = 0.5 ;
		stepAttenuator = 0.707 ;
		producerSampleIndex = consumerSampleIndex = 0 ;			//  v0.88
		readHysteresis = 0 ;									//  v0.88
		readBlocked = NO ;										// v0.88
        
        _auralBuffer = [[NSMutableArray alloc] initWithCapacity:AURALBUFFERS];
        _activeClient = [[NSMutableArray alloc] initWithCapacity:AURALCLIENTS];
		
		if ( [ [NSBundle mainBundle] loadNibNamed:@"AuralMonitor" owner:self topLevelObjects:nil] ) {
			lock = [ [ NSLock alloc ] init ] ;
			modemDest = [ [ PushedStereoDest alloc ] initIntoView:controlView device:@"Aural Monitor" level:levelView client:self ] ;
			[ modemDest setSoundLevelKey:kAuralMonitorLevel attenuatorKey:kAuralMonitorAttenuator ] ;
			[ modemDest setupSoundCards ] ;
			//  for now
			[ modemDest enableOutput:NO ] ;
			//[ modemDest enableOutput:YES ] ;
			[ self setInterface:muteCheckBox to:@selector(muteChanged) ] ;
			[ self setInterface:blendSlider to:@selector(blendChanged) ] ;
            for(int q = 0;q < AURALCLIENTS;q++)_activeClient[q] = [NSNull null] ;
            for(int q = 0;q < AURALBUFFERS;q++)_auralBuffer[q]  = [[AuralBuffer alloc] init];
			return self ;
		}
	}
	return nil ;
}

- (void)muteChanged
{
	Boolean muted ;
	
	muted = ( [ muteCheckBox state ] == NSOnState ) ;
	
	if ( muted == NO ) {
		[ modemDest enableOutput:YES ] ;									//  v0.88 turn on at start
		[ modemDest startSampling ] ;
	}
	else {
		[ modemDest stopSampling ] ;
		[ modemDest enableOutput:NO ] ;									//  v0.88 turn on at start
	}
	[ modemDest setMute:muted ] ;
}

- (void)blendChanged
{
	stereoBlend = [ blendSlider floatValue ] ;
	if ( stereoBlend > 0.5 ) stereoBlend = 0.5 ; else if ( stereoBlend < 0 ) stereoBlend = 0 ;
}

//  v0.88 callback from PushedStereoDest (ModemDest)
- (void)setOutputScale:(float)value
{
	stepAttenuator = value ;
}

//  place DestClient into the actively sampling list
- (void)addClient:(DestClient*)client
{
	
	[ lock lock ] ;
    if ([_activeClient indexOfObject:client] != NSNotFound) {
        [ lock unlock ];
        return;
    }
    
    //[_activeClient removeObjectAtIndex:clients ];
    [_activeClient addObject:client];
	clients++;
	if ( clients >= 1 ) {
		[ modemDest startSampling ] ;
	}
	[ lock unlock ] ;
}

//  place DestClient into the actively sampling list
- (void)removeClient:(DestClient*)client
{
	//int i ;
	
	[ lock lock ] ;
	//  check if this client is actually active
    if([_activeClient indexOfObject:client] == NSNotFound ){
		[ lock unlock ] ;
		return ;
	}
	//  remove the unregistering client
    
    [_activeClient removeObject:client];
    clients-- ;
	if ( clients <= 0 ) {
		[ modemDest stopSampling ] ;
	}
	[ lock unlock ] ;
}

//  clients add data to the Aural Monitor here.
//	left and right channel data can be nil.
- (void)addLeft:(float*)leftp right:(float*)rightp samples:(int)samples client:(DestClient*)who
{
	int i, size, samplesAvailable, writeBlock ;
	float *ldest, *rdest ;
	float left[512], right[512], v, alpha, beta ;
	AuralBuffer *a ;
    NSInteger n;
	
	if ( samples != 512 ) return ;		//  sanity check
	
	//  v0.88 check if input is close to overruning output
	samplesAvailable = (int)producerSampleIndex - (int)consumerSampleIndex ;
	if ( samplesAvailable > (AURALBUFFERS-4)*512 ) {
		//  already 12 AURALBUFFERS ahead of playback pointer
		return ;
	}
	
	//  v0.88 stereo blend
	alpha = ( 1-stereoBlend )*stepAttenuator ;
	beta = stereoBlend*stepAttenuator ;
	size = 512*sizeof( float ) ;
	
	if ( leftp == nil ) {
		memset( left, 0, size ) ;
		memset( right, 0, size ) ;
	}
	else {
		for ( i = 0 ; i < 512; i++ ) {
			v = leftp[i] ;
			left[i] = v*alpha ;
			right[i] = v*beta ;
		}
	}
	if ( rightp != nil ) {
		for ( i = 0 ; i < 512; i++ ) {
			v = rightp[i] ;
			left[i] += v*beta ;
			right[i] += v*alpha ;
		}
	}
    
	//  check if the client is already in the current buffer
	writeBlock = ( producerSampleIndex/512 ) % AURALBUFFERS ;
    
    //	a = _auralBuffer[writeBlock] ;
    //	n = a.clients ;
    //	for ( i = 0; i < n; i++ ) {
    //		if ( a.client[i] == who ) break ;
    //	}
    
    
    
    a = _auralBuffer[writeBlock];
    n = [ a.client indexOfObject:who ];
    
	if ( n != NSNotFound ) {
        a.clients = 1;
        [a.client removeObjectAtIndex:0];
        [a.client insertObject:who atIndex:0];
		memcpy( a.left, left, 512*sizeof( float ) ) ;
		memcpy( a.right, right, 512*sizeof( float ) ) ;
	}
	else {
		//  add the client to the current buffer's client list, and mix the new data into it
        int i_clients = a.clients;
        [ a.client removeObjectAtIndex:i_clients];
        [ a.client insertObject:who atIndex:i_clients];
        [a setClients:i_clients+1];
        ldest = a.left ;
		rdest = a.right ;
		for ( i = 0; i < 512; i++ ) {
			ldest[i] += left[i] ;
			rdest[i] += right[i] ;
		}
	}
	producerSampleIndex += 512 ;
}

//	Sound Card fetches data from here.
- (int)needData:(float*)outbuf samples:(int)requestedSamples channels:(int)ch
{
	int i, block, samplesAvailable, sampleOffset ;
	float *left, *right ;
	AuralBuffer *a ;
	
	if ( clients == 0 ) {
		//  sanity check
		[ modemDest stopSampling ] ;
		memset( outbuf, 0, requestedSamples*ch*sizeof( float ) ) ;
		return requestedSamples ;
	}
	
	//  v0.88  use producer-consumer model
	samplesAvailable = (int)(producerSampleIndex - consumerSampleIndex);
	
	//  sanity check
	if ( readHysteresis > 1024 ) readHysteresis = 1024 ;
	
	if ( samplesAvailable < requestedSamples+readHysteresis  || producerSampleIndex > 0x3ffffff ) {
        //  v0.88 once we run out of data, don't return until we have at least 1024 more samples than neccessary
        memset( outbuf, 0, requestedSamples*ch*sizeof( float ) ) ;
        readHysteresis = 512 ;
		if ( !readBlocked ) {
			consumerSampleIndex = 1;		//  this skips the first buffer sent to the aural monitor after input resumes (could be leftover)
			producerSampleIndex = 0 ;
		}
        readBlocked = TRUE;
        return requestedSamples ;
        
	}
	readBlocked = NO ;
	readHysteresis = 0 ;
	
	block = ( consumerSampleIndex / 512 ) % AURALBUFFERS ;
	sampleOffset = consumerSampleIndex%512 ;
	
	//  truncate read to the samples remaining in 512 samples buffer
	samplesAvailable = 512 - sampleOffset ;
	if ( requestedSamples > samplesAvailable ) requestedSamples = samplesAvailable ;
	a = [_auralBuffer objectAtIndex:block];
    
        if ( ch == 1 ) {
            memcpy( outbuf, &(a.left[sampleOffset]), sizeof( float )*requestedSamples ) ;
        }
        else {
            left  = &((a.left)[sampleOffset]) ;
            right = &((a.right)[sampleOffset]);
            int j = 0;
            for ( i = 0; i < requestedSamples; i++ ) {
                outbuf[j++] = left[i] ;
                outbuf[j++] = right[i] ;
            }
        }
	//  advance read pointer
	consumerSampleIndex += requestedSamples ;
    
	return requestedSamples ;
}

- (void)showWindow
{
	[ window setLevel:NSFloatingWindowLevel ] ;
	[ window makeKeyAndOrderFront:self ] ;
}

- (void)setupDefaultPreferences:(Preferences*)pref
{
	[ pref setFloat:0.0 forKey:kAuralMonitorBlend ] ;										//  v0.88
	[ pref setInt:0 forKey:kAuralMonitorMute ] ;
	if ( modemDest != nil && pref != nil ) [ modemDest setupDefaultPreferences:pref ] ;
}

- (void)updateFromPlist:(Preferences*)pref
{
	int mute ;
	
	if ( pref != nil ) {
		if ( modemDest != nil ) {
			[ modemDest updateFromPlist:pref updateAudioLevel:NO ] ;
			
			mute = [ pref intValueForKey:kAuralMonitorMute ] ;						//  v0.88
			[ muteCheckBox setState:( mute == 0 ) ? NSOffState : NSOnState ] ;
            
			if ( [ muteCheckBox state ] == NSOffState ) {
				[ modemDest enableOutput:YES ] ;									//  v0.88 turn on at start
				[ modemDest startSampling ] ;
			}
		}
		stereoBlend = [ pref floatValueForKey:kAuralMonitorBlend ] ;
		if ( blendSlider ) {
			[ blendSlider setFloatValue:stereoBlend ] ;
			[ self blendChanged ] ;
		}
	}
}

//  v0.86 (don't update aural monitor level)
- (void)retrieveForPlist:(Preferences*)pref
{
	if ( pref != nil ) {
		if ( modemDest != nil ) [ modemDest retrieveForPlist:pref updateAudioLevel:NO ] ;			//  v0.86
		[ pref setInt:( [ muteCheckBox state ] == NSOnState ) ? 1 : 0 forKey:kAuralMonitorMute ] ;	//  v0.88  missing plist
		[ pref setFloat:[ blendSlider floatValue ] forKey:kAuralMonitorBlend ] ;					//  v0.88
	}
}

//		This is called from Application.m when terminating to ensure that the output ModemDest stops sampling
- (void)unconditionalStop
{
	if ( modemDest ) [ modemDest stopSampling ] ;
}

@end
