import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Die letzten Nachrichten eines Chats, neueste unten. Wischen/Tasten scrollen, Tippen öffnet die Antworten.
class ChatView extends WatchUi.View {
    public var id as String;
    public var title as String;
    public var msgs as Array<Dictionary>? = null;
    private var _error as String? = null;
    // Fertig umbrochene Blöcke: [Kopfzeile, Text, eigene?, Höhe]
    private var _blocks as Array<Array>? = null;
    private var _total as Number = 0;
    private var _y as Number = 0;
    private var _h as Number = 0;
    private var _loading as Boolean = false;
    // Abstand zwischen Nachrichten und zwischen Kopfzeile und Text
    private const GAP = 30;
    private const GAP_HEAD = 4;

    public function initialize(id as String, title as String) {
        View.initialize();
        self.id = id;
        self.title = title;
    }

    public function onShow() as Void {
        if (msgs == null && !_loading) {
            reload();
        }
    }

    public function reload() as Void {
        _loading = true;
        Api.get("/api/w/chat", { "id" => id }, method(:onData));
    }

    public function onData(code as Number, data as Dictionary or String or Null) as Void {
        _loading = false;
        if (code == 401) {
            Ui.fail(code, data, null);
            return;
        }
        if (code != 200 || !(data instanceof Dictionary)) {
            _error = Ui.errorText(code, data);
            WatchUi.requestUpdate();
            return;
        }
        _error = null;
        var t = data.get("t");
        if (t instanceof String) {
            title = t;
        }
        msgs = data.get("msgs") as Array<Dictionary>;
        _blocks = null; // beim nächsten Zeichnen neu umbrechen, ans Ende springen
        WatchUi.requestUpdate();
    }

    //! Letzte Sprachnachricht ohne Transkript (für „Transkribieren“)
    public function voiceWithoutText() as String? {
        if (msgs == null) {
            return null;
        }
        var list = msgs as Array<Dictionary>;
        for (var i = list.size() - 1; i >= 0; i--) {
            var m = list[i];
            if (m.get("voice") != null && m.get("tr") == null) {
                return m.get("id") as String;
            }
        }
        return null;
    }

    public function scroll(dy as Number) as Void {
        var y = _y + dy;
        var max = maxY();
        if (y > max) {
            y = max;
        }
        if (y < 0) {
            y = 0;
        }
        if (y != _y) {
            _y = y;
            WatchUi.requestUpdate();
        }
    }

    public function page() as Number {
        return _h / 3;
    }

    private function layout(dc as Graphics.Dc) as Void {
        var w = (dc.getWidth() * 0.68).toNumber();
        var list = msgs as Array<Dictionary>;
        var blocks = [] as Array<Array>;
        var total = 0;
        var lineH = dc.getFontHeight(Graphics.FONT_SMALL);
        var headH = dc.getFontHeight(Graphics.FONT_XTINY);
        for (var i = 0; i < list.size(); i++) {
            var m = list[i];
            var from = m.get("from") as String;
            var head = Ui.when(m.get("ts") as Number);
            if (from.length() > 0) {
                head = from + " · " + head;
            }
            var text = m.get("text") as String;
            var wrapped = Graphics.fitTextToArea(text, Graphics.FONT_SMALL, w, lineH * 30, true);
            if (wrapped == null) {
                wrapped = text;
            }
            // Echte Höhe des umbrochenen Texts statt Zeilen zählen (Zeilenabstand ist größer als die Schrifthöhe)
            var textH = dc.getTextDimensions(wrapped as String, Graphics.FONT_SMALL)[1];
            var h = headH + GAP_HEAD + textH + GAP;
            blocks.add([head, wrapped, m.get("me") == true, h]);
            total += h;
        }
        _blocks = blocks;
        _total = total;
        // Unten (neueste Nachricht) anfangen
        _y = maxY();
    }

    private function maxY() as Number {
        // Letzte Nachricht endet etwas über dem unteren Rand (runder Bildschirm)
        var m = _total - (_h * 0.62).toNumber();
        return m < 0 ? 0 : m;
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        _h = dc.getHeight();
        var top = (_h * 0.2).toNumber();
        if (msgs == null || _error != null) {
            var t = _error != null ? (_error as String) + "\n" + Ui.str(Rez.Strings.TapRetry) : Ui.str(Rez.Strings.Loading);
            var f = Graphics.fitTextToArea(t, Graphics.FONT_SMALL, w * 0.75, _h * 0.6, true);
            dc.drawText(w / 2, _h / 2, Graphics.FONT_SMALL, f == null ? "" : f, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            if (_blocks == null) {
                layout(dc);
            }
            var blocks = _blocks as Array<Array>;
            if (blocks.size() == 0) {
                dc.drawText(w / 2, _h / 2, Graphics.FONT_SMALL, Ui.str(Rez.Strings.NoMessages), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            var x0 = (w * 0.16).toNumber();
            var x1 = w - x0;
            var headH = dc.getFontHeight(Graphics.FONT_XTINY);
            var y = top - _y;
            for (var i = 0; i < blocks.size(); i++) {
                var b = blocks[i];
                var h = b[3] as Number;
                if (y + h > 0 && y < _h) {
                    var mine = b[2] as Boolean;
                    var x = mine ? x1 : x0;
                    var just = mine ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_LEFT;
                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x, y, Graphics.FONT_XTINY, b[0] as String, just);
                    dc.setColor(mine ? 0x7CC4F5 : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x, y + headH + GAP_HEAD, Graphics.FONT_SMALL, b[1] as String, just);
                }
                y += h;
            }
        }
        // Kopf mit Chatname über dem Verlauf
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, w, top - 6);
        dc.setColor(0x4FA3E0, Graphics.COLOR_TRANSPARENT);
        var name = Graphics.fitTextToArea(title, Graphics.FONT_XTINY, w * 0.5, dc.getFontHeight(Graphics.FONT_XTINY), true);
        dc.drawText(w / 2, top - 8 - dc.getFontHeight(Graphics.FONT_XTINY), Graphics.FONT_XTINY, name == null ? "" : name, Graphics.TEXT_JUSTIFY_CENTER);
    }

    public function failed() as Boolean {
        return _error != null;
    }
}

class ChatDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ChatView;

    public function initialize(view as ChatView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Ziehen mit dem Finger: Verlauf folgt direkt dem Finger. Das Wischen, das das System danach
    // zusätzlich meldet, wird dann ignoriert, sonst springt der Verlauf noch eine Seite weiter.
    private var _dragY as Number? = null;
    private var _dragAt as Number = 0;

    public function onDrag(e as WatchUi.DragEvent) as Boolean {
        var y = e.getCoordinates()[1];
        var t = e.getType();
        if (t == WatchUi.DRAG_TYPE_START) {
            _dragY = y;
        } else if (_dragY != null) {
            var dy = (_dragY as Number) - y;
            if (dy != 0) {
                _view.scroll(dy);
                _dragAt = System.getTimer();
            }
            _dragY = t == WatchUi.DRAG_TYPE_STOP ? null : y;
        }
        return true;
    }

    private function dragged() as Boolean {
        return System.getTimer() - _dragAt < 500;
    }

    public function onNextPage() as Boolean {
        if (!dragged()) {
            _view.scroll(_view.page());
        }
        return true;
    }

    public function onPreviousPage() as Boolean {
        if (!dragged()) {
            _view.scroll(-_view.page());
        }
        return true;
    }

    public function onSelect() as Boolean {
        if (dragged()) {
            return true;
        }
        if (_view.failed()) {
            _view.reload();
            return true;
        }
        if (_view.msgs == null) {
            return true;
        }
        new RepliesLoader(_view).start();
        return true;
    }

    public function onMenu() as Boolean {
        return onSelect();
    }
}
