//
//  AuralBuffer.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>
#import "AuralClient.h"
#import "DestClient.h"
#define AURALSIZE 32

@interface AuralBuffer : NSObject



//	float left[512] ;
//	float right[512] ;
//	DestClient *client[32] ;
//	int clients ;

@property float *left;
@property float *right;
@property NSMutableArray *client;
@property int clients;

@end
