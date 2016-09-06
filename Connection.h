//
//  Connection.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import <Foundation/Foundation.h>
#import "CMTappedPipe.h"

@interface Connection : NSObject

    @property CMTappedPipe *pipe ;
    @property int index ;
    @property Boolean enableBaudotMarkers ;
    @property int timebase ;


@end
