//
//  AIFFSource.m
//  AudioInterface
//
//  Created by Kok Chen on 11/06/05
//	Ported from cocoaModem; file originally dated 1/21/05.
	#include "Copyright.h"
//

#import "AIFFSource.h"

void CheckError  (OSStatus error , const char*  operation);

@implementation AIFFSource

//  Allows data to be inserted from an AIFF or WAV file instead of the usual stream.
//  data is imported into AIFFSource through three means
//
//  -insertNextFileFrameWithOffset		: send next frame from file (with mono channel offset)
//  -insertNextStereoFileFrame			: send next stereo file frame to destination
//  -importData							: relays stream data to destination if file not active
//  
//  destination is an CMPipe

-(id)  init {
    self = [super init];
    soundFile = malloc(sizeof(AudioSoundFile));
    storage = malloc(1024*sizeof(float));
    return self;
}

- (void)pipeWithClient:(CMPipe*)inClient
{
	[ super pipeWithClient:inClient ] ;
	if ( self ) {
        self.data->samplingRate = 11025.0 ;
		self.data->array = &storage[0] ;
		self.data->components = 1 ;
		self.data->channels = 1 ;
		// soundFile
		soundFile->ID = 0 ;
		soundFile->active = NO ;
		soundFile->repeatFile = YES ;
		soundFile->stride = 1 ;
	}
}

- (float)samplingRate
{
	return soundFile->basicDescription.mSampleRate ;
}

- (void)setSamplingRate:(float)samplingRate
{
	self.data->samplingRate = samplingRate ;
}

- (void)setFileRepeat:(Boolean)doRepeat
{
	soundFile->repeatFile = doRepeat ;
}

- (int)soundFileStride
{
	return soundFile->stride ;
}

- (Boolean)soundFileActive
{
	return soundFile->active ;
}

- (void)stopSoundFile
{
	soundFile->active = NO ;
	if ( soundFile->ID ) {
       CheckError(AudioFileClose( soundFile->ID ), "Error closing Audio File") ;
    }
	soundFile->ID = 0 ;
}



//  fill in AudioStramBasicProperty, etc
static void GetSoundFileProperty( AudioSoundFile *s )
{
	UInt32 size ;
    UInt32 isWriteable;
	OSErr err ;
	AudioStreamBasicDescription *b ;
    UInt64 *a;

    
    UInt32 propertySize;
    CheckError(AudioFileGetPropertyInfo(s->ID, kAudioFilePropertyMagicCookieData, &propertySize, &isWriteable), "Couldn't get Magic Cookie Info");
    
    Byte* magicCookie = (UInt8*) malloc(sizeof(UInt8)* propertySize);
    
    CheckError(AudioFileGetProperty( s->ID, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie), "Couldn't get Magic Cookie itself");
    
	size = sizeof(UInt32) ;
	CheckError(AudioFileGetProperty( s->ID, kAudioFilePropertyFileFormat, &size, &s->fileFormat ), "Couldn't get file Format") ;
    
    
    
    CheckError(AudioFileGetPropertyInfo(s->ID,
                             kAudioFilePropertyAudioDataByteCount,
                             &size,
                             &isWriteable), "Couldn't get Audio Data Byte Count Info");
    
    
    a = &s->bytes;
	CheckError(AudioFileGetProperty( s->ID, kAudioFilePropertyAudioDataByteCount, &size, a), "Couldn't get Audio Data Byte Count Itself") ;
	size = sizeof( AudioStreamBasicDescription ) ;
	b = &s->basicDescription ;
	err = AudioFileGetProperty( s->ID, kAudioFilePropertyDataFormat, &size, b ) ;
    CheckError(err,"Couldn't get Audio File Property Data Format");
	if ( err == noErr ) {
		s->sampleSize = b->mBytesPerFrame/b->mChannelsPerFrame ;
		s->stride = b->mBytesPerFrame/s->sampleSize ;
		s->samples = s->bytes/( s->stride*s->sampleSize ) ;
		s->isBigEndian = ( b->mFormatFlags & kLinearPCMFormatFlagIsBigEndian ) != 0 ;
		s->isSigned = ( b->mFormatFlags & kLinearPCMFormatFlagIsSignedInteger ) != 0 ;
	}
}

//  return nil if user aborted, else path string
- (NSString*)openSoundFileWithTypes:(NSArray*)fileTypes
{
	
	
    NSURL *thisURL;
	CFURLRef ref ;
	int result ;
	OSErr err ;

	if ( soundFile->active ) [ self stopSoundFile ] ;

	NSOpenPanel *open = [ NSOpenPanel openPanel ] ;
	[ open setAllowsMultipleSelection:NO ] ;
    [ open setAllowedFileTypes:fileTypes];
    
	
	result = (int)[ open runModal] ;
	if ( result == NSOKButton ) {
		thisURL = [ [ open URLs ] objectAtIndex:0 ] ;
		//  now make an FSref
        ref = (__bridge CFURLRef) thisURL;
        //ref = [thisURL fileReferenceURL];
		if ( ref != nil) {
			err = AudioFileOpenURL( ref, kAudioFileReadPermission, 0, &(soundFile->ID) ) ;
            CheckError(err, "Couldn't open Audio File");
			if ( err == noErr ) {
				GetSoundFileProperty( soundFile ) ;
				soundFile->currentSample = 0 ;
				soundFile->active = YES ;
			}
		}
		return [thisURL absoluteString] ;
	}
	return nil ;
}

/* local */
- (void)fetchDataFromFile:(AudioSoundFile*)s channel:(int)offset bufferOffset:(int)bufferOffset
{
	int i, w, stride, skip ;
	short *u, t ;
	char *b ;
	unsigned char *c ;
	unsigned short *v ;
	float gain, *buffer ;
	
	stride = s->stride ;
	buffer = &storage[bufferOffset] ;
	
	if ( s->sampleSize == 1 ) {  /* 8-bit data */
		gain = 1./128.0 ;
		if ( s->isSigned ) {
			b = s->buf.b + offset ;
			for ( i = 0; i < 512; i++ ) {
				buffer[i] = *b*gain ;
				b += stride ;
			}
		}
		else {
			c = ( unsigned char*)( s->buf.b + offset ) ;
			for ( i = 0; i < 512; i++ ) {
				buffer[i] = *c*gain - 1.0 ;
				c += stride ;
			}
		}
	}
	else {	/* 16-bit data, sampleSize > 1 */
		gain = 1.0/32768.0 ;
		
		#if __BIG_ENDIAN__
		if ( s->isBigEndian ) {
			if ( s->isSigned ) {
				u = s->buf.u + offset ;
				for ( i = 0; i < 512; i++ ) {
					buffer[i] = *u*gain ;
					u += stride ;
				}
			}
			else {
				v = (unsigned short *)( s->buf.u + offset ) ;
				for ( i = 0; i < 512; i++ ) {
					buffer[i] = *v*gain - 1.0 ;
					v += stride ;
				}
			}
		}
		else {
			skip = stride*2 ;
			if ( s->isSigned ) {
				c = ( unsigned char* )s->buf.b + offset*2 ;
				for ( i = 0; i < 512; i++ ) {
					//  swap for little endian
					t = c[0] | ( c[1] << 8 ) ;
					buffer[i] = t*gain ;
					c += skip ;
				}
			}
			else {
				c = ( unsigned char* )s->buf.b + offset*2 ;
				for ( i = 0; i < 512; i++ ) {
					//  swap for little endian
					w = c[0] | ( c[1] << 8 ) ;
					buffer[i] = w*gain - 1.0 ;
					c += skip ;
				}
			}
		}
		#else /*LITTLE_ENDIAN */

		if ( !s->isBigEndian ) {
			if ( s->isSigned ) {
				u = s->buf.u + offset ;
				for ( i = 0; i < 512; i++ ) {
					buffer[i] = *u*gain ;
					u += stride ;
				}
			}
			else {
				v = (unsigned short *)( s->buf.u + offset ) ;
				for ( i = 0; i < 512; i++ ) {
					buffer[i] = *v*gain - 1.0 ;
					v += stride ;
				}
			}
		}
		else {
			skip = stride*2 ;
			if ( s->isSigned ) {
				c = ( unsigned char* )s->buf.b + offset*2 ;
				for ( i = 0; i < 512; i++ ) {
					//  swap for little endian
					t = ( c[0] << 8 ) | c[1] ;
					buffer[i] = t*gain ;
					c += skip ;
				}
			}
			else {
				c = ( unsigned char* )s->buf.b + offset*2 ;
				for ( i = 0; i < 512; i++ ) {
					//  swap for little endian
					w = ( c[0] << 8 ) | c[1] ;
					buffer[i] = w*gain - 1.0 ;
					c += skip ;
				}
			}
		}
		#endif
	}
}

//  fetch next 512 samples from AudioSoundFile and insert into CMPipe
//  return true if ended
- (Boolean)insertNextFileFrameWithOffset:(int)offset
{
	OSStatus status ;
	UInt32 bytes ;
    UInt32 packets;
    SInt64 inStartingPacket;
    
    
    
    
    if ( ( soundFile->currentSample+512 ) > soundFile->samples ) {
		// EOF reached
		if ( !soundFile->repeatFile ) {
			AudioFileClose( soundFile->ID ) ;
			return YES ;
		}
		//  repeat file at beginning
		soundFile->currentSample = 0 ;
	}


    inStartingPacket = (SInt64)soundFile->currentSample;
	bytes =soundFile->stride*soundFile->sampleSize*512 ;
    packets = soundFile->stride*512;
	//status = AudioFileReadBytes( soundFile->ID, FALSE, inStartingPacket*soundFile->sampleSize, &bytes,(void*) soundFile->buf.u) ;
    status = AudioFileReadPackets(soundFile->ID, TRUE, &bytes, NULL, inStartingPacket, &packets, (void*)soundFile->buf.u);
    
  	if ( status != noErr ) {
        
        AudioFileClose( soundFile->ID ) ;
        return YES;
    };

	//  extract data and send to client 
	[ self fetchDataFromFile:soundFile channel:offset bufferOffset:0 ] ;
	soundFile->currentSample += soundFile->stride*512 ;
	self.data->array = storage ;
	self.data->samples = 512 ;
	self.data->channels = 1 ;
	[ self exportData ] ;
	return NO ;
}
	
//  fetch next 512 stereo samples from AudioSoundFile and insert into CMPipe
//  truncate and return true if end reached
- (Boolean)insertNextStereoFileFrame
{
	int status ;
	UInt32 bytes ;

	bytes = soundFile->stride*soundFile->sampleSize*512 ;
	if ( ( soundFile->currentSample+512 ) > soundFile->samples ) {
		// EOF reached
		if ( !soundFile->repeatFile ) {
			[ self stopSoundFile ] ;
			return YES ;
		}
		//  repeat file
		soundFile->currentSample = 0 ;
	}
	status = AudioFileReadBytes( soundFile->ID, YES, soundFile->currentSample*soundFile->sampleSize, &bytes, soundFile->buf.u ) ;
	if ( status != 0 ) return YES ;
	
	//  extract and create "split complex" data and export to client 
	[ self fetchDataFromFile:soundFile channel:0 bufferOffset:0 ] ;
	if ( soundFile->stride == 1 ) {
		//  file is mono, duplicate the same mono channel of file into the output right channel
		[ self fetchDataFromFile:soundFile channel:0 bufferOffset:512 ] ;
	}
	else {
		//  file has more than one channel, fetch from second channel
		[ self fetchDataFromFile:soundFile channel:1 bufferOffset:512 ] ;
	}
	soundFile->currentSample += soundFile->stride*512 ;
	self.data->array = &storage[0] ;
	self.data->samples = 512 ;
	self.data->channels = 2 ; // "split complex" channels
	[ self exportData ] ;
	return NO ;
}

//  export imported data, but offsetting to the appropiate channel if it exist
- (void)importData:(CMPipe*)inpipe offset:(int)offset
{
	if ( soundFile->active ) return ;
	
	*self.data = *[ inpipe stream ] ;

	if ( offset < 2 ) {
		if ( self.data->channels != 1 ) {
			self.data->channels = 1 ;
			if ( offset != 0 ) self.data->array += self.data->samples ;
		}
	}
	[ self exportData ] ;
}

-(void)dealloc {
    free(soundFile);
}

@end
