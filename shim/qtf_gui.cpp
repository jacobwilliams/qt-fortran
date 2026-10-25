// C ABI shim over Qt Gui: colors, painting, images, input events, actions.
// QColor/QPen/QBrush/QFont are Fortran value types; their fields are passed
// as scalars.

#include "qtf_common.h"

#include <QAction>
#include <QFontMetrics>
#include <QImage>
#include <QKeyEvent>
#include <QKeySequence>
#include <QMouseEvent>
#include <QPainter>
#include <QPixmap>
#include <QPolygonF>
#include <QResizeEvent>
#include <QWheelEvent>

template <typename T> static T *as(void *p) { return static_cast<T *>(p); }

static QColor rgba(int r, int g, int b, int a) { return QColor(r, g, b, a); }

// ---------------------------------------------------------------------------
// QColor

// Parse a color name ("red", "#ff8000", ...); returns 0 if invalid.
QTF_API int qtf_qcolor_fromString(const char *s, int len, int *r, int *g, int *b, int *a) {
    const QColor c = QColor::fromString(qtf_qstring(s, len));
    c.getRgb(r, g, b, a);
    return qtf_bool(c.isValid());
}

// ---------------------------------------------------------------------------
// QPainter

static QPainter *painter(void *p) { return as<QPainter>(p); }

QTF_API void *qtf_qpainter_new_image(void *image) { return new QPainter(as<QImage>(image)); }

// End and delete a painter created by qtf_qpainter_new_*.
QTF_API void qtf_qpainter_delete(void *p) {
    painter(p)->end();
    delete painter(p);
}

QTF_API int qtf_qpainter_isActive(void *p) { return qtf_bool(painter(p)->isActive()); }

QTF_API int qtf_qpainter_deviceWidth(void *p) { return painter(p)->device()->width(); }

QTF_API int qtf_qpainter_deviceHeight(void *p) { return painter(p)->device()->height(); }

QTF_API void qtf_qpainter_setPen(void *p, int r, int g, int b, int a, double width, int style) {
    QPen pen(rgba(r, g, b, a));
    pen.setWidthF(width);
    pen.setStyle(Qt::PenStyle(style));
    painter(p)->setPen(pen);
}

QTF_API void qtf_qpainter_setBrush(void *p, int r, int g, int b, int a, int style) {
    painter(p)->setBrush(QBrush(rgba(r, g, b, a), Qt::BrushStyle(style)));
}

// pointSize <= 0 and an empty family keep the current values
QTF_API void qtf_qpainter_setFont(void *p, const char *family, int len, double pointSize, int bold, int italic) {
    QFont f = painter(p)->font();
    if (len > 0) f.setFamily(qtf_qstring(family, len));
    if (pointSize > 0) f.setPointSizeF(pointSize);
    f.setBold(bold != 0);
    f.setItalic(italic != 0);
    painter(p)->setFont(f);
}

QTF_API void qtf_qpainter_setRenderHint(void *p, int hint, int on) {
    painter(p)->setRenderHint(QPainter::RenderHint(hint), on != 0);
}

QTF_API void qtf_qpainter_setOpacity(void *p, double opacity) { painter(p)->setOpacity(opacity); }

QTF_API void qtf_qpainter_save(void *p) { painter(p)->save(); }

QTF_API void qtf_qpainter_restore(void *p) { painter(p)->restore(); }

QTF_API void qtf_qpainter_translate(void *p, double dx, double dy) { painter(p)->translate(dx, dy); }

QTF_API void qtf_qpainter_scale(void *p, double sx, double sy) { painter(p)->scale(sx, sy); }

QTF_API void qtf_qpainter_rotate(void *p, double degrees) { painter(p)->rotate(degrees); }

QTF_API void qtf_qpainter_resetTransform(void *p) { painter(p)->resetTransform(); }

QTF_API void qtf_qpainter_drawPoint(void *p, double x, double y) { painter(p)->drawPoint(QPointF(x, y)); }

QTF_API void qtf_qpainter_drawLine(void *p, double x1, double y1, double x2, double y2) {
    painter(p)->drawLine(QPointF(x1, y1), QPointF(x2, y2));
}

QTF_API void qtf_qpainter_drawRect(void *p, double x, double y, double w, double h) {
    painter(p)->drawRect(QRectF(x, y, w, h));
}

QTF_API void qtf_qpainter_drawRoundedRect(void *p, double x, double y, double w, double h, double rx, double ry) {
    painter(p)->drawRoundedRect(QRectF(x, y, w, h), rx, ry);
}

QTF_API void qtf_qpainter_drawEllipse(void *p, double x, double y, double w, double h) {
    painter(p)->drawEllipse(QRectF(x, y, w, h));
}

QTF_API void qtf_qpainter_fillRect(void *p, double x, double y, double w, double h, int r, int g, int b, int a) {
    painter(p)->fillRect(QRectF(x, y, w, h), rgba(r, g, b, a));
}

static QPolygonF polygon(const double *xs, const double *ys, int n) {
    QPolygonF poly;
    poly.reserve(n);
    for (int i = 0; i < n; ++i) poly << QPointF(xs[i], ys[i]);
    return poly;
}

QTF_API void qtf_qpainter_drawPolyline(void *p, const double *xs, const double *ys, int n) {
    painter(p)->drawPolyline(polygon(xs, ys, n));
}

QTF_API void qtf_qpainter_drawPolygon(void *p, const double *xs, const double *ys, int n) {
    painter(p)->drawPolygon(polygon(xs, ys, n));
}

QTF_API void qtf_qpainter_drawText(void *p, double x, double y, const char *s, int len) {
    painter(p)->drawText(QPointF(x, y), qtf_qstring(s, len));
}

QTF_API void qtf_qpainter_drawTextRect(void *p, double x, double y, double w, double h, int flags, const char *s,
                                       int len) {
    painter(p)->drawText(QRectF(x, y, w, h), flags, qtf_qstring(s, len));
}

QTF_API void qtf_qpainter_drawImage(void *p, double x, double y, void *image) {
    painter(p)->drawImage(QPointF(x, y), *as<QImage>(image));
}

QTF_API int qtf_qpainter_textWidth(void *p, const char *s, int len) {
    return painter(p)->fontMetrics().horizontalAdvance(qtf_qstring(s, len));
}

QTF_API int qtf_qpainter_fontHeight(void *p) { return painter(p)->fontMetrics().height(); }

// ---------------------------------------------------------------------------
// QImage, QPixmap

static QImage *image(void *p) { return as<QImage>(p); }

QTF_API void *qtf_qimage_new(int width, int height) {
    return new QImage(width, height, QImage::Format_ARGB32_Premultiplied);
}

QTF_API void *qtf_qimage_fromFile(const char *s, int len) { return new QImage(qtf_qstring(s, len)); }

QTF_API void qtf_qimage_delete(void *i) { delete image(i); }

QTF_API int qtf_qimage_isNull(void *i) { return qtf_bool(image(i)->isNull()); }

QTF_API int qtf_qimage_width(void *i) { return image(i)->width(); }

QTF_API int qtf_qimage_height(void *i) { return image(i)->height(); }

QTF_API void qtf_qimage_fill(void *i, int r, int g, int b, int a) { image(i)->fill(rgba(r, g, b, a)); }

QTF_API void qtf_qimage_pixelColor(void *i, int x, int y, int *r, int *g, int *b, int *a) {
    image(i)->pixelColor(x, y).getRgb(r, g, b, a);
}

QTF_API void qtf_qimage_setPixelColor(void *i, int x, int y, int r, int g, int b, int a) {
    image(i)->setPixelColor(x, y, rgba(r, g, b, a));
}

QTF_API int qtf_qimage_save(void *i, const char *s, int len) { return qtf_bool(image(i)->save(qtf_qstring(s, len))); }

static QPixmap *pixmap(void *p) { return as<QPixmap>(p); }

QTF_API void qtf_qpixmap_delete(void *p) { delete pixmap(p); }

QTF_API int qtf_qpixmap_isNull(void *p) { return qtf_bool(pixmap(p)->isNull()); }

QTF_API int qtf_qpixmap_width(void *p) { return pixmap(p)->width(); }

QTF_API int qtf_qpixmap_height(void *p) { return pixmap(p)->height(); }

QTF_API void *qtf_qpixmap_toImage(void *p) { return new QImage(pixmap(p)->toImage()); }

QTF_API int qtf_qpixmap_save(void *p, const char *s, int len) {
    return qtf_bool(pixmap(p)->save(qtf_qstring(s, len)));
}

// ---------------------------------------------------------------------------
// input events (construction is for sending synthetic events, e.g. in tests)

static QMouseEvent *mouse(void *p) { return as<QMouseEvent>(p); }
static QKeyEvent *key(void *p) { return as<QKeyEvent>(p); }
static QWheelEvent *wheel(void *p) { return as<QWheelEvent>(p); }
static QResizeEvent *resize(void *p) { return as<QResizeEvent>(p); }

QTF_API void *qtf_qmouseevent_new(int type, double x, double y, int button, int buttons, int modifiers) {
    const QPointF pos(x, y);
    return new QMouseEvent(QEvent::Type(type), pos, pos, Qt::MouseButton(button), Qt::MouseButtons(buttons),
                           Qt::KeyboardModifiers(modifiers));
}

QTF_API double qtf_qmouseevent_x(void *e) { return mouse(e)->position().x(); }

QTF_API double qtf_qmouseevent_y(void *e) { return mouse(e)->position().y(); }

QTF_API int qtf_qmouseevent_button(void *e) { return int(mouse(e)->button()); }

QTF_API int qtf_qmouseevent_buttons(void *e) { return int(mouse(e)->buttons()); }

QTF_API int qtf_qmouseevent_modifiers(void *e) { return int(mouse(e)->modifiers()); }

QTF_API void *qtf_qkeyevent_new(int type, int k, int modifiers, const char *s, int len) {
    return new QKeyEvent(QEvent::Type(type), k, Qt::KeyboardModifiers(modifiers), qtf_qstring(s, len));
}

QTF_API int qtf_qkeyevent_key(void *e) { return key(e)->key(); }

QTF_API int qtf_qkeyevent_modifiers(void *e) { return int(key(e)->modifiers()); }

QTF_API char *qtf_qkeyevent_text(void *e, int *len) { return qtf_to_c(key(e)->text(), len); }

QTF_API int qtf_qkeyevent_isAutoRepeat(void *e) { return qtf_bool(key(e)->isAutoRepeat()); }

QTF_API void *qtf_qwheelevent_new(double x, double y, int angleDeltaX, int angleDeltaY, int buttons, int modifiers) {
    const QPointF pos(x, y);
    return new QWheelEvent(pos, pos, QPoint(), QPoint(angleDeltaX, angleDeltaY), Qt::MouseButtons(buttons),
                           Qt::KeyboardModifiers(modifiers), Qt::NoScrollPhase, false);
}

QTF_API double qtf_qwheelevent_x(void *e) { return wheel(e)->position().x(); }

QTF_API double qtf_qwheelevent_y(void *e) { return wheel(e)->position().y(); }

QTF_API int qtf_qwheelevent_angleDeltaX(void *e) { return wheel(e)->angleDelta().x(); }

QTF_API int qtf_qwheelevent_angleDeltaY(void *e) { return wheel(e)->angleDelta().y(); }

QTF_API int qtf_qwheelevent_buttons(void *e) { return int(wheel(e)->buttons()); }

QTF_API int qtf_qwheelevent_modifiers(void *e) { return int(wheel(e)->modifiers()); }

QTF_API void *qtf_qresizeevent_new(int width, int height, int oldWidth, int oldHeight) {
    return new QResizeEvent(QSize(width, height), QSize(oldWidth, oldHeight));
}

QTF_API int qtf_qresizeevent_width(void *e) { return resize(e)->size().width(); }

QTF_API int qtf_qresizeevent_height(void *e) { return resize(e)->size().height(); }

QTF_API int qtf_qresizeevent_oldWidth(void *e) { return resize(e)->oldSize().width(); }

QTF_API int qtf_qresizeevent_oldHeight(void *e) { return resize(e)->oldSize().height(); }

// ---------------------------------------------------------------------------
// QAction

static QAction *action(void *p) { return as<QAction>(p); }

QTF_API void *qtf_qaction_new(const char *s, int len, void *parent) {
    return new QAction(qtf_qstring(s, len), as<QObject>(parent));
}

QTF_API void qtf_qaction_setText(void *a, const char *s, int len) { action(a)->setText(qtf_qstring(s, len)); }

QTF_API char *qtf_qaction_text(void *a, int *len) { return qtf_to_c(action(a)->text(), len); }

QTF_API void qtf_qaction_setShortcut(void *a, const char *s, int len) {
    action(a)->setShortcut(QKeySequence(qtf_qstring(s, len)));
}

QTF_API char *qtf_qaction_shortcut(void *a, int *len) {
    return qtf_to_c(action(a)->shortcut().toString(QKeySequence::PortableText), len);
}

QTF_API void qtf_qaction_setCheckable(void *a, int b) { action(a)->setCheckable(b != 0); }

QTF_API int qtf_qaction_isCheckable(void *a) { return qtf_bool(action(a)->isCheckable()); }

QTF_API void qtf_qaction_setChecked(void *a, int b) { action(a)->setChecked(b != 0); }

QTF_API int qtf_qaction_isChecked(void *a) { return qtf_bool(action(a)->isChecked()); }

QTF_API void qtf_qaction_setEnabled(void *a, int b) { action(a)->setEnabled(b != 0); }

QTF_API int qtf_qaction_isEnabled(void *a) { return qtf_bool(action(a)->isEnabled()); }

QTF_API void qtf_qaction_setStatusTip(void *a, const char *s, int len) {
    action(a)->setStatusTip(qtf_qstring(s, len));
}

QTF_API void qtf_qaction_setToolTip(void *a, const char *s, int len) { action(a)->setToolTip(qtf_qstring(s, len)); }

QTF_API void qtf_qaction_trigger(void *a) { action(a)->trigger(); }

// ---------------------------------------------------------------------------
// signal connectors

static const bool qtf_gui_registered = [] {
    // triggered(bool) is exposed without its argument; use toggled for the state
    qtf_register_connector(QTF_SIG_QACTION_TRIGGERED, [](void *s, const qtf_slot &ref) {
        return bool(QObject::connect(action(s), &QAction::triggered, action(s), [ref]() { qtf_emit(ref); }));
    });
    qtf_register_connector(QTF_SIG_QACTION_TOGGLED, [](void *s, const qtf_slot &ref) {
        return bool(
            QObject::connect(action(s), &QAction::toggled, action(s), [ref](bool b) { qtf_emit_bool(ref, b); }));
    });
    return true;
}();
