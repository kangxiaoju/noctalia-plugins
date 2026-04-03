import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property int editSlotCount: pluginApi?.pluginSettings?.slotCount || pluginApi?.manifest?.metadata?.defaultSettings?.slotCount || 4
  property var slotConfigs: []
  readonly property var colorChoices: [
    { "key": "none", "labelKey": "settings.color.none", "fallback": "None" },
    { "key": "primary", "labelKey": "settings.color.primary", "fallback": "Primary" },
    { "key": "secondary", "labelKey": "settings.color.secondary", "fallback": "Secondary" },
    { "key": "tertiary", "labelKey": "settings.color.tertiary", "fallback": "Tertiary" },
    { "key": "custom", "labelKey": "settings.color.custom", "fallback": "Custom" }
  ]

  function makeDefaultSlot(index) {
    return {
      "name": pluginApi?.tr("settings.slot.defaultName", { index: index + 1 }) || ("Slot " + (index + 1)),
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

  function cloneSlot(slot, index) {
    const fallback = makeDefaultSlot(index)
    if (!slot) {
      return fallback
    }

    return {
      "name": slot.name || fallback.name,
      "command": slot.command || fallback.command,
      "clickCommand": slot.clickCommand || fallback.clickCommand,
      "shellPath": slot.shellPath || fallback.shellPath,
      "refreshIntervalSeconds": slot.refreshIntervalSeconds || fallback.refreshIntervalSeconds,
      "maxTextLength": slot.maxTextLength || fallback.maxTextLength,
      "marqueeEnabled": slot.marqueeEnabled ?? fallback.marqueeEnabled,
      "colorMode": slot.colorMode || fallback.colorMode,
      "textColor": slot.textColor || fallback.textColor
    }
  }

  function normalizedSlotConfigs(targetCount) {
    const configured = pluginApi?.pluginSettings?.slotConfigs
    const manifest = pluginApi?.manifest?.metadata?.defaultSettings?.slotConfigs
    const current = configured || manifest || []
    const next = []

    for (let i = 0; i < targetCount; ++i) {
      next.push(cloneSlot(current[i], i))
    }

    return next
  }

  function ensureSlotCount(targetCount) {
    editSlotCount = targetCount
    slotConfigs = normalizedSlotConfigs(targetCount)
  }

  function colorModel() {
    return colorChoices.map(choice => ({
      "key": choice.key,
      "name": pluginApi?.tr(choice.labelKey) || choice.fallback
    }))
  }

  function setSlotField(index, key, value) {
    const next = slotConfigs.slice()
    next[index] = Object.assign({}, next[index] || makeDefaultSlot(index))
    next[index][key] = value
    slotConfigs = next
  }

  Component.onCompleted: ensureSlotCount(editSlotCount)

  spacing: Style.marginM

  NLabel {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.title") || "Command Runner"
    description: pluginApi?.tr("settings.description") || "Configure command slots. The first widget uses slot 1, the second widget uses slot 2, and so on."
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.slotCount.label") || "Slot Count"
      description: pluginApi?.tr("settings.slotCount.description") || "How many independent command slots are available."
    }

    NSpinBox {
      from: 1
      to: 16
      value: root.editSlotCount
      onValueChanged: root.ensureSlotCount(value)
    }
  }

  Repeater {
    model: root.editSlotCount

    delegate: Rectangle {
      required property int index
      property int slotIndex: index
      readonly property var slotValue: root.slotConfigs[slotIndex] || root.makeDefaultSlot(slotIndex)

      Layout.fillWidth: true
      radius: Style.radiusL
      color: Style.capsuleColor
      border.color: Style.capsuleBorderColor
      border.width: Style.capsuleBorderWidth
      implicitHeight: slotColumn.implicitHeight + Style.marginM * 2

      ColumnLayout {
        id: slotColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NLabel {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.slot.title", { index: slotIndex + 1 }) || ("Slot " + (slotIndex + 1))
          description: pluginApi?.tr("settings.slot.description", { index: slotIndex + 1 }) || ("Used by widget #" + (slotIndex + 1) + " in the bar.")
        }

        NTextInput {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.slot.nameLabel") || "Slot Name"
          description: pluginApi?.tr("settings.slot.nameDescription") || "Optional label for this slot."
          text: slotValue.name
          onTextChanged: root.setSlotField(slotIndex, "name", text)
        }

        NTextInput {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.command.label") || "Command"
          description: pluginApi?.tr("settings.command.description") || "Shell command to execute. The command stdout is shown in the bar."
          placeholderText: "date '+%H:%M:%S'"
          text: slotValue.command
          onTextChanged: root.setSlotField(slotIndex, "command", text)
        }

        NTextInput {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.clickCommand.label") || "Click Command"
          description: pluginApi?.tr("settings.clickCommand.description") || "Optional command executed when this slot is clicked."
          placeholderText: "playerctl play-pause"
          text: slotValue.clickCommand
          onTextChanged: root.setSlotField(slotIndex, "clickCommand", text)
        }

        NTextInput {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.shellPath.label") || "Shell Path"
          description: pluginApi?.tr("settings.shellPath.description") || "Interpreter used to execute the command."
          placeholderText: "/bin/sh"
          text: slotValue.shellPath
          onTextChanged: root.setSlotField(slotIndex, "shellPath", text)
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NLabel {
            label: pluginApi?.tr("settings.refreshInterval.label") || "Refresh Interval"
            description: pluginApi?.tr("settings.refreshInterval.description") || "How often the command reruns automatically, in seconds."
          }

          NSpinBox {
            from: 1
            to: 3600
            value: slotValue.refreshIntervalSeconds
            onValueChanged: root.setSlotField(slotIndex, "refreshIntervalSeconds", value)
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NLabel {
            label: pluginApi?.tr("settings.maxTextLength.label") || "Maximum Text Length"
            description: pluginApi?.tr("settings.maxTextLength.description") || "Start marquee scrolling when the text exceeds this length."
          }

          NSpinBox {
            from: 4
            to: 200
            value: slotValue.maxTextLength
            onValueChanged: root.setSlotField(slotIndex, "maxTextLength", value)
          }
        }

        NToggle {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.marqueeEnabled.label") || "Enable Marquee"
          description: pluginApi?.tr("settings.marqueeEnabled.description") || "Scroll the text when it exceeds the configured maximum length."
          checked: slotValue.marqueeEnabled
          onToggled: checked => root.setSlotField(slotIndex, "marqueeEnabled", checked)
        }

        NComboBox {
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.color.label") || "Color"
          description: pluginApi?.tr("settings.color.description") || "Choose theme color or a custom color."
          model: root.colorModel()
          currentKey: slotValue.colorMode
          onSelected: key => root.setSlotField(slotIndex, "colorMode", key)
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize
          radius: Style.radiusM
          color: Style.capsuleColor
          border.color: Style.capsuleBorderColor
          border.width: Style.capsuleBorderWidth

          NText {
            anchors.centerIn: parent
            text: pluginApi?.tr("settings.color.previewText") || "Preview Text"
            color: slotValue.colorMode === "primary"
              ? Color.mPrimary
              : slotValue.colorMode === "secondary"
                ? Color.mSecondary
                : slotValue.colorMode === "tertiary"
                  ? Color.mTertiary
                  : slotValue.colorMode === "custom"
                    ? slotValue.textColor
                    : Color.mOnSurface
            font.pointSize: Style.barFontSize
            font.weight: Font.Medium
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS
          visible: slotValue.colorMode === "custom"

          NLabel {
            label: pluginApi?.tr("settings.textColor.label") || "Custom Color"
            description: pluginApi?.tr("settings.textColor.description") || "Pick the custom text color."
          }

          NColorPicker {
            Layout.preferredWidth: Style.sliderWidth
            Layout.preferredHeight: Style.baseWidgetSize
            selectedColor: slotValue.textColor
            onColorSelected: function(color) {
              root.setSlotField(slotIndex, "textColor", color.toString())
            }
          }
        }
      }
    }
  }

  function saveSettings() {
    pluginApi.pluginSettings.slotCount = root.editSlotCount
    pluginApi.pluginSettings.slotConfigs = root.slotConfigs
    pluginApi.saveSettings()
  }
}
