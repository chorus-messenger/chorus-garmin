import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Lädt die Chatliste und ersetzt die oberste Ansicht durch das Menü
class ChatsLoader {
    public function initialize() {
    }

    public function start() as Void {
        Api.get("/api/w/chats", null, method(:onData));
    }

    public function onData(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200 || !(data instanceof Dictionary)) {
            Ui.fail(code, data, method(:start));
            return;
        }
        var chats = data.get("chats") as Array<Dictionary>;
        var menu = new WatchUi.Menu2({ :title => Ui.str(Rez.Strings.Chats) });
        for (var i = 0; i < chats.size(); i++) {
            var c = chats[i];
            var title = c.get("t") as String;
            var unread = c.get("u") as Number;
            var label = unread > 0 ? unread.toString() + " · " + title : title;
            var p = c.get("p");
            var sub = p instanceof String && p.length() > 0 ? p : Ui.when(c.get("ts") as Number);
            var av = new Avatar(title, c.get("n") as String);
            var url = c.get("a");
            var ver = c.get("av");
            if (url instanceof String && ver instanceof String) {
                av.key = "av" + ver;
                av.bmp = AvatarCache.get(av.key);
                if (av.bmp == null) {
                    av.url = url;
                    _avatars.add(av);
                }
            }
            menu.addItem(new WatchUi.IconMenuItem(label, sub, c.get("id") as String, av, null));
        }
        if (chats.size() == 0) {
            menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.NoChats), null, :none, null));
        }
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.Refresh), null, :refresh, null));
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.FontSize), Ui.fontName(), :font, null));
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.Unpair), null, :unpair, null));
        WatchUi.switchToView(menu, new ChatsDelegate(), WatchUi.SLIDE_IMMEDIATE);
        nextAvatar();
    }

    //! Profilbilder nacheinander laden (die Uhr verträgt nur wenige gleichzeitige Anfragen)
    private var _avatars as Array<Avatar> = [] as Array<Avatar>;
    private var _next as Number = 0;

    public function nextAvatar() as Void {
        if (_next >= _avatars.size()) {
            _avatars = [] as Array<Avatar>;
            return;
        }
        var url = _avatars[_next].url as String;
        Communications.makeImageRequest(Api.server() + url, null, {
            :maxWidth => Avatar.SIZE,
            :maxHeight => Avatar.SIZE,
            :dithering => Communications.IMAGE_DITHERING_NONE
        }, method(:onAvatar));
    }

    public function onAvatar(code as Number, data as WatchUi.BitmapResource or Graphics.BitmapReference or Null) as Void {
        if (_next < _avatars.size()) {
            if (code == 200 && data != null) {
                var av = _avatars[_next];
                av.bmp = data;
                AvatarCache.put(av.key, data);
                WatchUi.requestUpdate();
            }
            _next++;
        }
        nextAvatar();
    }
}

//! Rundes Profilbild in der Chatliste; ohne Bild ein farbiger Kreis mit Anfangsbuchstaben
class Avatar extends WatchUi.Drawable {
    public static const SIZE = 60;
    public var url as String? = null;
    public var key as String = "";
    public var bmp as WatchUi.BitmapResource or Graphics.BitmapReference or Null = null;
    private var _letter as String;
    private var _color as Number;

    public function initialize(title as String, network as String) {
        Drawable.initialize({});
        _letter = title.length() > 0 ? title.substring(0, 1).toUpper() : "?";
        _color = network.equals("whatsapp") ? 0x1F8F55 : network.equals("signal") ? 0x3A76F0 : network.equals("telegram") ? 0x2A9BD6 : network.equals("email") ? 0x8A6FD1 : 0x4FA3E0;
    }

    public function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var d = (w < h ? w : h) - 4;
        if (d > SIZE) {
            d = SIZE;
        }
        var r = d / 2;
        var cx = w / 2;
        var cy = h / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (bmp != null) {
            var b = bmp;
            var bw = b.getWidth();
            var bh = b.getHeight();
            if ((bw != d || bh != d) && dc has :drawScaledBitmap) {
                dc.drawScaledBitmap(cx - r, cy - r, d, d, b);
            } else {
                dc.drawBitmap(cx - bw / 2, cy - bh / 2, b);
            }
            // Ecken schwarz übermalen, damit das Bild rund wirkt
            var pen = (r * 0.5).toNumber() + 2;
            dc.setPenWidth(pen);
            dc.drawCircle(cx, cy, r + pen / 2);
            dc.setPenWidth(1);
        } else {
            dc.setColor(_color, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_SMALL, _letter, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

class ChatsDelegate extends WatchUi.Menu2InputDelegate {
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :refresh) {
            var info = new InfoView(Ui.str(Rez.Strings.Loading), null);
            WatchUi.switchToView(info, new InfoDelegate(info), WatchUi.SLIDE_IMMEDIATE);
            new ChatsLoader().start();
        } else if (id == :font) {
            Ui.setFontSize((Ui.fontSize() + 1) % Ui.FONTS.size());
            item.setSubLabel(Ui.fontName());
            WatchUi.requestUpdate();
        } else if (id == :unpair) {
            Api.setToken(null);
            var pair = new PairView();
            WatchUi.switchToView(pair, new PairDelegate(pair), WatchUi.SLIDE_IMMEDIATE);
        } else if (id instanceof String) {
            var view = new ChatView(id, item.getLabel());
            WatchUi.pushView(view, new ChatDelegate(view), WatchUi.SLIDE_LEFT);
        }
    }
}

//! Profilbilder dauerhaft auf der Uhr: Schlüssel enthält die Bildversion vom Server, also neu laden nur bei Änderung.
//! Höchstens 40 Bilder (je ca. 7 KB), die ältesten fliegen raus.
module AvatarCache {
    const MAX = 40;

    function get(key as String) as WatchUi.BitmapResource? {
        try {
            var v = Application.Storage.getValue(key);
            return v instanceof WatchUi.BitmapResource ? v : null;
        } catch (e) {
            return null;
        }
    }

    function put(key as String, data as WatchUi.BitmapResource or Graphics.BitmapReference) as Void {
        var bmp = data instanceof Graphics.BitmapReference ? (data as Graphics.BitmapReference).get() : data;
        if (!(bmp instanceof WatchUi.BitmapResource)) {
            return;
        }
        try {
            var keys = Application.Storage.getValue("avKeys");
            var list = keys instanceof Array ? keys as Array<String> : [] as Array<String>;
            list.remove(key);
            list.add(key);
            while (list.size() > MAX) {
                Application.Storage.deleteValue(list[0]);
                list = list.slice(1, null);
            }
            Application.Storage.setValue(key, bmp);
            Application.Storage.setValue("avKeys", list);
        } catch (e) {
            // Speicher voll o. Ä.: dann eben beim nächsten Mal wieder laden
        }
    }
}
