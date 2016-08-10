/*global cordova, module*/

var exec = require("cordova/exec")

/*
 * Format of the returned value:
 * {
 *    "sync_interval": 1224,
 *    "device_token": "90c00463..." (ios only)
 * }
 */

var ServerSync = {
    forceSync: function (resolve, reject) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "ServerSync", "forceSync", []);
        });
    },
    getConfig: function () {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "ServerSync", "getConfig", []);
        });
    },
    setConfig: function (newConfig) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "ServerSync", "setConfig", [newConfig]);
        });
    },
}

module.exports = ServerSync;
