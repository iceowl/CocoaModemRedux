//
//  InstalledModem.h
//  cocoaModem 2.0
//
//  Created by Joe Mastroianni on 11/7/13.
//
//

#import <Foundation/Foundation.h>
#import "Modem.h"

@interface InstalledModem : NSObject

    @property (retain)  NSString *name ;			//  AppleScript name
    @property Modem *modem ;
    @property (retain) NSTabViewItem *tabItem ;
    @property Boolean contest ;
    @property Boolean rttyMacro ;			// use shared RTTY macros
    @property Boolean slashedZero ;
    @property Boolean receiveOnly ;
    @property int	numberOfReceiveViews ;	//  v0.96c
    @property Boolean updatedFromPlist ;


@end
