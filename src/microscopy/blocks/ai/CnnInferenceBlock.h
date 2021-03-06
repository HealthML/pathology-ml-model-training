#ifndef CNNINFERENCEBLOCK_H
#define CNNINFERENCEBLOCK_H

#include "core/block_basics/InOutBlock.h"

#include <QImage>
#include <QRect>

class BackendManager;


class CnnInferenceBlock : public InOutBlock {

    Q_OBJECT

public:

    static bool s_registered;
    static BlockInfo info() {
        static BlockInfo info;
        info.typeName = "CNN Inference";
        info.category << "Neural Network";
        info.helpText = "Prepares the input for a neural network, sends it to the server and "
                        "applies a neural network forward pass on it (also called inference).<br>"
                        "It then downloads the result and stores it in the Image block connected "
                        "to the second output or creates a new one.<br>"
                        "The server also finds the cell centers in this process and the result is "
                        "stored in the Dataset block connected to the top output or a new "
                        "Dataset is created for it.<br><br>"
                        "The model to use for the neural network can be specified and the area "
                        "to apply the network on can be restricted (for example to reduce the "
                        "computation time).";
        info.qmlFile = "qrc:/microscopy/blocks/ai/CnnInferenceBlock.qml";
        info.orderHint = 1000 + 200 + 1;
        info.complete<CnnInferenceBlock>();
        return info;
    }

    explicit CnnInferenceBlock(CoreController* controller, QString uid);

signals:
    void triggerInference();

public slots:
    virtual BlockInfo getBlockInfo() const override { return info(); }

    void runInference(QImage image);

    void updateSources();

    QRect area() const;

protected slots:
    void doInference(QByteArray imageData);

protected:
    BackendManager* m_backend;

    QPointer<NodeBase> m_input1Node;
    QPointer<NodeBase> m_input2Node;
    QPointer<NodeBase> m_input3Node;
    QPointer<NodeBase> m_areaNode;

    QPointer<NodeBase> m_outputImageNode;

    // runtime:
    VariantListAttribute m_inputSources;
    DoubleAttribute m_networkProgress;
    BoolAttribute m_running;

};

#endif // CNNINFERENCEBLOCK_H
