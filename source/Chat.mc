import Toybox.Graphics;
import Toybox.Lang;
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
        var max = _total - _h / 2;
        _y += dy;
        if (_y > max) {
            _y = max;
        }
        if (_y < 0) {
            _y = 0;
        }
        WatchUi.requestUpdate();
    }

    public function page() as Number {
        return _h / 3;
    }

    private function layout(dc as Graphics.Dc) as Void {
        var w = (dc.getWidth() * 0.72).toNumber();
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
            var lines = 1;
            var s = wrapped as String;
            var idx = s.find("\n");
            while (idx != null) {
                lines++;
                s = s.substring(idx + 1, s.length()) as String;
                idx = s.find("\n");
            }
            var h = headH + lines * lineH + 14;
            blocks.add([head, wrapped, m.get("me") == true, h]);
            total += h;
        }
        _blocks = blocks;
        _total = total;
        // Unten (neueste Nachricht) anfangen
        _y = total - (_h * 0.62).toNumber();
        if (_y < 0) {
            _y = 0;
        }
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
            var x0 = (w * 0.14).toNumber();
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
                    dc.drawText(x, y + headH, Graphics.FONT_SMALL, b[1] as String, just);
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

    public function onNextPage() as Boolean {
        _view.scroll(_view.page());
        return true;
    }

    public function onPreviousPage() as Boolean {
        _view.scroll(-_view.page());
        return true;
    }

    public function onSelect() as Boolean {
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
