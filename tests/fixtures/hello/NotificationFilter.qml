import QtQuick

/** Notification filter of the fixture: drops, silences or throws by app name. */
QtObject {
    function filter(n) {
        if (n.appName === "throw")
            throw new Error(n.summary);
        if (n.appName === "drop")
            return false;
        if (n.appName === "quiet")
            return "silent";
    }
}
