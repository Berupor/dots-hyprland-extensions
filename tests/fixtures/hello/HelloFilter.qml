import QtQuick

/** Search filter of the fixture: drops, masks or throws by result name. */
QtObject {
    function filter(result): bool {
        if (result.name === "throw")
            throw new Error(result.name);
        if (result.name.startsWith("secret"))
            result.secret = true;
        return result.name !== "drop";
    }
}
