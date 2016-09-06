//
//  globalSettings.h
//  wsjtx
//
//  Created by Joe Mastroianni on 10/15/13.
//
//  A native Obj-C implementation of wsjtx  developed for Joe Taylor and John Nelson
//  for no reason other than the fun of it
//  source copied liberally from wsjtx C++ QT version
//  any copyright is owned by Joe Taylor and John Nelson  and the wsjtx developer community et. al.
//
//
#import <mach/mach.h>

#ifdef DEBUG
#   define DebugLog(fmt, ...) NSLog((@"%s(%d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DebugLog(...)
#endif


#define AlwaysLog(fmt, ...) NSLog((@"%s(%d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);


#ifdef DEBUG
#   define DPFLog NSLog(@"%s(%d)", __PRETTY_FUNCTION__, __LINE__);//Debug Pretty Function Log
#else
#   define DPFLog
#endif


#ifdef DEBUG
#   define MemoryLog {\
struct task_basic_info info;\
mach_msg_type_number_t size = sizeof(info);\
kern_return_t e = task_info(mach_task_self(),\
TASK_BASIC_INFO,\
(task_info_t)&info,\
&size);\
if(KERN_SUCCESS == e) {\
NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init]; \
[formatter setNumberStyle:NSNumberFormatterDecimalStyle]; \
DebugLog(@"%@ bytes", [formatter stringFromNumber:[NSNumber numberWithInteger:info.resident_size]]);\
} else {\
DebugLog(@"Error with task_info(): %s", mach_error_string(e));\
}\
}
#else
#   define MemoryLog
#endif


#import <Foundation/Foundation.h>



@interface globalSettings : NSObject {
    
}

@property int m_serialRate;
@property int m_serialRateIndex;
@property int m_dataBits;
@property int m_dataBitsIndex;
@property int m_stopBits;
@property int m_stopBitsIndex;
@property int m_handshakeIndex;

@property bool m_bDTR;
@property bool m_bRTS;
@property bool m_test;
@property bool m_PTTData;

@property NSString* m_catPort;
@property NSString* m_handshake;



@end
