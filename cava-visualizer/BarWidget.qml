import QtQuick
import QtQuick.Layouts
import "." as Plugin
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: 0
    property int sectionWidgetsCount: 1

    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property int barCount: pluginApi?.pluginSettings?.bars ?? 12
    readonly property int framerate: pluginApi?.pluginSettings?.framerate ?? 30
    readonly property real barWidth: pluginApi?.pluginSettings?.barWidth ?? 6
    readonly property real barRadius: pluginApi?.pluginSettings?.barRadius ?? 0
    readonly property string barColorMode:
        pluginApi?.pluginSettings?.barColorMode ??
        pluginApi?.manifest?.metadata?.defaultSettings?.barColorMode ??
        "primary"
    readonly property color barCustomColor:
        pluginApi?.pluginSettings?.barCustomColor ??
        pluginApi?.manifest?.metadata?.defaultSettings?.barCustomColor ??
        "#ff4d4d"
    readonly property string barVerticalAlign:
        pluginApi?.pluginSettings?.barVerticalAlign ??
        pluginApi?.manifest?.metadata?.defaultSettings?.barVerticalAlign ??
        "center"
    readonly property bool showWhenIdle:
        pluginApi?.pluginSettings?.showWhenIdle ??
        pluginApi?.manifest?.metadata?.defaultSettings?.showWhenIdle ??
        false

    readonly property color barColor:
        barColorMode === "custom" ? barCustomColor : Color.resolveColorKey(barColorMode)

    readonly property bool audioActive: Plugin.CavaController.audioActive
    readonly property var barValues: Plugin.CavaController.barValues

    readonly property real barSpacing: 2
    readonly property real totalW: barCount * barWidth + (barCount - 1) * barSpacing + Style.marginM * 2

    readonly property bool shouldShow: audioActive || showWhenIdle
    readonly property real contentWidth: shouldShow ? totalW : 0
    readonly property real contentHeight: shouldShow ? capsuleHeight : 0

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    visible: opacity > 0.01
    opacity: shouldShow ? 1.0 : 0.0

    function syncControllerConfig() {
        Plugin.CavaController.applyConfig(root.barCount, root.framerate, root.showWhenIdle)
    }

    Component.onCompleted: syncControllerConfig()
    onBarCountChanged: syncControllerConfig()
    onFramerateChanged: syncControllerConfig()
    onShowWhenIdleChanged: syncControllerConfig()

    Rectangle {
        id: capsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: Style.capsuleColor
        radius: Style.radiusM

        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, capsule, root.screen)
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: root.barVerticalAlign === "center" ? parent.verticalCenter : undefined
            anchors.bottom: root.barVerticalAlign === "bottom" ? parent.bottom : undefined
            anchors.bottomMargin: root.barVerticalAlign === "bottom" ? 0 : 0
            spacing: root.barSpacing

            Repeater {
                model: root.barCount
                delegate: Item {
                    width: root.barWidth
                    height: capsule.height

                    Rectangle {
                        id: bar
                        width: root.barWidth
                        property real normalized: (root.barValues.length > index)
                                                ? root.barValues[index] / 16.0
                                                : 0.0
                        property real maxBarHeight: root.barVerticalAlign === "bottom"
                                                    ? (capsule.height - Style.marginS - 3)
                                                    : (capsule.height - Style.marginS * 2)
                        height: root.barVerticalAlign === "bottom"
                                ? Math.max(0.4, normalized * maxBarHeight)
                                : Math.max(0.4, normalized * maxBarHeight / 2)
                        anchors.bottom: root.barVerticalAlign === "bottom" ? parent.bottom : parent.verticalCenter
                        anchors.bottomMargin: root.barVerticalAlign === "bottom" ? 3 : 0
                        radius: barRadius
                        bottomLeftRadius: root.barVerticalAlign === "bottom" ? barRadius : 0
                        bottomRightRadius: root.barVerticalAlign === "bottom" ? barRadius : 0
                        color: root.barColor

                        Behavior on height {
                            NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }

                    Rectangle {
                        visible: root.barVerticalAlign === "center"
                        width: bar.width
                        height: bar.height
                        anchors.top: parent.verticalCenter
                        radius: bar.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                        color: bar.color
                        transform: Scale {
                            yScale: -1
                            origin.y: bar.height / 2 - 0.2
                        }
                    }
                }
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
    }

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: function(action) {
            contextMenu.close()
            PanelService.closeContextMenu(root.screen)
            if (action === "widget-settings") {
                BarService.openPluginSettings(root.screen, root.pluginApi.manifest)
            }
        }
    }
}
