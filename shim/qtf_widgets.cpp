// C ABI shim over Qt Widgets: QApplication, QWidget, QLabel.

#include "qtf_common.h"

#include <QApplication>
#include <QLabel>
#include <QWidget>

// ---------------------------------------------------------------------------
// QApplication

// QApplication keeps references to argc/argv, so they must outlive it.
static int qtf_argc = 1;
static char qtf_argv0[] = "qt-fortran";
static char *qtf_argv[] = {qtf_argv0, nullptr};

QTF_API void *qtf_qapplication_new(void) {
    if (QApplication::instance()) return QApplication::instance();
    return new QApplication(qtf_argc, qtf_argv);
}

QTF_API int qtf_qapplication_exec(void) { return QApplication::exec(); }

QTF_API void qtf_qapplication_quit(void) { QApplication::quit(); }

QTF_API void qtf_qapplication_processEvents(void) { QApplication::processEvents(); }

// ---------------------------------------------------------------------------
// QWidget

static QWidget *widget(void *p) { return static_cast<QWidget *>(p); }

QTF_API void *qtf_qwidget_new(void *parent) { return new QWidget(widget(parent)); }

QTF_API void qtf_qwidget_show(void *w) { widget(w)->show(); }

QTF_API void qtf_qwidget_hide(void *w) { widget(w)->hide(); }

QTF_API int qtf_qwidget_isVisible(void *w) { return qtf_bool(widget(w)->isVisible()); }

QTF_API void qtf_qwidget_resize(void *w, int width, int height) { widget(w)->resize(width, height); }

QTF_API int qtf_qwidget_width(void *w) { return widget(w)->width(); }

QTF_API int qtf_qwidget_height(void *w) { return widget(w)->height(); }

QTF_API void qtf_qwidget_setWindowTitle(void *w, const char *s, int len) {
    widget(w)->setWindowTitle(qtf_qstring(s, len));
}

QTF_API char *qtf_qwidget_windowTitle(void *w, int *len) {
    return qtf_to_c(widget(w)->windowTitle(), len);
}

// ---------------------------------------------------------------------------
// QLabel

static QLabel *label(void *p) { return static_cast<QLabel *>(p); }

QTF_API void *qtf_qlabel_new(const char *s, int len, void *parent) {
    return new QLabel(qtf_qstring(s, len), widget(parent));
}

QTF_API void qtf_qlabel_setText(void *w, const char *s, int len) {
    label(w)->setText(qtf_qstring(s, len));
}

QTF_API char *qtf_qlabel_text(void *w, int *len) { return qtf_to_c(label(w)->text(), len); }

QTF_API void qtf_qlabel_setAlignment(void *w, int flags) {
    label(w)->setAlignment(Qt::Alignment(flags));
}
