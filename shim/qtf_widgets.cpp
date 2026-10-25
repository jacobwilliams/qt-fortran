// C ABI shim over Qt Widgets. Qt objects cross the boundary as opaque void*.

#include "qtf_common.h"

#include <QApplication>
#include <QLabel>
#include <QTimer>
#include <QWidget>

#include <cstdlib>
#include <cstring>

typedef void (*qtf_callback_t)(void *data);

// QApplication keeps references to argc/argv, so they must outlive it.
static int qtf_argc = 1;
static char qtf_argv0[] = "qt-fortran";
static char *qtf_argv[] = {qtf_argv0, nullptr};

// Strings returned to Fortran are malloc'd UTF-8 buffers, released by qtf_free.
static char *qtf_to_c(const QString &s, int *len) {
    const QByteArray b = s.toUtf8();
    *len = static_cast<int>(b.size());
    char *p = static_cast<char *>(std::malloc(b.size() + 1));
    std::memcpy(p, b.constData(), b.size() + 1);
    return p;
}

QTF_API void qtf_free(void *p) { std::free(p); }

// QApplication

QTF_API void *qtf_qapplication_new(void) {
    if (QApplication::instance()) return QApplication::instance();
    return new QApplication(qtf_argc, qtf_argv);
}

QTF_API int qtf_qapplication_exec(void) { return QApplication::exec(); }

QTF_API void qtf_qapplication_quit(void) { QApplication::quit(); }

// QWidget

QTF_API void qtf_qwidget_show(void *w) { static_cast<QWidget *>(w)->show(); }

QTF_API void qtf_qwidget_resize(void *w, int width, int height) {
    static_cast<QWidget *>(w)->resize(width, height);
}

QTF_API void qtf_qwidget_setWindowTitle(void *w, const char *s, int len) {
    static_cast<QWidget *>(w)->setWindowTitle(QString::fromUtf8(s, len));
}

QTF_API void qtf_qwidget_delete(void *w) { delete static_cast<QWidget *>(w); }

// QLabel

QTF_API void *qtf_qlabel_new(const char *s, int len, void *parent) {
    return new QLabel(QString::fromUtf8(s, len), static_cast<QWidget *>(parent));
}

QTF_API void qtf_qlabel_setText(void *w, const char *s, int len) {
    static_cast<QLabel *>(w)->setText(QString::fromUtf8(s, len));
}

QTF_API char *qtf_qlabel_text(void *w, int *len) {
    return qtf_to_c(static_cast<QLabel *>(w)->text(), len);
}

QTF_API void qtf_qlabel_setAlignment(void *w, int flags) {
    static_cast<QLabel *>(w)->setAlignment(Qt::Alignment(flags));
}

// QTimer

QTF_API void qtf_qtimer_singleShot(int msec, qtf_callback_t cb, void *data) {
    QTimer::singleShot(msec, [cb, data]() { cb(data); });
}

