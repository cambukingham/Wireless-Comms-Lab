import os
import sys
srcpath = os.path.realpath('SourceFiles')
sys.path.append(srcpath)
import warnings # this is for GUI warnings
warnings.filterwarnings("ignore")
from tevisainst import TEVisaInst
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import keyboard
import time
data_type = np.uint16



####### SET PARAMETERS HERE #######
enab2g = True
enabCW = False
enab5g6g = True

cFreq2g = 2.4E9 ## PROTEUS CHANNEL 1
cFreqCW = 7.2E9 ## PROTEUS CHANNEL 2
cFreq5g6g = 5.180E9 ## PROTEUS CHANNEL 3

voltage2g = 1
voltageCW = 0.5
voltage5g6g = 0.0775

filenameI = "LTE_FDD_100RB_QPSK_Re_Pn9.csv"
filenameQ = "LTE_FDD_100RB_QPSK_Im_Pn9.csv"

preTrigLoops = 2
#######  END SET PARAMETERS #######


#Set rates for DAC 
#sampleRateDAC = 1.1059E9
sampleRateDAC = 1.1059E9

raw_data = open(filenameQ, "rt")
dacWaveQ = np.loadtxt(raw_data, delimiter=",")
dacWaveQ = dacWaveQ.astype(data_type)

raw_data = open(filenameI, "rt")
dacWaveI = np.loadtxt(raw_data, delimiter=",")
dacWaveI = dacWaveI.astype(data_type)

# Init ADC
sampleRateADC = 2.7E9

#Set number of frames to be collected
numframes, framelen = 1, 96768

totlen = numframes * framelen

#Preallocate processing memory
wav1 = np.zeros(framelen//2, dtype=np.uint16)
xT = np.linspace(0, numframes * framelen,  numframes * framelen//2 )
xT = xT/(sampleRateADC/16)
tpCount = len(wav1)
timeStep = xT[1]-xT[0]
xF = np.fft.fftfreq(tpCount, timeStep)
xF = xF[range(int(len(wav1)/2))]



# Connect to instrument(LAN)
inst_addr = '192.168.1.21' #Proteus Local Lan
inst_Tx = TEVisaInst(inst_addr)
resp = inst_Tx.send_scpi_query("*IDN?")
print('Transmit connected to: ' + resp)
# initialize DAC
inst_Tx.send_scpi_cmd('*CLS; *RST')      

#AWG channel
ch = 1
cmd = ':INST:CHAN {0}'.format(ch)
inst_Tx.send_scpi_cmd(cmd)

print('CH 1 DAC Clk Freq {0}'.format(2.5E9))  # force to max 16 bit
cmd = ':FREQ:RAST {0}'.format(2.5E9)
inst_Tx.send_scpi_cmd(cmd)
inst_Tx.send_scpi_cmd(':INIT:CONT ON')
inst_Tx.send_scpi_cmd(':TRAC:DEL:ALL')


inst_addr = '192.168.1.14' #Proteus Local Lan
inst_Rx = TEVisaInst(inst_addr)
resp = inst_Rx.send_scpi_query("*IDN?")
print('Receive connected to: ' + resp)
# initialize DAC
inst_Rx.send_scpi_cmd('*CLS; *RST')   

print('ADC Clk Freq {0}'.format(sampleRateADC))
cmd = ':DIG:FREQ  {0}'.format(sampleRateADC)
inst_Rx.send_scpi_cmd(cmd)

# Start the digitizer

 # initialize DAC and take the first capture.
inst_Rx.send_scpi_cmd(':DIG:MODE DUAL')

print('ADC Clk Freq {0}'.format(sampleRateADC))
cmd = ':DIG:FREQ  {0}'.format(sampleRateADC)
inst_Rx.send_scpi_cmd(cmd)

inst_Rx.send_scpi_cmd(':DIG:ACQ:ZERO:ALL')
inst_Rx.send_scpi_cmd(':DIG:DDC:MODE COMP')   # DDC activation to complex i+jq
inst_Rx.send_scpi_cmd(':DIG:DDC:CFR1 {0}'.format(300E6))
inst_Rx.send_scpi_cmd(':DIG:DDC:PHAS1 0')  
inst_Rx.send_scpi_cmd(':DIG:DDC:DEC X16')    

# Enable capturing data from channel 1
inst_Rx.send_scpi_cmd(':DIG:CHAN:SEL 1')
inst_Rx.send_scpi_cmd(':DIG:TRIG:SOUR CPU')
inst_Rx.send_scpi_cmd(':DIG:CHAN:STATE ENAB')


inst_Rx.send_scpi_cmd(':DIG:CHAN:RANG LOW')
cmd = ':DIG:ACQuire:FRAM:DEF {0},{1}'.format(numframes, framelen)
inst_Rx.send_scpi_cmd(cmd)

# Select the frames for the capturing 
# (all the four frames in this example)
capture_first, capture_count = 1, numframes
cmd = ':DIG:ACQuire:FRAM:CAPT {0},{1}'.format(capture_first, capture_count)
inst_Rx.send_scpi_cmd(cmd)

resp = inst_Rx.send_scpi_query(':SYST:ERR?')
print("Digitizer Error = ")
print(resp)

# Create sub plots
figure, ax1 = plt.subplots(2,1)
   
def makeDCData(segLen):
    global dacWaveI
    global dacWaveQ
    
    max_dac=65535
    half_dac=max_dac/2
    data_type = np.uint16
    
    #Set DC
    dacWaveDC = np.zeros(segLen) + half_dac    
    dacWaveI = dacWaveDC.astype(data_type)   
    
    dacWaveDC = np.zeros(segLen) + half_dac      
    dacWaveQ = dacWaveDC.astype(data_type)  

def downLoad_IQ_DUC(ch, segnum):
    global dacWaveI
    global dacWaveQ

    arr_tuple = (dacWaveI, dacWaveQ)
    dacWaveIQ = np.vstack(arr_tuple).reshape((-1,), order='F')

    #segnum = 1

    # Select channel
    cmd = ':INST:CHAN {0}'.format(ch)
    inst_Tx.send_scpi_cmd(cmd)

    # Define segment
    cmd = ':TRAC:DEF {0}, {1}'.format(segnum, len(dacWaveIQ))
    inst_Tx.send_scpi_cmd(cmd)

    # Select the segment
    cmd = ':TRAC:SEL {0}'.format(segnum)
    inst_Tx.send_scpi_cmd(cmd)

    # Increase the timeout before writing binary-data:
    inst_Tx.timeout = 30000
    # Send the binary-data with *OPC? added to the beginning of its prefix.
    inst_Tx.write_binary_data('*OPC?; :TRAC:DATA', dacWaveIQ)
    # Set normal timeout
    inst_Tx.timeout = 10000

    resp = inst_Tx.send_scpi_query(':SYST:ERR?')
    print("Trace Download Error = ")
    print(resp)

def setTaskDUC(ch):
   
    #Direct RF Output CH
    cmd = ':INST:CHAN {0}'.format(ch)
    inst_Tx.send_scpi_cmd(cmd)

    cmd = ':TASK:COMP:LENG 2'
    inst_Tx.send_scpi_cmd(cmd)
     
    cmd = ':TASK:COMP:SEL 1' 
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:SEGM 1'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:DTR OFF'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:LOOP 1'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:ENAB INT'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:NEXT1 2'
    inst_Tx.send_scpi_cmd(cmd)
    
    cmd = ':TASK:COMP:SEL 2' 
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:SEGM 2'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:LOOP 1'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:NEXT1 2'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':TASK:COMP:ENAB NONE'
    inst_Tx.send_scpi_cmd(cmd)
    
    cmd = ':TASK:COMP:WRITE'
    inst_Tx.send_scpi_cmd(cmd)
    cmd = ':SOUR:FUNC:MODE TASK'
    inst_Tx.send_scpi_cmd(cmd)
        
    
def acquireData():
    wav1 = np.zeros(framelen, dtype=np.uint32)
    #inst.send_scpi_cmd(':DIG:TRIG:AWG:TDEL 280E-6')
    # Start the digitizer's capturing machine
    inst_Rx.send_scpi_cmd(':DIG:INIT ON')
    
    inst_Rx.send_scpi_cmd(':DIG:TRIG:IMM')
    # Stop the digitizer's capturing machine (to be on the safe side)
    inst_Rx.send_scpi_cmd(':DIG:INIT OFF')
    
    # Choose which frames to read (all in this example)
    inst_Rx.send_scpi_cmd(':DIG:DATA:SEL ALL')

    # Choose what to read 
    # (only the frame-data without the header in this example)
    inst_Rx.send_scpi_cmd(':DIG:DATA:TYPE FRAM')

    # Get the total data size (in bytes)
    resp = inst_Rx.send_scpi_query(':DIG:DATA:SIZE?')
    num_bytes = np.uint32(resp)
    
    # Read the data that was captured by channel 1:
    inst_Rx.send_scpi_cmd(':DIG:CHAN:SEL 1')

    resp = inst_Rx.read_binary_data(':DIG:DATA:READ?', wav1, num_bytes)
    print("Aquisition Error = ")
    print(resp)
     
    time.sleep(0.1)
    return wav1

def scaleTodBm(ydat):
    ydat = 0.250/4096*(np.add(ydat, -2048)) #shift to [-2048, 2048]
    ydat = (ydat**2)/50 #assume 50 Ohm termination
    ydat = 20*np.log10(ydat/0.001) #convert to dBm
    return ydat


# -------- IQ Mod ----------

downLoad_IQ_DUC(1,2)
makeDCData(13200)
downLoad_IQ_DUC(1,1)


cmd = ':SOUR:MODE DUC'
resp = inst_Tx.send_scpi_cmd(cmd)

cmd = ':SOUR:INT X8'
resp = inst_Tx.send_scpi_cmd(cmd)

cmd = ':SOUR:IQM ONE'
resp = inst_Tx.send_scpi_cmd(cmd)

sampleRateDACInt = sampleRateDAC * 8
print('Sample Clk Freq {0}'.format(sampleRateDACInt))
cmd = ':FREQ:RAST {0}'.format(sampleRateDACInt)
resp = inst_Tx.send_scpi_cmd(cmd)


resp = inst_Tx.send_scpi_query(':SYST:ERR?')
print("IQ Set Error = ")
print(resp)

setTaskDUC(1)


cmd = ':INST:CHAN 1'
resp = inst_Tx.send_scpi_cmd(cmd)
cmd = ':SOUR:NCO:CFR1 {0}'.format(cFreq2g)
resp = inst_Tx.send_scpi_cmd(cmd)
cmd = ':SOUR:VOLT {0}'.format(voltage2g)
inst_Tx.send_scpi_cmd(cmd)
if enab2g:
    cmd = ':OUTP ON'
    resp = inst_Tx.send_scpi_cmd(cmd)
else:
    cmd = ':OUTP OFF'
    resp = inst_Tx.send_scpi_cmd(cmd)

inst_Tx.send_scpi_cmd(':INST:CHAN 1')

TRG_SRC='CPU'
# Turn on trigger-coupling 
# This means that trigger 1 of the master-module goes to all modules.
# Temporarily, the enabling-signal should be INTernal instead of TRG1.
inst_Tx.send_scpi_cmd(':TRIG:COUPLE ON')
inst_Tx.send_scpi_cmd(':TRIG:CPU:MODE LOCAL')
inst_Tx.send_scpi_cmd('TRIG:SOUR:ENAB {}'.format(TRG_SRC))
#inst.send_scpi_cmd('TRIG:SEL {}'.format(TRG_SRC))
inst_Tx.send_scpi_cmd('TRIG:STAT ON')
  
resp = inst_Tx.send_scpi_query(':SYST:ERR?')

input('--- PRESS ENTER TO ENABLE JAM/CAPTURE ---')

inst_Tx.send_scpi_cmd('*TRG')

spectrumInv=0
wav1 = acquireData()   

Idat = np.int32(wav1[0::2]) - 16384
Qdat = np.int32(wav1[1::2]) - 16384
Adat = np.sqrt(Qdat**2 + Idat**2)

#wav2 = wav1 - np.average(wav1)
wav2 = Idat
w = np.blackman(len(wav2))
wavFFT = w * wav2
fourierTransform = np.fft.fft(wavFFT)/len(wav2)           # Normalize amplitude
fourierTransform = abs(fourierTransform[range(int(len(wav2)/2))]) # Exclude sampling frequency
if(spectrumInv == 1):
    fftPlot = 20*np.log10(fourierTransform[::-1])
else:
    fftPlot = 20*np.log10(fourierTransform)
    
time.sleep(0.1)


ax1[0].plot(xT, Idat, 'k')
ax1[0].set_xlabel('Time (s)')
ax1[0].set_ylabel('LinMag (au)')

ax1[1].plot(2*xF/1E6, fftPlot, 'k')
ax1[1].set_xlabel('FFT Frequency (MHz)')
ax1[1].set_ylabel('FFT Amp (dB)')


#cmd = ':INST:CHAN 1'
#resp = inst_Tx.send_scpi_cmd(cmd)

#cmd = ':OUTP OFF'
#resp = inst_Tx.send_scpi_cmd(cmd)


inst_Tx.close_instrument()
inst_Rx.close_instrument()
