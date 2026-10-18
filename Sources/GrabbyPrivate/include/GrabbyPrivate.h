#ifndef GRABBY_PRIVATE_H
#define GRABBY_PRIVATE_H

// The only place in Grabby that names private macOS API. Every symbol is resolved
// with dlsym at runtime so a missing one becomes a NULL pointer, never a link error.

#include <stdbool.h>
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>

// IOHIDEvent constants (IOKit IOHIDEventTypes.h / IOHIDEventFieldDefs.h)
#define GRABBY_HID_TYPE_VELOCITY        9
#define GRABBY_HID_TYPE_DOCK_SWIPE      23
#define GRABBY_HID_FIELD_BASE(type)     ((type) << 16)
#define GRABBY_HID_FIELD_DOCK_SWIPE_MOTION    (GRABBY_HID_FIELD_BASE(GRABBY_HID_TYPE_DOCK_SWIPE) | 1)
#define GRABBY_HID_FIELD_DOCK_SWIPE_PROGRESS  (GRABBY_HID_FIELD_BASE(GRABBY_HID_TYPE_DOCK_SWIPE) | 2)
#define GRABBY_HID_FIELD_DOCK_SWIPE_FLAVOR    (GRABBY_HID_FIELD_BASE(GRABBY_HID_TYPE_DOCK_SWIPE) | 5)
#define GRABBY_HID_FIELD_VELOCITY_X     (GRABBY_HID_FIELD_BASE(GRABBY_HID_TYPE_VELOCITY) | 0)
#define GRABBY_HID_FIELD_VELOCITY_Y     (GRABBY_HID_FIELD_BASE(GRABBY_HID_TYPE_VELOCITY) | 1)
#define GRABBY_HID_FIELD_VELOCITY_Z     (GRABBY_HID_FIELD_BASE(GRABBY_HID_TYPE_VELOCITY) | 2)
#define GRABBY_FLAVOR_DOCK_PRIMARY      1
#define GRABBY_DOCK_SWIPE_HORIZONTAL    1
#define GRABBY_DOCK_SWIPE_VERTICAL      2
#define GRABBY_PHASE_BEGAN              (1 << 0)
#define GRABBY_PHASE_CHANGED            (1 << 1)
#define GRABBY_PHASE_ENDED              (1 << 2)
#define GRABBY_PHASE_CANCELLED          (1 << 3)
#define GRABBY_PHASE_SHIFT              24
#define GRABBY_CGEVENT_TYPE_GESTURE_WRAPPER 30

// Symbolic hotkey ids (CGSHotKeys.h)
#define GRABBY_SHK_MISSION_CONTROL      32
#define GRABBY_SHK_APP_EXPOSE           33
#define GRABBY_SHK_SHOW_DESKTOP         36
#define GRABBY_SHK_SPACE_LEFT           79
#define GRABBY_SHK_SPACE_RIGHT          81
#define GRABBY_CGS_NUMERIC_PAD_MASK     (1u << 21)
#define GRABBY_CGS_FUNCTION_KEY_MASK    (1u << 23)

typedef CFTypeRef GrabbyHIDEventRef;
typedef uint32_t GrabbyModifierFlags;

typedef GrabbyHIDEventRef (*grabby_IOHIDEventCreate_t)(CFAllocatorRef allocator, uint32_t type, uint64_t timestamp, uint32_t options);
typedef void (*grabby_IOHIDEventSetIntegerValue_t)(GrabbyHIDEventRef event, uint32_t field, CFIndex value);
typedef void (*grabby_IOHIDEventSetFloatValue_t)(GrabbyHIDEventRef event, uint32_t field, double value);
typedef void (*grabby_IOHIDEventAppendEvent_t)(GrabbyHIDEventRef parent, GrabbyHIDEventRef child, uint32_t options);
typedef void (*grabby_SLEventSetIOHIDEvent_t)(CGEventRef cgEvent, GrabbyHIDEventRef hidEvent);
typedef int (*grabby_CGSMainConnectionID_t)(void);
typedef uint64_t (*grabby_CGSGetActiveSpace_t)(int connection);
typedef CFArrayRef (*grabby_CGSCopyManagedDisplaySpaces_t)(int connection);
typedef CGError (*grabby_CGSGetSymbolicHotKeyValue_t)(int hotKey, uint16_t *keyEquivalent, CGKeyCode *virtualKeyCode, GrabbyModifierFlags *modifiers);
typedef CGError (*grabby_CGSSetSymbolicHotKeyValue_t)(int hotKey, uint16_t keyEquivalent, CGKeyCode virtualKeyCode, GrabbyModifierFlags modifiers);
typedef bool (*grabby_CGSIsSymbolicHotKeyEnabled_t)(int hotKey);
typedef CGError (*grabby_CGSSetSymbolicHotKeyEnabled_t)(int hotKey, bool enabled);

struct grabby_private_api {
    grabby_IOHIDEventCreate_t IOHIDEventCreate;
    grabby_IOHIDEventSetIntegerValue_t IOHIDEventSetIntegerValue;
    grabby_IOHIDEventSetFloatValue_t IOHIDEventSetFloatValue;
    grabby_IOHIDEventAppendEvent_t IOHIDEventAppendEvent;
    grabby_SLEventSetIOHIDEvent_t SLEventSetIOHIDEvent;
    grabby_CGSMainConnectionID_t CGSMainConnectionID;
    grabby_CGSGetActiveSpace_t CGSGetActiveSpace;
    grabby_CGSCopyManagedDisplaySpaces_t CGSCopyManagedDisplaySpaces;
    grabby_CGSGetSymbolicHotKeyValue_t CGSGetSymbolicHotKeyValue;
    grabby_CGSSetSymbolicHotKeyValue_t CGSSetSymbolicHotKeyValue;
    grabby_CGSIsSymbolicHotKeyEnabled_t CGSIsSymbolicHotKeyEnabled;
    grabby_CGSSetSymbolicHotKeyEnabled_t CGSSetSymbolicHotKeyEnabled;
};

#define GRABBY_PRIVATE_SYMBOL_COUNT 12

/// Resolves every symbol. Safe to call more than once. Never fails; check the pointers.
struct grabby_private_api grabby_private_resolve(void);

/// True when every pointer in the struct is non-NULL.
bool grabby_private_all_present(const struct grabby_private_api *api);

/// Name of the symbol at index 0..<GRABBY_PRIVATE_SYMBOL_COUNT, and whether it resolved.
const char *grabby_private_symbol_name(int index);
bool grabby_private_symbol_present(const struct grabby_private_api *api, int index);

#endif
