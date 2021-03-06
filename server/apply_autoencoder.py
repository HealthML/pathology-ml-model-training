from fastai.vision import *


class TrainedAutoencoder(object):
    progress = 0.0

    def __init__(self, model_path: str):
        """
        :param model_path: the path containing the 'export.pkl' file
        """
        self.learn = load_learner(model_path)
        self.learn.model.decode = False

    def get_feature_vectors(self, img_path, cell_positions):
        img = open_image(img_path)
        feature_vectors = []

        for i, pos in enumerate(cell_positions):
            TrainedAutoencoder.progress = i / len(cell_positions)
            x = int(pos[0])
            y = int(pos[1])
            p, prediction, b = self.learn.predict(img.data[:, y-16:y+16, x-16:x+16])
            feature_vectors.append([float(x) for x in prediction])

        TrainedAutoencoder.progress = 0.0
        return feature_vectors

    def destroy(self):
        self.learn.destroy()
