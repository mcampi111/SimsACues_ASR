# -*- coding: utf-8 -*-
"""
Created on Fri Feb 15 23:36:50 2019

@author: js2251
"""

import numpy as np
import tensorflow as tf

def add_cognitive_noise(neurogram, snr_db=10):
    """Add pink noise to neurogram at specified SNR level"""
    # Calculate signal power
    signal_power = np.mean(neurogram ** 2)
    
    # Generate pink noise
    noise = np.random.normal(0, 1, neurogram.shape)
    # Simple approximation of pink noise frequency characteristics
    noise = np.cumsum(noise, axis=0) * 0.02
    noise = noise - np.mean(noise, axis=0)
    
    # Scale noise to achieve target SNR
    noise_power = np.mean(noise ** 2)
    if noise_power > 0:
        scaling_factor = np.sqrt(signal_power / (noise_power * 10**(snr_db/10)))
        noise = noise * scaling_factor
    
    # Add noise to neurogram
    noisy_neurogram = neurogram + noise
    return noisy_neurogram

class DataGenerator(tf.keras.utils.Sequence):
    ''' generate data from timit, indeces given separately to have possibility to ignore first n timesteps
        out_dim: 0-th element is batch size further elements input dim of NN
        reduce_factor to use only a fraction of the data per (randomly shuffled) batch'''
    def __init__(self, idx, X, Y, out_dim=(64,128,2,192), shuffle=True, reduce_factor = 1, non_causal_steps = 0):
        self.X = X
        self.Y = Y
        self.out_dim = out_dim
        self.batch_size = out_dim[0]
        self.time_dim = tuple(out_dim[1:-1])
        self.out_dim_nobatch = tuple(out_dim[1:])
        self.num_time_steps = 1
        for i in range(1,len(out_dim)-1):
            self.num_time_steps *= out_dim[i]
#       self.num_classes = int( max( Y ) + 1 )
        self.num_classes = 40# len(set(Y))  MARTA
        self.shuffle = shuffle
        self.idx = idx[ int(self.num_time_steps): ]
        self.non_causal_steps = non_causal_steps
        self.reduce_factor = reduce_factor
        self.on_epoch_end()        

    def __len__(self):
        ''' batches per epoch '''
        return int(np.floor(len(self.idx) / self.batch_size / self.reduce_factor))

    def __getitem__(self, index):       
        indexes = self.indexes[index*self.batch_size:(index+1)*self.batch_size] # Generate indexes of the batch        
        list_idx_temp = [self.idx[k] for k in indexes] # Find list of IDs
        X, Y = self.__data_generation(list_idx_temp)
        
        # Apply cognitive noise to each sample in the batch
        for i in range(X.shape[0]):
            X[i] = add_cognitive_noise(X[i])
            
        return X, Y

    def on_epoch_end(self):
        '''Update indexes after each epoch'''
        self.indexes = np.arange(len(self.idx))
        if self.shuffle == True:
            np.random.shuffle(self.indexes)

    def __data_generation(self, list_idx_temp):
        'Generates data containing batch_size samples' # X : (n_samples, *dim)

        X = np.empty(self.out_dim)
        Y = np.empty((self.batch_size), dtype=int)
        

        for i, ID in enumerate(list_idx_temp):
            X[i,] = self.X[ ID-self.num_time_steps+1:ID+1,  ].reshape( self.out_dim_nobatch )
            
            # MARTA MODIFIED HERE - Add bounds checking to prevent index out of bounds errors
            index = min(ID-self.non_causal_steps, len(self.Y) - 1)
            Y[i] = self.Y[index]

        #return X, tf.keras.utils.to_categorical(Y, num_classes=self.num_classes)  MARTA
        return X, tf.keras.utils.to_categorical(Y, num_classes=40, dtype='float32')
        
        
class PredictGenerator( DataGenerator ):
    
    def __init__(self, **kwargs):
        super(PredictGenerator, self).__init__(**kwargs)
    
    def on_epoch_end(self):
        pass
