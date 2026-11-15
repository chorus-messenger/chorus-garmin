import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Foto bzw. Video-Standbild im Vollbild. Das Handy rechnet das Bild für die Uhr um.
class PhotoView extends WatchUi.View {
    private var _url as String;
    private var _video as Boolean;
    private var _bmp as WatchUi.BitmapResource or Graphics.BitmapReference or Null = null;
    private var _error as String? = null;
    private var _started as Boolean = false;

    public function initialize(url as String, video as Boolean) {
        View.initialize();
        _url = url;
        _video = video;
    }

    public function onShow() as Void {
        if (!_started) {
            _started = true;
            var s = System.getDeviceSettings();
            Communications.makeImageRequest(Api.server() + _url, null, {
                :maxWidth => s.screenWidth,
                :maxHeight => s.screenHeight
            }, method(:onImage));
        }
    }

    public function onImage(code as Number, data as WatchUi.BitmapResource or Graphics.BitmapReference or Null) as Void {
        if (code == 200 && data != null) {
            _bmp = data;
        } else {
            _error = Ui.errorText(code, null);
        }
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (_bmp != null) {
            var b = _bmp;
            dc.drawBitmap((w - b.getWidth()) / 2, (h - b.getHeight()) / 2, b);
            if (_video) {
                // Abspielen geht auf der Uhr nicht: Standbild mit Play-Zeichen und Hinweis
                var r = (w * 0.11).toNumber();
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(w / 2, h / 2, r);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[w / 2 - r / 3, h / 2 - r / 2], [w / 2 - r / 3, h / 2 + r / 2], [w / 2 + r / 2, h / 2]]);
                var y = (h * 0.8).toNumber();
                var t = Ui.str(Rez.Strings.VideoPhone);
                var tw = dc.getTextWidthInPixels(t, Graphics.FONT_XTINY);
                var th = dc.getFontHeight(Graphics.FONT_XTINY);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle((w - tw) / 2 - 10, y - 2, tw + 20, th + 4, 8);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w / 2, y, Graphics.FONT_XTINY, t, Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            var t = _error != null ? _error as String : Ui.str(Rez.Strings.Loading);
            var f = Graphics.fitTextToArea(t, Graphics.FONT_SMALL, w * 0.75, h * 0.6, true);
            dc.drawText(w / 2, h / 2, Graphics.FONT_SMALL, f == null ? "" : f, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

//! Antippen oder Zurück schließt das Bild
class PhotoDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }

    public function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
