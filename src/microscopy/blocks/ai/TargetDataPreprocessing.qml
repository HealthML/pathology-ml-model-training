import QtQuick 2.12
import CustomElements 1.0
import "qrc:/core/ui/items"
import "qrc:/core/ui/controls"
import "qrc:/ui/app"

Rectangle {
    id: root
    color: "black"

    property real inputWidth
    property real inputHeight

    property real xOffset: 0.0
    property real yOffset: 0.0
    property real contentRotation: 0.0

    Loader {
        id: image1
        active: block.attr("targetSources").val[0] !== undefined
        visible: false  // drawn by shaderEffectSource
        sourceComponent: Component {
            TissueChannelUi {
                imageBlock: block.attr("targetSources").val[0]
            }
        }
    }
    ShaderEffectSource {
        id: source1
        anchors.fill: shaderEffect
        sourceRect: Qt.rect(0, 0, shaderEffect.width, shaderEffect.height)
        sourceItem: image1
        visible: false  // used by shaderEffect below
    }

    Loader {
        id: image2
        active: block.attr("targetSources").val[1] !== undefined
        visible: false  // drawn by shaderEffectSource
        sourceComponent: Component {
            TissueChannelUi {
                imageBlock: block.attr("targetSources").val[1]
            }
        }
    }
    ShaderEffectSource {
        id: source2
        anchors.fill: shaderEffect
        sourceRect: Qt.rect(0, 0, shaderEffect.width, shaderEffect.height)
        sourceItem: image2
        visible: false  // used by shaderEffect below
    }

    Loader {
        id: image3
        active: block.attr("targetSources").val[2] !== undefined
        visible: false  // drawn by shaderEffectSource
        sourceComponent: Component {
            TissueChannelUi {
                imageBlock: block.attr("targetSources").val[2]
            }
        }
    }
    ShaderEffectSource {
        id: source3
        anchors.fill: shaderEffect
        sourceRect: Qt.rect(0, 0, shaderEffect.width, shaderEffect.height)
        sourceItem: image3
        visible: false  // used by shaderEffect below
    }

    ShaderEffect {
        id: shaderEffect
        width: inputWidth
        height: inputHeight
        x: (block.area().x + (Math.min(block.area().width, width) - root.width) * xOffset) * -1
        y: (block.area().y + (Math.min(block.area().height, height) - root.height) * yOffset) * -1
        property variant src1: source1
        property variant src2: source2
        property variant src3: source3
        vertexShader: "qrc:/microscopy/ui/default_shader.vert"
        fragmentShader: "qrc:/microscopy/blocks/ai/target_preprocessing_shader.frag"
        blending: false

        transform: Rotation {
            origin.x: shaderEffect.x * -1 + root.width / 2
            origin.y: shaderEffect.y * -1 + root.height / 2
            axis { x: 0; y: 0; z: 1 }
            angle: contentRotation * 360
        }
    }
}
