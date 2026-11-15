import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Holt KI-Vorschläge und feste Antworten und zeigt sie als Menü
class RepliesLoader {
    private var _chat as ChatView;
    private var _info as InfoView;

    public function initialize(chat as ChatView) {
        _chat = chat;
        _info = new InfoView(Ui.str(Rez.Strings.Loading), null);
    }

    public function start() as Void {
        WatchUi.pushView(_info, new InfoDelegate(_info), WatchUi.SLIDE_UP);
        load();
    }

    public function load() as Void {
        Api.get("/api/w/replies", { "id" => _chat.id }, method(:onData));
    }

    public function onData(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200 || !(data instanceof Dictionary)) {
            Ui.fail(code, data, method(:load));
            return;
        }
        var texts = [] as Array<String>;
        var menu = new WatchUi.Menu2({ :title => Ui.str(Rez.Strings.Replies) });
        var photos = _chat.photos();
        for (var i = 0; i < photos.size(); i++) {
            var p = photos[i];
            var from = p.get("from") as String;
            var when = Ui.when(p.get("ts") as Number);
            menu.addItem(new WatchUi.MenuItem(Ui.str(p.get("vid") != null ? Rez.Strings.ShowVideo : Rez.Strings.ShowPhoto), from.length() > 0 ? from + " · " + when : when, p, null));
        }
        var ai = data.get("ai") as Array<String>;
        for (var i = 0; i < ai.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(ai[i], Ui.str(Rez.Strings.AiTag), texts.size(), null));
            texts.add(ai[i]);
        }
        var fixed = data.get("fixed") as Array<String>;
        for (var i = 0; i < fixed.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(fixed[i], null, texts.size(), null));
            texts.add(fixed[i]);
        }
        var voice = _chat.voiceWithoutText();
        if (voice != null) {
            menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.Transcribe), null, :transcribe, null));
        }
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.MarkRead), null, :read, null));
        menu.addItem(new WatchUi.MenuItem(Ui.str(Rez.Strings.Refresh), null, :refresh, null));
        WatchUi.switchToView(menu, new RepliesDelegate(_chat, texts, voice), WatchUi.SLIDE_IMMEDIATE);
    }
}

class RepliesDelegate extends WatchUi.Menu2InputDelegate {
    private var _chat as ChatView;
    private var _texts as Array<String>;
    private var _voice as String?;

    public function initialize(chat as ChatView, texts as Array<String>, voice as String?) {
        Menu2InputDelegate.initialize();
        _chat = chat;
        _texts = texts;
        _voice = voice;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            // Erst ganzen Text zeigen, Senden mit zweitem Tippen (gegen versehentliches Antippen)
            var view = new SendView(_texts[id]);
            WatchUi.pushView(view, new SendDelegate(view, _chat), WatchUi.SLIDE_LEFT);
        } else if (id instanceof Dictionary) {
            var v = new PhotoView(id.get("u") as String, id.get("vid") != null);
            WatchUi.pushView(v, new PhotoDelegate(), WatchUi.SLIDE_UP);
        } else if (id == :transcribe && _voice != null) {
            new Action(_chat, "/api/w/transcribe", { "id" => _voice }, Ui.str(Rez.Strings.Transcribing), null).start();
        } else if (id == :read) {
            new Action(_chat, "/api/w/read", { "id" => _chat.id }, Ui.str(Rez.Strings.Loading), Ui.str(Rez.Strings.Read)).start();
        } else if (id == :refresh) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _chat.reload();
        }
    }
}

//! Eine Anfrage an den Server, danach zurück in den Chat (Menü schließen) und neu laden
class Action {
    private var _chat as ChatView;
    private var _path as String;
    private var _body as Dictionary;
    private var _done as String?;
    private var _info as InfoView;
    private var _pops as Number;

    public function initialize(chat as ChatView, path as String, body as Dictionary, busy as String, done as String?) {
        _chat = chat;
        _path = path;
        _body = body;
        _done = done;
        _info = new InfoView(busy, null);
        _pops = 2; // Hinweis + Antwortmenü
    }

    public function setPops(n as Number) as Void {
        _pops = n;
    }

    public function start() as Void {
        WatchUi.pushView(_info, new InfoDelegate(_info), WatchUi.SLIDE_IMMEDIATE);
        run();
    }

    public function run() as Void {
        Api.post(_path, _body, method(:onData));
    }

    public function onData(code as Number, data as Dictionary or String or Null) as Void {
        if (code != 200) {
            if (code == 401) {
                Ui.fail(code, data, null);
                return;
            }
            _info.text = Ui.errorText(code, data);
            _info.hint = Ui.str(Rez.Strings.TapRetry);
            _info.retry = method(:run);
            WatchUi.requestUpdate();
            return;
        }
        for (var i = 0; i < _pops; i++) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        if (_done != null) {
            Ui.toast(_done as String);
        }
        _chat.reload();
    }
}

//! Antwort vor dem Senden ganz zeigen
class SendView extends WatchUi.View {
    public var text as String;

    public function initialize(text as String) {
        View.initialize();
        self.text = text;
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var font = Ui.textFont();
        var t = Graphics.fitTextToArea(text, font, w * 0.74, h * 0.55, true);
        dc.drawText(w / 2, h * 0.45, font, t == null ? text : t, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x4FA3E0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.8, Graphics.FONT_XTINY, Ui.str(Rez.Strings.SendHint), Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SendDelegate extends WatchUi.BehaviorDelegate {
    private var _view as SendView;
    private var _chat as ChatView;

    public function initialize(view as SendView, chat as ChatView) {
        BehaviorDelegate.initialize();
        _view = view;
        _chat = chat;
    }

    public function onSelect() as Boolean {
        var a = new Action(_chat, "/api/w/send", { "id" => _chat.id, "text" => _view.text }, Ui.str(Rez.Strings.Sending), Ui.str(Rez.Strings.Sent));
        a.setPops(3); // Hinweis + Vorschau + Antwortmenü
        a.start();
        return true;
    }
}
