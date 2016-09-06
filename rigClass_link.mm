//
//  rigClass_link.m
//  wsjtx
//
//  Created by Joe Mastroianni on 10/11/13.
//  A native Obj-C implementation of wsjtx  developed for Joe Taylor and John Nelson
//  for no reason other than the fun of it
//  source copied liberally from wsjtx C++ QT version
//  any copyright is owned by Joe Taylor and John Nelson  and the wsjtx developer community et. al.
//
//






#import "rigClass_link.h"
#import "rigClass.h"

@interface rigClass_link  () {       // putting this @interface here keeps the vars out of the header file,
    //which keeps it out of WSJTX MAIN, so it can compile with the mixture of C++ and Obj-C
    // you have endless trouble trying to put a C++.h in an OBJ-C project otherwise
    Rig*  myRig;                     // you need to put the open parens () to declare this.
    // Rig comes from Rig::Rig in the C++ rigClass.h & that's how it gets connected
    // here to Obj-C
    
}

@property Rig  *myRig;


@end


@implementation rigClass_link

@synthesize myRig = _myRig;


-(id)init {
    
    self = [super init];
    
    
    if(self ) {
        char buf[80];
        
        _myRig = new Rig();
        
        gSettings = [[globalSettings alloc] init];
        hAlert = [[hamAlert alloc]init];
        //NSLog(@"initializing myRig()");
        int status;
        _myRig = new Rig();
        
        //parameters for MY rig - would have to be generalized for other people
        
        gSettings.m_catPort    = @"/dev/cu.SLAB_USBtoUART"; // just my connection
        gSettings.m_handshake  = @"None";
        gSettings.m_serialRate = 9600;
        gSettings.m_dataBits   = 8;
        gSettings.m_stopBits   = 1;
        _myRig->init(RIG_MODEL_IC7600); // i'm just doing this for myself right now
        // NSLog(@"rig init status = %d",status);
        
        _myRig->setConf("rig_pathname", [gSettings.m_catPort cStringUsingEncoding:NSASCIIStringEncoding]);
        
        sprintf(buf,"%d",gSettings.m_serialRate);
        _myRig->setConf("serial_speed",buf);
        sprintf(buf,"%d",gSettings.m_dataBits);
        _myRig->setConf("data_bits",buf);
        sprintf(buf,"%d",gSettings.m_stopBits);
        _myRig->setConf("stop_bits",buf);
        _myRig->setConf("serial_handshake",[gSettings.m_handshake cStringUsingEncoding:NSASCIIStringEncoding]);
        if(gSettings.m_handshakeIndex != 2) {
            _myRig->setConf("rts_state",gSettings.m_bRTS ? "ON" : "OFF");
            _myRig->setConf("dtr_state",gSettings.m_bDTR ? "ON" : "OFF");
        }
        
        status = _myRig->open(RIG_MODEL_IC7600); // just for me... ;)
        
        if(status) {
            NSLog(@" failure to open rig status = %d",status);
            [hAlert raiseAlert:@"failure to open rig" :[NSString stringWithFormat:@" status = %d",status]];
            
        }
    }
    
    return self;
}

-(int) open : (int) n {
    return _myRig->open(n);
}
-(int) close {
    return _myRig->close();
}

-(int) setConf : (const char*) name : (const char*) val {
    return _myRig->setConf(name, val);
}

-(rigToken_t) tokenLookup : (const char*) name {
    return _myRig->tokenLookup(name);
}

-(int) setFreq : (freq_t) freq {
    return _myRig->setFreq(freq);
}

-(freq_t) getFreq {
    return _myRig->getFreq();
}

-(int) setMode : (rmode_t) rmode  {
    return _myRig->setMode(rmode);
}

//-(rmode_t) getMode : (pbwidth_t&) pb {
//    return _myRig->getMode(pb);
//}

-(int) setVFO : (vfo_t) vfot {
    return _myRig->setVFO(vfot);
}

-(vfo_t) getVFO {
    return _myRig->getVFO();
}

-(int) setXit : (shortfreq_t) xit : (vfo_t) vfo {
    return _myRig->setXit(xit,vfo);
}

-(int) setSplitFreq : (freq_t) tx_freq  {
    return _myRig->setSplitFreq(tx_freq);
}

-(int) setPTT : (ptt_t) ptt {
    return _myRig->setPTT(ptt);
}

-(ptt_t) getPTT {
    return _myRig->getPTT();
}

-(IBAction)testPTT :(id)sender {
    
    if(gSettings.m_test == TRUE) {
        _myRig->setPTT(RIG_PTT_OFF, RIG_VFO_CURR);
        gSettings.m_test = FALSE;
    } else {
        if(gSettings.m_PTTData) _myRig->setPTT(RIG_PTT_ON_DATA, RIG_VFO_CURR);
        if(!gSettings.m_PTTData) _myRig->setPTT(RIG_PTT_ON_MIC, RIG_VFO_CURR);
        gSettings.m_test = TRUE;
    }
}

-(void)clickPttOn {
    
    
    if(gSettings.m_PTTData) _myRig->setPTT(RIG_PTT_ON_DATA, RIG_VFO_CURR);
    if(!gSettings.m_PTTData) _myRig->setPTT(RIG_PTT_ON_MIC, RIG_VFO_CURR);
    gSettings.m_test = TRUE;
}

-(void)clickPttOff {
    
    _myRig->setPTT(RIG_PTT_OFF, RIG_VFO_CURR);
    gSettings.m_test = FALSE;
    
}


@end
