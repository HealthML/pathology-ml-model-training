import QtQuick 2.12
import QtGraphicalEffects 1.12
import CustomElements 1.0
import "qrc:/core/ui/items"
import "qrc:/core/ui/controls"

Rectangle {
    id: root
    color: "black"
    width: block.areaSize()
    height: block.areaSize()
    anchors.centerIn: parent

    property QtObject db: block.dbQml()

    Component.onCompleted: {
        console.log(block.indexes().length, cellRepeater.count)
    }

    Item {
        id: cells
        anchors.fill: parent
        opacity: 0.0

        Repeater {
            id: cellRepeater
            model: block.indexes()

            IrregularCircle {
                property int idx: modelData
                width: db.getFeature(2, idx) * 2
                height: width
                x: db.getFeature(0, idx) - width / 2
                y: db.getFeature(1, idx) - width / 2
                radii: db.getShapeVector(idx)
                outerColor: Qt.hsva(0, 0, 0.1 + Math.random() * 0.6, 1.0)
                innerColor: Qt.hsva(0, 0, Math.random() * 0.1, 1.0)
                visible: Math.random() > 0.5
            }
        }
    }

    GaussianBlur {
        anchors.fill: parent
        source: cells
        radius: 3
    }
}
