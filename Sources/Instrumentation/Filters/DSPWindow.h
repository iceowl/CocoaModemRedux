/*
 *	DSPWindow.h
 *  From cocoaModem 2.0
 *
 *  Created by Kok Chen on 10/24/05
//	Ported September 13, 2011
 *  Copyright 2005,2011 Kok Chen, W7AY. All rights reserved.
 */

#include <Carbon/Carbon.h>

double blackmanWindow( float i, int n ) ;
double blackmanHarrisWindow( float i, int n ) ;
double blackmanNuttallWindow( float i, int n ) ;
double flatTopWindow( float i, int n ) ;
double hammingWindow( float i, int n ) ;
double hannWindow( float i, int n ) ;
double gaussianWindow( float x, int n, float sigma ) ;
double sineWindow( float i, int n ) ;
double sincWindow( float f, int n, double cycles ) ;
		
float *blackmanHarrisKernel(float passband, int halfwidth ) ;

