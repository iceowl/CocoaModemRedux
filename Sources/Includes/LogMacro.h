/*
 *  LogMacro.h
 *
 *  Created by Kok Chen on 5/7/06.
 */

#define Log( debug, s,... )  if ( debug ) NSLog( [ NSString stringWithCString:s encoding:NSASCIIStringEncoding], ##__VA_ARGS__ )
