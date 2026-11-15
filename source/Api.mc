import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;

//! Verbindung zum Chorus-Server (über das Handy). Alle Antworten sind JSON-Objekte.
module Api {
    function server() as String {
        var s = Application.Properties.getValue("server");
        if (s instanceof String && s.length() > 0) {
            // Ohne Schrägstrich am Ende
            if (s.substring(s.length() - 1, s.length()).equals("/")) {
                return s.substring(0, s.length() - 1) as String;
            }
            return s;
        }
        return "https://chorus.example.org";
    }

    function token() as String? {
        var t = Application.Storage.getValue("token");
        return t instanceof String ? t : null;
    }

    function setToken(t as String?) as Void {
        if (t == null) {
            Application.Storage.deleteValue("token");
        } else {
            Application.Storage.setValue("token", t);
        }
    }

    function get(path as String, params as Dictionary?, cb as Method) as Void {
        send(Communications.HTTP_REQUEST_METHOD_GET, path, params, cb);
    }

    function post(path as String, body as Dictionary?, cb as Method) as Void {
        send(Communications.HTTP_REQUEST_METHOD_POST, path, body == null ? {} : body, cb);
    }

    function send(m as Communications.HttpRequestMethod, path as String, params as Dictionary?, cb as Method) as Void {
        var headers = {} as Dictionary<String, String>;
        if (m == Communications.HTTP_REQUEST_METHOD_POST) {
            headers.put("Content-Type", Communications.REQUEST_CONTENT_TYPE_JSON);
        }
        var t = token();
        if (t != null) {
            headers.put("Authorization", "Bearer " + t);
        }
        var options = {
            :method => m,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(server() + path, params, options, cb);
    }
}
