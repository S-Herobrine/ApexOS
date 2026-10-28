import QtQuick 2.0;
import QtQuick.Controls 2.0;

Rectangle {
    id: presentation
    color: "#1E1B2E"

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: {
            slideView.currentIndex = (slideView.currentIndex + 1) % slideView.count
        }
    }

    SwipeView {
        id: slideView
        anchors.fill: parent

        // Slide 1: Welcome
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Welcome to ApexOS"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "The unified OS combining Linux, Windows, and Android"
                    font.pixelSize: 15
                    color: "#A78BFA"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Slide 2: Windows Experience
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Windows Familiarity & Productivity"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Centered Taskbar, Start Menu, C: and D: Drive Explorer, and Window Snapping"
                    font.pixelSize: 14
                    color: "#E8E0F0"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Slide 3: Android Subsystem
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Native Android Subsystem"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Google Play Store, Play Services, and multi-window Android app execution"
                    font.pixelSize: 14
                    color: "#E8E0F0"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Slide 4: Low-End PC Tuning
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Optimized for Low-End Hardware"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#FFFFFF"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Runs effortlessly on 4GB RAM with zRAM memory compression and sub-450MB idle"
                    font.pixelSize: 14
                    color: "#10B981"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    PageIndicator {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 16
        currentIndex: slideView.currentIndex
        count: slideView.count
    }
}
