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
            menu.addItem(new WatchUi.MenuItem(label, sub, c.get("id") as String, null));
        }
        if (chats.size() == 0) {
            menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.NoChats), null, :none, null));
        }
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.Refresh), null, :refresh, null));
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.Unpair), null, :unpair, null));
        WatchUi.switchToView(menu, new ChatsDelegate(), WatchUi.SLIDE_IMMEDIATE);
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
