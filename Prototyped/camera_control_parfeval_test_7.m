%% This file is to test camera acquisition using TDT pulse as trigger

addpath(genpath('C:\TDT\TDTMatlabSDK'));

syn = SynapseAPI('localhost');
gizmos = syn.getGizmoNames();
params = syn.getParameterValue('PulseGen1', 'out_FloatOut')