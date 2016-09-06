//
//  Interfaces.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>
#import "MicroKeyer.h"
@interface Interfaces : NSObject
//typedef struct {
@property	MicroKeyer *keyer ;
@property	int type ;
@property	Boolean enabled ;
//} Interfaces ;

@end
