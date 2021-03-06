//
//  YMBarb.m
//  YMBarbwire
//
//  Created by Adam Kaplan on 12/22/14.
//  Copyright (c) 2014 Yahoo. All rights reserved.
//

#import "YMBarb.h"
#import "YMBarbConfig.h"
#import <objc/runtime.h>

/*
 This file should be compiled with ARC-disabled for performance reasons.
 */

#define __BW_PRAGMA_PUSH_NO_WARNINGS    _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
#define __BW_PRAGMA_POP_NO_WARNINGS     _Pragma("clang diagnostic pop")

static inline void* barbwireTestFunc(__unsafe_unretained id self, SEL _cmd) {
    //NSLog(@"Running: %@ %@", self, NSStringFromSelector(_cmd));
    __unsafe_unretained YMBarbConfig *config;
    __unsafe_unretained id thing = self;
    do {
        //NSLog(@"thing: %s class? %d meta? %d", class_getName(object_getClass(thing)), object_isClass(thing), class_isMetaClass(object_getClass(thing)));
        config = objc_getAssociatedObject(thing, _cmd);
        if (config) {
            break;
        }
        
        // If the object instance didn't have any config, check it's class instance.  "wireAll"
        // impls will store the global configs in the class instance itself. Can this cause
        // class vs instance selector conflicts? If so, can we fix?
        __unsafe_unretained Class clazz = object_getClass(thing);
        //NSLog(@"clazz: %s class? %d meta? %d", class_getName(clazz), object_isClass(clazz), class_isMetaClass(clazz));
        config = objc_getAssociatedObject(clazz, _cmd);
        if (config) {
            break;
        }
        
        // Still fails... traverse up the class heirarchy into a root metaclass
        if (class_isMetaClass(clazz)) {
            thing = class_getSuperclass(thing);
        } else {
            thing = class_getSuperclass(clazz);
        }
        //NSLog(@"super: %s class? %d meta? %d", class_getName(object_getClass(thing)), object_isClass(thing), class_isMetaClass(object_getClass(thing)));
    } while(thing);
    
    if (config->threadPointer) {
        NSAssert(config->threadPointer == [NSThread currentThread], // should be equals:?
                 @"-[%s %s] must be called on thread %@ (was %@)",
                 object_getClassName(self), sel_getName(_cmd), config->threadPointer, [NSThread currentThread]);
        return config->functionImp;
    }
    
    if (config->queuePointer) {
        __BW_PRAGMA_PUSH_NO_WARNINGS // ignore dispatch_get_current_queue() deprecation (allowed for debugging per docs)
        NSAssert(config->queuePointer == dispatch_get_current_queue(),
                 @"-[%s %s] must be called on queue %@ (was %@)",
                 object_getClassName(self), sel_getName(_cmd), config->queuePointer, dispatch_get_current_queue());
        __BW_PRAGMA_POP_NO_WARNINGS
        
        return config->functionImp;
    }
    
    return config->functionImp;
}

void* barbwire_msgSend(__unsafe_unretained id self, SEL _cmd) {
    return barbwireTestFunc(self, _cmd);
}

// One day...
//void* barbwire_msgSend_stret(void *st_addr, __unsafe_unretained id self, SEL sel) {
//}

//void* barbwire_msgSend_fpret(void *fp, __unsafe_unretained id self, SEL sel) {
//}
