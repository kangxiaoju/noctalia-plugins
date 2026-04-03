import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string screenName: screen?.name ?? ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property int slotCount: pluginApi?.pluginSettings?.slotCount || pluginApi?.manifest?.metadata?.defaultSettings?.slotCount || 4

  function defaultSlot(slotNumber) {
    return {
      "name": pluginApi?.tr("settings.slot.defaultName", { index: slotNumber }) || ("Slot " + slotNumber),
      "command": "date '+%H:%M:%S'",
      "clickCommand": "",
      "shellPath": "/bin/sh",
      "refreshIntervalSeconds": 5,
      "maxTextLength": 24,
      "marqueeEnabled": true,
      "colorMode": "none",
      "textColor": "#A6E3A1"
    }
  }

  function slotConfig(index) {
    const configuredSlots = pluginApi?.pluginSettings?.slotConfigs
    if (configuredSlots && configuredSlots[index]) {
      return configuredSlots[index]
    }

    const manifestSlots = pluginApi?.manifest?.metadata?.defaultSettings?.slotConfigs
    if (manifestSlots && manifestSlots[index]) {
      return manifestSlots[index]
    }

    return defaultSlot(index + 1)
  }

  function resolveTextColor(colorMode, customTextColor) {
    switch (colorMode) {
      case "primary":
        return Color.mPrimary
      case "secondary":
        return Color.mSecondary
      case "tertiary":
        return Color.mTertiary
      case "custom":
        return customTextColor
      default:
        return Color.mOnSurface
    }
  }

  function refreshAllSlots() {
    for (let i = 0; i < slotRepeater.count; ++i) {
      const item = slotRepeater.itemAt(i)
      if (item) {
        item.refreshOutput()
      }
    }
  }

  implicitWidth: visualCapsule.width
  implicitHeight: visualCapsule.height

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.isBarVertical ? root.capsuleHeight : Math.min(slotRow.implicitWidth + Style.marginM * 2, 1600)
    height: root.isBarVertical ? slotRow.implicitHeight + Style.marginM * 2 : root.capsuleHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Row {
      id: slotRow
      anchors.centerIn: parent
      spacing: 0

      Repeater {
        id: slotRepeater
        model: root.slotCount

        delegate: Item {
          id: slotItem
          required property int index

          readonly property var config: root.slotConfig(index)
          readonly property string displayCommand: config.command || "date '+%H:%M:%S'"
          readonly property string clickCommand: config.clickCommand || ""
          readonly property string shellPath: config.shellPath || "/bin/sh"
          readonly property int refreshIntervalSeconds: config.refreshIntervalSeconds || 5
          readonly property int maxTextLength: config.maxTextLength || 24
          readonly property bool marqueeEnabled: config.marqueeEnabled ?? true
          readonly property color textColor: root.resolveTextColor(config.colorMode || "none", config.textColor || "#A6E3A1")
          readonly property real maxViewportWidth: Math.max(80, maxTextLength * root.barFontSize * 0.72)
          readonly property bool hasVisibleText: displayText.length > 0
          readonly property bool shouldMarquee: hasVisibleText && marqueeEnabled && textMetrics.width > maxViewportWidth
          readonly property real viewportWidth: shouldMarquee ? maxViewportWidth : (hasVisibleText ? Math.max(1, Math.min(textMetrics.width, maxViewportWidth)) : 0)

          property string displayText: root.pluginApi?.tr("widget.loading") || "Loading..."
          property string lastStdErr: ""

          visible: hasVisibleText
          implicitWidth: hasVisibleText ? viewport.implicitWidth + leftPadding.width : 0
          implicitHeight: viewport.implicitHeight

          function resetMarquee() {
            marqueeText.x = 0
          }

          function refreshOutput() {
            if (!displayCommand || scriptProcess.running) {
              return
            }

            scriptProcess.running = true
          }

          function triggerClickCommand() {
            if (!clickCommand || clickProcess.running) {
              return
            }

            clickProcess.running = true
          }

          onDisplayTextChanged: resetMarquee()
          onShouldMarqueeChanged: resetMarquee()

          Item {
            id: leftPadding
            width: slotItem.index > 0 && slotItem.hasVisibleText ? Style.marginM : 0
            height: 1
          }

          Rectangle {
            anchors.left: leftPadding.left
            anchors.leftMargin: -Style.marginS / 2
            anchors.verticalCenter: parent.verticalCenter
            width: slotItem.index > 0 && slotItem.hasVisibleText ? 1 : 0
            height: root.barFontSize * 1.2
            color: Color.mOutlineVariant || Style.capsuleBorderColor
            opacity: 0.6
          }

          Item {
            id: viewport
            x: leftPadding.width
            implicitWidth: slotItem.viewportWidth
            implicitHeight: root.barFontSize * 1.8
            clip: true

            TextMetrics {
              id: textMetrics
              text: slotItem.displayText
              font.pointSize: root.barFontSize
              font.weight: Font.Medium
            }

            Text {
              anchors.fill: parent
              visible: !slotItem.shouldMarquee
              text: slotItem.displayText
              color: slotItem.textColor
              font.pointSize: root.barFontSize
              font.weight: Font.Medium
              verticalAlignment: Text.AlignVCenter
              horizontalAlignment: Text.AlignLeft
              wrapMode: Text.NoWrap
              elide: Text.ElideRight
              maximumLineCount: 1
              clip: true
            }

            Text {
              id: marqueeText
              anchors.verticalCenter: parent.verticalCenter
              visible: slotItem.shouldMarquee
              height: parent.height
              x: 0
              text: slotItem.displayText + "     " + slotItem.displayText
              color: slotItem.textColor
              font.pointSize: root.barFontSize
              font.weight: Font.Medium
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.NoWrap
              elide: Text.ElideNone
              maximumLineCount: 1
              clip: true
            }

            NumberAnimation {
              target: marqueeText
              property: "x"
              running: slotItem.shouldMarquee && marqueeText.implicitWidth > viewport.width
              from: 0
              to: -(marqueeText.implicitWidth - textMetrics.width - 5 * root.barFontSize * 0.35)
              duration: Math.max(5000, slotItem.displayText.length * 220)
              loops: Animation.Infinite
              easing.type: Easing.Linear
            }

            onWidthChanged: slotItem.resetMarquee()
          }

          MouseArea {
            anchors.fill: viewport
            hoverEnabled: true
            cursorShape: clickCommand ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: slotItem.triggerClickCommand()
          }

          Process {
            id: scriptProcess
            command: [slotItem.shellPath, "-lc", slotItem.displayCommand]
            running: false

            onStarted: slotItem.lastStdErr = ""

            onExited: function(exitCode) {
              if (exitCode !== 0 && !slotItem.lastStdErr) {
                slotItem.displayText = root.pluginApi?.tr("widget.commandFailed", { code: exitCode }) || ("Command failed (" + exitCode + ")")
              }
            }

            stdout: StdioCollector {
              onStreamFinished: slotItem.displayText = this.text.trim()
            }

            stderr: StdioCollector {
              onStreamFinished: {
                const errorText = this.text.trim()
                slotItem.lastStdErr = errorText
                if (errorText.length > 0) {
                  slotItem.displayText = errorText
                }
              }
            }
          }

          Process {
            id: clickProcess
            command: [slotItem.shellPath, "-lc", slotItem.clickCommand]
            running: false
          }

          Timer {
            interval: Math.max(1, slotItem.refreshIntervalSeconds) * 1000
            running: !!slotItem.displayCommand
            repeat: true
            triggeredOnStart: true
            onTriggered: slotItem.refreshOutput()
          }
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.refresh") || "Refresh",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("menu.openSettings") || "Open Slot Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)

      if (action === "refresh") {
        root.refreshAllSlots()
      } else if (action === "settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }
}
