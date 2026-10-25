// C ABI shim over Qt Widgets.

#include "qtf_common.h"

#include <QApplication>
#include <QBoxLayout>
#include <QCheckBox>
#include <QComboBox>
#include <QDialog>
#include <QDoubleSpinBox>
#include <QFileDialog>
#include <QGridLayout>
#include <QLabel>
#include <QLineEdit>
#include <QMainWindow>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QPainter>
#include <QPushButton>
#include <QRadioButton>
#include <QSlider>
#include <QSpinBox>
#include <QStatusBar>
#include <QToolBar>
#include <QWidget>

#include <array>
#include <cstdlib>
#include <cstring>
#include <vector>

template <typename T> static T *as(void *p) { return static_cast<T *>(p); }

static QWidget *widget(void *p) { return as<QWidget>(p); }

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

QTF_API void *qtf_qapplication_activeModalWidget(void) { return QApplication::activeModalWidget(); }

// ---------------------------------------------------------------------------
// QWidget

QTF_API void *qtf_qwidget_new(void *parent) { return new QWidget(widget(parent)); }

QTF_API void qtf_qwidget_show(void *w) { widget(w)->show(); }

QTF_API void qtf_qwidget_hide(void *w) { widget(w)->hide(); }

QTF_API void qtf_qwidget_close(void *w) { widget(w)->close(); }

QTF_API void qtf_qwidget_setVisible(void *w, int b) { widget(w)->setVisible(b != 0); }

QTF_API int qtf_qwidget_isVisible(void *w) { return qtf_bool(widget(w)->isVisible()); }

QTF_API void qtf_qwidget_setEnabled(void *w, int b) { widget(w)->setEnabled(b != 0); }

QTF_API int qtf_qwidget_isEnabled(void *w) { return qtf_bool(widget(w)->isEnabled()); }

QTF_API void qtf_qwidget_resize(void *w, int width, int height) { widget(w)->resize(width, height); }

QTF_API int qtf_qwidget_width(void *w) { return widget(w)->width(); }

QTF_API int qtf_qwidget_height(void *w) { return widget(w)->height(); }

QTF_API void qtf_qwidget_setMinimumSize(void *w, int width, int height) {
    widget(w)->setMinimumSize(width, height);
}

QTF_API void qtf_qwidget_setFixedSize(void *w, int width, int height) {
    widget(w)->setFixedSize(width, height);
}

QTF_API void qtf_qwidget_setWindowTitle(void *w, const char *s, int len) {
    widget(w)->setWindowTitle(qtf_qstring(s, len));
}

QTF_API char *qtf_qwidget_windowTitle(void *w, int *len) {
    return qtf_to_c(widget(w)->windowTitle(), len);
}

QTF_API void qtf_qwidget_setToolTip(void *w, const char *s, int len) {
    widget(w)->setToolTip(qtf_qstring(s, len));
}

QTF_API char *qtf_qwidget_toolTip(void *w, int *len) { return qtf_to_c(widget(w)->toolTip(), len); }

QTF_API void qtf_qwidget_setStyleSheet(void *w, const char *s, int len) {
    widget(w)->setStyleSheet(qtf_qstring(s, len));
}

QTF_API void qtf_qwidget_setFocus(void *w) { widget(w)->setFocus(); }

QTF_API void qtf_qwidget_setLayout(void *w, void *layout) { widget(w)->setLayout(as<QLayout>(layout)); }

QTF_API void *qtf_qwidget_layout(void *w) { return widget(w)->layout(); }

QTF_API void qtf_qwidget_update(void *w) { widget(w)->update(); }

QTF_API void qtf_qwidget_repaint(void *w) { widget(w)->repaint(); }

QTF_API void qtf_qwidget_setMouseTracking(void *w, int b) { widget(w)->setMouseTracking(b != 0); }

QTF_API int qtf_qwidget_hasMouseTracking(void *w) { return qtf_bool(widget(w)->hasMouseTracking()); }

QTF_API void qtf_qwidget_setFocusPolicy(void *w, int policy) { widget(w)->setFocusPolicy(Qt::FocusPolicy(policy)); }

QTF_API int qtf_qwidget_hasFocus(void *w) { return qtf_bool(widget(w)->hasFocus()); }

// Render the widget into a new pixmap (works for hidden widgets too).
QTF_API void *qtf_qwidget_grab(void *w) { return new QPixmap(widget(w)->grab()); }

QTF_API void qtf_qwidget_addAction(void *w, void *action) { widget(w)->addAction(as<QAction>(action)); }

// ---------------------------------------------------------------------------
// QtfWidget: a QWidget whose event handlers (virtual functions) are forwarded
// to Fortran slots. An event with no connected slot gets Qt's default handling.

enum qtf_widget_event {
    QTF_EV_PAINT,
    QTF_EV_MOUSEPRESS,
    QTF_EV_MOUSERELEASE,
    QTF_EV_MOUSEMOVE,
    QTF_EV_MOUSEDOUBLECLICK,
    QTF_EV_WHEEL,
    QTF_EV_KEYPRESS,
    QTF_EV_KEYRELEASE,
    QTF_EV_RESIZE,
    QTF_EV_COUNT
};

class QtfWidget : public QWidget {
  public:
    explicit QtfWidget(QWidget *parent) : QWidget(parent) { setFocusPolicy(Qt::StrongFocus); }

    // (not named `slots`: that is a Qt macro)
    std::array<std::vector<qtf_slot>, QTF_EV_COUNT> handlers;

  protected:
    // Emit to a copy: a slot may connect more slots while we iterate.
    bool forward(qtf_widget_event ev, void *p) {
        const std::vector<qtf_slot> targets = handlers[ev];
        for (const qtf_slot &s : targets) qtf_emit_ptr(s, p);
        return !targets.empty();
    }

    void paintEvent(QPaintEvent *e) override {
        if (handlers[QTF_EV_PAINT].empty()) return QWidget::paintEvent(e);
        QPainter painter(this);
        forward(QTF_EV_PAINT, &painter);
    }
    void mousePressEvent(QMouseEvent *e) override {
        if (!forward(QTF_EV_MOUSEPRESS, e)) QWidget::mousePressEvent(e);
    }
    void mouseReleaseEvent(QMouseEvent *e) override {
        if (!forward(QTF_EV_MOUSERELEASE, e)) QWidget::mouseReleaseEvent(e);
    }
    void mouseMoveEvent(QMouseEvent *e) override {
        if (!forward(QTF_EV_MOUSEMOVE, e)) QWidget::mouseMoveEvent(e);
    }
    void mouseDoubleClickEvent(QMouseEvent *e) override {
        if (!forward(QTF_EV_MOUSEDOUBLECLICK, e)) QWidget::mouseDoubleClickEvent(e);
    }
    void wheelEvent(QWheelEvent *e) override {
        if (!forward(QTF_EV_WHEEL, e)) QWidget::wheelEvent(e);
    }
    void keyPressEvent(QKeyEvent *e) override {
        if (!forward(QTF_EV_KEYPRESS, e)) QWidget::keyPressEvent(e);
    }
    void keyReleaseEvent(QKeyEvent *e) override {
        if (!forward(QTF_EV_KEYRELEASE, e)) QWidget::keyReleaseEvent(e);
    }
    void resizeEvent(QResizeEvent *e) override {
        QWidget::resizeEvent(e);
        forward(QTF_EV_RESIZE, e);
    }
};

QTF_API void *qtf_qtfwidget_new(void *parent) { return new QtfWidget(widget(parent)); }

// Attach a slot to one of the QtfWidget's event handlers. The slots are owned
// by the widget, so they are released when it is destroyed.
template <qtf_widget_event EV> static bool connect_event(void *s, const qtf_slot &ref) {
    auto *w = dynamic_cast<QtfWidget *>(widget(s));
    if (!w) return false;
    w->handlers[EV].push_back(ref);
    return true;
}

// ---------------------------------------------------------------------------
// QLabel

static QLabel *label(void *p) { return as<QLabel>(p); }

QTF_API void *qtf_qlabel_new(const char *s, int len, void *parent) {
    return new QLabel(qtf_qstring(s, len), widget(parent));
}

QTF_API void qtf_qlabel_setText(void *w, const char *s, int len) { label(w)->setText(qtf_qstring(s, len)); }

QTF_API char *qtf_qlabel_text(void *w, int *len) { return qtf_to_c(label(w)->text(), len); }

QTF_API void qtf_qlabel_setAlignment(void *w, int flags) { label(w)->setAlignment(Qt::Alignment(flags)); }

QTF_API void qtf_qlabel_setWordWrap(void *w, int b) { label(w)->setWordWrap(b != 0); }

// ---------------------------------------------------------------------------
// QAbstractButton, QPushButton, QCheckBox, QRadioButton

static QAbstractButton *button(void *p) { return as<QAbstractButton>(p); }

QTF_API void *qtf_qpushbutton_new(const char *s, int len, void *parent) {
    return new QPushButton(qtf_qstring(s, len), widget(parent));
}

QTF_API void *qtf_qcheckbox_new(const char *s, int len, void *parent) {
    return new QCheckBox(qtf_qstring(s, len), widget(parent));
}

QTF_API void *qtf_qradiobutton_new(const char *s, int len, void *parent) {
    return new QRadioButton(qtf_qstring(s, len), widget(parent));
}

QTF_API void qtf_qabstractbutton_setText(void *b, const char *s, int len) {
    button(b)->setText(qtf_qstring(s, len));
}

QTF_API char *qtf_qabstractbutton_text(void *b, int *len) { return qtf_to_c(button(b)->text(), len); }

QTF_API void qtf_qabstractbutton_setCheckable(void *b, int v) { button(b)->setCheckable(v != 0); }

QTF_API int qtf_qabstractbutton_isCheckable(void *b) { return qtf_bool(button(b)->isCheckable()); }

QTF_API void qtf_qabstractbutton_setChecked(void *b, int v) { button(b)->setChecked(v != 0); }

QTF_API int qtf_qabstractbutton_isChecked(void *b) { return qtf_bool(button(b)->isChecked()); }

QTF_API void qtf_qabstractbutton_click(void *b) { button(b)->click(); }

QTF_API void qtf_qabstractbutton_toggle(void *b) { button(b)->toggle(); }

QTF_API void qtf_qpushbutton_setDefault(void *b, int v) { as<QPushButton>(b)->setDefault(v != 0); }

// ---------------------------------------------------------------------------
// QLineEdit

static QLineEdit *lineedit(void *p) { return as<QLineEdit>(p); }

QTF_API void *qtf_qlineedit_new(const char *s, int len, void *parent) {
    return new QLineEdit(qtf_qstring(s, len), widget(parent));
}

QTF_API void qtf_qlineedit_setText(void *e, const char *s, int len) { lineedit(e)->setText(qtf_qstring(s, len)); }

QTF_API char *qtf_qlineedit_text(void *e, int *len) { return qtf_to_c(lineedit(e)->text(), len); }

QTF_API void qtf_qlineedit_setPlaceholderText(void *e, const char *s, int len) {
    lineedit(e)->setPlaceholderText(qtf_qstring(s, len));
}

QTF_API char *qtf_qlineedit_placeholderText(void *e, int *len) {
    return qtf_to_c(lineedit(e)->placeholderText(), len);
}

QTF_API void qtf_qlineedit_setReadOnly(void *e, int b) { lineedit(e)->setReadOnly(b != 0); }

QTF_API int qtf_qlineedit_isReadOnly(void *e) { return qtf_bool(lineedit(e)->isReadOnly()); }

QTF_API void qtf_qlineedit_setMaxLength(void *e, int n) { lineedit(e)->setMaxLength(n); }

QTF_API int qtf_qlineedit_maxLength(void *e) { return lineedit(e)->maxLength(); }

QTF_API void qtf_qlineedit_clear(void *e) { lineedit(e)->clear(); }

// ---------------------------------------------------------------------------
// QSpinBox, QDoubleSpinBox

static QSpinBox *spin(void *p) { return as<QSpinBox>(p); }
static QDoubleSpinBox *dspin(void *p) { return as<QDoubleSpinBox>(p); }

QTF_API void *qtf_qspinbox_new(void *parent) { return new QSpinBox(widget(parent)); }

QTF_API void qtf_qspinbox_setRange(void *s, int lo, int hi) { spin(s)->setRange(lo, hi); }

QTF_API int qtf_qspinbox_minimum(void *s) { return spin(s)->minimum(); }

QTF_API int qtf_qspinbox_maximum(void *s) { return spin(s)->maximum(); }

QTF_API void qtf_qspinbox_setValue(void *s, int v) { spin(s)->setValue(v); }

QTF_API int qtf_qspinbox_value(void *s) { return spin(s)->value(); }

QTF_API void qtf_qspinbox_setSingleStep(void *s, int v) { spin(s)->setSingleStep(v); }

QTF_API int qtf_qspinbox_singleStep(void *s) { return spin(s)->singleStep(); }

QTF_API void qtf_qspinbox_setPrefix(void *s, const char *p, int len) { spin(s)->setPrefix(qtf_qstring(p, len)); }

QTF_API void qtf_qspinbox_setSuffix(void *s, const char *p, int len) { spin(s)->setSuffix(qtf_qstring(p, len)); }

QTF_API void *qtf_qdoublespinbox_new(void *parent) { return new QDoubleSpinBox(widget(parent)); }

QTF_API void qtf_qdoublespinbox_setRange(void *s, double lo, double hi) { dspin(s)->setRange(lo, hi); }

QTF_API double qtf_qdoublespinbox_minimum(void *s) { return dspin(s)->minimum(); }

QTF_API double qtf_qdoublespinbox_maximum(void *s) { return dspin(s)->maximum(); }

QTF_API void qtf_qdoublespinbox_setValue(void *s, double v) { dspin(s)->setValue(v); }

QTF_API double qtf_qdoublespinbox_value(void *s) { return dspin(s)->value(); }

QTF_API void qtf_qdoublespinbox_setSingleStep(void *s, double v) { dspin(s)->setSingleStep(v); }

QTF_API double qtf_qdoublespinbox_singleStep(void *s) { return dspin(s)->singleStep(); }

QTF_API void qtf_qdoublespinbox_setDecimals(void *s, int n) { dspin(s)->setDecimals(n); }

QTF_API int qtf_qdoublespinbox_decimals(void *s) { return dspin(s)->decimals(); }

QTF_API void qtf_qdoublespinbox_setPrefix(void *s, const char *p, int len) {
    dspin(s)->setPrefix(qtf_qstring(p, len));
}

QTF_API void qtf_qdoublespinbox_setSuffix(void *s, const char *p, int len) {
    dspin(s)->setSuffix(qtf_qstring(p, len));
}

// ---------------------------------------------------------------------------
// QAbstractSlider, QSlider

static QAbstractSlider *slider(void *p) { return as<QAbstractSlider>(p); }

QTF_API void *qtf_qslider_new(int orientation, void *parent) {
    return new QSlider(Qt::Orientation(orientation), widget(parent));
}

QTF_API void qtf_qabstractslider_setRange(void *s, int lo, int hi) { slider(s)->setRange(lo, hi); }

QTF_API int qtf_qabstractslider_minimum(void *s) { return slider(s)->minimum(); }

QTF_API int qtf_qabstractslider_maximum(void *s) { return slider(s)->maximum(); }

QTF_API void qtf_qabstractslider_setValue(void *s, int v) { slider(s)->setValue(v); }

QTF_API int qtf_qabstractslider_value(void *s) { return slider(s)->value(); }

QTF_API void qtf_qabstractslider_setSingleStep(void *s, int v) { slider(s)->setSingleStep(v); }

QTF_API void qtf_qabstractslider_setPageStep(void *s, int v) { slider(s)->setPageStep(v); }

QTF_API void qtf_qabstractslider_setOrientation(void *s, int o) { slider(s)->setOrientation(Qt::Orientation(o)); }

QTF_API int qtf_qabstractslider_orientation(void *s) { return int(slider(s)->orientation()); }

// ---------------------------------------------------------------------------
// QComboBox

static QComboBox *combo(void *p) { return as<QComboBox>(p); }

QTF_API void *qtf_qcombobox_new(void *parent) { return new QComboBox(widget(parent)); }

QTF_API void qtf_qcombobox_addItem(void *c, const char *s, int len) { combo(c)->addItem(qtf_qstring(s, len)); }

QTF_API void qtf_qcombobox_insertItem(void *c, int index, const char *s, int len) {
    combo(c)->insertItem(index, qtf_qstring(s, len));
}

QTF_API void qtf_qcombobox_removeItem(void *c, int index) { combo(c)->removeItem(index); }

QTF_API void qtf_qcombobox_clear(void *c) { combo(c)->clear(); }

QTF_API int qtf_qcombobox_count(void *c) { return combo(c)->count(); }

QTF_API int qtf_qcombobox_currentIndex(void *c) { return combo(c)->currentIndex(); }

QTF_API void qtf_qcombobox_setCurrentIndex(void *c, int index) { combo(c)->setCurrentIndex(index); }

QTF_API char *qtf_qcombobox_currentText(void *c, int *len) { return qtf_to_c(combo(c)->currentText(), len); }

QTF_API void qtf_qcombobox_setCurrentText(void *c, const char *s, int len) {
    combo(c)->setCurrentText(qtf_qstring(s, len));
}

QTF_API char *qtf_qcombobox_itemText(void *c, int index, int *len) {
    return qtf_to_c(combo(c)->itemText(index), len);
}

QTF_API int qtf_qcombobox_findText(void *c, const char *s, int len) {
    return combo(c)->findText(qtf_qstring(s, len));
}

QTF_API void qtf_qcombobox_setEditable(void *c, int b) { combo(c)->setEditable(b != 0); }

// ---------------------------------------------------------------------------
// QLayout, QBoxLayout, QGridLayout

static QLayout *layout(void *p) { return as<QLayout>(p); }
static QBoxLayout *box(void *p) { return as<QBoxLayout>(p); }
static QGridLayout *grid(void *p) { return as<QGridLayout>(p); }

QTF_API void qtf_qlayout_setContentsMargins(void *l, int left, int top, int right, int bottom) {
    layout(l)->setContentsMargins(left, top, right, bottom);
}

QTF_API void qtf_qlayout_setSpacing(void *l, int s) { layout(l)->setSpacing(s); }

QTF_API int qtf_qlayout_spacing(void *l) { return layout(l)->spacing(); }

QTF_API int qtf_qlayout_count(void *l) { return layout(l)->count(); }

QTF_API void *qtf_qvboxlayout_new(void *parent) { return new QVBoxLayout(widget(parent)); }

QTF_API void *qtf_qhboxlayout_new(void *parent) { return new QHBoxLayout(widget(parent)); }

QTF_API void qtf_qboxlayout_addWidget(void *l, void *w, int stretch, int alignment) {
    box(l)->addWidget(widget(w), stretch, Qt::Alignment(alignment));
}

QTF_API void qtf_qboxlayout_addLayout(void *l, void *child, int stretch) { box(l)->addLayout(layout(child), stretch); }

QTF_API void qtf_qboxlayout_addStretch(void *l, int stretch) { box(l)->addStretch(stretch); }

QTF_API void qtf_qboxlayout_addSpacing(void *l, int size) { box(l)->addSpacing(size); }

QTF_API void *qtf_qgridlayout_new(void *parent) { return new QGridLayout(widget(parent)); }

QTF_API void qtf_qgridlayout_addWidget(void *l, void *w, int row, int col, int rowSpan, int colSpan, int alignment) {
    grid(l)->addWidget(widget(w), row, col, rowSpan, colSpan, Qt::Alignment(alignment));
}

QTF_API void qtf_qgridlayout_addLayout(void *l, void *child, int row, int col, int rowSpan, int colSpan,
                                       int alignment) {
    grid(l)->addLayout(layout(child), row, col, rowSpan, colSpan, Qt::Alignment(alignment));
}

QTF_API void qtf_qgridlayout_setRowStretch(void *l, int row, int stretch) { grid(l)->setRowStretch(row, stretch); }

QTF_API void qtf_qgridlayout_setColumnStretch(void *l, int col, int stretch) {
    grid(l)->setColumnStretch(col, stretch);
}

QTF_API int qtf_qgridlayout_rowCount(void *l) { return grid(l)->rowCount(); }

QTF_API int qtf_qgridlayout_columnCount(void *l) { return grid(l)->columnCount(); }

// ---------------------------------------------------------------------------
// QMainWindow, QStatusBar

QTF_API void *qtf_qmainwindow_new(void *parent) { return new QMainWindow(widget(parent)); }

QTF_API void qtf_qmainwindow_setCentralWidget(void *m, void *w) {
    as<QMainWindow>(m)->setCentralWidget(widget(w));
}

QTF_API void *qtf_qmainwindow_centralWidget(void *m) { return as<QMainWindow>(m)->centralWidget(); }

QTF_API void *qtf_qmainwindow_statusBar(void *m) { return as<QMainWindow>(m)->statusBar(); }

QTF_API void *qtf_qmainwindow_menuBar(void *m) { return as<QMainWindow>(m)->menuBar(); }

QTF_API void *qtf_qmainwindow_addToolBar(void *m, const char *s, int len) {
    return as<QMainWindow>(m)->addToolBar(qtf_qstring(s, len));
}

// ---------------------------------------------------------------------------
// QMenuBar, QMenu, QToolBar

QTF_API void *qtf_qmenubar_addMenu(void *b, const char *s, int len) {
    return as<QMenuBar>(b)->addMenu(qtf_qstring(s, len));
}

QTF_API void *qtf_qmenu_new(const char *s, int len, void *parent) {
    return new QMenu(qtf_qstring(s, len), widget(parent));
}

QTF_API void *qtf_qmenu_addMenu(void *m, const char *s, int len) { return as<QMenu>(m)->addMenu(qtf_qstring(s, len)); }

QTF_API void *qtf_qmenu_addSeparator(void *m) { return as<QMenu>(m)->addSeparator(); }

QTF_API char *qtf_qmenu_title(void *m, int *len) { return qtf_to_c(as<QMenu>(m)->title(), len); }

QTF_API void *qtf_qmenu_menuAction(void *m) { return as<QMenu>(m)->menuAction(); }

QTF_API void *qtf_qtoolbar_addSeparator(void *t) { return as<QToolBar>(t)->addSeparator(); }

QTF_API void *qtf_qtoolbar_addWidget(void *t, void *w) { return as<QToolBar>(t)->addWidget(widget(w)); }

QTF_API void qtf_qstatusbar_showMessage(void *b, const char *s, int len, int timeout) {
    as<QStatusBar>(b)->showMessage(qtf_qstring(s, len), timeout);
}

QTF_API void qtf_qstatusbar_clearMessage(void *b) { as<QStatusBar>(b)->clearMessage(); }

QTF_API char *qtf_qstatusbar_currentMessage(void *b, int *len) {
    return qtf_to_c(as<QStatusBar>(b)->currentMessage(), len);
}

// ---------------------------------------------------------------------------
// QDialog, QMessageBox

static QDialog *dialog(void *p) { return as<QDialog>(p); }
static QMessageBox *msgbox(void *p) { return as<QMessageBox>(p); }

QTF_API void *qtf_qdialog_new(void *parent) { return new QDialog(widget(parent)); }

QTF_API int qtf_qdialog_exec(void *d) { return dialog(d)->exec(); }

QTF_API void qtf_qdialog_open(void *d) { dialog(d)->open(); }

QTF_API void qtf_qdialog_accept(void *d) { dialog(d)->accept(); }

QTF_API void qtf_qdialog_reject(void *d) { dialog(d)->reject(); }

QTF_API void qtf_qdialog_done(void *d, int r) { dialog(d)->done(r); }

QTF_API int qtf_qdialog_result(void *d) { return dialog(d)->result(); }

QTF_API void qtf_qdialog_setModal(void *d, int b) { dialog(d)->setModal(b != 0); }

QTF_API void *qtf_qmessagebox_new(void *parent) { return new QMessageBox(widget(parent)); }

QTF_API void qtf_qmessagebox_setText(void *m, const char *s, int len) { msgbox(m)->setText(qtf_qstring(s, len)); }

QTF_API char *qtf_qmessagebox_text(void *m, int *len) { return qtf_to_c(msgbox(m)->text(), len); }

QTF_API void qtf_qmessagebox_setInformativeText(void *m, const char *s, int len) {
    msgbox(m)->setInformativeText(qtf_qstring(s, len));
}

QTF_API char *qtf_qmessagebox_informativeText(void *m, int *len) {
    return qtf_to_c(msgbox(m)->informativeText(), len);
}

QTF_API void qtf_qmessagebox_setIcon(void *m, int icon) { msgbox(m)->setIcon(QMessageBox::Icon(icon)); }

QTF_API void qtf_qmessagebox_setStandardButtons(void *m, int buttons) {
    msgbox(m)->setStandardButtons(QMessageBox::StandardButtons(buttons));
}

QTF_API void qtf_qmessagebox_setDefaultButton(void *m, int which) {
    msgbox(m)->setDefaultButton(QMessageBox::StandardButton(which));
}

QTF_API void *qtf_qmessagebox_button(void *m, int which) {
    return msgbox(m)->button(QMessageBox::StandardButton(which));
}

// static convenience dialogs; `which`: 1 information, 2 warning, 3 critical, 4 question
QTF_API int qtf_qmessagebox_static(int which, void *parent, const char *title, int tlen, const char *text,
                                   int len, int buttons, int defaultButton) {
    const QString t = qtf_qstring(title, tlen), s = qtf_qstring(text, len);
    const auto b = QMessageBox::StandardButtons(buttons);
    const auto d = QMessageBox::StandardButton(defaultButton);
    switch (which) {
    case 1: return QMessageBox::information(widget(parent), t, s, b, d);
    case 2: return QMessageBox::warning(widget(parent), t, s, b, d);
    case 3: return QMessageBox::critical(widget(parent), t, s, b, d);
    case 4: return QMessageBox::question(widget(parent), t, s, b, d);
    }
    return QMessageBox::NoButton;
}

// ---------------------------------------------------------------------------
// QFileDialog

static QFileDialog *filedialog(void *p) { return as<QFileDialog>(p); }

// String lists are returned as one malloc'd buffer of NUL-terminated strings.
static char *qtf_list_to_c(const QStringList &list, int *len) {
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

QTF_API void *qtf_qfiledialog_new(void *parent, const char *caption, int clen, const char *dir, int dlen,
                                  const char *filter, int flen) {
    return new QFileDialog(widget(parent), qtf_qstring(caption, clen), qtf_qstring(dir, dlen),
                           qtf_qstring(filter, flen));
}

QTF_API void qtf_qfiledialog_setFileMode(void *d, int mode) { filedialog(d)->setFileMode(QFileDialog::FileMode(mode)); }

QTF_API void qtf_qfiledialog_setAcceptMode(void *d, int mode) {
    filedialog(d)->setAcceptMode(QFileDialog::AcceptMode(mode));
}

QTF_API void qtf_qfiledialog_setOption(void *d, int option, int on) {
    filedialog(d)->setOption(QFileDialog::Option(option), on != 0);
}

QTF_API void qtf_qfiledialog_setNameFilter(void *d, const char *s, int len) {
    filedialog(d)->setNameFilter(qtf_qstring(s, len));
}

QTF_API void qtf_qfiledialog_setDirectory(void *d, const char *s, int len) {
    filedialog(d)->setDirectory(qtf_qstring(s, len));
}

QTF_API void qtf_qfiledialog_setDefaultSuffix(void *d, const char *s, int len) {
    filedialog(d)->setDefaultSuffix(qtf_qstring(s, len));
}

QTF_API void qtf_qfiledialog_selectFile(void *d, const char *s, int len) {
    filedialog(d)->selectFile(qtf_qstring(s, len));
}

QTF_API char *qtf_qfiledialog_selectedFiles(void *d, int *len) {
    return qtf_list_to_c(filedialog(d)->selectedFiles(), len);
}

// static dialogs; `which`: 1 getOpenFileName, 2 getSaveFileName, 3 getExistingDirectory
QTF_API char *qtf_qfiledialog_static(int which, void *parent, const char *caption, int clen, const char *dir,
                                     int dlen, const char *filter, int flen, int options, int *len) {
    const QString c = qtf_qstring(caption, clen), d = qtf_qstring(dir, dlen), f = qtf_qstring(filter, flen);
    const auto o = QFileDialog::Options(options);
    QString result;
    switch (which) {
    case 1: result = QFileDialog::getOpenFileName(widget(parent), c, d, f, nullptr, o); break;
    case 2: result = QFileDialog::getSaveFileName(widget(parent), c, d, f, nullptr, o); break;
    case 3: result = QFileDialog::getExistingDirectory(widget(parent), c, d, o); break;
    }
    return qtf_to_c(result, len);
}

QTF_API char *qtf_qfiledialog_getOpenFileNames(void *parent, const char *caption, int clen, const char *dir,
                                               int dlen, const char *filter, int flen, int options, int *len) {
    return qtf_list_to_c(QFileDialog::getOpenFileNames(widget(parent), qtf_qstring(caption, clen),
                                                       qtf_qstring(dir, dlen), qtf_qstring(filter, flen), nullptr,
                                                       QFileDialog::Options(options)),
                         len);
}

// ---------------------------------------------------------------------------
// signal connectors

template <typename T, typename Signal> static bool connect_void(void *s, Signal sig, const qtf_slot &ref) {
    return bool(QObject::connect(as<T>(s), sig, as<T>(s), [ref]() { qtf_emit(ref); }));
}

template <typename T, typename Signal> static bool connect_bool(void *s, Signal sig, const qtf_slot &ref) {
    return bool(QObject::connect(as<T>(s), sig, as<T>(s), [ref](bool b) { qtf_emit_bool(ref, b); }));
}

template <typename T, typename Signal> static bool connect_int(void *s, Signal sig, const qtf_slot &ref) {
    return bool(QObject::connect(as<T>(s), sig, as<T>(s), [ref](int i) { qtf_emit_int(ref, i); }));
}

template <typename T, typename Signal> static bool connect_double(void *s, Signal sig, const qtf_slot &ref) {
    return bool(QObject::connect(as<T>(s), sig, as<T>(s), [ref](double d) { qtf_emit_double(ref, d); }));
}

template <typename T, typename Signal> static bool connect_string(void *s, Signal sig, const qtf_slot &ref) {
    return bool(QObject::connect(as<T>(s), sig, as<T>(s), [ref](const QString &v) { qtf_emit(ref, v); }));
}

static const bool qtf_widgets_registered = [] {
    using B = QAbstractButton;
    using L = QLineEdit;
    using S = QAbstractSlider;
    using C = QComboBox;
    using D = QDialog;
    // clicked(bool) is exposed without its argument; use toggled for the state
    qtf_register_connector(QTF_SIG_QABSTRACTBUTTON_CLICKED,
                           [](void *s, const qtf_slot &r) { return connect_void<B>(s, &B::clicked, r); });
    qtf_register_connector(QTF_SIG_QABSTRACTBUTTON_TOGGLED,
                           [](void *s, const qtf_slot &r) { return connect_bool<B>(s, &B::toggled, r); });
    qtf_register_connector(QTF_SIG_QABSTRACTBUTTON_PRESSED,
                           [](void *s, const qtf_slot &r) { return connect_void<B>(s, &B::pressed, r); });
    qtf_register_connector(QTF_SIG_QABSTRACTBUTTON_RELEASED,
                           [](void *s, const qtf_slot &r) { return connect_void<B>(s, &B::released, r); });
    qtf_register_connector(QTF_SIG_QLINEEDIT_TEXTCHANGED,
                           [](void *s, const qtf_slot &r) { return connect_string<L>(s, &L::textChanged, r); });
    qtf_register_connector(QTF_SIG_QLINEEDIT_TEXTEDITED,
                           [](void *s, const qtf_slot &r) { return connect_string<L>(s, &L::textEdited, r); });
    qtf_register_connector(QTF_SIG_QLINEEDIT_RETURNPRESSED,
                           [](void *s, const qtf_slot &r) { return connect_void<L>(s, &L::returnPressed, r); });
    qtf_register_connector(QTF_SIG_QLINEEDIT_EDITINGFINISHED,
                           [](void *s, const qtf_slot &r) { return connect_void<L>(s, &L::editingFinished, r); });
    qtf_register_connector(QTF_SIG_QSPINBOX_VALUECHANGED, [](void *s, const qtf_slot &r) {
        return connect_int<QSpinBox>(s, &QSpinBox::valueChanged, r);
    });
    qtf_register_connector(QTF_SIG_QDOUBLESPINBOX_VALUECHANGED, [](void *s, const qtf_slot &r) {
        return connect_double<QDoubleSpinBox>(s, &QDoubleSpinBox::valueChanged, r);
    });
    qtf_register_connector(QTF_SIG_QABSTRACTSLIDER_VALUECHANGED,
                           [](void *s, const qtf_slot &r) { return connect_int<S>(s, &S::valueChanged, r); });
    qtf_register_connector(QTF_SIG_QABSTRACTSLIDER_SLIDERMOVED,
                           [](void *s, const qtf_slot &r) { return connect_int<S>(s, &S::sliderMoved, r); });
    qtf_register_connector(QTF_SIG_QABSTRACTSLIDER_SLIDERPRESSED,
                           [](void *s, const qtf_slot &r) { return connect_void<S>(s, &S::sliderPressed, r); });
    qtf_register_connector(QTF_SIG_QABSTRACTSLIDER_SLIDERRELEASED,
                           [](void *s, const qtf_slot &r) { return connect_void<S>(s, &S::sliderReleased, r); });
    qtf_register_connector(QTF_SIG_QCOMBOBOX_CURRENTINDEXCHANGED,
                           [](void *s, const qtf_slot &r) { return connect_int<C>(s, &C::currentIndexChanged, r); });
    qtf_register_connector(QTF_SIG_QCOMBOBOX_CURRENTTEXTCHANGED,
                           [](void *s, const qtf_slot &r) { return connect_string<C>(s, &C::currentTextChanged, r); });
    qtf_register_connector(QTF_SIG_QCOMBOBOX_ACTIVATED,
                           [](void *s, const qtf_slot &r) { return connect_int<C>(s, &C::activated, r); });
    qtf_register_connector(QTF_SIG_QDIALOG_ACCEPTED,
                           [](void *s, const qtf_slot &r) { return connect_void<D>(s, &D::accepted, r); });
    qtf_register_connector(QTF_SIG_QDIALOG_REJECTED,
                           [](void *s, const qtf_slot &r) { return connect_void<D>(s, &D::rejected, r); });
    qtf_register_connector(QTF_SIG_QDIALOG_FINISHED,
                           [](void *s, const qtf_slot &r) { return connect_int<D>(s, &D::finished, r); });
    qtf_register_connector(QTF_SIG_QTFWIDGET_PAINT, connect_event<QTF_EV_PAINT>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_MOUSEPRESS, connect_event<QTF_EV_MOUSEPRESS>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_MOUSERELEASE, connect_event<QTF_EV_MOUSERELEASE>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_MOUSEMOVE, connect_event<QTF_EV_MOUSEMOVE>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_MOUSEDOUBLECLICK, connect_event<QTF_EV_MOUSEDOUBLECLICK>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_WHEEL, connect_event<QTF_EV_WHEEL>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_KEYPRESS, connect_event<QTF_EV_KEYPRESS>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_KEYRELEASE, connect_event<QTF_EV_KEYRELEASE>);
    qtf_register_connector(QTF_SIG_QTFWIDGET_RESIZE, connect_event<QTF_EV_RESIZE>);
    return true;
}();
