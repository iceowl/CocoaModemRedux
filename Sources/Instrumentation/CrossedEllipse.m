//
//  CrossedEllipse.m
//  diddles
//
//  Created by Kok Chen on 10/7/11.
//  Copyright 2011 Kok Chen, W7AY. All rights reserved.
//

#import "CrossedEllipse.h"
#import "CrossedEllipseFilter.h"
#import "CrossedEllipseChannel.h"

#define	kFilterLength	128
#define	kInhibitHead	2
#define	kInhibitTail	1

@implementation CrossedEllipse

//	"Two-beam" cross ellipse tuning indicator.
//	The filtered Mark and Space signals are projected as two separate "beams" to the display.
//	This removes the extraneous traces between the ellipses as seen on conventional crossed ellipse displays.

- (void)drawRect:(NSRect)frame
{
	if ( ignore ) return ;
	[ backgroundColor set ] ;
	[ background fill ] ;
	[ borderColor set ] ;
	[ background stroke ] ;
	[ waveformColor set ] ;
	if ( mark.path ) [ mark.path stroke ] ;
	if ( space.path ) [ space.path stroke ] ;
	[ graticuleColor set ] ;
	[ graticule stroke ] ;
	if ( embedCross ) {
		[ crossColor set ] ;
		[ crossPath[0] stroke ] ;
		[ crossPath[1] stroke ] ;
		[ crossGraticule stroke ] ;
	}
}

//  (Private API)
//	Interpolate baseband samples at 3000 samples/second into 24000 smaples/sec
- (void)interpolate:(Complex*)baseband toChannel:(CrossedEllipseChannel*)channel
{
	memcpy( baseband, channel.tail, sizeof( Complex )*kInterpolationSpan ) ;
	memcpy( channel.tail, &baseband[kBasebandBufferSize], sizeof( Complex )*kInterpolationSpan ) ;
	[ channel.interpolate interpolateComplexArray:baseband into:channel.q samples:kBasebandBufferSize ] ;
}

//	(Private API)
//	update channel's pointers
- (void)updatePointersForChannel:(CrossedEllipseChannel*)channel
{
	int n ;
	
	n = ( mux )*kInterpolatedSize ;
	channel.p = &channel.data[n] ;
	n = ( pmux )*kInterpolatedSize ;
	channel.q = &channel.data[n] ;
}

- (void)drawPoints:(CrossedEllipseChannel*)channel otherChannel:(CrossedEllipseChannel*)other verticalAxis:(Boolean)axis start:(int)start end:(int)end
{
	float x, y, x0, y0, dx, dy, lastx, lasty, ureal, vreal, noise, flat ;
	CGPoint *point ;
	Complex u, v, *p, *q ;
	Boolean *penDown ;
	int i, index ;

	//  cache channel's states
	index = channel.index ;
	point = &((channel.point)[0]) ;
	penDown = &channel.penDown[0] ;
	p = &channel.p[0] ;
	q = &other.p[0] ;
	lastx = channel.last.x ;
	lasty = channel.last.y ;
	
	x0 = width*0.5 ;
	y0 = height*0.5 ;
	
	flat = 5.0/agc ;
	for ( i = start; i < end; i++ ) {
		//  draw point
		u = p[i] ;
		v = q[i] ;
		ureal = crealf( u ) ;
		vreal = crealf( v ) ;	
		x = ellipseScale*( ureal + aspectRatio*cimagf( v ) ) ;
		y = -ellipseScale*( vreal - aspectRatio*cimagf( u ) ) ;
		dx = lastx - x ;
		dy = lasty - y ;
		//  plot only if point has moved sufficiently
		if ( fabs( dx ) + fabs( dy ) >= flat ) {
			//  moved in Manhattan metric by more than 3 pixels
			lastx = x ;
			lasty = y ;
			//	apply agc and dither the output
			noise = dither[i] ;
			x = x*agc + noise ;
			y = y*agc + noise ;
			point[index] = ( axis ) ? NSMakePoint( y+y0, x+x0 ) : NSMakePoint( x+x0, y+y0 ) ;
			penDown[index] = YES ;
			index = ( index+1 ) & kPhosphorDecayMask ;
		}
	}
	//  restore channel's states
	channel.index = index ;
	channel.penstate = YES ;
	channel.last = NSMakePoint( lastx, lasty ) ;
}

- (void)liftPen:(CrossedEllipseChannel*)channel duration:(int)duration
{
	CGPoint *point ;
	Boolean *penDown ;
	int i, index ;
	
	//  cache channel's states
	index = channel.index ;
	point = &channel.point[0];
	penDown = &channel.penDown[0] ;
	
	if ( channel.penstate == YES ) {
		channel.penstate = NO ;
		//  inhibit plotting of half of the frame
		//  lift pen (indicated by (0,0)
		//  erase a few samples to mimic phosphor decay
		for ( i = 0; i < duration; i++ ) {	
			point[index] = NSMakePoint( 0, 0 ) ;
			penDown[index] = NO ;
			index = ( index+1 ) & kPhosphorDecayMask ;
		}
		channel.index = index ;
	}
}

- (void)updatePlotData:(CrossedEllipseChannel*)channel otherChannel:(CrossedEllipseChannel*)other verticalAxis:(Boolean)axis inhibit:(int)inhibit
{	
	//  check for inhibits
	//	if this frame is inhibited, also inhibit second half of previous frame
	if ( inhibit != 0 ) {
		channel.gated[mux] = 3 ;
		if ( inhibit & kInhibitHead ) {
			//  inhibit at first half of frame, pass that on to the end of the previous frame
			channel.gated[pmux] |= kInhibitTail ;
		}
	}
	else {
		//  gate the first half of the frame if the second half of the previous frame is inhibited
		channel.gated[mux] = ( ( channel.previousFrameInhibit & kInhibitTail ) != 0 ) ? kInhibitHead : 0 ;
	}
	channel.previousFrameInhibit = inhibit ;

	switch ( channel.gated[pmux] ) {
	default:
	case (kInhibitHead|kInhibitTail):
		[ self liftPen:channel duration:16 ] ;
		break ;
	case kInhibitTail:
		[ self drawPoints:channel otherChannel:other verticalAxis:axis start:0 end:kInterpolatedSize/2 ] ;
		[ self liftPen:channel duration:8 ] ;
		break ;
	case kInhibitHead:
		[ self liftPen:channel duration:8 ] ;
		[ self drawPoints:channel otherChannel:other verticalAxis:axis start:kInterpolatedSize*2 end:kInterpolatedSize ] ;
		break ;
	case 0:
		[ self drawPoints:channel otherChannel:other verticalAxis:axis start:0 end:kInterpolatedSize ] ;
		break ;
	}
}

- (void)updateCrossData:(CrossedEllipseChannel*)channel otherChannel:(CrossedEllipseChannel*)other verticalAxis:(Boolean)axis inhibit:(int)inhibit
{
	float x, y, accumx, accumy ;
	Complex *p, *q ;
	int i ;
	
	accumx = accumy = 0.0 ;
	
	p = &channel.p[0] ;
	q = &other.p[0] ;
	if ( channel.gated[pmux] == 0 ) {
		for ( i = 0; i < kInterpolatedSize; i++ ) {
			x = crealf( p[i] ) ;
			y = crealf( q[i] ) ;
			if ( x < 0 ) {
				accumx += x ;
				accumy -= y ;
			}
			else {
				accumx -= x ;
				accumy += y ;
			}
		}
		channel.crossPoint = ( axis ) ? NSMakePoint( accumy, accumx ) : NSMakePoint( accumx, accumy ) ;
	}
}

//	create the NSBezierPath for either the Mark or Space channel
- (void)createPathForChannel:(CrossedEllipseChannel*)channel
{
	NSBezierPath *path ;
	int i, n ;
	CGPoint *point ;
	Boolean penstate, *penDown ;
	
	path = channel.path ;
	[ path removeAllPoints ] ;
	
	penstate = NO ;
	n = channel.index ;
	point = &channel.point[0];
	penDown = &channel.penDown[0] ;
	
	
	for ( i = 2; i < kPhosphorDecayMask; i++ ) {
		if ( penDown[n] == NO ) {
			//  lift pen
			penstate = NO ;
		}
		else {
			if ( penstate == NO ) {
				//  lower pen if not already lowered
				[ path moveToPoint:point[n] ] ;
				penstate = YES ;
			}
			else {
				//  draw path if pen is already lowered earlier
				[ path lineToPoint:point[n] ] ;
			}
		}
		n = ( n+1 ) & kPhosphorDecayMask ;
	}
}

static inline float absDot( NSPoint a, NSPoint b )
{
	return fabs( a.x*b.x + a.y*b.y ) ;
}

static inline float absQuadratureDot( NSPoint a, NSPoint b )
{
	return fabs( a.x*b.y - a.y*b.x ) ;
}

- (void)accumToPath:(NSPoint)a
{
	NSPoint p ;
	float x, y ;
	int i ;
	
	if ( a.x == 0 && a.y == 0 ) return ;
	
	i = 0 ;
	p = sortedCrossPoint[0] ;
	
	if ( absDot( p, a ) < absQuadratureDot( p, a ) ) {
		i = 1 ;
		p = sortedCrossPoint[1] ;
	}
	//  First align ( a.x,a.y ) in the same quadrant as ( p.x,p.y ) before accumulating into ( p.x,p.y )
	//	Use the larger of ( a.x,a.y ) to determine which component to comare with ( p.x,p.y ).
	if ( fabs( a.x ) > fabs( a.y ) ) {
		if ( a.x*p.x < 0 ) {
			a.x = -a.x ;
			a.y = -a.y ;
		}
	}
	else {
		if ( a.y*p.y < 0 ) {
			a.x = -a.x ;
			a.y = -a.y ;
		}
	}
	//  leaky accumulate	
	x = p.x*0.9 + 0.1*a.x ;
	y = p.y*0.9 + 0.1*a.y ;
	sortedCrossPoint[i] = NSMakePoint( x, y ) ;
}	

- (void)createCrossPath:(int)i
{
	NSPoint *p ;
	float x, y, x0, y0, d ;
	
	[ crossPath[i] setLineWidth:3.0 ] ;
	
	p = &sortedCrossPoint[i] ;
	x = p->x ;
	y = p->y ;
	
	x0 = width*0.5 ;
	y0 = height*0.5 ;
	d = crossScale/sqrt( x*x + y*y )+0.001 ;
	x *= d ;
	y *= d ;
	
	[ crossPath[i] moveToPoint:NSMakePoint( -x+x0, -y+y0 ) ] ;
	[ crossPath[i] lineToPoint:NSMakePoint( x+x0, y+y0 ) ] ;
}

//	There are two crossPoints that received data from either the Mark or the Space cross point.
//	Pict the closes ones to (leaky) accumulate into.
- (void)accumulateCrossPaths
{
	[ crossPath[0] removeAllPoints ] ;
	[ crossPath[1] removeAllPoints ] ;

	if ( embedCross ) {
		[ self accumToPath:mark.crossPoint ] ;
		[ self accumToPath:space.crossPoint ] ;
	}
}

static float computeAGC( float meanSquare )
{
	float ampl, tau ;
	
	ampl = sqrt( meanSquare ) ;
	//  if amplitude is > 1.0, agc it directly down
	if ( ampl > 1.0 ) return 1.0/ampl ;
	
	//  Smaller tau give higher AGC gain.
	//	For tau = 0.05, max AGC gain is 26.5 dB.  A -40 dB signal (0.01) will display as 0.175 (25 dB AGC gain)
	//	For tau = 0.01, max AGC gain is 40 dB.  A -40 dB signal (0.01) will display as 0.5 (34 dB AGC gain) 	
	tau = .01 ;
	return ( 1.0+tau )/( ampl+tau ) ;
}

//	Receive baseband passband (decimated to kBasebandSamplingRate).
//	This method is called once every 32/3000 second (93.75 times per second)
- (void)newSplitBuffer:(DSPSplitComplex)input pipeline:(id<PipelineProtocol>)source
{
	int i ;
	float c, markAbs, spaceAbs, markPower, spacePower, peakPower ;
	Complex basebandMark[kBasebandBufferSize+kInterpolationSpan], basebandSpace[kBasebandBufferSize+kInterpolationSpan] ;
	BasebandComplexArray sfo, pfo, roofed, lowpassed, markLowpass, spaceLowpass, filteredMark, filteredSpace ;
	int inhibitMark, inhibitSpace ;
	Complex u, v ;
	
	for ( i = 0; i < kBasebandBufferSize; i++ ) {	//--
		input.realp[i] *= 0.1 ;
		input.imagp[i] *= 0.1 ;
	}
	
	//	muliplex between two buffers, mux and pmux are either 0 or 2 (complementary)
	[ self updatePointersForChannel:mark ] ;
	[ self updatePointersForChannel:space ] ;
	mux = ( mux+1 ) & 1 ;
	pmux = 1 - mux ;
	
	//  For a 170 Hz shift complex input signal, Mark is at -85 Hz and Space is at +85 Hz.
	//	The identical Mark and Space (real coefficients) lowpass filter is ±170 Hz.
	
	//	First, apply a roofing lowpass to AGC the tuning display.
	//	This needs to be wider than the tuning filter so we can see the attenuation effect of an off-tuned signal.
	[ roofingFilter filterSplitComplex:input to:roofed length:kBasebandBufferSize ] ;
	//	Next, lowpass the baseband signal the signal to pass enough baseband signal for tuning
	[ tuningFilter filterComplex:roofed to:lowpassed length:kBasebandBufferSize ] ;	
	//  Get cos + i.sin == down shift oscillator
	[ shiftOscillator getQuadratureSamples:sfo samples:kBasebandBufferSize ] ;
	//	Get oscillator to move minimum pitch above DC
	[ pitchOscillator getQuadratureSamples:pfo samples:kBasebandBufferSize ] ;
	//	Shift Mark and Space into lowlass signals (for filtering)
	for ( i = 0; i < kBasebandBufferSize; i++ ) {
		u = sfo[i] ;
		v = lowpassed[i] ;
		markLowpass[i] = conj( u )*v ;						//  shift Mark at -85 Hz up to DC
		spaceLowpass[i] = u*v ;								//  shift Space at +85 Hz down to DC
	}
	//  Lowpass filter baseband Mark.
	[ mark.filter filterComplex:markLowpass to:filteredMark length:kBasebandBufferSize ] ;	
	// compute power in Mark channel
	markPower = 0 ;
	for ( i = 0; i < kBasebandBufferSize; i++ ) {
		float uu = cabsf( filteredMark[i] ) ;
		markPower += uu*uu ;
	}
	//  Modulate mark back down to -85 Hz
	for ( i = 0; i < kBasebandBufferSize; i++ ) {
		u = sfo[i]*pfo[i] ;
		basebandMark[i+kInterpolationSpan] = filteredMark[i]*u ;
	}
	[ self interpolate:basebandMark toChannel:mark ] ;

	//  Lowpass filter baseband Space.	
	[ space.filter filterComplex:spaceLowpass to:filteredSpace length:kBasebandBufferSize ] ;
	// compute power in Space channel
	spacePower = 0 ;
	for ( i = 0; i < kBasebandBufferSize; i++ ) {
		float uu = cabsf( filteredSpace[i] ) ;
		spacePower += uu*uu ;
	}
	//  Use fast charge slow discharge AGC, using signal from stronger channel
	//	Use exponential filter over a few frames for AGC discharge
	
	//--peakPower = ( ( markPower > spacePower ) ? markPower : spacePower ) / ( kBasebandBufferSize ) ;
	
	peakPower = ( markPower + spacePower ) / ( kBasebandBufferSize ) ;
	agcPower = ( peakPower > agcPower ) ? peakPower : ( agcPower*0.9 + peakPower*0.1 ) ;
	agc = computeAGC( agcPower*1.414 ) ;
	
	//agc = 8 ;
	
	//  Modulate space back up +85 Hz (with an additional 90 degree phase shift)
	for ( i = 0; i < kBasebandBufferSize; i++ ) {
		u = phaseCorrection*conjf( sfo[i] )*pfo[i] ;
		basebandSpace[i+kInterpolationSpan] = filteredSpace[i]*u ;
	}
	[ self interpolate:basebandSpace toChannel:space ] ;
	
	//  Partition into two plot paths (with a small overlap)
	//	Partitioning reduces "flicker" when there are substantially more mark athan space bits, and vice versa.

	//	For the current frame, check if first or second half needs to be turned off
	markAbs = spaceAbs = 0 ;
	for ( i = 0; i < kInterpolatedSize/2; i += 16 ) {
		c = cabsf( mark.q[i] ) ;
		markAbs += c*c ;
		c = cabsf( space.q[i] ) ;
		spaceAbs += c*c ;
	}
	inhibitMark = ( spaceAbs > markAbs ) ? kInhibitHead : 0 ;
	inhibitSpace = ( markAbs > spaceAbs ) ? kInhibitHead : 0 ;

	markAbs = spaceAbs = 0 ;
	for ( i = kInterpolatedSize/2; i < kInterpolatedSize; i += 16 ) {
		c = cabsf( mark.q[i] ) ;
		markAbs += c*c ;
		c = cabsf( space.q[i] ) ;
		spaceAbs += c*c ;
	}
	if ( spaceAbs > markAbs ) inhibitMark |= kInhibitTail ;
	if ( markAbs > spaceAbs ) inhibitSpace |= kInhibitTail ;
	
	//  Update plot data.  
	//	This data will be turned into a NSBezierPath by createPathForChannel
	[ self updatePlotData:mark otherChannel:space verticalAxis:NO inhibit:inhibitMark ] ;
	[ self updatePlotData:space otherChannel:mark verticalAxis:YES inhibit:inhibitSpace ] ;
	//  update cross data
	[ self updateCrossData:mark otherChannel:space verticalAxis:NO inhibit:inhibitMark ] ;
	[ self updateCrossData:space otherChannel:mark verticalAxis:YES inhibit:inhibitSpace ] ;
	[ self accumulateCrossPaths ] ;

	//	Refresh plot only every 15 cycles (0.17 seconds)
	if ( ++cycle >= 15 ) {
		cycle = 0 ;
		ignore = YES ;
		[ self createPathForChannel:mark ] ;
		[ self createPathForChannel:space ] ;
		[ self createCrossPath:0 ] ;
		[ self createCrossPath:1 ] ;
		ignore = NO ;
		[ self setNeedsDisplay:YES ] ;
	}
}

- (void)updateParameters:(id)sender
{
	float oldPhaseShift, scale ;
	Boolean canDrawCross ;
	
	//  shape (aspect ratio should be between 0 and 0.5)
	oldPhaseShift = phaseShift ;
	aspectRatio = [ aspectRatioSlider floatValue ] ;	
	phaseShift = 0 ;
	canDrawCross = aspectRatio > 0.1 ;
	embedCross = ( canDrawCross && [ crossTuneCheckbox state ] == NSOnState ) ;
	[ crossTuneCheckbox setEnabled:canDrawCross ] ;
	
	scale = ( width+height )*0.25 ;
	if ( embedCross ) {
		crossScale = 0.8*scale ;
		ellipseScale = 0.8*scale ;
	}
	else {
		crossScale = 0.1*scale ;	//  cross not drawn
		ellipseScale = scale ;
	}
	[ self setNeedsDisplay:YES ] ;
}

- (void)setShift:(float)value
{
	if ( shiftFrequency == value ) return ;
	shiftFrequency = value ;
	[ mark.filter setShift:shiftFrequency ] ;
	[ space.filter setShift:shiftFrequency ] ;
}

//	(Private API)
- (void)setInterface:(NSControl*)object to:(SEL)selector
{
	[ object setAction:selector ] ;
	[ object setTarget:self ] ;
}

- (void)awakeFromNib
{
	if ( aspectRatioSlider ) [ self setInterface:aspectRatioSlider to:@selector(updateParameters:) ] ;
	if ( crossTuneCheckbox ) [ self setInterface:crossTuneCheckbox to:@selector(updateParameters:) ] ;
}

//	root is part of the PlistProtocol but is not used here
- (Boolean)restoreFromDictionary:(NSMutableDictionary*)dict root:(NSDictionary*)root
{
	NSNumber *number ;
	
	number = [ dict objectForKey:kEmbedCross ] ;
	if ( number ) [ crossTuneCheckbox setState:[ number boolValue ] ? NSOnState : NSOffState ] ;
	number = [ dict objectForKey:kAspectRatio ] ;
	if ( number ) [ aspectRatioSlider setFloatValue:[ number floatValue ] ] ;
	
	[ self updateParameters:aspectRatioSlider ] ;
	return NO ;
}

- (NSDictionary*)crossedEllipsePlist
{
	NSMutableDictionary *dict ;
	
	dict = [ NSMutableDictionary dictionaryWithCapacity:3 ] ;
	
	[ Plist dictionary:dict setFloatValue:[ aspectRatioSlider floatValue ] forKey:kAspectRatio ] ;
	[ Plist dictionary:dict setBooleanValue:( [ crossTuneCheckbox state ] == NSOnState ) forKey:kEmbedCross ] ;
	
	return dict ;
}

//	(Private API)
//	initialize the mark or space pipeline
- (void)initChannel:(CrossedEllipseChannel*)channel
{
	channel.path = [ [ NSBezierPath alloc ] init ] ;
	//	channel filter
	channel.filter = [ [ CrossedEllipseFilter alloc ] initWithShift:shiftFrequency length:kFilterLength ] ;
	//	interpolate from 6 input points (at 3000 samples/sec) with an interpolation factor of 8 (24000 sample/sec)
	channel.interpolate = [ [ Interpolate alloc ] initWithSpan:kInterpolationSpan factor:kInterpolationFactor ] ;
	//  plot data
	channel.previousFrameInhibit = 0 ;
	channel.penstate = YES ;
	channel.index = 0 ;
	
	channel.last = NSMakePoint( 0, 0 ) ;
	memset( channel.point, 0, sizeof( CGPoint )*kPhosphorDecay ) ;
	memset( channel.penDown, 0, sizeof( Boolean )*kPhosphorDecay ) ;
	
	channel.gated[0] = channel.gated[1] = 0 ;
	memset( channel.data, 0, sizeof( Complex)*kInterpolatedSize*2 ) ;
	memset( channel.tail, 0, sizeof( Complex)*kInterpolationSpan ) ;
}

- (id)initWithFrame:(NSRect)frame 
{
	float y, phi, piPerHz, lowpass, x0, y0, d, scale ;
	int i ;
	
	self = [ super initWithFrame:frame ] ;
	if ( self ) {
		aspectRatio = 0.0 ;
		phaseShift = 0 ;
		embedCross = YES ;
		shiftFrequency = 170 ;
		
		//	Lowpass filter that is wider than the tuning filter, so that we see attenuation on off tuned signals
		lowpass = shiftFrequency/kBasebandSamplingRate ;
		roofingFilter = [ [ ComplexFilter alloc ] initWithBandwidth:lowpass*2.2 length:64 ] ;
		//	Lowpass filter that includes mark and space basebands plus enough bandwidth for tuning
		tuningFilter = [ [ TuningFilter alloc ] initWithBandwidth:lowpass*1.5 length:64 ] ;
		
		shiftOscillator = [ [ NumericalOscillator alloc ] initWithFrequency:( ( shiftFrequency*0.5 )/kBasebandSamplingRate )*kInternalSamplingRate ] ;
		pitchOscillator = [ [ NumericalOscillator alloc ] initWithFrequency:( 500.0/kBasebandSamplingRate )*kInternalSamplingRate ] ;

		//	phase correction to center of FIR (1/2 filter length) (for space channel)		
		piPerHz = ( kFilterLength/2 + 1 )/kBasebandSamplingRate ;
		phi = -2.0*kPi*( shiftFrequency*piPerHz + 0.5 ) ;
		phaseCorrection = cos( phi ) - I*sin( phi ) ;
		
		x0 = width*0.5 ;
		y0 = height*0.5 ;
		scale = ( x0+y0 )*0.5 ;
		crossScale = 0.8*scale ;
		ellipseScale = 0.8*scale ;
		agc = 1.0 ;
		agcPower = 0.707/2 ;
		
		cycle = mux = 0 ;
		pmux = 1 ;
        mark = [[CrossedEllipseChannel alloc] init];
        space = [[CrossedEllipseChannel alloc] init];
		[ self initChannel:mark ] ;
		[ self initChannel:space ] ;
		crossPath[0] = [ [ NSBezierPath alloc ] init ] ;
		crossPath[1] = [ [ NSBezierPath alloc ] init ] ;
		sortedCrossPoint[0] = NSMakePoint( 1, 0 ) ;
		sortedCrossPoint[1] = NSMakePoint( 0, 1 ) ;
		//  dither the stroked lines
		y = 0 ;
		for ( i = 0; i < kInterpolatedSize; i++ ) {
			y = y*0.98 + 0.001*( ( rand() & 0xff ) - 128.0 ) ;
			dither[i] = y*0.1 ;
		}
		y = ( int )( height/2 ) + 0.5 ;
		[ graticule moveToPoint:NSMakePoint( 0.05*width, y ) ] ;
		[ graticule lineToPoint:NSMakePoint( 0.95*width, y ) ] ;
		y = ( int )( width/2 ) + 0.5 ;
		[ graticule moveToPoint:NSMakePoint( y, 0.05*height ) ] ;
		[ graticule lineToPoint:NSMakePoint( y, 0.95*height ) ] ;
		
		ellipseScale = 0.5 ;
		crossGraticule = [ [ NSBezierPath alloc ] init ] ;
		[ crossGraticule setLineWidth:3 ] ;
		
		
		d = crossScale ;
		[ crossGraticule moveToPoint:NSMakePoint( x0+d, y0 ) ] ;
		[ crossGraticule lineToPoint:NSMakePoint( x0+d+8, y0 ) ] ;
		[ crossGraticule moveToPoint:NSMakePoint( x0-d, y0 ) ] ;
		[ crossGraticule lineToPoint:NSMakePoint( x0-d-8, y0 ) ] ;
		[ crossGraticule moveToPoint:NSMakePoint( x0, y0+d ) ] ;
		[ crossGraticule lineToPoint:NSMakePoint( x0, y0+d+8 ) ] ;
		[ crossGraticule moveToPoint:NSMakePoint( x0, y0-d ) ] ;
		[ crossGraticule lineToPoint:NSMakePoint( x0, y0-d-8 ) ] ;
		crossColor = [ NSColor colorWithCalibratedRed:0.9 green:0.5 blue:0.1 alpha:0.9 ] ;
	}
	return self ;
}

- (void)releaseChannel:(CrossedEllipseChannel*)channel
{
//	if ( channel.filter ) [ channel.filter release ] ;
//	[ channel.interpolate release ] ;
//	[ channel.path release ] ;
}

- (void)dealloc
{
	//int i ;
	
	//[ shiftOscillator release ] ;
	[ self releaseChannel:mark ] ;
	[ self releaseChannel:space ] ;
//	for ( i = 0; i < 2; i++ ) [ crossPath[i] release ] ;
//	[ crossGraticule release ] ;
//	[ crossColor release ] ;
//	[ super dealloc ] ;
}

@end
