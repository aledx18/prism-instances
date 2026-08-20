import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.aledx18.prism-instances"

  visible: true

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
    readonly property bool popoutSwitchClosing: panelLoader.item
      ? panelLoader.item.popoutSwitchClosing === true
      : false
      readonly property bool anyRunning: panelLoader.item
        ? panelLoader.item.anyRunning === true
        : false

        function open()
        {
          if (panelLoader.item) panelLoader.item.open()
            }

          function close()
          {
            if (panelLoader.item) panelLoader.item.close()
              }

            function toggle()
            {
              if (panelLoader.item) panelLoader.item.toggle()
                }

              function closeForPopoutSwitch()
              {
                if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
                  }

                function injectPanel()
                {
                  if (!panelLoader.item) return
                  panelLoader.item.bar = root.bar
                  panelLoader.item.anchorItem = button
                  panelLoader.item.hostWidget = root
                }

                implicitWidth: button.implicitWidth
                implicitHeight: button.implicitHeight

                onBarChanged: injectPanel()

                Loader {
                  id: panelLoader
                  active: true
                  source: Qt.resolvedUrl("Panel.qml")
                  visible: false
                  onLoaded: {
                    root.injectPanel()
                    Qt.callLater(root.injectPanel)
                  }
                }

                BarIconButton {
                  id: button
                  anchors.fill: parent
                  bar: root.bar
                  text: "󰍳"
                  tooltipText: root.anyRunning ? "Playing now" : "Open Prism Instances"
                  active: root.anyRunning
                  useActiveColor: true
                  activeColor: "#45ae37"
                  onPressed: function(buttonCode) {
                  if (buttonCode === Qt.LeftButton) root.toggle()
                    }
                }
              }
