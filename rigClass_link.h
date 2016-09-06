//
//  rigClass_link.h
//  wsjtx
//
//  Created by Joe Mastroianni on 10/11/13.
//  A native Obj-C implementation of wsjtx  developed for Joe Taylor and John Nelson
//  for no reason other than the fun of it
//  source copied liberally from wsjtx C++ QT version
//  any copyright is owned by Joe Taylor and John Nelson  and the wsjtx developer community et. al.
//
//





#import <Foundation/Foundation.h>
#include "rig.h"
#include "hamAlert.h"
#include "externSettings.h"

@interface rigClass_link : NSObject {
    
    hamAlert *hAlert;
    globalSettings *gSettings;
    
}

-(int) open : (int) n;
-(int) close ;
-(int) setConf : (const char*) name : (const char*) val ;
-(rigToken_t) tokenLookup : (const char*) name;
-(int) setFreq : (freq_t) freq ;
-(freq_t) getFreq ;
-(int) setMode : (rmode_t) rmode ;
//-(rmode_t) getMode : (pbwidth_t&) pb; // gotta figure out what to do with the struct copy "&" of pbWidth_t... .mm no like it
//-(rmode_t) getMode : (pbwidth_t) pb; // hope this works... not a copy
-(int) setVFO : (vfo_t) vfot;
-(vfo_t) getVFO ;
-(int) setXit : (shortfreq_t) xit : (vfo_t) vfo;
-(int) setSplitFreq : (freq_t) tx_freq ;
-(int) setPTT : (ptt_t) ptt ;
-(ptt_t) getPTT ;
-(void) clickPttOn;
-(void) clickPttOff;



@end
