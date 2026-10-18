#include "GrabbyPrivate.h"
#include <dlfcn.h>
#include <string.h>

static const char *kSkyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight";
static const char *kIOKitPath = "/System/Library/Frameworks/IOKit.framework/IOKit";

static const char *kSymbolNames[GRABBY_PRIVATE_SYMBOL_COUNT] = {
    "IOHIDEventCreate",
    "IOHIDEventSetIntegerValue",
    "IOHIDEventSetFloatValue",
    "IOHIDEventAppendEvent",
    "SLEventSetIOHIDEvent",
    "CGSMainConnectionID",
    "CGSGetActiveSpace",
    "CGSCopyManagedDisplaySpaces",
    "CGSGetSymbolicHotKeyValue",
    "CGSSetSymbolicHotKeyValue",
    "CGSIsSymbolicHotKeyEnabled",
    "CGSSetSymbolicHotKeyEnabled",
};

static void *lookup(void *primary, void *secondary, const char *name) {
    void *p = primary ? dlsym(primary, name) : NULL;
    if (!p && secondary) p = dlsym(secondary, name);
    return p;
}

struct grabby_private_api grabby_private_resolve(void) {
    struct grabby_private_api api;
    memset(&api, 0, sizeof api);
    void *iokit = dlopen(kIOKitPath, RTLD_LAZY | RTLD_NOLOAD) ?: dlopen(kIOKitPath, RTLD_LAZY);
    void *skylight = dlopen(kSkyLightPath, RTLD_LAZY | RTLD_NOLOAD) ?: dlopen(kSkyLightPath, RTLD_LAZY);

    api.IOHIDEventCreate = (grabby_IOHIDEventCreate_t)lookup(iokit, skylight, kSymbolNames[0]);
    api.IOHIDEventSetIntegerValue = (grabby_IOHIDEventSetIntegerValue_t)lookup(iokit, skylight, kSymbolNames[1]);
    api.IOHIDEventSetFloatValue = (grabby_IOHIDEventSetFloatValue_t)lookup(iokit, skylight, kSymbolNames[2]);
    api.IOHIDEventAppendEvent = (grabby_IOHIDEventAppendEvent_t)lookup(iokit, skylight, kSymbolNames[3]);
    api.SLEventSetIOHIDEvent = (grabby_SLEventSetIOHIDEvent_t)lookup(skylight, NULL, kSymbolNames[4]);
    api.CGSMainConnectionID = (grabby_CGSMainConnectionID_t)lookup(skylight, NULL, kSymbolNames[5]);
    api.CGSGetActiveSpace = (grabby_CGSGetActiveSpace_t)lookup(skylight, NULL, kSymbolNames[6]);
    api.CGSCopyManagedDisplaySpaces = (grabby_CGSCopyManagedDisplaySpaces_t)lookup(skylight, NULL, kSymbolNames[7]);
    api.CGSGetSymbolicHotKeyValue = (grabby_CGSGetSymbolicHotKeyValue_t)lookup(skylight, NULL, kSymbolNames[8]);
    api.CGSSetSymbolicHotKeyValue = (grabby_CGSSetSymbolicHotKeyValue_t)lookup(skylight, NULL, kSymbolNames[9]);
    api.CGSIsSymbolicHotKeyEnabled = (grabby_CGSIsSymbolicHotKeyEnabled_t)lookup(skylight, NULL, kSymbolNames[10]);
    api.CGSSetSymbolicHotKeyEnabled = (grabby_CGSSetSymbolicHotKeyEnabled_t)lookup(skylight, NULL, kSymbolNames[11]);
    return api;
}

bool grabby_private_symbol_present(const struct grabby_private_api *api, int index) {
    switch (index) {
        case 0: return api->IOHIDEventCreate != NULL;
        case 1: return api->IOHIDEventSetIntegerValue != NULL;
        case 2: return api->IOHIDEventSetFloatValue != NULL;
        case 3: return api->IOHIDEventAppendEvent != NULL;
        case 4: return api->SLEventSetIOHIDEvent != NULL;
        case 5: return api->CGSMainConnectionID != NULL;
        case 6: return api->CGSGetActiveSpace != NULL;
        case 7: return api->CGSCopyManagedDisplaySpaces != NULL;
        case 8: return api->CGSGetSymbolicHotKeyValue != NULL;
        case 9: return api->CGSSetSymbolicHotKeyValue != NULL;
        case 10: return api->CGSIsSymbolicHotKeyEnabled != NULL;
        case 11: return api->CGSSetSymbolicHotKeyEnabled != NULL;
        default: return false;
    }
}

bool grabby_private_all_present(const struct grabby_private_api *api) {
    for (int i = 0; i < GRABBY_PRIVATE_SYMBOL_COUNT; i++) {
        if (!grabby_private_symbol_present(api, i)) return false;
    }
    return true;
}

const char *grabby_private_symbol_name(int index) {
    if (index < 0 || index >= GRABBY_PRIVATE_SYMBOL_COUNT) return "";
    return kSymbolNames[index];
}

void grabby_poke_hid_event(CGEventRef cgEvent, GrabbyHIDEventRef hidEvent) {
    if (!cgEvent || !hidEvent) return;
    CFRetain(hidEvent);
    uint8_t *record = *(uint8_t **)((uint8_t *)cgEvent + 0x18);
    *(GrabbyHIDEventRef *)(record + 0xd0) = hidEvent;
}
