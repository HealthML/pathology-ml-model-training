from flask import Flask
from flask import request, abort
import numpy as np
import cbor2

from hashlib import md5
import os
import os.path

from inference import NeuralNetwork

default_network = NeuralNetwork('/home/tim/Masterarbeit/artificial_data/input')


UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER


def secure_filename(filename):
    return filename.replace("/", "").replace("\\", "")


@app.route('/version', methods=['GET'])
def version():
    return "1.0", 200


@app.route('/data', methods=['POST'])
def upload():
    raw_data = request.get_data()
    hash = md5(raw_data).hexdigest()
    path = os.path.join(app.config['UPLOAD_FOLDER'], hash)
    with open(path, 'wb') as file:
        file.write(raw_data)
    return hash, 200


@app.route('/data/check/<hash>', methods=['GET'])
def check(hash):
    path = os.path.join(app.config['UPLOAD_FOLDER'], hash)
    return ("1" if os.path.isfile(path) else "0"), 200


@app.route('/data/<hash>', methods=['GET'])
def download(hash):
    path = os.path.join(app.config['UPLOAD_FOLDER'], hash)
    if not os.path.isfile(path):
        abort(404)

    with open(path, 'rb') as file:
        content = file.read()

    return content, 200


@app.route('/data/<hash>', methods=['DELETE'])
def delete_data(hash):
    path = os.path.join(app.config['UPLOAD_FOLDER'], hash)
    if not os.path.isfile(path):
        abort(404)

    os.remove(path)
    return '', 204


# @app.route('/model', methods=['GET'])
# def all_models(model_id):
#    # get list of models
#    return list_of_models


# @app.route('/model/<model_id>', methods=['GET'])
# def model_metadata(model_id):
#    # get metadata
#    return model_metadata


@app.route('/model/<model_id>/prediction/<hash>', methods=['GET'])
def predict(model_id, hash):
    if model_id != "default":
        print("Model not found:", model_id)
        abort(404)

    path = os.path.join(app.config['UPLOAD_FOLDER'], hash)
    if not os.path.isfile(path):
        print("Image not found:", hash)
        abort(404)

    output_img_data, centers = default_network.get_output_and_centers(path)

    output_hash = md5(output_img_data).hexdigest()
    path = os.path.join(app.config['UPLOAD_FOLDER'], output_hash)
    with open(path, 'wb') as file:
        file.write(output_img_data)

    centroids = np.array([[5, 6], [8, 19], [40, 45]]).astype(float)
    nuclei_data = {'xPositions': tuple(centroids[:, 0]),
                   'yPositions': tuple(centroids[:, 1])}

    result = {'outputImageHash': output_hash,
              'cellCenters': nuclei_data}

    cbor = cbor2.dumps(result)
    return cbor

# @app.route('/model/train/<data_hash>', methods=['GET'])
# def train(data_hash):
#    data = None
#    train, val = data
#    epoch_count = -1
#    # create dir
#    # unpack data there
#    # create metadata file
#    # train in other thread
#    return model_id
