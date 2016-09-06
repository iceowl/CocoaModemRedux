/*
 *	FilterKernels.h
 *  From cocoaModem 2.0
 *
 *  Created by Kok Chen on 10/24/05
//	Ported September 13, 2011
 *  Copyright 2005,2011 Kok Chen, W7AY. All rights reserved.
 */

#include <Carbon/Carbon.h>

double sincf( float t ) ;
double sinc( float t, int n, double bandwidth ) ;
double raisedCosine( float t, int n, double baudrate ) ;
double generalRaisedCosine( float t, int n, double baudrate, double beta ) ;
double extendedNyquist( int order, float t, int n, double baudrate ) ;

double centeredSinc( float f, int n, double bandwidth ) ;


