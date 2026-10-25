// Shared definitions for the qtf C ABI shim.
#pragma once

#include <QString>

#include <cstdint>
#include <memory>

// Every shim function is exported from the qtf shared library.
#if defined(_WIN32)
#define QTF_API extern "C" __declspec(dllexport)
#else
#define QTF_API extern "C" __attribute__((visibility("default")))
#endif

// Signal ids: must match the QTF_SIG_* parameters in src/core/qt_c_core.f90.
enum qtf_signal : int {
    // core (1..999)
    QTF_SIG_QOBJECT_DESTROYED = 1,
    QTF_SIG_QOBJECT_OBJECTNAMECHANGED = 2,
    QTF_SIG_QTIMER_TIMEOUT = 3,
    // widgets (1000..1999)
    QTF_SIG_QABSTRACTBUTTON_CLICKED = 1000,
    QTF_SIG_QABSTRACTBUTTON_TOGGLED = 1001,
    QTF_SIG_QABSTRACTBUTTON_PRESSED = 1002,
    QTF_SIG_QABSTRACTBUTTON_RELEASED = 1003,
    QTF_SIG_QLINEEDIT_TEXTCHANGED = 1010,
    QTF_SIG_QLINEEDIT_TEXTEDITED = 1011,
    QTF_SIG_QLINEEDIT_RETURNPRESSED = 1012,
    QTF_SIG_QLINEEDIT_EDITINGFINISHED = 1013,
    QTF_SIG_QSPINBOX_VALUECHANGED = 1020,
    QTF_SIG_QDOUBLESPINBOX_VALUECHANGED = 1021,
    QTF_SIG_QABSTRACTSLIDER_VALUECHANGED = 1030,
    QTF_SIG_QABSTRACTSLIDER_SLIDERMOVED = 1031,
    QTF_SIG_QABSTRACTSLIDER_SLIDERPRESSED = 1032,
    QTF_SIG_QABSTRACTSLIDER_SLIDERRELEASED = 1033,
    QTF_SIG_QCOMBOBOX_CURRENTINDEXCHANGED = 1040,
    QTF_SIG_QCOMBOBOX_CURRENTTEXTCHANGED = 1041,
    QTF_SIG_QCOMBOBOX_ACTIVATED = 1042,
    QTF_SIG_QDIALOG_ACCEPTED = 1050,
    QTF_SIG_QDIALOG_REJECTED = 1051,
    QTF_SIG_QDIALOG_FINISHED = 1052,
};

// Signal arguments passed to the Fortran dispatcher (mirrors type(qtf_args)).
// Strings are borrowed: valid only for the duration of the call.
struct qtf_args {
    int64_t i[4];
    double d[4];
    const char *s;
    int32_t slen;
};

typedef void (*qtf_dispatch_fn)(int slot, const qtf_args *args);
typedef void (*qtf_release_fn)(int slot);

// A Fortran slot id owned by a connection. When Qt destroys the connection
// (sender/context deleted, single-shot fired), the Fortran slot is released.
struct qtf_slot_ref {
    explicit qtf_slot_ref(int id) : id(id) {}
    ~qtf_slot_ref();
    qtf_slot_ref(const qtf_slot_ref &) = delete;
    qtf_slot_ref &operator=(const qtf_slot_ref &) = delete;
    const int id;
};
using qtf_slot = std::shared_ptr<qtf_slot_ref>;

inline qtf_slot qtf_make_slot(int id) { return std::make_shared<qtf_slot_ref>(id); }

// Invoke the Fortran slot.
void qtf_emit(const qtf_slot &slot, const qtf_args &args);
void qtf_emit(const qtf_slot &slot);
void qtf_emit(const qtf_slot &slot, const QString &s);
void qtf_emit_bool(const qtf_slot &slot, bool b);
void qtf_emit_int(const qtf_slot &slot, int i);
void qtf_emit_double(const qtf_slot &slot, double d);

// Connect `signal` of `sender` to Fortran slot `slot`; returns false on failure.
typedef bool (*qtf_connector_fn)(void *sender, const qtf_slot &slot);
bool qtf_register_connector(int signal, qtf_connector_fn fn);

// Strings returned to Fortran are malloc'd UTF-8 buffers, released by qtf_free.
char *qtf_to_c(const QString &s, int *len);

inline QString qtf_qstring(const char *s, int len) { return QString::fromUtf8(s, len); }

inline int qtf_bool(bool b) { return b ? 1 : 0; }
