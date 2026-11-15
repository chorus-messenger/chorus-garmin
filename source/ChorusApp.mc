import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Chorus auf der Garmin-Uhr: Chats lesen, Sprachnachrichten als Text, mit Schnellantworten antworten.
class ChorusApp extends Application.AppBase {
    public function initialize() {
        AppBase.initialize();
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        if (Api.token() == null) {
            var pair = new PairView();
            return [pair, new PairDelegate(pair)];
        }
        var info = new InfoView(Ui.str(Rez.Strings.Loading), null);
        new ChatsLoader().start();
        return [info, new InfoDelegate(info)];
    }
}
