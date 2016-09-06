//
//  MicroHamKeyerCache.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>
#import "MicroKeyer.h"

@interface MicroHamKeyerCache : NSObject


@property MicroKeyer *keyer ;
@property int controlPort ;
//		//  FSK
@property int fskPort ;
@property int flagsPort ;
@property int currentBaudConstant ;
@property int currentTxInvert ;
@property int currentStopIndex ;
//		//  PTT
@property int pttPort ;
//	} MicroHamKeyerCache ;



@end
