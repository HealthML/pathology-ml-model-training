from autoencoder import Autoencoder, CellAutoencoderItemList
from global_training_tracker import training_tracker

from fastai.vision import Learner, MSELossFlat, apply_init, models
from fastai.vision.transform import dihedral, brightness, contrast
from fastai.callbacks import EarlyStoppingCallback, CSVLogger
from torch import nn

from pathlib import Path
from functools import partial
import os
import shutil


def prepare_and_train_autoencoder(params, model_id, img_path):
    model_path = Path("models")/model_id
    if os.path.exists(model_path):
        shutil.rmtree(model_path, ignore_errors=True)
    os.makedirs(model_path)

    if params['baseModel']:
        base_model_weights = Path("models")/params['baseModel']/'trained_model.pth'
    else:
        base_model_weights = ""

    # prepare train data:
    items = [(img_path, pos) for pos in params['cellPositions']]
    item_list = CellAutoencoderItemList(items, path=model_path/'input')
    item_lists = item_list.split_by_rand_pct()
    label_lists = item_lists.label_from_func(lambda x: x, label_cls=CellAutoencoderItemList)
    transforms = ((dihedral(),
                   brightness(change=(0.4, 0.6)),
                   contrast(scale=(0.9, 1.1)),
                   ), [])  # empty list at the end means no transforms for the validation set
    label_lists = label_lists.transform(transforms, tfm_y=True)
    databunch = label_lists.databunch(bs=1, num_workers=1)
    databunch.c = 3

    # TODO: store model name

    train_unet_autoencoder(model_path, base_model_weights, databunch, epochs=params['epochs'])


def train_unet_autoencoder(path, base_model_weights, databunch, epochs):
    training_tracker.dataset_size = len(databunch.train_dl)

    wd = 1e-3
    loss_gen = MSELossFlat()
    model = Autoencoder()

    learn = Learner(databunch, model, wd=wd, loss_func=loss_gen, callbacks=[training_tracker],
                    callback_fns=[CSVLogger,
                                  partial(EarlyStoppingCallback, monitor='valid_loss', min_delta=0.01, patience=2)])
    apply_init(model, nn.init.kaiming_normal_)
    # learn = learn.to_fp16()  # to save memory?

    if base_model_weights:
        print("Loading weights of base model...", base_model_weights)
        with open(base_model_weights, 'rb') as file:
            learn.load(file)

    print(learn.summary())  # TODO: save this to a file

    learning_rate = 1e-4
    print("Training...")
    # at this point, the early layers are frozen and only the last layers are trained
    learn.fit_one_cycle(epochs, learning_rate)
    learn.recorder.plot(return_fig=True).savefig(path/'lr_vs_loss.png')
    learn.recorder.plot_losses(return_fig=True).savefig(path/'losses.png')
    learn.recorder.plot_lr(return_fig=True).savefig(path/'learning_rate.png')
    #learn.recorder.plot_metrics(return_fig=True).savefig(path/'metrics.png')
    print("Saving...")
    with open(path/'trained_model.pth', 'wb') as file:
        learn.save(file)  # save for later finetuning
    learn.export()  # export for simple inference
    training_tracker.progress = 0.0
    print("Finished training and exported the model.")

