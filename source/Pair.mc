import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! Koppeln: Uhr holt einen 6-stelligen Code, man gibt ihn in Chorus ein, die Uhr fragt alle 3 s nach dem Schlüssel.
class PairView extends WatchUi.View {
    private var _code as String? = null;
    private var _pair as String? = null;
    private var _msg as String? = null;
    private var _timer as Timer.Timer? = null;
    private var _busy as Boolean = false;

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        if (_pair == null && !_busy) {
            start();
        }
    }

    public function onHide() as Void {
        stopTimer();
    }

    public function start() as Void {
        _busy = true;
        _msg = Ui.str(Rez.Strings.Loading);
        _code = null;
        _pair = null;
        WatchUi.requestUpdate();
        Api.post("/api/w/pair", null, method(:onPair));
    }

    public function onPair(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        if (code != 200 || !(data instanceof Dictionary)) {
            _msg = Ui.errorText(code, data) + "\n" + Ui.str(Rez.Strings.TapRetry);
            WatchUi.requestUpdate();
            return;
        }
        var c = data.get("code") as String;
        _code = c.substring(0, 3) + " " + c.substring(3, 6);
        _pair = data.get("pair") as String;
        _msg = null;
        stopTimer();
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:poll), 3000, true);
        WatchUi.requestUpdate();
    }

    public function poll() as Void {
        if (_pair != null && !_busy) {
            _busy = true;
            Api.get("/api/w/pair/" + _pair, null, method(:onPoll));
        }
    }

    public function onPoll(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        if (code != 200 || !(data instanceof Dictionary)) {
            return; // Handy kurz weg: einfach weiter fragen
        }
        var state = data.get("state");
        if ("done".equals(state)) {
            stopTimer();
            Api.setToken(data.get("token") as String);
            var info = new InfoView(Ui.str(Rez.Strings.Loading), null);
            WatchUi.switchToView(info, new InfoDelegate(info), WatchUi.SLIDE_IMMEDIATE);
            new ChatsLoader().start();
        } else if ("gone".equals(state)) {
            // Code abgelaufen (10 Minuten): neuen holen
            stopTimer();
            start();
        }
    }

    public function failed() as Boolean {
        return _code == null && !_busy;
    }

    private function stopTimer() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.drawText(w / 2, h * 0.14, Graphics.FONT_SMALL, Ui.str(Rez.Strings.PairTitle), Graphics.TEXT_JUSTIFY_CENTER);
        if (_code != null) {
            dc.setColor(0x4FA3E0, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.42, Graphics.FONT_LARGE, _code, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            var hint = Graphics.fitTextToArea(Ui.str(Rez.Strings.PairHint), Graphics.FONT_XTINY, w * 0.7, h * 0.3, true);
            if (hint != null) {
                dc.drawText(w / 2, h * 0.58, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else if (_msg != null) {
            var t = Graphics.fitTextToArea(_msg as String, Graphics.FONT_XTINY, w * 0.75, h * 0.5, true);
            dc.drawText(w / 2, h / 2, Graphics.FONT_XTINY, t == null ? "" : t, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

class PairDelegate extends WatchUi.BehaviorDelegate {
    private var _view as PairView;

    public function initialize(view as PairView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        if (_view.failed()) {
            _view.start();
        }
        return true;
    }
}
