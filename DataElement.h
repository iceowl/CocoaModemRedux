//
//  DataElement.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>

@interface DataElement : NSObject
//typedef struct _DE_ {
//	id data ;
//	struct _DE_ *next ;
//} DataElement ;

@property id data;
@property DataElement *next;


@end
