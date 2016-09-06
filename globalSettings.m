//
//  globalSettings.m
//  wsjtx
//
//  Created by Joe Mastroianni on 10/15/13.
//  A native Obj-C implementation of wsjtx  developed for Joe Taylor and John Nelson
//  for no reason other than the fun of it
//  source copied liberally from wsjtx C++ QT version
//  any copyright is owned by Joe Taylor and John Nelson  and the wsjtx developer community et. al.
//
//






#import "globalSettings.h"

@implementation globalSettings


//@synthesize  m_serialRate;
//@synthesize  m_serialRateIndex;
//@synthesize  m_dataBits;
//@synthesize  m_dataBitsIndex;
//@synthesize  m_stopBits;
//@synthesize  m_stopBitsIndex;
//@synthesize  m_handshakeIndex;
//
//@synthesize  m_catPort;
//@synthesize  m_handshake;
//
//@synthesize  m_bDTR;
//@synthesize  m_bRTS;
//@synthesize  m_PTTData;
//@synthesize  m_test;
//

-(id) init {
    
    self = [super init];
    
    if(self) {
        
        self.m_catPort    = @"/dev/cu.SLAB_USBtoUART"; // just my connection
        self.m_handshake  = @"None";
        self.m_serialRate = 9600;
        self.m_dataBits   = 8;
        self.m_stopBits   = 1;
        self.m_bRTS       = FALSE;
        self.m_bDTR       = FALSE;
        self.m_test       = TRUE;
        self.m_PTTData    = FALSE;
    }
    
    return self;
    
    
}


@end
