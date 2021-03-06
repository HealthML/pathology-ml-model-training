#include "CellRendererBlock.h"

#include "core/CoreController.h"
#include "core/manager/BlockList.h"
#include "core/manager/BlockManager.h"
#include "core/manager/FileSystemManager.h"
#include "core/connections/Nodes.h"

#include "microscopy/blocks/basic/TissueImageBlock.h"
#include "microscopy/blocks/basic/CellDatabaseBlock.h"
#include "microscopy/manager/ViewManager.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QImageReader>

inline QString md5(QByteArray input) {
    QString result = QString(QCryptographicHash::hash(input, QCryptographicHash::Md5).toHex());
    return result;
}


bool CellRendererBlock::s_registered = BlockList::getInstance().addBlock(CellRendererBlock::info());

CellRendererBlock::CellRendererBlock(CoreController* controller, QString uid)
    : InOutBlock(controller, uid)
    , m_engine(m_rd())
    , m_renderType(this, "renderType", "DAPI")
    , m_largeNoise(this, "largeNoise", true)
    , m_smallNoise(this, "smallNoise", true)
    , m_feature(this, "feature", "x")
    , m_relativeOutputPath(this, "relativeOutputPath")
    , m_preferredWidth(this, "preferredWidth", -1, -1, std::numeric_limits<int>::max())
    , m_preferredHeight(this, "preferredHeight", -1, -1, std::numeric_limits<int>::max())
    , m_maxFeatureValue(this, "maxFeatureValue", 1.0, 0.000001, std::numeric_limits<double>::max(), /*persistent*/ false)
{
    m_runNode = createInputNode("run");
    m_runNode->enableImpulseDetection();
    connect(m_runNode, &NodeBase::impulseBegin, this, [this]() {
        updateReferenceSize();
        QTimer::singleShot(300, this, &CellRendererBlock::triggerRendering);
    });

    m_referenceImageNode = createInputNode("referenceImage");
    connect(m_referenceImageNode, &NodeBase::connectionChanged, this, &CellRendererBlock::updateReferenceSize);

    connect(&m_feature, &StringAttribute::valueChanged, this, &CellRendererBlock::updateFeatureMax);
}

double CellRendererBlock::areaSize() const {
    CellDatabaseBlock* db = m_inputNode->constData().referenceObject<CellDatabaseBlock>();
    if (!db) return 200;

    const QVector<int>& ids = m_inputNode->constData().ids();

    double maxPosition = 200.0;

    for (int idx: ids) {
        maxPosition = std::max(maxPosition, db->getFeature(CellDatabaseConstants::X_POS, idx));
        maxPosition = std::max(maxPosition, db->getFeature(CellDatabaseConstants::Y_POS, idx));
    }
    return maxPosition;
}

QVariantList CellRendererBlock::indexes() const {
    const QVector<int>& ids = m_inputNode->constData().ids();
    QVariantList list;
    for (int idx: ids) {
        list.append(idx);
    }
    return list;
}

QObject* CellRendererBlock::dbQml() const {
    return m_inputNode->constData().referenceObject<CellDatabaseBlock>();
}

void CellRendererBlock::saveRenderedImage(QImage image, QString type) {
    auto* referenceImage = m_referenceImageNode->getConnectedBlock<TissueImageBlock>();
    if (referenceImage) {
        auto info = QFileInfo(referenceImage->filePath());
        QString path = info.path() + "/" + m_relativeOutputPath;
        if (!QDir(path).exists()) {
            QDir().mkpath(path);
        }
        path = path + info.baseName() + ".png";
        image.save(path, "PNG", 80);
        m_outputNode->sendImpulse();
    } else {
        QByteArray imageData;
        QBuffer buffer(&imageData);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG", 80);
        QString hash = md5(imageData);
        QString path = m_controller->dao()->saveFile("renderedImages", hash + ".png", imageData);

        auto* block = m_controller->blockManager()->addNewBlock<TissueImageBlock>();
        if (!block) {
            qWarning() << "Could not create TissueImageBlock.";
            return;
        }
        block->focus();
        block->loadLocalFile(path);
        static_cast<StringAttribute*>(block->attr("label"))->setValue(type);
        static_cast<BoolAttribute*>(block->attr("ownsFile"))->setValue(true);
        block->onCreatedByUser();
    }
}

QVector<double> CellRendererBlock::randomRadii(float ellipseFactor, float variance) const {
    std::uniform_real_distribution<float> sizeVarianceDist(variance, 1.0f);
    std::uniform_real_distribution<float> ellipseDist(ellipseFactor, 1.0);
    std::uniform_real_distribution<float> rotationDist(0.0f, 1.0f);
    QVector<double> radii(24);

    const float rotation = rotationDist(m_engine);
    const float ellipseStrength = ellipseDist(m_engine);
    for (int j = 0; j < CellDatabaseConstants::RADII_COUNT; ++j) {
        const float pos = j / float(CellDatabaseConstants::RADII_COUNT - 1);
        // from https://math.stackexchange.com/a/432907 with a = 1 and b = ellipseStrength
        const float angle = (rotation + pos) * float(M_PI) * 2;
        const float ellipseRadius = ellipseStrength / std::sqrt(std::pow(std::sin(angle), 2.0f) + std::pow(ellipseFactor, 2.0f) * std::pow(std::cos(angle), 2.0f));
        radii[j] = double(ellipseRadius * sizeVarianceDist(m_engine));
    }
    return radii;
}

QStringList CellRendererBlock::availableFeatures() const {
    QStringList features = m_controller->manager<ViewManager>("viewManager")->availableFeatures();
    if (!features.contains(m_feature)) {
        features << m_feature;
    }
    return features;
}

void CellRendererBlock::updateFeatureMax() {
    if (m_feature.getValue().isEmpty()) return;
    CellDatabaseBlock* db = m_inputNode->constData().referenceObject<CellDatabaseBlock>();
    if (!db) return;

    const int featureId = db->getOrCreateFeatureId(m_feature);
    m_maxFeatureValue = db->featureMax(featureId);
    if (m_maxFeatureValue == 0.0) {
        m_maxFeatureValue = 1.0;
    }
}

void CellRendererBlock::updateReferenceSize() {
    bool referenceSizeAvailable = false;
    if (m_referenceImageNode->isConnected()) {
        auto* referenceImage = m_referenceImageNode->getConnectedBlock<TissueImageBlock>();
        if (referenceImage) {
            auto reader = QImageReader(referenceImage->filePath());
            auto size = reader.size();
            m_preferredWidth = size.width();
            m_preferredHeight = size.height();
            referenceSizeAvailable = m_preferredWidth > 0 && m_preferredHeight > 0;
        }
    }
    if (!referenceSizeAvailable) {
        m_preferredWidth = -1;
        m_preferredHeight = -1;
    }
}
