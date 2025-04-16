# -*- coding: utf-8 -*-
"""
Created on Wed May 26 16:03:51 2021

@author: tjbro
"""
import numpy as np
#import multiprocessing as mp
import pickle
from TimitData import savePhonemeInformation, getPhonemeDict, savePhonemeInformation39, savePhoneme39Dict, getPhonemeDict39,\
    getIndexNonSa, saveStartIndices, saveAuditoryInformation, scaleAuditoryVariables, removeStartOfPhonemes # , saveMelInformation
from srA1 import trainCausalNN
from srA1predict import combineModelCausalNN
from srA2 import trainNonCausalNN
from srA2predict import predictPhonemeProbabilitiesNonCausalNN
from TimitLanguage import getPhonemeTransitionP, getBiphoneme2PhonemeTransitionP, getTriphonemeStateTransitionP, getTriphonemeStartP, \
    getFullTriphonemeStartP, getPreviousTriphonemeStatesAndTransitionP, \
    ViterbiTriphonemeFromNN, ViterbiOutput2Phonemes, PhonemePerTimestep2Sequence, minimumEditDistance



#Run this segment of code to convert the neurogram from a mat file to a numpy array
import h5py
import sklearn
import sklearn.preprocessing
f=h5py.File('TIMIT_neurogram.mat','r')
data = f.get('TIMIT_neurogram')
data = np.transpose(data)
data = np.ascontiguousarray(data)
L = sklearn.preprocessing.scale(data)
np.save('TIMIT_neurogram_scaled',L)


#Run this segment of code to train the causal portion of the ASR.
#Run this first...it will run through 12 epochs. Choose the epoch with the highest validation accuracy, and pass that as the "load_model" input for the next call to trainCausalNN
trainCausalNN( filename_X = 'TIMIT_neurogram_scaled.npy', filename_Y = 'Phonemes39consecutive.npy', filename_idx = 'Phonemes39_position_index.npy', file_identifier_out = 'srA1_TIMIT_neurogram_a', epochs_to_save = 1, epochs_total = 12,  batch_size = 128)

#For the "load_model" input, change to the epoch with highest validation accuracy from the previous step
trainCausalNN( filename_X = 'TIMIT_neurogram_scaled.npy', filename_Y = 'Phonemes39consecutive.npy', filename_idx = 'Phonemes39_position_index.npy', file_identifier_out = 'srA1_TIMIT_neurogram_b', epochs_to_save = 1, epochs_total = 1, batch_size = 1024, load_model='srA1_TIMIT_neurogram_a_11.h5' )
trainCausalNN( filename_X = 'TIMIT_neurogram_scaled.npy', filename_Y = 'Phonemes39consecutive.npy', filename_idx = 'Phonemes39_position_index.npy', file_identifier_out = 'srA1_TIMIT_neurogram_c', epochs_to_save = 1, epochs_total = 1, batch_size = 4096, load_model='srA1_TIMIT_neurogram_b_0.h5' )

combineModelCausalNN( model_name_1 = 'srA1_TIMIT_neurogram_c_0', model_name_2 = 'srA1_TIMIT_neurogram_c_0', model_name_out = 'srA1_TIMIT_neurogram', filename_X1 = 'TIMIT_neurogram_scaled.npy', filename_X2 = 'TIMIT_neurogram_scaled.npy', filename_Y = 'Phonemes39consecutive.npy' )

#Run this segment of code to train the non-causal portion of the ASR
trainNonCausalNN( filename_X = 'srA1_TIMIT_neurogram_logp_combined_all.npy', filename_Y = 'Phonemes39consecutive.npy', file_identifier_out = 'srA2_TIMIT_neurogram_a', epochs_to_save = 1, epochs_total = 10, batch_size = 1024, reduce_factor = 10, load_model = None )
trainNonCausalNN( filename_X = 'srA1_TIMIT_neurogram_logp_combined_all.npy', filename_Y = 'Phonemes39consecutive.npy', file_identifier_out = 'srA2_TIMIT_neurogram_b', epochs_to_save = 1, epochs_total = 10, batch_size = 1024, reduce_factor = 1, load_model = 'srA2_TIMIT_neurogram_a_9.h5' )
    

#Run this segment to predict the Phoneme Probabilities. Input the the predictions from the
#Causal network, which will be stored in srA1_yourFileName_logp_combined_all.npy
#Note, if you are using the TRAIN set, set the data_split_factor to 0.9 to use the last 10% as validation data
#If using the TEST set, use a data_split_factor of 0 to use the whole Test set 
predictPhonemeProbabilitiesNonCausalNN( filename_X = 'srA1_TIMIT_neurogram_logp_combined_all.npy', filename_Y = 'Phonemes39consecutive.npy', model_name = 'srA2_TIMIT_neurogram_b_0', data_split_factor = 0)

#Generate confusion matrix from the predicted phoneme probabilities
from sklearn.metrics import confusion_matrix
import scipy.io

x = np.load('Phonemes39true_srA2_TIMIT_neurogram_b_0.npy')
y = np.load('Phonemes39pred_srA2_TIMIT_neurogram_b_0.npy')

cf_matrix = confusion_matrix(y,x)

scipy.io.savemat('cfMatrix_TIMIT_neurogram.mat', {'cf_matrix': cf_matrix})