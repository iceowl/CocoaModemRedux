

/**
 * \file src/rigclass.cc
 * \brief Ham Radio Control Libraries C++ interface
 * \author Stephane Fillod
 * \date 2001-2003
 *
 * Hamlib C++ interface is a frontend implementing wrapper functions.
 */

/**
 *
 *  Hamlib C++ bindings - main file
 *  Copyright (c) 2001-2003 by Stephane Fillod
 *
 *
 *   This library is free software; you can redistribute it and/or
 *   modify it under the terms of the GNU Lesser General Public
 *   License as published by the Free Software Foundation; either
 *   version 2.1 of the License, or (at your option) any later version.
 *
 *   This library is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *   Lesser General Public License for more details.
 *
 *   You should have received a copy of the GNU Lesser General Public
 *   License along with this library; if not, write to the Free Software
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#define NUMTRIES 5
#include "rigClass.h"


@implementation rigClass 


static int hamlibpp_freq_event(RIG *rig, vfo_t vfo, freq_t freq, rig_ptr_t arg);

static int hamlibpp_freq_event(RIG *rig, vfo_t vfo, freq_t freq, rig_ptr_t arg)
{
    if (!rig || !rig->state.obj)
        return -RIG_EINVAL;
    
    /* assert rig == ((Rig*)rig->state.obj).theRig */
    return ((Rig*)rig->state.obj)->FreqEvent(vfo, freq, arg);
}

Rig::Rig()
{
    rig_set_debug_level( RIG_DEBUG_WARN);
}

Rig::~Rig() {
    theRig->state.obj = NULL;
    rig_cleanup(theRig);
    caps = NULL;
}

int Rig::init(rig_model_t rig_model)
{
  //  int initOk;
    
    theRig = rig_init(rig_model);
    if (!theRig) {
      //  initOk = false;
        return 0;
    }
    else {
//initOk = true;
        caps = theRig->caps;
        theRig->callbacks.freq_event = &hamlibpp_freq_event;
        theRig->state.obj = (rig_ptr_t)this;
    }
    return 1;
}

int Rig::open(int n) {
    m_hrd=false;
    m_cmndr=false;
    if(n<9900) {
        if(n==-99999) return -1;                      //Silence compiler warning
        return rig_open(theRig);
    }
    return -1;
}

int Rig::close(void) {
    
    return rig_close(theRig);
}

int Rig::setConf(const char *name, const char *val)
{
    return rig_set_conf(theRig, tokenLookup(name), val);
}

int Rig::setFreq(freq_t freq, vfo_t vfo) {
    
    {
        return rig_set_freq(theRig, vfo, freq);
    }
}

int Rig::setXit(shortfreq_t xit, vfo_t vfo)
{
    return rig_set_xit(theRig, vfo, xit);
}

int Rig::setVFO(vfo_t vfo)
{
    return rig_set_vfo(theRig, vfo);
}

vfo_t Rig::getVFO()
{
    vfo_t vfo;
    rig_get_vfo(theRig, &vfo);
    return vfo;
}

int Rig::setSplitFreq(freq_t tx_freq, vfo_t vfo) {
    
    {
        return rig_set_split_freq(theRig, vfo, tx_freq);
    }
}

freq_t Rig::getFreq(vfo_t vfo)
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

int Rig::setMode(rmode_t mode, pbwidth_t width, vfo_t vfo) {
    return rig_set_mode(theRig, vfo, mode, width);
}

rmode_t Rig::getMode(pbwidth_t& width, vfo_t vfo) {
    rmode_t mode;
    rig_get_mode(theRig, vfo, &mode, &width);
    return mode;
}

int Rig::setPTT(ptt_t ptt, vfo_t vfo)
{
    
    return rig_set_ptt(theRig, vfo, ptt);
}

ptt_t Rig::getPTT(vfo_t vfo)
{
    ptt_t ptt;
    rig_get_ptt(theRig, vfo, &ptt);
    return ptt;
}

rigToken_t Rig::tokenLookup(const char *name)
{
    return rig_token_lookup(theRig, name);
}

@end