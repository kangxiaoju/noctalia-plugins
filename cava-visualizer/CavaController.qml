pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property int barCount: 12
    property int framerate: 30
    property bool showWhenIdle: false
    property bool configured: false

    property bool audioActive: false
    property double lastActiveMs: 0
    property var barValues: zeroValues(barCount)

    function zeroValues(count) {
        var zeros = []
        for (var i = 0; i < count; i++) zeros.push(0)
        return zeros
    }

    function applyConfig(nextBarCount, nextFramerate, nextShowWhenIdle) {
        var changed = barCount !== nextBarCount ||
                      framerate !== nextFramerate ||
                      showWhenIdle !== nextShowWhenIdle

        barCount = nextBarCount
        framerate = nextFramerate
        showWhenIdle = nextShowWhenIdle

        if (!configured) {
            configured = true
            bridge.running = true
            return
        }

        if (changed) {
            audioActive = false
            lastActiveMs = 0
            barValues = zeroValues(barCount)
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 400
        repeat: false
        onTriggered: {
            bridge.running = false
            bridge.running = true
        }
    }

    Process {
        id: bridge
        command: ["bash", Qt.resolvedUrl("cava-bridge.sh").toString().replace("file://", ""),
                  root.barCount.toString(),
                  root.framerate.toString(),
                  root.showWhenIdle ? "1" : "0"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                if (line.startsWith("ACTIVE:")) {
                    root.audioActive = true
                    root.lastActiveMs = Date.now()

                    var data = line.substring(7)
                    var parts = data.split(";")
                    var vals = []
                    for (var i = 0; i < parts.length && vals.length < root.barCount; i++) {
                        var n = parseInt(parts[i], 10)
                        if (!isNaN(n)) vals.push(n)
                    }
                    while (vals.length < root.barCount) vals.push(0)
                    root.barValues = vals
                } else if (line === "IDLE") {
                    root.audioActive = false
                    root.barValues = root.zeroValues(root.barCount)
                }
            }
        }
    }

    Timer {
        id: idleGuard
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!root.audioActive) {
                return
            }

            if (Date.now() - root.lastActiveMs > 1500) {
                root.audioActive = false
                root.barValues = root.zeroValues(root.barCount)
            }
        }
    }
}
