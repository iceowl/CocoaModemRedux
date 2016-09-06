//
//  rigControl.m
//  wsjtx
//
//  Created by Joe Mastroianni on 10/9/13.
//  Copyright (c) 2013 Joe Mastroianni. All rights reserved.
//

#import "rigControl.h"
#import  "rigclass.h"
#define NUMTRIES 5


static int hamlibpp_freq_event(RIG *rig, vfo_t vfo, freq_t freq, rig_ptr_t arg);



@implementation rigControl



static int hamlibpp_freq_event(RIG *rig, vfo_t vfo, freq_t freq, rig_ptr_t arg)
{
    if (!rig || !rig->state.obj)
        return -RIG_EINVAL;
    
    /* assert rig == ((Rig*)rig->state.obj).theRig */
    return ((Rig*)rig->state.obj)->FreqEvent(vfo, freq, arg);
}

-(id) init
{
    self = [super init];
    if (self) {
    rig_set_debug_level( RIG_DEBUG_WARN);
    }
    
    return self;
}

-(void)dealloc {
    theRig->state.obj = NULL;
    rig_cleanup(theRig);
    caps = NULL;
}

-(int) rigInit : (rig_model_t) rig_model 
{
    int initOk;
    
    theRig = rig_init(rig_model);
    if (!theRig)
        initOk = false;
    else
        initOk = true;
    
    caps = theRig->caps;
    theRig->callbacks.freq_event = &hamlibpp_freq_event;
    theRig->state.obj = (__bridge rig_ptr_t)self;
    
    return initOk;
}

-(int) openRig: (int) n {
    m_hrd=false;
    m_cmndr=false;
    if(n<9900) {
        if(n==-99999) return -1;                      //Silence compiler warning
        return rig_open(theRig);
    }
    return -1;
}

-(int) closeRig {
    
    return rig_close(theRig);
}

-(int) setConf : (const char*) name : (const char*) val
{
    return rig_set_conf(theRig, [self tokenLookup:name], val);
}

-(int) setFreq :(freq_t) freq:  (vfo_t) vfo {
    
    {
        return rig_set_freq(theRig, vfo, freq);
    }
}

-(int) setXit: (shortfreq_t) xit : (vfo_t) vfo
{
    return rig_set_xit(theRig, vfo, xit);
}

-(int) setVFO: (vfo_t) vfo
{
    return rig_set_vfo(theRig, vfo);
}

-(vfo_t) getVFO
{
    vfo_t vfo;
    rig_get_vfo(theRig, &vfo);
    return vfo;
}

-(int) setSplitFreq : (freq_t) tx_freq : (vfo_t) vfo {
    
    {
        return rig_set_split_freq(theRig, vfo, tx_freq);
    }
}

-(freq_t) getFreq :(vfo_t) vfo
{
    freq_t freq;
    
    {
        freq=-1.0;
        for(int i=0; i<NUMTRIES; i++) {
            int iret=rig_get_freq(theRig, vfo, &freq);
            if(iret==RIG_OK) break;
        }
        return freq;
    }
}

-(int) setMode : (rmode_t) mode : (pbwidth_t) width : (vfo_t) vfo {
    return rig_set_mode(theRig, vfo, mode, width);
}

-(rmode_t) getMode :(pbwidth_t) width : (vfo_t) vfo {
    rmode_t mode;
    rig_get_mode(theRig, vfo, &mode, &width);
    return mode;
}

-(int) setPTT :(ptt_t) ptt : (vfo_t) vfo
{
    return rig_set_ptt(theRig, vfo, ptt);
}



-(ptt_t) getPTT :(vfo_t) vfo
{
    ptt_t ptt;
    rig_get_ptt(theRig, vfo, &ptt);
    return ptt;
}

-(token_t) tokenLookup :(const char*) name
{
    return rig_token_lookup(theRig, name);
}




@end
