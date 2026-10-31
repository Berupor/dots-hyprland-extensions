import QtQuick

/** Unlock hook of the fixture: records every password it is handed. */
QtObject {
    function unlocked(password: string): void {
        HelloState.unlocks = HelloState.unlocks.concat([password]);
    }
}
