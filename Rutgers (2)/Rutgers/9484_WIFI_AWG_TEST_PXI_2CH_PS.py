import os
import sys

import warnings # this is for GUI warnings
warnings.filterwarnings("ignore")

srcpath = os.path.realpath('SourceFiles')
sys.path.append(srcpath)

from tevisainst import TEVisaInst

import numpy as np

import matplotlib.pyplot as plt
from matplotlib.widgets import Button

import keyboard
import time

#init DAC
#Set rates for DAC 
sampleRateDAC = 1.1E9



#Preallocate
dacWaveI = []
dacWaveQ = []

data_type = np.uint16


filename = "WiFiImag.csv"
raw_data = open(filename, "rt")
dacWaveQ = np.loadtxt(raw_data, delimiter=",")
dacWaveQ = dacWaveQ.astype(data_type)

filename = "WiFiReal.csv"
raw_data = open(filename, "rt")
dacWaveI = np.loadtxt(raw_data, delimiter=",")
dacWaveI = dacWaveI.astype(data_type)

'''
# Connect to instrument(PXI)
sid = 4 #PXI slot of AWT on chassis
from teproteus import TEProteusAdmin as TepAdmin
admin = TepAdmin() #required to control PXI module
inst = admin.open_instrument(slot_id=sid) 
resp = inst.send_scpi_query("*IDN?") # Get the instrument's *IDN
print('connected to: ' + resp) # Print *IDN
'''
# Connect to instrument(LAN)
#inst_addr = 'TCPIP::169.254.124.21::5025::SOCKET' #Proteus 9484 in office '
inst_addr = 'TCPIP::192.168.1.3::5025::SOCKET' #Proteus Local Lan
inst_addr = 'TCPIP::169.254.18.80::5025::SOCKET' #Proteus Local Lan
inst = TEVisaInst(inst_addr)
resp = inst.send_scpi_query("*IDN?")
print('connected to: ' + resp)


inst.send_scpi_cmd('*CLS; *RST')

# global ch

def init_Channel():
    # initialize DAC

    
    #AWG channel
    cmd = ':INST:CHAN {0}'.format(ch)
    inst.send_scpi_cmd(cmd)
    
    print('Baseband Sample Rate Freq {0}'.format(sampleRateDAC))  
    
    cmd = ':FREQ:RAST {0}'.format(2.5E9) # force to max 16 bit DAC
    inst.send_scpi_cmd(cmd)
    inst.send_scpi_cmd(':INIT:CONT ON')
    # inst.send_scpi_cmd(':TRAC:DEL:ALL')
  
 

def makeSineData():
    global dacWaveI
    global dacWaveQ
    
    ampI = 1  
    ampQ = 1
    max_dac=65535
    half_dac=max_dac/2
    data_type = np.uint16
    
    #Set waveform length
    segLen = 1024 # Signal
    
    cycles = 2
    time = np.linspace(0, segLen-1, segLen)
    omega = 2 * np.pi * cycles
    dacWave = ampI*np.cos(omega*time/segLen)
    
    print('Frequency {0} Hz'.format(sampleRateDAC*cycles/segLen))
   
    dacWaveI = ((dacWave) + 1.0) * half_dac  
    dacWaveI = dacWaveI.astype(data_type)
    
    dacWave = ampQ*np.sin(omega*time/segLen)  
    
    dacWaveQ = ((dacWave) + 1.0) * half_dac  
    
    dacWaveQ = dacWaveQ.astype(data_type)
   
def makeOnPulse(segLen):
    global dacWaveI
    global dacWaveQ
    
    max_dac=65535
    half_dac=max_dac/2
    data_type = np.uint16
    
    #Set DC
    dacWaveDC = np.zeros(segLen) + half_dac    
    dacWaveI = dacWaveDC.astype(data_type)   
    
    dacWaveDC = np.zeros(segLen) + max_dac      
    dacWaveQ = dacWaveDC.astype(data_type)
    
    
def makeOffPulse(segLen):
    global dacWaveI
    global dacWaveQ
    
    max_dac=65535
    half_dac=max_dac/2
    data_type = np.uint16
    
    #Set DC
    dacWaveDC = np.zeros(segLen) + half_dac    
    dacWaveI = dacWaveDC.astype(data_type)   
             
    dacWaveQ = dacWaveI
    

def downLoad_IQ_DUC():
    global dacWaveI
    global dacWaveQ

    arr_tuple = (dacWaveI, dacWaveQ)
    dacWaveIQ = np.vstack(arr_tuple).reshape((-1,), order='F')

    print(segnum)
    # Select channel
    cmd = ':INST:CHAN {0}'.format(ch)
    inst.send_scpi_cmd(cmd)

    # Define segment
    cmd = ':TRAC:DEF {0}, {1}'.format(segnum, len(dacWaveIQ))
    inst.send_scpi_cmd(cmd)

    # Select the segment
    cmd = ':TRAC:SEL {0}'.format(segnum)
    inst.send_scpi_cmd(cmd)

    # Increase the timeout before writing binary-data:
    inst.timeout = 30000
    # Send the binary-data with *OPC? added to the beginning of its prefix.
    inst.write_binary_data('*OPC?; :TRAC:DATA', dacWaveIQ)
    # Set normal timeout
    inst.timeout = 10000

    resp = inst.send_scpi_query(':SYST:ERR?')
    print("Trace Download Error = ")
    print(resp)

def set_IQ_MOD():
    
    #Direct RF Output CH
    cmd = ':INST:CHAN {0}'.format(ch)
    inst.send_scpi_cmd(cmd)

    cmd = ':SOUR:MODE DUC'
    resp = inst.send_scpi_cmd(cmd)
    
    cmd = ':SOUR:INT X8'
    resp = inst.send_scpi_cmd(cmd)

    cmd = ':SOUR:IQM ONE'
    resp = inst.send_scpi_cmd(cmd)
    
    sampleRateDACInt = sampleRateDAC * 8
    print('Interpolated Sample Clk Freq {0}'.format(sampleRateDACInt))
    cmd = ':FREQ:RAST {0}'.format(sampleRateDACInt)
    resp = inst.send_scpi_cmd(cmd)
    
    resp = inst.send_scpi_query(':SYST:ERR?')
    print("IQ Set Error = ")
    print(resp)

    cmd = ':SOUR:NCO:CFR1 {0}'.format(ncoFreq)
    resp = inst.send_scpi_cmd(cmd)
    
    print('NCO CF: {0}'.format(ncoFreq))

 
def setTaskDUC():
   
    #Direct RF Output CH
    cmd = ':INST:CHAN {0}'.format(ch)
    inst.send_scpi_cmd(cmd)

    cmd = ':TASK:COMP:LENG 1'
    inst.send_scpi_cmd(cmd)
     
    cmd = ':TASK:COMP:SEL 1' 
    inst.send_scpi_cmd(cmd)
    md = ':TASK:COMP:SEGM {0}'.format(segnum)
    inst.send_scpi_cmd(cmd)
    # cmd = ':TASK:COMP:DTR ON'
    # inst.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:NEXT1 1'
    inst.send_scpi_cmd(cmd)
    
    cmd = ':TASK:COMP:WRITE'
    inst.send_scpi_cmd(cmd)
    cmd = ':SOUR:FUNC:MODE TASK'
    inst.send_scpi_cmd(cmd)
    
    
def setTaskDUC2():
   
    #Direct RF Output CH
    cmd = ':INST:CHAN {0}'.format(ch)
    inst.send_scpi_cmd(cmd)

    cmd = ':TASK:COMP:LENG 2'
    inst.send_scpi_cmd(cmd)
     
    cmd = ':TASK:COMP:SEL 1' 
    inst.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:SEGM {0}'.format(segnum)
    inst.send_scpi_cmd(cmd)
    # cmd = ':TASK:COMP:DTR ON'
    # inst.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:NEXT1 2'
    inst.send_scpi_cmd(cmd)
     
    cmd = ':TASK:COMP:SEL 2' 
    inst.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:SEGM {0}'.format(segnum+1)
    inst.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:LOOP 2' 
    inst.send_scpi_cmd(cmd)
    # cmd = ':TASK:COMP:DTR ON'
    # inst.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:NEXT1 1'
    inst.send_scpi_cmd(cmd)
    
    cmd = ':TASK:COMP:WRITE'
    inst.send_scpi_cmd(cmd)
    cmd = ':SOUR:FUNC:MODE TASK'
    inst.send_scpi_cmd(cmd)
        
    

# -------- IQ Mod ----------

ch=1
init_Channel();
#makeOnPulse(2048)
segnum=1
downLoad_IQ_DUC()
ncoFreq= 2.422E9
set_IQ_MOD()
#downLoad_mrkr()
setTaskDUC()

cmd = ':OUTP ON'
rc = inst.send_scpi_cmd(cmd)

ch=3
init_Channel();
makeOnPulse(20480)
segnum=2
downLoad_IQ_DUC()
makeOffPulse(20480)
segnum=3
downLoad_IQ_DUC()

ncoFreq= 2.0E9
set_IQ_MOD()
#downLoad_mrkr()
segnum=2
setTaskDUC2()

cmd = ':OUTP ON'
rc = inst.send_scpi_cmd(cmd)


inst.close_instrument()
