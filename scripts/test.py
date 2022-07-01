#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri May 27 11:56:56 2022

@author: jpmcgeown
"""

import os
import sys
import pandas as pd
import numpy as np

df = pd.read_csv('/home/jpmcgeown/fmri_wf/first_level_dataset_clean.csv')

# df['networks'] = np.nan
networks = ['DMN', 'Salience']
df['networks'] = [networks for _ in range(len(df))]
# df['networks'][0] = ['DMN', 'Salience']

test = df.explode('networks', ignore_index=True)

pp_df = df.copy()
