//
//  rigControl.h
//  wsjtx
//
//  Created by Joe Mastroianni on 10/9/13.
//  Copyright (c) 2013 Joe Mastroianni. All rights reserved.
//
#include "rig.h"
#include <iostream>
#import <Foundation/Foundation.h>

@interface rigControl : NSObject {


///extern QTcpSocket* commanderSocket;


    RIG* theRig;  // Global ref. to the rig
    bool m_hrd;
    bool m_cmndr;
    NSString *m_context;
    
    

    const struct rig_caps *caps;
}

    // Initialize rig
    -(int) rigInit:(rig_model_t) rig_model;
    
    // This method open the communication port to the rig
    -(int) openRig: (int) n;
    
    // This method close the communication port to the rig
    -(int) closeRig;
    
    -(int) setConf: (const char*) name : (const char*) val;
    -(token_t) tokenLookup: (const char*) name;
    
    -(int) setFreq : (freq_t) freq : (vfo_t) vfo;
    -(freq_t) getFreq : (vfo_t) vfo;
    -(int) setMode :  (rmode_t) a : (pbwidth_t) width : (vfo_t) vfo;
    -(rmode_t) getMode : (pbwidth_t) a : (vfo_t) vfo;
    -(int) setVFO : (vfo_t) a;
    -(vfo_t) getVFO;
    -(int) setXit : (shortfreq_t) xit : (vfo_t) vfo;
    -(int) setSplitFreq : (freq_t) tx_freq : (vfo_t) vfo;
    -(int) setPTT : (ptt_t) ptt : (vfo_t) vfo;
    -(ptt_t) getPTT : (vfo_t) vfo;
    
    // callbacks available in your derived object
    virtual FreqEvent(vfo_t, freq_t, rig_ptr_t) const {
        return RIG_OK;
    }
    virtual int ModeEvent(vfo_t, rmode_t, pbwidth_t, rig_ptr_t) const {
        return RIG_OK;
    }
    virtual int VFOEvent(vfo_t, rig_ptr_t) const {
        return RIG_OK;
    }
    virtual int PTTEvent(vfo_t, ptt_t, rig_ptr_t) const {
        return RIG_OK;
    }
    virtual int DCDEvent(vfo_t, dcd_t, rig_ptr_t) const {
        return RIG_OK;
    }

@end
