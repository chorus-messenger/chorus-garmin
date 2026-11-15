import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Kleine Helfer für Texte, Fehler und Hinweise
module Ui {
    function str(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    //! Schriftgröße für Nachrichtentexte (auf der Uhr in der Chatliste umstellbar), 5 Stufen, Standard Mittel
    const FONTS = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE];

    function fontSize() as Number {
        var v = Application.Storage.getValue("font2");
        return v instanceof Number && v >= 0 && v < FONTS.size() ? v : 2;
    }

    function setFontSize(v as Number) as Void {
        Application.Storage.setValue("font2", v);
    }

    function textFont() as Graphics.FontDefinition {
        return FONTS[fontSize()] as Graphics.FontDefinition;
    }

    function fontName() as String {
        var names = [Rez.Strings.FontXSmall, Rez.Strings.FontSmall, Rez.Strings.FontMedium, Rez.Strings.FontLarge, Rez.Strings.FontXLarge];
        return str(names[fontSize()] as ResourceId);
    }

    function toast(text as String) as Void {
        if (WatchUi has :showToast) {
            WatchUi.showToast(text, null);
        }
    }

    //! Fehlertext zu einer Antwort: negative Codes kommen von der Uhr bzw. dem Handy, positive vom Server
    function errorText(code as Number, data) as String {
        if (code == -104 || code == -2 || code == -101) {
            return str(Rez.Strings.ErrPhone);
        }
        if (data instanceof Dictionary) {
            var e = data.get("error");
            if (e instanceof String) {
                return e;
            }
        }
        return str(Rez.Strings.ErrServer) + " (" + code.toString() + ")";
    }

    //! Fehler anzeigen, Tippen versucht es nochmal. 401 = Schlüssel ungültig → neu koppeln.
    function fail(code as Number, data, retry as Method?) as Void {
        if (code == 401) {
            Api.setToken(null);
            Ui.toast(str(Rez.Strings.Unpaired));
            var pair = new PairView();
            WatchUi.switchToView(pair, new PairDelegate(pair), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        var info = new InfoView(errorText(code, data), retry == null ? null : str(Rez.Strings.TapRetry));
        info.retry = retry;
        WatchUi.switchToView(info, new InfoDelegate(info), WatchUi.SLIDE_IMMEDIATE);
    }

    //! Uhrzeit, bei älteren Nachrichten das Datum
    function when(ts as Number) as String {
        var m = new Time.Moment(ts);
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (i.day == now.day && i.month == now.month && i.year == now.year) {
            return i.hour.format("%02d") + ":" + i.min.format("%02d");
        }
        return i.day.format("%d") + "." + (i.month as Number).format("%d") + ". " + i.hour.format("%02d") + ":" + i.min.format("%02d");
    }
}

//! Einfache Textanzeige (Laden, Fehler, Hinweise). retry wird beim Tippen aufgerufen.
class InfoView extends WatchUi.View {
    public var text as String;
    public var hint as String?;
    public var retry as Method? = null;

    public function initialize(text as String, hint as String?) {
        View.initialize();
        self.text = text;
        self.hint = hint;
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var t = Graphics.fitTextToArea(text, Graphics.FONT_SMALL, w * 0.75, h * 0.6, true);
        dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, t == null ? text : t, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (hint != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.8, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class InfoDelegate extends WatchUi.BehaviorDelegate {
    private var _view as InfoView;

    public function initialize(view as InfoView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    public function onSelect() as Boolean {
        var r = _view.retry;
        if (r != null) {
            _view.retry = null;
            _view.text = Ui.str(Rez.Strings.Loading);
            _view.hint = null;
            WatchUi.requestUpdate();
            r.invoke();
            return true;
        }
        return false;
    }
}
