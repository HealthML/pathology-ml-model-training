import QtQuick 2.12
import QtQuick.Dialogs 1.2
import CustomElements 1.0
import "qrc:/core/ui/items"
import "qrc:/core/ui/controls"

BlockBase {
    id: root
    width: 200*dp
    height: 80*dp
    settingsComponent: settings

    StretchColumn {
        height: parent.height
        width: parent.width

        BlockRow {
            Spacer { implicitWidth: -0.5 }
            AttributeDotSlider {
                width: 30*dp
                attr: block.attr("blackLevel")
            }
            Spacer { implicitWidth: -1 }
            AttributeDotSlider {
                width: 30*dp
                attr: block.attr("whiteLevel")
            }
            Spacer { implicitWidth: -1 }
            AttributeDotSlider {
                width: 30*dp
                attr: block.attr("gamma")
            }
            Spacer { implicitWidth: -1 }
            AttributeDotSlider {
                width: 30*dp
                attr: block.attr("opacity")
            }
            Spacer { implicitWidth: -0.5 }
        }

        BlockRow {
            height: 20*dp
            implicitHeight: 0
            Repeater {
                model: ["Black", "White", "Gamma", "Alpha"]

                StretchText {
                    text: modelData
                    hAlign: Text.AlignHCenter
                    font.pixelSize: 12*dp
                    color: "#bbb"
                }
            }
        }

        DragArea {
            text: block.filename.slice(0, 20) || "Tissue Image"

            AttributeDotColorPicker {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 5*dp
                width: 26*dp
                height: 26*dp
                attr: block.attr("color")
            }

            OutputNode {
                node: block.node("outputNode")
            }
        }
    }

    // -------------------------- Settings ----------------------------

    Component {
        id: settings
        StretchColumn {
            leftMargin: 15*dp
            rightMargin: 15*dp
            defaultSize: 30*dp

            BlockRow {
                StretchText {
                    text: "Interactive Watershed:"
                }
                AttributeCheckbox {
                    width: 30*dp
                    attr: block.attr("isNucleiChannel")
                }
            }

            BlockRow {
                StretchText {
                    text: "Interpret 8 as 16 bit:"
                }
                AttributeCheckbox {
                    width: 30*dp
                    attr: block.attr("interpretAs16Bit")
                }
            }

            BlockRow {
                StretchText {
                    text: "Path:"
                }
                TextInput {
                    width: parent.width - 65*dp
                    text: block.attr("filePath").val || "No image loaded"
                    clip: true
                    color: "#ccc"
                }
            }

            BlockRow {
                ButtonBottomLine {
                    implicitWidth: -1
                    text: "Load new Image"
                    onClick: fileDialogLoader.active = true
                }

                Loader {
                    id: fileDialogLoader
                    active: false

                    sourceComponent: FileDialog {
                        id: fileDialog
                        title: "Select Tissue Image File"
                        folder: shortcuts.documents
                        selectMultiple: false
                        nameFilters: "Image Files (*.tiff *.tif *.png *.jpg *.jpeg *.bpm)"
                        onAccepted: {
                            if (fileUrl) {
                                block.attr("serverHash").val = ""
                                block.attr("filePath").val = fileUrl
                            }
                            fileDialogLoader.active = false
                        }
                        onRejected: {
                            fileDialogLoader.active = false
                        }
                        Component.onCompleted: {
                            // don't set visible to true before component is complete
                            // because otherwise the dialog will not be configured correctly
                            visible = true
                        }
                    }
                }
            }

            BlockRow {
                ButtonBottomLine {
                    implicitWidth: -1
                    text: "Upload"
                    allUpperCase: false
                    onPress: block.upload()

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width * block.attr("networkProgress").val
                        height: 2*dp
                        color: "lightgreen"

                        Behavior on width {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }
                }

                Item {
                    width: 15*dp
                    Rectangle {
                        width: 5*dp
                        height: 5*dp
                        anchors.centerIn: parent
                        radius: width / 2
                        color: block.attr("locallyAvailable").val ? "lightgreen" : "black"
                    }
                }
            }

            BlockRow {
                ButtonBottomLine {
                    implicitWidth: -1
                    text: "Download"
                    allUpperCase: false
                    onPress: block.download()
                }

                Item {
                    width: 15*dp
                    Rectangle {
                        width: 5*dp
                        height: 5*dp
                        anchors.centerIn: parent
                        radius: width / 2
                        color: block.attr("serverHash").val ? "lightgreen" : "black"
                    }
                }
            }

            BlockRow {
                ButtonBottomLine {
                    implicitWidth: -1
                    text: "Remove from Server"
                    allUpperCase: false
                    onPress: block.removeFromServer()
                }
            }

            Repeater {
                model: viewManager.views
                BlockRow {
                    CheckBox {
                        width: 30*dp
                        active: block.isAssignedTo(modelData.getUid())
                        onClick: {
                            if (active) {
                                block.assignView(modelData.getUid())
                            } else {
                                block.removeFromView(modelData.getUid())
                            }
                        }
                    }
                    StretchText {
                        text: "View " + (index + 1)
                    }
                }
            }
        }
    }  // end Settings Component
}

