# -*- coding: utf-8 -*-
"""
Created on Sat Apr 20 00:45:24 2019

@author: Antonia
"""

import numpy as np
from scipy import signal
from scipy.fftpack import dct

def fft(s,fs=32000,db_max=0,npts=4096):
    ''' calculate frequency, and level, intensity and amplitude spectrum '''
    w = np.hanning(npts)
    f = np.arange(npts/2+1)/npts*fs
    hann_correction = 1 / ( np.sum(w**2) / npts )
    s = np.multiply( w,s )
    Y = np.fft.rfft(s)
    S = np.abs(Y/npts)
    S[1:-1] *= np.sqrt(2)
    I = S ** 2
    I *= hann_correction
    I += 10 ** -13
    L = 10 * np.log10(I) + db_max + 10*np.log10(2)
    
    return f,L,I,S

def downsampleSignal( s, n ):
    list_s = []
    for i in range(n):
        s2 = signal.resample_poly(s, 1, 2 ** i)
        list_s.append(s2)
    return list_s

def fftMultiLow( list_s,fs=32000,db_max=0 ):
    ''' longer windows towards low f; low f multiple times '''
    list_f = []
    list_L = []
    npts = len(list_s[-1])
    for i in range(len(list_s)):
        s = list_s[i]
        f,L,I,S = fft(s[-npts:],fs/(2**i),db_max,npts)
        list_f.append(f)
        list_L.append(L)
    return list_f,list_L

def MultiCC(list_L):
    list_CC = []
    for i in range(len(list_L)):
        CC = dct(list_L[i])
        list_CC.append(CC[1:])
    return list_CC

def AuditoryFeatures( s, n, fs=32000,db_max=0 ):
    list_s        = downsampleSignal( s, n )
    list_f,list_L = fftMultiLow( list_s,fs,db_max )
    list_CC       = MultiCC(list_L)
    L             = flattenListOfArrays(list_L)
    CC            = flattenListOfArrays(list_CC)
    return L,CC

def flattenListOfArrays( list_A ):
    res = np.empty([0,])
    for i in range(len(list_A)):
        res = np.r_[res,list_A[i]]
    res = np.float32(res)
    return res

#def flattenList:
 
#def ListTo2D:
    