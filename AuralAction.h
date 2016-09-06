//
//  AuralAction.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/8/13.
//
//

#import <Foundation/Foundation.h>

@interface AuralAction : NSObject
//	typedef struct {
@property (retain)	NSButton *enableButton ;
@property (retain)  NSTextField *attenuationField ;
@property (retain)	NSMatrix *floatMatrix ;
@property (retain)  NSTextField *fixedFrequency ;
//	} AuralAction ;

@end
