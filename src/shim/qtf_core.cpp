// C ABI shim over Qt Core: strings, signal dispatch, QObject, QTimer.

// Compiled by fpm as part of the qt-fortran library, unless the shim is
// built separately as a shared library (QTF_EXTERNAL_SHIM; see tools/fpm_qt.py).
#ifndef QTF_EXTERNAL_SHIM

#include "qtf_common.h"

#include <QCoreApplication>
#include <QEvent>
#include <QObject>
#include <QTimer>

#include <cstdlib>
#include <cstring>
#include <unordered_map>

// ---------------------------------------------------------------------------
// strings

char *qtf_to_c(const QString &s, int *len) {
    const QByteArray b = s.toUtf8();
    *len = static_cast<int>(b.size());
    char *p = static_cast<char *>(std::malloc(b.size() + 1));
    std::memcpy(p, b.constData(), b.size() + 1);
    return p;
}

char *qtf_list_to_c(const QStringList &list, int *len) {
    QByteArray b;
    for (const QString &s : list) {
        b += s.toUtf8();
        b += '\0';
    }
    *len = static_cast<int>(b.size());
    char *p = static_cast<char *>(std::malloc(b.size() + 1));
    std::memcpy(p, b.constData(), b.size() + 1);
    return p;
}

int *qtf_ints_to_c(const QList<int> &list, int *len) {
    *len = static_cast<int>(list.size());
    int *p = static_cast<int *>(std::malloc(sizeof(int) * (list.size() + 1)));
    for (qsizetype i = 0; i < list.size(); ++i) p[i] = list[i];
    return p;
}

QStringList qtf_qstringlist(const char *s, int itemlen, int n) {
    QStringList list;
    for (int i = 0; i < n; ++i) {
        const char *item = s + static_cast<qsizetype>(i) * itemlen;
        int len = itemlen;
        while (len > 0 && item[len - 1] == ' ') --len;
        list << QString::fromUtf8(item, len);
    }
    return list;
}

QList<int> qtf_intlist(const int *v, int n) { return QList<int>(v, v + n); }

QTF_API void qtf_free(void *p) { std::free(p); }

// ---------------------------------------------------------------------------
// signal dispatch

static qtf_dispatch_fn qtf_dispatcher = nullptr;
static qtf_release_fn qtf_releaser = nullptr;

QTF_API void qtf_set_dispatcher(qtf_dispatch_fn dispatch, qtf_release_fn release) {
    qtf_dispatcher = dispatch;
    qtf_releaser = release;
}

// The live refs by Fortran slot id, for qtf_disconnect.
static std::unordered_map<int, qtf_slot_ref *> &qtf_live_slots() {
    static std::unordered_map<int, qtf_slot_ref *> m;
    return m;
}

qtf_slot_ref::qtf_slot_ref(int id) : id(id) { qtf_live_slots()[id] = this; }

qtf_slot_ref::~qtf_slot_ref() {
    if (!alive) return;   // already released by qtf_disconnect
    qtf_live_slots().erase(id);
    if (qtf_releaser) qtf_releaser(id);
}

void qtf_emit(const qtf_slot &slot, const qtf_args &args) {
    if (slot->alive && qtf_dispatcher) qtf_dispatcher(slot->id, &args);
}

int qtf_emit_all(const std::vector<qtf_slot> &slots_, const qtf_args &args) {
    const std::vector<qtf_slot> targets = slots_;
    int n = 0;
    for (const qtf_slot &s : targets) {
        if (!s->alive) continue;
        qtf_emit(s, args);
        ++n;
    }
    return n;
}

// Disconnect the connection that owns Fortran slot `slot` and release the slot
// now. Returns 1 if it was connected. A connection kept in a handler list (event
// slots) stays in the list, dead, until its owner is destroyed.
QTF_API int qtf_disconnect(int slot) {
    auto it = qtf_live_slots().find(slot);
    if (it == qtf_live_slots().end()) return 0;
    qtf_slot_ref *ref = it->second;
    qtf_live_slots().erase(it);
    ref->alive = false;
    // may destroy `ref` (the lambda owned the last reference): do not touch it after
    QObject::disconnect(QMetaObject::Connection(ref->connection));
    if (qtf_releaser) qtf_releaser(slot);
    return 1;
}

void qtf_emit(const qtf_slot &slot) {
    qtf_args a{};
    qtf_emit(slot, a);
}

void qtf_emit(const qtf_slot &slot, const QString &s) {
    const QByteArray b = s.toUtf8();
    qtf_args a{};
    a.s = b.constData();
    a.slen = static_cast<int32_t>(b.size());
    qtf_emit(slot, a);
}

void qtf_emit_bool(const qtf_slot &slot, bool b) {
    qtf_args a{};
    a.i[0] = b ? 1 : 0;
    qtf_emit(slot, a);
}

void qtf_emit_int(const qtf_slot &slot, int i) {
    qtf_args a{};
    a.i[0] = i;
    qtf_emit(slot, a);
}

void qtf_emit_double(const qtf_slot &slot, double d) {
    qtf_args a{};
    a.d[0] = d;
    qtf_emit(slot, a);
}

void qtf_emit_ptr(const qtf_slot &slot, void *p) {
    qtf_args a{};
    a.p = p;
    qtf_emit(slot, a);
}

void qtf_emit_ints(const qtf_slot &slot, std::initializer_list<int> ints) {
    qtf_args a{};
    int k = 0;
    for (int v : ints) a.i[k++ & 3] = v;
    qtf_emit(slot, a);
}

void qtf_emit_ptr_ints(const qtf_slot &slot, void *p, std::initializer_list<int> ints) {
    qtf_args a{};
    a.p = p;
    int k = 0;
    for (int v : ints) a.i[k++ & 3] = v;
    qtf_emit(slot, a);
}

void qtf_emit_ints_string(const qtf_slot &slot, std::initializer_list<int> ints, const QString &s) {
    const QByteArray b = s.toUtf8();
    qtf_args a{};
    a.s = b.constData();
    a.slen = static_cast<int32_t>(b.size());
    int k = 0;
    for (int v : ints) a.i[k++ & 3] = v;
    qtf_emit(slot, a);
}

// function-local static: safe to use from other translation units' static init
static std::unordered_map<int, qtf_connector_fn> &qtf_connectors() {
    static std::unordered_map<int, qtf_connector_fn> m;
    return m;
}

bool qtf_register_connector(int signal, qtf_connector_fn fn) {
    qtf_connectors()[signal] = fn;
    return true;
}

// Returns 1 on success. On failure the slot is released before returning.
QTF_API int qtf_connect(void *sender, int signal, int slot) {
    qtf_slot ref = qtf_make_slot(slot);
    if (!sender) return 0;
    auto it = qtf_connectors().find(signal);
    if (it == qtf_connectors().end()) return 0;
    return qtf_bool(it->second(sender, ref));
}

// ---------------------------------------------------------------------------
// QObject

static QObject *obj(void *p) { return static_cast<QObject *>(p); }

QTF_API void *qtf_qobject_new(void *parent) { return new QObject(obj(parent)); }

QTF_API void qtf_qobject_delete(void *o) { delete obj(o); }

QTF_API void qtf_qobject_deleteLater(void *o) { obj(o)->deleteLater(); }

QTF_API char *qtf_qobject_objectName(void *o, int *len) {
    return qtf_to_c(obj(o)->objectName(), len);
}

QTF_API void qtf_qobject_setObjectName(void *o, const char *s, int len) {
    obj(o)->setObjectName(qtf_qstring(s, len));
}

QTF_API void qtf_qobject_setParent(void *o, void *parent) { obj(o)->setParent(obj(parent)); }

QTF_API void *qtf_qobject_parent(void *o) { return obj(o)->parent(); }

QTF_API char *qtf_qobject_className(void *o, int *len) {
    return qtf_to_c(QString::fromLatin1(obj(o)->metaObject()->className()), len);
}

QTF_API int qtf_qobject_inherits(void *o, const char *s, int len) {
    return qtf_bool(obj(o)->inherits(QByteArray(s, len).constData()));
}

// ---------------------------------------------------------------------------
// QEvent

static QEvent *event(void *p) { return static_cast<QEvent *>(p); }

QTF_API int qtf_qevent_type(void *e) { return int(event(e)->type()); }

QTF_API void qtf_qevent_accept(void *e) { event(e)->accept(); }

QTF_API void qtf_qevent_ignore(void *e) { event(e)->ignore(); }

QTF_API int qtf_qevent_isAccepted(void *e) { return qtf_bool(event(e)->isAccepted()); }

QTF_API void qtf_qevent_delete(void *e) { delete event(e); }

QTF_API int qtf_qcoreapplication_sendEvent(void *receiver, void *e) {
    return qtf_bool(QCoreApplication::sendEvent(obj(receiver), event(e)));
}

// ---------------------------------------------------------------------------
// QTimer

static QTimer *timer(void *p) { return static_cast<QTimer *>(p); }

QTF_API void *qtf_qtimer_new(void *parent) { return new QTimer(obj(parent)); }

// msec < 0: start with the current interval
QTF_API void qtf_qtimer_start(void *t, int msec) {
    if (msec < 0) timer(t)->start();
    else timer(t)->start(msec);
}

QTF_API void qtf_qtimer_stop(void *t) { timer(t)->stop(); }

QTF_API void qtf_qtimer_setInterval(void *t, int msec) { timer(t)->setInterval(msec); }

QTF_API int qtf_qtimer_interval(void *t) { return timer(t)->interval(); }

QTF_API int qtf_qtimer_isActive(void *t) { return qtf_bool(timer(t)->isActive()); }

QTF_API void qtf_qtimer_setSingleShot(void *t, int b) { timer(t)->setSingleShot(b != 0); }

QTF_API int qtf_qtimer_isSingleShot(void *t) { return qtf_bool(timer(t)->isSingleShot()); }

QTF_API void qtf_qtimer_singleShot(int msec, int slot) {
    qtf_slot ref = qtf_make_slot(slot);
    QTimer::singleShot(msec, [ref]() { qtf_emit(ref); });
}

// ---------------------------------------------------------------------------
// signals defined in Fortran

// The sender of a signal created in Fortran (QSignal(parent), ...): it holds the
// connected slots, which `emit` calls in order.
class QtfSignalSource : public QObject {
  public:
    using QObject::QObject;
    std::vector<qtf_slot> handlers;
};

// A new signal source, owned by `parent` if given.
QTF_API void *qtf_qtfsignal_new(void *parent) { return new QtfSignalSource(obj(parent)); }

// Call the slots of a Fortran-defined signal with the given arguments (integers,
// one real, a string). Returns 0 if `source` is not a Fortran-defined signal.
QTF_API int qtf_qtfsignal_emit(void *source, const int *ints, double d, const char *s, int slen) {
    auto *src = dynamic_cast<QtfSignalSource *>(obj(source));
    if (!src) return 0;
    qtf_args a{};
    for (int k = 0; k < 4; ++k) a.i[k] = ints[k];
    a.d[0] = d;
    a.s = s;
    a.slen = slen;
    qtf_emit_all(src->handlers, a);
    return 1;
}

// ---------------------------------------------------------------------------
// signal connectors

static const bool qtf_core_registered = [] {
    qtf_register_connector(QTF_SIG_QOBJECT_DESTROYED, [](void *s, const qtf_slot &ref) {
        return qtf_track(ref, QObject::connect(obj(s), &QObject::destroyed, [ref]() { qtf_emit(ref); }));
    });
    qtf_register_connector(QTF_SIG_QOBJECT_OBJECTNAMECHANGED, [](void *s, const qtf_slot &ref) {
        return qtf_track(ref, QObject::connect(obj(s), &QObject::objectNameChanged, obj(s),
                                               [ref](const QString &name) { qtf_emit(ref, name); }));
    });
    qtf_register_connector(QTF_SIG_QTIMER_TIMEOUT, [](void *s, const qtf_slot &ref) {
        return qtf_track(ref, QObject::connect(timer(s), &QTimer::timeout, timer(s), [ref]() { qtf_emit(ref); }));
    });
    qtf_register_connector(QTF_SIG_QTFSIGNAL, [](void *s, const qtf_slot &ref) {
        auto *src = dynamic_cast<QtfSignalSource *>(obj(s));
        if (src) src->handlers.push_back(ref);
        return src != nullptr;
    });
    return true;
}();

#endif // QTF_EXTERNAL_SHIM
