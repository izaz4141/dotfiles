// Copyright at EOF

import QtQuick 
import QtQuick.Layouts 
import QtQuick.Controls 

import qs.Services

RowLayout {

    readonly property real fontSize: 10
    spacing: fontSize

    readonly property var suspend: ["Suspend", "Suspend", true]
    readonly property var hibernate: ["Hibernate", "Hibernate", true]
    readonly property var reboot: ["Reboot", "Reboot", true]
    readonly property var shutdown: ["Shutdown", "Shutdown", true]

    Repeater {

        id: systemButtons
        model: [suspend, hibernate, reboot, shutdown]

        RoundButton {
            text: modelData[1]
            font.pointSize: fontSize * 0.8
            Layout.alignment: Qt.AlignHCenter
            icon.source: modelData ? Qt.resolvedUrl("../Assets/" + modelData[0] + ".svgz") : ""
            icon.height: 2 * Math.round((fontSize * 3) / 2)
            icon.width: 2 * Math.round((fontSize * 3) / 2)
            display: AbstractButton.TextUnderIcon
            visible: modelData[2]
            hoverEnabled: true
            palette.buttonText: root.palette.text
            background: Rectangle {
                height: 2
                color: "transparent"
                width: parent.width
                border.width: parent.activeFocus ? 1 : 0
                border.color: "transparent"
                anchors.top: parent.bottom
            }
            Keys.onReturnPressed: clicked()
            onClicked: {
                parent.forceActiveFocus()
                switch (index) {
                    case 0:
                        SessionService.suspend()
                        break
                    case 1:
                        SessionService.hibernate()
                        break
                    case 2:
                        SessionService.reboot()
                        break
                    case 3:
                        SessionService.poweroff()
                        break
                }
            }

            states: [
                State {
                    name: "pressed"
                    when: parent.children[index].down
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: Qt.darker(root.palette.highlight, 1.1)
                    }
                    PropertyChanges {
                        target: parent.children[index].background
                        border.color: Qt.darker(root.palette.highlight, 1.1)
                    }
                },
                State {
                    name: "hovered"
                    when: parent.children[index].hovered
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: Qt.lighter(root.palette.highlight, 1.1)
                    }
                    PropertyChanges {
                        target: parent.children[index].background
                        border.color: Qt.lighter(root.palette.highlight, 1.1)
                    }
                },
                State {
                    name: "focused"
                    when: parent.children[index].activeFocus
                    PropertyChanges {
                        target: parent.children[index]
                        palette.buttonText: root.palette.highlight
                    }
                    PropertyChanges {
                        target: parent.children[index].background
                        border.color: root.palette.highlight
                    }
                }
            ]

            transitions: [
                Transition {
                    PropertyAnimation {
                        properties: "palette.buttonText, border.color"
                        duration: 150
                    }
                }
            ]
        }
    }
}

// This file is part of SDDM Eucalyptus Drop.
// A theme for the Simple Display Desktop Manager.
//
// Copyright (C) 2018–2020 Marian Arlt
// Copyright (C)  <matt.jolly@footclan.ninja>
//
// SDDM Eucalyptus Drop is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, either version 3 of the License, or any later version.
//
// You are required to preserve this and any additional legal notices, either
// contained in this file or in other files that you received along with
// SDDM Eucalyptus Drop that refer to the author(s) in accordance with
// sections §4, §5 and specifically §7b of the GNU General Public License.
//
// SDDM Eucalyptus Drop is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with SDDM Eucalyptus Drop. If not, see <https://www.gnu.org/licenses/>
