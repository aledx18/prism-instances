import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.aledx18.prism-instances"
  manageIpc: false

  property var anchorItem: null
    property var hostWidget: null
      property bool launcherAvailable: false
        property string accountName: ""
          property var instances: []
          readonly property color panelForeground: Color.foreground
            readonly property string scanScript: Qt.resolvedUrl("scan.sh").toString().replace("file://", "")
            readonly property string launchScript: Qt.resolvedUrl("launch.sh").toString().replace("file://", "")
            readonly property string detectScript: Qt.resolvedUrl("detect-running.sh").toString().replace("file://", "")
            readonly property bool anyRunning: root.instances.some(function(i) { return i.running === true })

            property var runningState: ({})
            property int tick: 0
              property string instanceSearch: ""
                readonly property var filteredInstances: {
                  if (!root.instanceSearch) return root.instances
                  var needle = root.instanceSearch.toLowerCase()
                  return root.instances.filter(function(it) {
                  return (it.name && it.name.toLowerCase().indexOf(needle) !== -1)
                  || (it.version && it.version.toLowerCase().indexOf(needle) !== -1)
                  || (it.loader && it.loader.toLowerCase().indexOf(needle) !== -1)
                })
              }

              function open()
              {
                root.controller.show()
                root.refresh()
              }

              function close()
              {
                root.controller.hide()
              }

              function toggle()
              {
                if (root.opened) root.close()
                  else root.open()
              }

              function closeForPopoutSwitch()
              {
                root.close()
              }

              function switchPanel(direction)
              {
                if (root.bar && typeof root.bar.switchPanelFrom === "function")
                  return root.bar.switchPanelFrom(root.hostWidget || root, direction)
                return false
              }

              function refresh()
              {
                if (scanProcess.running) return
                scanProcess.collected = ""
                scanProcess.command = ["bash", root.scanScript]
                scanProcess.running = true
              }

              function parseScanOutput(raw)
              {
                root.launcherAvailable = false
                root.accountName = ""
                var rows = []
                var lines = String(raw || "").split("\n")
                for (var i = 0; i < lines.length; i++) {
                  var line = lines[i].replace(/\r$/, "")
                  if (!line.trim()) continue
                  var parts = line.split("\t")
                  if (parts[0] === "#available")
                  {
                    root.launcherAvailable = parts[1] === "1"
                    continue
                  }
                  if (parts[0] === "#account")
                  {
                    root.accountName = parts[1] || ""
                    continue
                  }
                  if (parts.length < 5) continue
                  rows.push({
                  id: parts[0],
                  name: parts[1],
                  version: parts[2],
                  loader: parts[3],
                  totalTime: parseInt(parts[4], 10) || 0,
                  iconPath: parts.length > 5 ? parts[5] : "",
                  lastLaunch: parts.length > 6 ? parseInt(parts[6], 10) || 0 : 0,
                  instancePath: parts.length > 7 ? parts[7] : ""
                })
              }
              return rows
            }

            function shellQuote(value)
            {
              return "'" + String(value).replace(/'/g, "'\\''") + "'"
            }

            function launch(instanceId)
            {
              if (!instanceId || !root.launcherAvailable) return
              root.close()
              Util.execDetached("bash " + root.shellQuote(root.launchScript)
              + " " + root.shellQuote(instanceId))
            }

            function openFolder(instancePath)
            {
              if (!instancePath) return
              root.close()
              Util.execDetached("xdg-open " + root.shellQuote(instancePath))
            }

            function formatPlayTime(seconds)
            {
              var minutes = Math.floor(seconds / 60)
              if (minutes <= 0) return "No play time recorded."
              if (minutes < 60) return minutes + "m played"
              var hours = Math.floor(minutes / 60)
              var remainingMinutes = minutes % 60
              return hours + "h " + remainingMinutes + "m played"
            }

            function formatLastPlayed(timestamp)
            {
              if (timestamp <= 0) return "Never"
              return Qt.formatDateTime(new Date(timestamp), "d MMM yyyy")
            }

            function fallbackIcon(loader)
            {
              var key = String(loader || "").toLowerCase()
              var file = "icons/unknown.png"
              if (key.indexOf("fabric") !== -1) file = "icons/fabric.png"
              else if (key.indexOf("neoforge") !== -1) file = "icons/neoforge.png"
                else if (key.indexOf("quilt") !== -1) file = "icons/fabric.png"
                  else if (key.indexOf("forge") !== -1) file = "icons/forge.png"
                    else if (key.indexOf("vanilla") !== -1 || key === "") file = "icons/vanilla.png"
                      return file
                    }

                    function runDetect()
                    {
                      if (detectProcess.running) return
                      detectProcess.command = ["bash", root.detectScript]
                      detectProcess.running = true
                    }

                    function mergeRunning(raw)
                    {
                      var live = []
                      try { live = JSON.parse(raw || "[]") } catch (e) { live = [] }

                      var liveById = {}
                        for (var i = 0; i < live.length; i++)
                          liveById[live[i].instanceId] = live[i]

                          var newState = {}
                            var nowEpoch = Math.floor(Date.now() / 1000)

                            var newInstances = root.instances.map(function(inst) {
                            var wasRunning = !!(root.runningState[inst.id])
                            var nowLive = liveById[inst.id]
                            var prevState = root.runningState[inst.id]

                            if (nowLive)
                            {
                              // Corriendo ahora (confirmado por detect-running.sh)
                              newState[inst.id] = {
                              pid: nowLive.pid,
                              sessionStart: nowLive.startEpoch,
                              missedTicks: 0
                            }
                            return Object.assign({}, inst, {
                            running: true,
                            pid: nowLive.pid,
                            sessionStart: nowLive.startEpoch
                          })
                        }

                        if (prevState)
                        {
                          // No apareció este tick. Toleramos hasta 2 misses antes de dar por cerrada la sesión.
                          var missed = (prevState.missedTicks || 0) + 1
                          if (missed < 2)
                          {
                            newState[inst.id] = Object.assign({}, prevState, { missedTicks: missed })
                            return Object.assign({}, inst, { running: true })
                          }
                          // Confirmado: sesión terminada -> notificar
                          var duration = nowEpoch - prevState.sessionStart
                          root.notifySessionEnd(inst.name, duration)
                        }

                        return Object.assign({}, inst, { running: false, pid: 0, sessionStart: 0 })
                      })

                      root.runningState = newState
                      root.instances = newInstances
                    }

                    function notifySessionEnd(name, durationSeconds)
                    {
                      var text = root.formatSession(durationSeconds)
                      Util.execDetached("notify-send " + root.shellQuote(name)
                      + " " + root.shellQuote("Played for " + text + " — session ended"))
                    }

                    function formatSession(seconds)
                    {
                      if (seconds < 60) return seconds + "s"
                      var minutes = Math.floor(seconds / 60)
                      if (minutes < 60) return minutes + "m"
                      var hours = Math.floor(minutes / 60)
                      return hours + "h " + (minutes % 60) + "m"
                    }
                    function reapplyRunningState()
                    {
                      root.instances = root.instances.map(function(inst) {
                      var state = root.runningState[inst.id]
                      if (!state) return inst
                      return Object.assign({}, inst, {
                      running: true,
                      pid: state.pid,
                      sessionStart: state.sessionStart
                    })
                  })
                }

                Component.onCompleted: root.refresh()

                Process {
                  id: scanProcess
                  property string collected: ""
                    command: []
                    stdout: StdioCollector {
                      id: scanOutput
                      waitForEnd: true
                    }
                    onExited: function(exitCode) {
                    if (exitCode === 0)
                      root.instances = root.parseScanOutput(scanOutput.text)
                    root.reapplyRunningState()
                  }
                }

                Process {
                  id: detectProcess
                  command: []
                  stdout: StdioCollector {
                    id: detectOutput
                    waitForEnd: true
                  }
                  onExited: function(exitCode) {
                  if (exitCode === 0)
                    root.mergeRunning(detectOutput.text)
                }
              }

              Timer {
                interval: 5000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: root.runDetect()
              }

              Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: root.tick++
              }

              KeyboardPanel {
                id: panel
                anchorItem: root.anchorItem
                owner: root.hostWidget || root
                bar: root.bar
                open: root.opened
                focusTarget: keyCatcher
                contentWidth: panel.fittedContentWidth(Style.space(420))
                contentHeight: panel.fittedContentHeight(content.implicitHeight)

                PanelKeyCatcher {
                  id: keyCatcher

                  anchors.fill: parent

                  onCloseRequested: root.close()
                  onTabRequested: function(direction) {
                  root.switchPanel(direction)
                }

                Column {
                  id: content

                  width: parent.width
                  spacing: Style.space(10)

                  // =========================================================
                  // HEADER
                  // =========================================================

                  Row {
                    width: parent.width
                    height: Style.space(48)
                    visible: root.launcherAvailable
                    spacing: Style.space(10)

                    Rectangle {
                      id: icon
                      width: Style.space(40)
                      height: Style.space(40)
                      radius: width / 2
                      color: "transparent"
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        anchors.centerIn: parent
                        text: "󰍳"
                        font.pixelSize: Style.space(30)
                        color: root.panelForeground
                      }
                    }

                    Column {
                      width: parent.width - icon.width - parent.spacing
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        id: title
                        width: parent.width
                        text: "Prism Instances"
                        color: root.panelForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        text: "Account: " + (root.accountName || "No active Prism account.")
                        color: root.panelForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        opacity: 0.75
                        elide: Text.ElideRight
                      }
                    }
                  }


                  // =========================================================
                  // SEPARATOR
                  // =========================================================

                  Rectangle {
                    width: parent.width
                    height: 1
                    visible: root.launcherAvailable
                    color: root.panelForeground
                    opacity: 0.15
                  }

                  Item {
                    width: parent.width
                    height: Style.space(32)
                    visible: root.launcherAvailable

                    Text {
                      id: searchIcon
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      text: "󰍉"
                      color: Util.alpha(root.panelForeground, 0.55)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      z: 2
                    }

                    TextField {
                      id: searchField
                      anchors.fill: parent
                      leftPadding: Style.space(28)
                      rightPadding: Style.space(26)
                      placeholderText: "Search instances…"
                      text: root.instanceSearch
                      onTextChanged: root.instanceSearch = text
                      foreground: root.panelForeground
                      Keys.onEscapePressed: {
                        if (root.instanceSearch.length > 0) root.instanceSearch = ""
                        else root.close()
                        }
                      }

                      Text {
                        visible: root.instanceSearch.length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: Util.alpha(root.panelForeground, 0.6)
                        font.pixelSize: Style.font.bodySmall
                        z: 2
                        MouseArea {
                          anchors.fill: parent
                          anchors.margins: -Style.space(6)
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            searchField.text = ""
                            root.instanceSearch = ""
                          }
                        }
                      }
                    }


                    // =========================================================
                    // DESCRIPTION
                    // =========================================================

                    Text {
                      width: parent.width

                      text: {
                        if (!root.launcherAvailable)
                          return "Prism Launcher is not installed."
                        if (root.instances.length > 0)
                          return "Select an instance to launch it."
                        return "No Minecraft instances found."
                      }

                      color: root.panelForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      wrapMode: Text.WordWrap

                      topPadding: Style.space(2)
                      bottomPadding: Style.space(2)
                    }

                    Text {
                      width: parent.width
                      visible: !root.launcherAvailable

                      text: "Install Prism Launcher to manage\nyour Minecraft instances from here."
                      color: root.panelForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      opacity: 0.6
                      wrapMode: Text.WordWrap

                      bottomPadding: Style.space(4)
                    }


                    // =========================================================
                    // INSTANCES
                    // =========================================================

                    Text {
                      width: parent.width
                      visible: root.launcherAvailable && root.instances.length > 0 && root.filteredInstances.length === 0
                      text: "No results for \"" + root.instanceSearch + "\""
                      color: Util.alpha(root.panelForeground, 0.7)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.bodySmall
                      wrapMode: Text.WordWrap
                      topPadding: Style.space(2)
                      bottomPadding: Style.space(2)
                    }

                    Column {
                      width: parent.width

                      spacing: Style.space(6)
                      visible: root.launcherAvailable && root.instances.length > 0

                      Repeater {
                        model: root.filteredInstances

                        BorderSurface {
                          id: instanceCard
                          required property var modelData
                          required property int index

                          width: parent.width
                          height: Style.space(64)
                          radius: Style.space(8)
                          color: "transparent"
                          borderSpec: Border.controlSpec("normal", root.panelForeground, Color.accent)
                          opacity: modelData.running === true ? 0.7 : 1.0

                          HoverHandler {
                            id: hoverHandler
                          }

                          Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: root.panelForeground
                            opacity: hoverHandler.hovered && modelData.running !== true ? 0.04 : 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                          }

                          Row {
                            id: cardRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.space(10)
                            anchors.rightMargin: Style.space(10)
                            spacing: Style.space(10)

                            // Bloque informativo (no clickeable)
                            Row {
                              width: cardRow.width - actionsRow.width - Style.space(10)
                              spacing: Style.space(10)
                              anchors.verticalCenter: parent.verticalCenter

                              Rectangle {
                                id: instanceIcon
                                width: Style.space(35)
                                height: Style.space(35)
                                radius: Style.space(8)
                                color: "#262734"
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                  anchors.fill: parent
                                  anchors.margins: Style.space(4)
                                  source: modelData.iconPath.length > 0 ? "file://" + modelData.iconPath : Qt.resolvedUrl(root.fallbackIcon(modelData.loader))
                                  fillMode: Image.PreserveAspectFit
                                }
                              }

                              Column {
                                id: instanceDetails
                                width: parent.width - (instanceIcon.visible ? instanceIcon.width + Style.space(10) : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(4)

                                Row {
                                  spacing: Style.space(6)
                                  width: parent.width

                                  Text {
                                    text: modelData.name
                                    color: root.panelForeground
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.bold: true
                                    elide: Text.ElideRight
                                  }

                                  Rectangle {
                                    width: Math.min(loaderVersionText.implicitWidth + Style.space(12), Style.space(100))
                                    height: Style.space(17)
                                    radius: height / 2
                                    color: "#262734"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                      id: loaderVersionText
                                      width: parent.width - Style.space(12)
                                      anchors.centerIn: parent
                                      horizontalAlignment: Text.AlignHCenter
                                      elide: Text.ElideRight
                                      text: ((modelData.loader || "Vanilla").split(" ")[0]) + " " + (modelData.version || "?")
                                      color: root.panelForeground
                                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                      font.pixelSize: Style.font.caption
                                    }
                                  }

                                }

                                Row {
                                  spacing: Style.space(6)
                                  width: parent.width

                                  Text {
                                    text: "󰃰 " + root.formatPlayTime(modelData.totalTime)
                                    color: root.panelForeground
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.caption
                                    opacity: 0.55
                                  }

                                  Text {
                                    text: "·"
                                    color: root.panelForeground
                                    font.pixelSize: Style.font.caption
                                    opacity: 0.3
                                  }

                                  Text {
                                    text: root.formatLastPlayed(modelData.lastLaunch)
                                    color: root.panelForeground
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.caption
                                    opacity: 0.55
                                  }


                                }
                              }
                            }

                            Row {
                              id: actionsRow
                              anchors.verticalCenter: parent.verticalCenter
                              spacing: Style.space(6)

                              Button {
                                id: launchButton
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.running === true ? "Running 🟢 " + root.formatSession(
                                  Math.floor(Date.now() / 1000) - modelData.sessionStart + (root.tick * 0)
                                ) : "󰐊 Play"
                                bordered: true
                                selected: false
                                foreground: root.panelForeground
                                fontSize: Style.font.caption
                                horizontalPadding: Style.space(10)
                                verticalPadding: Style.space(4)
                                tooltipText: modelData.running === true ? "" : "Launch"
                                enabled: modelData.running !== true
                                opacity: enabled ? 1.0 : 0.65
                                onClicked: root.launch(modelData.id)
                              }

                              Button {
                                id: folderButton
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰉋"
                                bordered: true
                                selected: false
                                foreground: root.panelForeground
                                fontSize: Style.font.caption
                                horizontalPadding: Style.space(8)
                                verticalPadding: Style.space(4)
                                tooltipText: "Open Folder"
                                onClicked: root.openFolder(modelData.instancePath)
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
