// Shared definitions for the qtf C ABI shim.
#pragma once

#include <QString>
#include <QStringList>

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
    // widgets (1000..1999): generated in shim/qtf_widgets.cpp from spec/widgets.toml
    // gui (2000..2999): generated in shim/qtf_gui.cpp from spec/gui.toml
};

// Signal arguments passed to the Fortran dispatcher (mirrors type(qtf_args) in
// src/core/qt_c_util.f90). `s` and `p` (an event or painter) are borrowed:
// valid only for the duration of the call.
struct qtf_args {
    int64_t i[4];
    double d[4];
    const char *s;
    void *p;
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
void qtf_emit_ptr(const qtf_slot &slot, void *p);  // event or painter, borrowed

// Connect `signal` of `sender` to Fortran slot `slot`; returns false on failure.
typedef bool (*qtf_connector_fn)(void *sender, const qtf_slot &slot);
bool qtf_register_connector(int signal, qtf_connector_fn fn);

// Strings returned to Fortran are malloc'd UTF-8 buffers, released by qtf_free.
char *qtf_to_c(const QString &s, int *len);

// String lists are returned as one malloc'd buffer of NUL-terminated strings.
char *qtf_list_to_c(const QStringList &list, int *len);

inline QString qtf_qstring(const char *s, int len) { return QString::fromUtf8(s, len); }

inline int qtf_bool(bool b) { return b ? 1 : 0; }
