% the Free Software Foundation, either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>. 
% =========================================================================
% Author: Joan Mercade
% Date: December 11, 2024
% Version: 1.1.0
% $Revision: 0001 $

%> @file TEProteusLib.m
%> @brief MATLAB Class Library fo Proteus
% ======================================================================
%> @brief Set of MATLAB functions to control AWG and Digitizer functionality in Proteus.
%
%> Functions include instrument control, data formating, waveform calculation, and processing functionality.

% ======================================================================

classdef TEProteusLib < handle
    properties
        %> Communication API, either 0(COMM_IFC_LAN), or 1(COMM_IFC_DLL)
        com_ifc         = 0; 
        %> IP Address to access the Proteus unit when controlled through COMM_IFC_LAN
        %> '127.0.0.1' = Local Host, your IP address here
        ip_addr         = '127.0.0.1';
        %> 5025 = Ip Default Port for TCP-IP Communications
        ip_port         = 5025;
        %> PXI Slot # to access the Proteus unit when controlled through COMM_IFC_DLL
        %> 0 means that the user will type this number at runtime
        pxi_slot        = 0; 
        %> Debugging level at runtime (0:low, 1:normal, 2:high) 
        paranoia_level  = 0; 
        %> Handle for administration session
        admin           = 0;
        %> Handle for instrument communication
        inst            = 0;
        %> Verbose functions
        lib_verbose = false;
        %> 
    end

%**************************************************************************

    properties (Constant=true)

        % LIBRARY ERRORS AND WARNINGS
        LIBRARY_ERROR_STRINGS   =[    "000: No Error";...
                                      "001: Unknown Error";...
                                      "002: Empty Array";...
                                      "003: Wrong Array Dimensions";...
                                      "004: Wrong Granularity";...
                                      "005: Wrong Parameter";...
                                      "006: Failed to Open File";...
                                      "007: No Valid Data in File";...
                                      "008: Failed to Create File";...
                                      "009: Bad Polyphase Code or Number"]

        LIBRARY_WARNING_STRINGS =[    "000: No Warnings";...
                                      "001: Unknown Warning";...
                                      "002: Empty Array";...
                                      "003: Wrong Array Dimensions";...
                                      "004: Truncated Array";...
                                      "005: Unsupported HPGL Command"];

        %> COMMUNICATION IFC
        COMM_IFC_LAN            = 0; %> VISA API
        COMM_IFC_DLL            = 1; %> TABOR'S DLL PXIe API
        COMM_IFC_TCP            = 2; %> RAW SOCKET COMM

        %> PARANOIA LEVEL
        %> For debiu
        PARANOIA_LVL_LOW        = 0; %> NO CHECKS
        PARANOIA_LVL_NORMAL     = 1; %> *OPC? CHECK
        PARANOIA_LVL_HIGH       = 2; %> ERROR CHECK

        %> PROTEUS MODEL
        PROTEUS_P1282M          = 0;
        PROTEUS_P1282D          = 1;
        PROTEUS_P1282B          = 2;
        PROTEUS_P1284M          = 3;
        PROTEUS_P1284D          = 4;
        PROTEUS_P1284B          = 5;
        PROTEUS_P1288D          = 6;
        PROTEUS_P1288B          = 7
        PROTEUS_P12812D         = 8;
        PROTEUS_P12812B         = 9;
        PROTEUS_P2582M          = 10;
        PROTEUS_P2582D          = 11;
        PROTEUS_P2582B          = 12;
        PROTEUS_P2584M          = 13;
        PROTEUS_P2584D          = 14;
        PROTEUS_P2584B          = 15;
        PROTEUS_P2588D          = 16;
        PROTEUS_P2588B          = 17;
        PROTEUS_P25812D         = 18;
        PROTEUS_P25812B         = 19;
        PROTEUS_P9482M          = 20;
        PROTEUS_P9482D          = 21;
        PROTEUS_P9482B          = 22;
        PROTEUS_P9484M          = 23;
        PROTEUS_P9484D          = 24;
        PROTEUS_P9484B          = 25;
        PROTEUS_P9488D          = 26;
        PROTEUS_P9488B          = 27;
        PROTEUS_P94812D         = 28;
        PROTEUS_P94812B         = 29;
        PROTEUS_P9082M          = 30;
        PROTEUS_P9082D          = 31;
        PROTEUS_P9082B          = 32;
        PROTEUS_P9084D          = 33;
        PROTEUS_P9084B          = 34;
        PROTEUS_P9086D          = 35;
        PROTEUS_P9086B          = 36;

        % PROTEUS MODULES
        PROTEUS_MODULE_00       = 0;
        PROTEUS_MODULE_01       = 1;
        PROTEUS_MODULE_02       = 2;
        PROTEUS_MODULE_03       = 3;
        PROTEUS_MODULE_04       = 4;
        PROTEUS_MODULE_05       = 5;
        PROTEUS_MODULE_06       = 6;
        PROTEUS_MODULE_07       = 7;
        PROTEUS_MODULE_08       = 8;
        PROTEUS_MODULE_09       = 9;
        PROTEUS_MODULE_10       = 10;
        PROTEUS_MODULE_11       = 11;

        % PROTEUS OPTIONS
        PROTEUS_OPT_STRINGS     =[  "4M1"; "4M2"; "4M3"; "4M4";...
                                    "8M1"; "8M2"; "8M3"; "8M4";...
                                    "16M1"; "16M2"; "16M3";...
                                    "DO1"; "DO2"; "DO3"; "DO4";...
                                    "DC1"; "DC2"; "DC3"; "DC4";...
                                    "DJ1"; "DJ2"; "DJ3";...
                                    "LVTTL1"; "LVTTL2"; "LVTTL3";...
                                    "MKR1"; "MKR2"; "MKR3";...
                                    "LTJ1"; "LTJ2"; "LTJ3"; "LTJ4";...
                                    "G1"; "G2"; "G3"; "G4";...
                                    "DUC"; "TRG"; "AWT"; "STM";...
                                    "FPGA_PROG"; "SHELL_CORE"];

        PROTEUS_OPT_TEXT        =[  "4 GS memory"; "4 GS memory"; "4 GS memory"; "4 GS memory";...
                                    "8 GS memory"; "8 GS memory"; "8 GS memory"; "8 GS memory";...
                                    "16 GS memory"; "16 GS memory"; "16 GS memory";...
                                    " 9 GHz BW direct output"; " 9 GHz BW direct output"; " 9 GHz BW direct output"; " 9 GHz BW direct output";...
                                    " DC output"; " DC output"; " DC output"; " DC output";...
                                    " Dynamic jump input"; " Dynamic jump input"; " Dynamic jump input";...
                                    "TTL 8 markers output"; "TTL 8 markers output"; "TTL 8 markers output";...
                                    "4 extra markers"; "8 extra markers"; " 12 extra markers";...
                                    "Ultra-low trigger jitter"; "Ultra-low trigger jitter"; "Ultra-low trigger jitter"; "Ultra-low trigger jitter";...
                                    "Low waveform granularity"; "Low waveform granularity"; "Low waveform granularity"; "Low waveform granularity";...
                                    "Digital up-converter"; "Fast trigger input"; "2 channel, 12-bit digitizer"; "Streaming";...
                                    "Built-in FPGA programming capability"; "Open FPGA programming capability"];

        PROTEUS_OPT_4M1         = 1;
        PROTEUS_OPT_4M2         = 2;
        PROTEUS_OPT_4M3         = 3;
        PROTEUS_OPT_4M4         = 4;
        PROTEUS_OPT_8M1         = 5;
        PROTEUS_OPT_8M2         = 6;
        PROTEUS_OPT_8M3         = 7;
        PROTEUS_OPT_8M4         = 8;
        PROTEUS_OPT_16M1        = 9;
        PROTEUS_OPT_16M2        = 10;
        PROTEUS_OPT_16M3        = 11;
        PROTEUS_OPT_DO1         = 12;
        PROTEUS_OPT_DO2         = 13;
        PROTEUS_OPT_DO3         = 14;
        PROTEUS_OPT_DO4         = 15;
        PROTEUS_OPT_DC1         = 16;
        PROTEUS_OPT_DC2         = 17;
        PROTEUS_OPT_DC3         = 18;
        PROTEUS_OPT_DC4         = 19;
        PROTEUS_OPT_DJ1         = 20;
        PROTEUS_OPT_DJ2         = 21;
        PROTEUS_OPT_DJ3         = 22;
        PROTEUS_OPT_LVTTL1      = 23;
        PROTEUS_OPT_LVTTL2      = 24;
        PROTEUS_OPT_LVTTL3      = 25;
        PROTEUS_OPT_MKR1        = 26;
        PROTEUS_OPT_MKR2        = 27;
        PROTEUS_OPT_MKR3        = 28;
        PROTEUS_OPT_LTJ1        = 29;
        PROTEUS_OPT_LTJ2        = 30;
        PROTEUS_OPT_LTJ3        = 31;
        PROTEUS_OPT_LTJ4        = 32;
        PROTEUS_OPT_G1          = 33;
        PROTEUS_OPT_G2          = 34;
        PROTEUS_OPT_G3          = 35;
        PROTEUS_OPT_G4          = 36;
        PROTEUS_OPT_DUC         = 37;
        PROTEUS_OPT_TRG         = 38;
        PROTEUS_OPT_AWT         = 39;
        PROTEUS_OPT_STM         = 40;
        PROTEUS_OPT_PROG        = 41;
        PROTEUS_OPT_SHELL       = 42;
        
        %> MISCELLANEOUS
        BINARY_CHUNK_XFER_SIZE  = 2^30;  %> Binary-Data Xfer Chunk Size (bytes)
        WAIT_PAUSE_SEC          = 0.02;  %> Waiting pause (seconds)
        DLL_PATH                = 'C:\\Windows\\System32\\TEPAdmin.dll'; %> Path for Tabor's DLL for PXIe access

        %> FILE FORMATS
        FILE_FMT_BINARY         = 0; %> Pure Binary
        FILE_FMT_CSV            = 1; %> CSV (Comma Sepparated Values)
        FILE_FMT_MATLAB         = 2; %> .mat format
        FILE_FMT_89600          = 3; %> Keysight 89600 VSA SW format
        FILE_FMT_XSERIES        = 4; %> Keysight X Series VSA format

        % TIME LAYOUT IN FILES
        FILE_TIME_IMPLICIT      = 0; %> File does not include time coordinates for each sample
        FILE_TIME_EXPLICIT      = 1; %> File includes explicit time coordinate for each sample

        % COMPLEX LAYOUT IN FILES
        FILE_COMPLEX_REAL       = 0; %> No complex data
        FILE_COMPLEX_IMPLICIT   = 1; %> Complex data in two real columns (real, imag)
        FILE_COMPLEX_EXPLICIT   = 2; %> Direct complex data (real) + i(imag)

        %> RESAMPLING CONSTANTS
        RESAMP_QUALITY          = 4.8;      %> Linked to interpolation filter length
        RESAMP_FILTER_RES       = 50000;    %> Linked to resolution of the filter lookup table. The higher, the better.
        RESAMP_BW_FRACTION      = 1.0;      %> Fraction of the Nyquist BW implemented by interpolation filter

        % TASK
        % ****

        %> TASK LIST INDEX CONSTANTS
        TASK_MATRIX_WIDTH       = 15;       %> Number of fields in Task Lists

        TASK_SEGMENT_PTR        = 1;
        TASK_TYPE               = 2;
        TASK_LOOPS              = 3;
        TASK_LOOPS_SEQ          = 4;
        TASK_NEXT               = 5;
        TASK_DTR_FLAG           = 6;
        TASK_ENABLE_EVENT       = 7;
        TASK_ABORT_EVENT        = 8;
        TASK_IDLE_MODE          = 9;
        TASK_IDLE_LVL           = 10;
        TASK_JUMP_MODE          = 11;
        TASK_DELAY              = 12;
        TASK_NEXT2              = 13;
        TASK_KEEP               = 14;
        TASK_DEST               = 15;

        % TASK DESTINATION CHOICES
        TASK_DEST_NEXT          = 0;
        TASK_DEST_FBTRG         = 1;
        TASK_DEST_TRG           = 2;
        TASK_DEST_NTSEL         = 3;
        TASK_DEST_SCENARIO      = 4;
        TASK_DEST_DSP           = 5;
        TASK_DEST_DSIG          = 6;

        % TASK IDLE MODE
        TASK_IDLE_MODE_DC       = 0;
        TASK_IDLE_MODE_FIRST    = 1;
        TASK_IDLE_MODE_CURRENT  = 2;

        %> TASK JUMP MODE
        TASK_JUMP_MODE_EVENT    = 0;
        TASK_JUMP_MODE_IMMED    = 1;

        %> TASK KEEP MODE
        TASK_KEEP_OFF           = 0;
        TASK_KEEP_ON            = 1;

        %> TASK TYPE
        TASK_TYPE_SINGLE        = 0;
        TASK_TYPE_START         = 1;
        TASK_TYPE_SEQ           = 2;
        TASK_TYPE_END           = 3;

        %> TASK LIST ENABLE/DISABLE EVENTS
        TASK_EVENT_NONE         = 0;
        TASK_EVENT_TRG1         = 1;
        TASK_EVENT_TRG2         = 2;
        TASK_EVENT_CPU          = 3;
        TASK_EVENT_INT          = 4;

        %> TASK LIST RUN MODE
        TASK_RUN_MODE_TASK      = 0;
        TASK_RUN_MODE_CONT      = 1;
        TASK_RUN_MODE_TRG1      = 2;
        TASK_RUN_MODE_TRG2      = 3;
        TASK_RUN_MODE_CPU       = 4;
        TASK_RUN_MODE_INT       = 5;

        % MARKERS
        % *******

        %> MARKER MODE
        AWG_MKR_MODE_TWO        = 2; %> 2 Markers per channel
        AWG_MKR_MODE_FOUR       = 4; %> 4 Markers per channel
        AWG_MKR_MODE_EIGHT      = 8; %> 8 Markers per channel
        %> AWG MODE
        AWG_MODE_DIRECT         = 0;
        AWG_MODE_DUC            = 1;
        AWG_MODE_NCO            = 2;
        %> AWG CHANNEL
        AWG_CHAN_EXT            = -1;
        AWG_CHAN_ALL            = 0;
        AWG_CHAN_CH01           = 1;
        AWG_CHAN_CH02           = 2;
        AWG_CHAN_CH03           = 3;
        AWG_CHAN_CH04           = 4;
        AWG_CHAN_CH05           = 5;
        AWG_CHAN_CH06           = 6;
        AWG_CHAN_CH07           = 7;
        AWG_CHAN_CH08           = 8;
        AWG_CHAN_CH09           = 9;
        AWG_CHAN_CH10           = 10;
        AWG_CHAN_CH11           = 11;
        AWG_CHAN_CH12           = 12;
        %> IQ_MODE
        AWG_IQ_MODE_HALF        = 0;
        AWG_IQ_MODE_ONE         = 1;
        AWG_IQ_MODE_TWO         = 2;
        %> INTERPOLATION FACTORS
        %> DAC chip interpolation factors. X1, X2, X4, X8 implemented in
        %> Proteus.
        AWG_INTERPOL_X1         = 1;
        AWG_INTERPOL_X2         = 2;
        AWG_INTERPOL_X4         = 4;
        AWG_INTERPOL_X6         = 6;
        AWG_INTERPOL_X8         = 8;
        AWG_INTERPOL_X10        = 10;
        AWG_INTERPOL_X12        = 12;
        AWG_INTERPOL_X16        = 16;
        AWG_INTERPOL_X18        = 18;
        AWG_INTERPOL_X20        = 20;
        AWG_INTERPOL_X24        = 24;
        %> AWG Repeat Sample Factor
        AWG_REPEAT_X1           = 1; % NONE
        AWG_REPEAT_X2           = 2;
        AWG_REPEAT_X4           = 4;
        AWG_REPEAT_X8           = 8;
        %> INTERPOLATION FILTERS
        %> Interpolation filter stages and pointer in filter vector
        AWG_INT_FILTER_0        = 1;
        AWG_INT_FILTER_1        = 2;
        AWG_INT_FILTER_0_5X     = 3;
        AWG_INT_FILTER_2        = 4;
        AWG_INT_FILTER_0_3X     = 5;
        AWG_INT_FILTER_3        = 6;
        AWG_INT_FILTER_1_3X     = 7;
        AWG_INT_FILTER_INVSINC  = 8;
        AWG_INT_FILTER_NOFILTER = 9;
        % NCO
        % ***
        %> NCO MODE
        AWG_NCO_MODE_SINGLE     = 1; %> One NCO per AWG Channel
        AWG_NCO_MODE_DUAL       = 2; %> Two NCO per AWG Channel
        %> NCOs RESOLUTION
        %> Phase accumulator (PA) and Frequency Control Register (FCR) size
        AWG_NCO_RES_DAC         = 48; %> NCO DUC, 48 bits
        AWG_NCO_RES_ADC         = 32; %> NCO DDC, 32 bits
        % OTHER AWG SETTINGS
        % ******************
        %> DAC MODE
        AWG_DAC_MODE_8          = 8;
        AWG_DAC_MODE_16         = 16;
        %> MKR DIVIDER
        AWG_MKR_DIV_8           = 8; % Marker divider for 8-bit mode
        AWG_MKR_DIV_16          = 2; % Marker divider for 16-bit mode
        %> MKR POLARITY
        AWG_MKR_POL_NONE        = 0; % Marker not active
        AWG_MKR_POL_POS         = 1; % Marker in High State
        AWG_MKR_POL_NEG         = 2; % Marker in lOW State
        %> AWG TRIGGER MODE
        AWG_TRG_MODE_CONT       = 0;
        AWG_TRG_MODE_TRIG       = 1;
        % TRIGGER SLOPE
        AWG_TRG_SLOPE_NEG       = 0;
        AWG_TRG_SLOPE_POS       = 1;
        %> CPU TRIGGER MODE
        AWG_CPU_TRG_LOCAL       = 0;
        AWG_CPU_TRG_GLOBAL      = 1;

        % DIGITIZER CONSTANTS
        % *******************

        %> DIGITIZER SELECTION
        DIG_SEL_ALL             = 1; % All ADCs selected
        DIG_SEL_ONE             = 1; % ADC #1 selected
        DIG_SEL_TWO             = 2; % ADC #2 selected (Future use)
        %> DIGITIZER CHANNEL
        DIG_CHAN_ALL            = 0;
        DIG_CHAN_ONE            = 1;
        DIG_CHAN_TWO            = 2;
        %> DIGITIZER CHANNEL ENABLE
        DIG_CHAN_DISABLE        = 0;
        DIG_CHAN_ENABLE         = 1;
        %> DIGITIZER ACQ MODE
        DIG_ACQ_MODE_SINGLE     = 1;
        DIG_ACQ_MODE_DUAL       = 2;
        %> DIGITIZER RANGES
        DIG_RNG_250MV           = 1;
        DIG_RNG_400MV           = 2;
        DIG_RNG_500MV           = 3;
        %> DIGITIZER GRANULARITY
        DIG_GRANUL_SINGLE       = 96; %> Granularity for Single Mode
        DIG_GRANUL_DUAL         = 48; %> Granularity for Dual Mode
        DIG_GRANUL_AVG          = 20; %> Granularity for Averaging
        %> DIGITIZER DDC STATE
        DIG_MODE_REAL           = 0; %> DDC Disabled
        DIG_MODE_COMPLEX        = 1; %> DDC Enabled
        %> DDC BINDING
        DIG_DDC_BIND_OFF        = 0;
        DIG_DDC_BIND_ON         = 1;
        %> DDC DECIMATION
        DIG_DDC_DECIM_NONE      = 1; %> No decimation in DDC
        DIG_DDC_DECIM_X4        = 4; %> 4X decimation in DDC
        DIG_DDC_DECIM_X16       = 16; %> x16 decimation in DDC, not available
        %> ADC RESOLUTION
        DIG_ADC_RESOL_REAL      = 12; %> ADC resolution real mode
        DIG_ADC_RESOL_COMPLEX   = 15; %> ADC resolution for Complex (DDC) Mode
        %> CLK SOURCE
        DIG_CLK_SRC_DIG         = 0; %> Internal Clock Source for ADC
        DIG_CLK_SRC_AWG         = 1; %> AWG Clock Source for ADC.
        %> TRIGGER SOURCE
        DIG_TRG_CPU             = 0; %> Trigger Source *TRG
        DIG_TRG_EXT             = 1; %> ADC's External Trigger Input
        DIG_TRG_CH1             = 2; %> Self trigger CH1
        DIG_TRG_CH2             = 3; %> Self trigger CH2
        DIG_TRG_DTR_CH1         = 4; %> Task trigger AWG CH1
        DIG_TRG_DTR_CH2         = 5; %> Task trigger AWG CH2
        DIG_TRG_DTR_CH3         = 6; %> Task trigger AWG CH3
        DIG_TRG_DTR_CH4         = 7; %> Task trigger AWG CH4
        DIG_TRG_MR1             = 8; %> Rise of Marker Bit CH1
        DIG_TRG_MF1             = 9; %> Fall of Marker Bit CH2
        DIG_TRG_MR2             = 10; %> Rise of Marker Bit CH1
        DIG_TRG_MF2             = 11; %> Fall of Marker Bit CH2
        %> TRIGGER TYPE
        DIG_TRG_TYPE_EDGE       = 0; %> Trigger Type Edge
        DIG_TRG_TYPE_GATE       = 1; %> Trigger Type Gate
        DIG_TRG_TYPE_WEDGE      = 2; %> Trigger Type Window Edge
        DIG_TRG_TYPE_WGATE      = 3; %> Trigger Type Window Gate
        DIG_TRG_TYPE_CUSTOM     = 4; %> Future Usage
        %> TRIGGER SLOPE
        DIG_TRG_EDGE_NEG        = 0;
        DIG_TRG_EDGE_POS        = 1;
        %> TRIGGER TIME CONDITION
        % For Trigger Types Window Edge and Window Gate
        DIG_TRG_COND_SHORTER    = 0;
        DIG_TRG_COND_GREATER    = 1;
        %> DIGITIZER MARKER MODE STATE
        DIG_MKR_OFF             = 0;
        DIG_MKR_ON              = 1;
        %> DIGITIZER AVERAGING
        DIG_AVG_OFF             = 0;
        DIG_AVG_ON              = 1;
        %> DIGITIZER ACQUISTION TYPE
        DIG_ACQ_TYPE_ALL        = 0; %> Headers and Frames
        DIG_ACQ_TYPE_HEADERS    = 1; %> Headers Only, no Frames
        %> DIGITIZER DATA TYPE
        % Selection of data to be transferred from Digitizer
        DIG_DATA_TYPE_FRAMES    = 0; %> Only Frames
        DIG_DATA_TYPE_HEADERS   = 1; %> Only Headers
        DIG_DATA_TYPE_BOTH      = 2; %> Frames and Headers
        % DIGITIZER DATA SELECT
        DIG_DATA_SEL_ALL        = 0;
        DIG_DATA_SEL_FRAMES     = 1;
        DIG_DATA_SEL_CHUNK      = 2;
        %> DIGITIZER DATA SELECT
        % Digitizer data type selection
        DIG_DATA_FMT_U16        = 0; %> Unsigned Integer (16-bits)
        DIG_DATA_FMT_SINGLE     = 1; %> Single Precision Floating Point
        DIG_DATA_FMT_DOUBLE     = 2; %> Double Precision Floating Point
        %> DIGITIZER INIT STATE
        DIG_INIT_OFF            = 0;
        DIG_INIT_ON             = 1;
        %> DIGITIZER EQUIVALENT TIME MODE
        %> Equivalent Time 
        DIG_ET_MODE_NORMAL      = 0; %> Equivalent time normal (scope mode)
        DIG_ET_MODE_EYE_DIAG    = 1; %> Equivalent time Eye Diagram
        %> EYE DIAGRAM SIZES FOR COLOR GRADED
        DIG_ET_EYE_BINS         = 1000; %> Num of bins in time domain for ET
        DIG_ET_EYE_LVLS         = 1000; %> Num of levels for ET
        %> MINIMUM JITTER IN EYE SEARCH ITERATIONS
        DIG_ET_JIT_SEARCH_ITER  = 10; %> Number of iterations to find optimal threshold for Jitter
        %> FRAME HEADERS ADC
        DIG_FRAME_HDR_TOT_SIZE  = 88; %> Total size of headers in bytes
        DIG_FRAME_HDR_TRG_LOC   = 1; %> Field #1: Trigger Location
        DIG_FRAME_HDR_GATE_ADDR = 2; %> Field #2: Gate Address
        DIG_FRAME_HDR_MIN_ADC   = 3; %> Field #3: Min ADC levl for frame
        DIG_FRAME_HDR_MAX_ADC   = 4; %> Field #4: Max ADC levl for frame
        DIG_FRAME_HDR_TIMESTAMP = 5; %> Field #5: Timestamp
        %> FRAME HEADERS FIELD SIZE
        DIG_FRAME_HDR_FLD_SIZE  = [4, 4, 4, 4, 8]; %> Size of the fields in bytes

        % PULSE CONSTANTS
        % ***************

        %> PULSE TYPE
        PULSE_TYPE_SQUARE       = 0;
        PULSE_TYPE_TRAPEZOIDAL  = 1;
        PULSE_TYPE_GAUSSIAN     = 2;
        PULSE_TYPE_NMR_FID      = 3;
        PULSE_TYPE_CHIRP_UP     = 4;
        PULSE_TYPE_CHIRP_DOWN   = 5;
        PULSE_TYPE_CHIRP_UPDOWN = 6;
        PULSE_TYPE_CHIRP_DOWNUP = 7;
        PULSE_TYPE_BARKER_CODE  = 8;
        PULSE_TYPE_FRANK_CODE   = 9;
        PULSE_TYPE_P1_CODE      = 10;
        PULSE_TYPE_P2_CODE      = 11;
        PULSE_TYPE_P3_CODE      = 12;
        PULSE_TYPE_P4_CODE      = 13;
        PULSE_TYPE_FILE         = 14;
        PULSE_TYPE_RAISEDCOS    = 15;
        PULSE_TYPE_POLYPHASE    = 16;
        PULSE_TYPE_NL_FM        = 17;
        PULSE_TYPR_MFSK         = 18;
        PULSE_TYPE_STEP_FM      = 19;
        %> PULSE EDGE SHAPE
        PULSE_EDGE_LINEAR       = 0;
        PULSE_EDGE_EXPONENTIAL  = 1;
        PULSE_EDGE_GAUSSIAN     = 2;
        PULSE_EDGE_COSINE       = 3;
        %> PULSE EDGE THRESHOLD
        PULSE_EDGE_THRESH_0100  = 0;
        PULSE_EDGE_THRESH_2080  = 1;
        PULSE_EDGE_THRESH_1090  = 2;
        %> PULSE JITTER_CATEGORIES
        PULSE_JITTER_CAT_SINE   = 1;
        PULSE_JITTER_CAT_RAND   = 2;
        PULSE_JITTER_CAT_SSC    = 3;
        PULSE_JITTER_CAT_MTONE  = 4;
        %> PULSE RANDOM JITTER PROFILE
        PULSE_JITTER_RND_GAUSS  = 0;
        PULSE_JITTER_RND_UNIF   = 1;
        %> PULSE SSC JITTER PROFILE
        PULSE_JITTER_SSC_TRIAN  = 0; %> Triangular
        PULSE_JITTER_SSC_SAWTH  = 1; %> Sawtooth
        %> PULSE JITTER UNIT
        PULSE_JITTER_UNIT_UI    = 0; %> Unit Intervals
        PULSE_JITTER_UNIT_SEC   = 1; %> Seconds
        %> BARKER CODE PULSES
        PULSE_BARKER_02         = 2;
        PULSE_BARKER_02_BIS     = 0;
        PULSE_BARKER_03         = 3;
        PULSE_BARKER_04         = 3;
        PULSE_BARKER_04_BIS     = 1;
        PULSE_BARKER_05         = 5;
        PULSE_BARKER_07         = 7;
        PULSE_BARKER_11         = 11;
        PULSE_BARKER_13         = 13;
        %> BARKER CODES SEQUENCES
        PULSE_BARKER_02_SEQ     = [+1, -1];
        PULSE_BARKER_02_BIS_SEQ = [+1, +1];
        PULSE_BARKER_03_SEQ     = [+1, +1, -1];
        PULSE_BARKER_04_SEQ     = [+1, +1, -1, +1];
        PULSE_BARKER_04_BIS_SEQ = [+1, +1, +1, -1];
        PULSE_BARKER_05_SEQ     = [+1, +1, +1, -1, +1];
        PULSE_BARKER_07_SEQ     = [+1, +1, +1, -1, -1, +1, -1];
        PULSE_BARKER_11_SEQ     = [+1, +1, +1, -1, -1, -1, +1, -1, -1, +1, -1];
        PULSE_BARKER_13_SEQ     = [+1, +1, +1, +1, +1, -1, -1, +1, +1, -1, +1, -1, +1];

        % MODULATION CONSTANTS
        % *********************

        %> ANALOG MODULATION SCHEME
        MOD_ANALOG_AM           = -1;
        MOD_ANALOG_FM           = -2;
        MOD_ANALOG_PM           = -3;
        MOD_ANALOG_SSB          = -4;
        %> DIGITAL MODULATION SCHEME
        MOD_SCHEME_BPSK         = 0;
        MOD_SCHEME_QPSK         = 1;
        MOD_SCHEME_QAM16        = 2;
        MOD_SCHEME_QAM32        = 3;
        MOD_SCHEME_QAM64        = 4;
        MOD_SCHEME_QAM128       = 5;
        MOD_SCHEME_QAM256       = 6;
        MOD_SCHEME_QAM512       = 7;
        MOD_SCHEME_QAM1024      = 8;
        MOD_SCHEME_FSK          = 9;
        MOD_SCHEME_MSK          = 10;
        MOD_SCHEME_8PSK         = 11;
        MOD_SCHEME_APSK16       = 12;
        MOD_SCHEME_APSK32       = 13;
        %> DVB-S2 CODING
        MOD_DVBS2_CODE_1_4      = 0;
        MOD_DVBS2_CODE_1_3      = 1;
        MOD_DVBS2_CODE_2_5      = 2;
        MOD_DVBS2_CODE_1_2      = 3;
        MOD_DVBS2_CODE_3_5      = 4;
        MOD_DVBS2_CODE_2_3      = 5;
        MOD_DVBS2_CODE_3_4      = 6;
        MOD_DVBS2_CODE_4_5      = 7;
        MOD_DVBS2_CODE_5_6      = 8;
        MOD_DVBS2_CODE_7_8      = 9;
        MOD_DVBS2_CODE_8_9      = 10;
        MOD_DVBS2_CODE_9_10     = 11;

        %> BASEBAND RAISED-COSINE FILTER TYPE
        MOD_BB_FILTER_NORMAL    = 0; %> Raise-Cosine Basedband Filter
        MOD_BB_FILTER_SQRT      = 1; %> Sqrt of Raised Cosine Baseband Filter

        %> MULTI-TONE PHASE DISTRIBUTION
        MTONE_PHASE_CONSTANT    = 0; %> Same phase for all tones
        MTONE_PHASE_RANDOM      = 1; %> Random Phase for all tones
        MTONE_PHASE_NEWMAN      = 2; %> Newman (Quadratic) phase distribution
        MTONE_PHASE_RUDIN       = 3; %> Rudin phase distribution for 2^N tones

        %> DATA SOURCE
        DATA_SRC_PRBS           = 0;
        DATA_SRC_USER           = 1;
        DATA_SRC_FILE           = 2;

        %> DATA ENCODING
        DATA_ENCDG_NONE         = 0;
        DATA_ENCDG_NRZL         = 1;
        DATA_ENCDG_NRZI         = 2;
        DATA_ENCDG_MANCHESTER   = 3;
        DATA_ENCDG_DME          = 4;
        DATA_ENCDG_DME_T1S      = 5; 

        %> PRBS SEQUENCES
        PRBS_RND                = 1;
        PRBS_2                  = 2;
        PRBS_3                  = 3;
        PRBS_4                  = 4;
        PRBS_5                  = 5;
        PRBS_6                  = 6;
        PRBS_7                  = 7;
        PRBS_8                  = 8;
        PRBS_9                  = 9;
        PRBS_10                 = 10;
        PRBS_11                 = 11;
        PRBS_12                 = 12;
        PRBS_13                 = 13;
        PRBS_14                 = 14;
        PRBS_15                 = 15;
        PRBS_16                 = 16;
        PRBS_17                 = 17;
        PRBS_18                 = 18;
        PRBS_19                 = 19;
        PRBS_20                 = 20;
        PRBS_21                 = 21;
        PRBS_22                 = 22;
        PRBS_23                 = 23;
        PRBS_24                 = 24;
        PRBS_25                 = 25;
        PRBS_26                 = 26;
        PRBS_27                 = 27;
        PRBS_28                 = 28;
        PRBS_29                 = 29;
        PRBS_30                 = 30;
        PRBS_31                 = 31;
        PRBS_32                 = 32;
        PRBS_33                 = 33;
        PRBS_34                 = 34;
        PRBS_35                 = 35;
        PRBS_36                 = 36;
        PRBS_37                 = 37;
        PRBS_38                 = 38;
        PRBS_39                 = 39;
        PRBS_USER               = 100;

        %> DATA WFM TYPE
        DATA_TYPE_BILVL_NRZ     = 0; %> Two levels Non Return to Zero
        DATA_TYPE_BILVL_RZ      = 1; %> Two levels Return to Zero
        DATA_TYPE_PAM4          = 2;
        DATA_TYPE_PAM8          = 3;
        DATA_TYPE_PAM3          = 4;
        DATA_TYPE_PAM5          = 5;   

        %> SCOPE MODEL
        SCOPE_MODEL_TEKTRONIX   = 0;
        SCOPE_MODEL_KEYSIGHT    = 10;
        SCOPE_MODEL_LECROY      = 20;
        SCOPE_MODEL_ROHDE       = 30;
        SCOPE_MODEL_RIGOL       = 40;
        SCOPE_MODEL_SIGLENT     = 50;
        SCOPE_MODEL_PICO        = 60;

        % SCOPE TRIGGER SLOPE
        SCOPE_TRG_SLOPE_NEG     = 0;
        SCOPE_TRG_SLOPE_POS     = 1;

        % STANDARD FUNCTION CONSTANTS
        STD_FUNC_SINE           = 0; % Sine Waveform
        STD_FUNC_TRIANGLE       = 1; % Triangular Waveform
        STD_FUNC_SQUARE         = 2; % Square Waveform
        STD_FUNC_RAMP           = 3; % Ramp Waveform

        % CALIBRATION CONSTANTS
        % *********************

        % CALIBRATION TYPE / CORRECTION TYPE
        CAL_TYPE_AMPL_PHASE     = 0;
        CAL_TYPE_AMPL           = 1;

        % CALIBRATION / CORRECTION FACTOR FILE FORMAT
        CAL_TYPE_FILE_FMT_MAT   = 0;
        CAL_TYPE_FILE_FMT_CSV   = 1;

        % CORRECTION MODE
        CORR_MODE_FREQ_DOMAIN   = 0;
        CORR_MODE_TIME_DOMAIN   = 1;

        % CORRECTION INTERPOLATION FACTOR
        CORR_INTERPOL_DEFAULT   = 10;

        % CORRECTION FACTOR FREQ UNITS
        CORR_FREQ_UNIT_HZ       = 0;
        CORR_FREQ_UNIT_KHZ      = 1;
        CORR_FREQ_UNIT_MHZ      = 2;
        CORR_FREQ_UNIT_GHZ      = 3; 

        % CORRECTION FACTOR AMPL UNITS
        CORR_AMPL_UNIT_DB       = 0;
        CORR_AMPL_UNIT_LINEAR   = 1;

        % CORRECTION FACTOR PHASE UNITS
        CORR_PHASE_UNIT_DEGREE  = 0;
        CORR_PHASE_UNIT_RADIAN  = 1;
    end

%**************************************************************************
    methods % public methods
%**************************************************************************

% =========================================================================
%> @brief Class constructor
%>
%> This constructor generates an instance of the class and initializes some global variables 
%>
%> @return instance of the TEProteusLib class.
% =========================================================================
        function obj = TEProteusLib()
            obj.com_ifc         = obj.COMM_IFC_LAN;
            obj.paranoia_level  = obj.PARANOIA_LVL_LOW; % Paranoia level (0:low, 1:normal, 2:high)
        end

%**************************************************************************

        %> UTILITY METHODS
        %> ***************

% =========================================================================
%> @brief Get description of error or warning
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param error_code Error coe. Negative for Errors, positive for warnings
%> @retval error_description string with the description of error/warning
% =========================================================================
        function error_description = GetErrorDescription(obj, error_code)
            if error_code <= 0
                error_code = -error_code + 1;
                if error_code > length(obj.LIBRARY_ERROR_STRINGS)
                    error_code = 1;
                end
                error_description = obj.LIBRARY_ERROR_STRINGS(error_code);
                error_description = strcat("Error ", error_description);
            else
                error_code = error_code + 1;
                if error_code > length(obj.LIBRARY_WARNING_STRINGS)
                    error_code = 1;
                end
                error_description = obj.LIBRARY_WARNING_STRINGS(error_code);
                error_description = strcat("Warning ", error_description);
            end
        end

%**************************************************************************
function error = ReportError(obj, error_code)
    if error_code == 0
        fprintf("No error\n")
    elseif error_code > 0
        fprintf("Warning: %s\n", obj.GetErrorDescription(error_code))
    else
        fprintf("Error: %s\n", obj.GetErrorDescription(error_code))
    end
    error = error_code;
end
%**************************************************************************

% =========================================================================
%> @brief Conversion of vectors of integers or chars to string
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param netStr vector to be converted to string
%> @retval str converted string
% =========================================================================
        function [str, error] = netStrToStr(obj, netStr)
            error = 0;
            try
                str = convertCharsToStrings(char(netStr));
            catch
                error = -1;
                str = '';
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a AWG Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_awg_setup created struct with default values
% =========================================================================
        function [default_awg_setup, error] = CreateDefaultAwgSetup(obj)
            % Fields:
            %   mode = AWG Mode, DIR, DUC, NCO
            %   iq_mode = half, one , two
            %   cfr = carrier frequencies (vector)
            %   phase = carrier initial phase (vector)
            %   six_db = true = on (vector)
            %   channel = target channel #
            %   segment = target segment #
            %   wfm_map = size for each waveform in myWfm, 0 = one wfm
            %   dac_resolution = DAC resolution (8 or 16 bit)
            %   volt = Voltage peak-to-peak. < 0 = MAX
            %   offset = DC Offset
            %   sampling_rate = AWG sampling rate
            %   interpol = interpolation factor
            %   output_state = 1, output ON, 0, output OFF
            %   report_time = 1, report download time, 0, do not report
            error = 0;

            default_awg_setup.handle        = int8.empty;
            default_awg_setup.sel_module    = obj.PROTEUS_MODULE_01;
            default_awg_setup.mode          = obj.AWG_MODE_DIRECT;
            default_awg_setup.iq_mode       = obj.AWG_IQ_MODE_ONE;
            default_awg_setup.nco_mode      = obj.AWG_NCO_MODE_SINGLE;
            default_awg_setup.interpol      = obj.AWG_INTERPOL_X1;
            default_awg_setup.repeat_sample = obj.AWG_REPEAT_X1;
            default_awg_setup.granularity   = 32;
            default_awg_setup.min_segment   = 64;
            default_awg_setup.cfr1          = 0.0;
            default_awg_setup.phase1        = 0.0;
            default_awg_setup.six_db1       = true;
            default_awg_setup.cfr2          = 0.0;
            default_awg_setup.phase2        = 0.0;
            default_awg_setup.six_db2       = true;
            default_awg_setup.channel       = obj.AWG_CHAN_CH01;
            default_awg_setup.segment       = 1;
            default_awg_setup.wfm_map       = 0;
            default_awg_setup.dac_resolution= obj.AWG_DAC_MODE_16;
            default_awg_setup.volt          = 0.0;
            default_awg_setup.offset        = 0.0;
            default_awg_setup.delay         = 0.0;
            default_awg_setup.mkr_mode      = obj.AWG_MKR_MODE_TWO;
            default_awg_setup.mkr1_state    = 1;
            default_awg_setup.mkr1_volt     = 0.5;
            default_awg_setup.mkr1_offset   = 0.0;
            default_awg_setup.mkr1_skew     = 0.0;
            default_awg_setup.mkr2_state    = 1;
            default_awg_setup.mkr2_volt     = 0.5;
            default_awg_setup.mkr2_offset   = 0.0;
            default_awg_setup.mkr2_skew     = 0.0;
            default_awg_setup.mkr3_state    = 1;
            default_awg_setup.mkr3_volt     = 0.5;
            default_awg_setup.mkr3_offset   = 0.0;
            default_awg_setup.mkr3_skew     = 0.0;
            default_awg_setup.mkr4_state    = 1;
            default_awg_setup.mkr4_volt     = 0.5;
            default_awg_setup.mkr4_offset   = 0.0;
            default_awg_setup.mkr4_skew     = 0.0;
            default_awg_setup.sampling_rate = 1E9;            
            default_awg_setup.dtr_delay     = 0.0;
            default_awg_setup.output_state  = 1;
            default_awg_setup.report_time   = 1;
            default_awg_setup.trg_mode      = obj.AWG_TRG_MODE_CONT;
            default_awg_setup.trg_src       = obj.TASK_EVENT_NONE;
            default_awg_setup.trg_slope     = obj.AWG_TRG_SLOPE_POS;
            default_awg_setup.trg_lvl       = 0.0;
            default_awg_setup.trg_count     = 1;
            default_awg_setup.trg_idle_mode = obj.TASK_IDLE_MODE_DC;
            default_awg_setup.trg_idle_lvl  = 32768;
            default_awg_setup.task_run_mode = obj.TASK_RUN_MODE_TASK;
            default_awg_setup.cpu_trg_mode  = obj.AWG_CPU_TRG_LOCAL;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Digitizer Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_dig_setup created struct with default values
% =========================================================================
        function [default_dig_setup, error] = CreateDefaultDigSetup(obj)
            error = 0;

            default_dig_setup.sel_module    =   1;
            default_dig_setup.mode          =   obj.DIG_ACQ_MODE_DUAL;
            default_dig_setup.acq_type      =   obj.DIG_ACQ_TYPE_ALL;
            default_dig_setup.data_type     =   obj.DIG_DATA_TYPE_FRAMES;

            default_dig_setup.ddc           =   obj.DIG_MODE_REAL;
            default_dig_setup.adc_resol     =   obj.DIG_ADC_RESOL_REAL;
            default_dig_setup.ddc_decim     =   obj.DIG_DDC_DECIM_NONE;
            default_dig_setup.ddc_bind      =   obj.DIG_DDC_BIND_OFF;
            default_dig_setup.granul        =   obj.DIG_GRANUL_DUAL;
            default_dig_setup.clk_src       =   obj.DIG_CLK_SRC_DIG;
            default_dig_setup.mkr           =   obj.DIG_MKR_OFF;
            default_dig_setup.avg           =   obj.DIG_AVG_OFF;

            default_dig_setup.ch_state      = [ obj.DIG_CHAN_ENABLE,...
                                                obj.DIG_CHAN_ENABLE];            
            default_dig_setup.rng           = [ obj.DIG_RNG_500MV,...
                                                obj.DIG_RNG_500MV];
            default_dig_setup.trg_src       = [ obj.DIG_TRG_CH1,...
                                                obj.DIG_TRG_CH1];
            default_dig_setup.dtr_src       = [ obj.DIG_TRG_DTR_CH1,...
                                                obj.DIG_TRG_DTR_CH1];
            default_dig_setup.trg_slope     = [ obj.DIG_TRG_EDGE_POS,...
                                                obj.DIG_TRG_EDGE_POS];
            default_dig_setup.trg_type      = [ obj.DIG_TRG_TYPE_EDGE,...
                                                obj.DIG_TRG_TYPE_EDGE];
            default_dig_setup.trg_cond      = [ obj.DIG_TRG_COND_GREATER,...
                                                obj.DIG_TRG_COND_GREATER];

            default_dig_setup.frame_length  =   2^10;            
            default_dig_setup.num_of_frames =   1;
            default_dig_setup.acq_timeout   =   180.0;
            default_dig_setup.pre_trigger   =   0;
            default_dig_setup.sampling_rate =   2.7E9;
            default_dig_setup.num_avgs      =   1;            
            default_dig_setup.trg_holdoff   =   0.0;

            default_dig_setup.offset        =   [0.0, 0.0];
            default_dig_setup.trg_lvl       =   [0.0, 0.0];
            default_dig_setup.cfr           =   [1E9, 1E9];
            default_dig_setup.phase         =   [0.0, 0.0];
            default_dig_setup.trg_width     =   [0.0, 0.0];
            default_dig_setup.trg_delay     =   [0.0, 0.0];
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Modulation Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_mod_setup created struct with default values
% =========================================================================
        function [default_mod_setup, error] = CreateDefaultModSetup(obj)
            error = 0;

            default_mod_setup.mod_type          = obj.MOD_SCHEME_QPSK;
            default_mod_setup.carrier_freq      = 1.0E6;
            default_mod_setup.modul_freq        = 1E3;
            default_mod_setup.num_of_mod_cycles = 1;
            default_mod_setup.modul_index       = 0.0; % AM: index(%), FM/FSK: Dev(Hz), PM: Peak Phase (º)
            default_mod_setup.num_of_symbols    = 2^10;            
            default_mod_setup.symbol_rate       = 1.0E6;
            default_mod_setup.sample_rate       = 1.0E9;
            default_mod_setup.filter_type       = obj.MOD_BB_FILTER_SQRT;
            default_mod_setup.roll_off          = 0.35;
            default_mod_setup.oversampling      = 2;
            default_mod_setup.decimation        = 2;
            default_mod_setup.dvbs2_hp_code     = obj.MOD_DVBS2_CODE_9_10;
            default_mod_setup.dvbs2_lp_code     = obj.MOD_DVBS2_CODE_1_4;
            default_mod_setup.dvbs2_8psk_teta   = 0.0;

            default_mod_setup.data_src          = obj.DATA_SRC_PRBS;
            default_mod_setup.prbs_seq          = obj.PRBS_RND;
            default_mod_setup.usr_polinom       = uint8.empty;
            default_mod_setup.usr_seed          = uint32.empty;
            default_mod_setup.usr_data          = uint8.empty;
            default_mod_setup.apply_fsk_corr    = true;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Multi-Tone Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_mtone_setup created struct with default values
% =========================================================================
        function [default_mtone_setup, error] = CreateDefaultMtoneSetup(obj)
            error = 0;

            default_mtone_setup.num_of_tones    = 10;
            default_mtone_setup.spacing         = 1.0E6;
            default_mtone_setup.phase_distr     = obj.MTONE_PHASE_NEWMAN;
            default_mtone_setup.offset_tone     = 0;
            default_mtone_setup.num_of_repeats  = 2;
            default_mtone_setup.notch_start     = 0;
            default_mtone_setup.notch_size      = 0;
            default_mtone_setup.oversampling    = 2;
        end
        
%**************************************************************************

% =========================================================================
%> @brief Creation of a Frequency Hopping Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_mtone_setup created struct with default values
% =========================================================================
        function [default_fhopping_setup, error] = CreateDefaultFreqHopSetup(obj)
            error = 0;

            default_fhopping_setup.num_of_hops          = 100;
            default_fhopping_setup.num_of_carriers      = 10;
            default_fhopping_setup.hop_duration         = 1E-6;
            default_fhopping_setup.carrier_spacing      = 1E6;  
            default_fhopping_setup.frequency_shift      = 0.0;  
        end
        
%**************************************************************************

% =========================================================================
%> @brief Creation of a Pulse Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_pulse_setup created struct with default values
% =========================================================================
        function [default_pulse_setup, error] = CreateDefaultPulseSetup(obj)
            error = 0;

            default_pulse_setup.num_of_pulses   = 1;
            default_pulse_setup.data_src        = obj.DATA_SRC_PRBS;
            default_pulse_setup.data_encdg      = obj.DATA_ENCDG_NONE;
            default_pulse_setup.prbs_seq        = obj.PRBS_10;
            default_pulse_setup.usr_polinom     = uint32.empty;
            default_pulse_setup.usr_seed        = uint32.empty;
            default_pulse_setup.usr_data        = uint8.empty;
            
            default_pulse_setup.data_wfm_type   = obj.DATA_TYPE_BILVL_NRZ;
            default_pulse_setup.amplitude       = 50.0;
            default_pulse_setup.apply_offset    = false;
            default_pulse_setup.pulse_width     = 1E-6; % Tau for FID
            default_pulse_setup.width_thresh    = 50.0;            
            default_pulse_setup.pulse_rep_freq  = 1E+3;
            default_pulse_setup.staggering      = 0.0;
            default_pulse_setup.apply_offset    = false;
            default_pulse_setup.freq_offset     = 0.0;
            default_pulse_setup.initial_phase   = 0.0;
            default_pulse_setup.spec_reversed   = false;
            default_pulse_setup.pulse_type      = obj.PULSE_TYPE_SQUARE;
            default_pulse_setup.edge_shape      = obj.PULSE_EDGE_LINEAR;
            default_pulse_setup.edge_thresh     = obj.PULSE_EDGE_THRESH_1090;
            default_pulse_setup.rise_time       = 0.0;
            default_pulse_setup.fall_time       = 0.0;
            default_pulse_setup.time_offset     = 0.0;
            default_pulse_setup.sampling_rate   = 0;
            default_pulse_setup.bandwidth       = 0.0;
            default_pulse_setup.granul          = 32;
            default_pulse_setup.quality         = 4;  
            default_pulse_setup.timing_res      = 100.0E-15;
            default_pulse_setup.jit_enable      = [false, false, false];
            default_pulse_setup.jit_unit        = obj.PULSE_JITTER_UNIT_SEC;
            default_pulse_setup.jit_sine_freq   = 1E6;
            default_pulse_setup.jit_sine_ampl   = 1E-12;
            default_pulse_setup.jit_sine_phase  = 0.0;
            default_pulse_setup.jit_rnd_freq    = 1E6;
            default_pulse_setup.jit_rnd_ampl    = 1E-12;
            default_pulse_setup.jit_ssc_freq    = 1E3;
            default_pulse_setup.jit_ssc_dev     = 100.0; %ppm
            default_pulse_setup.jit_mtone_tones = 2; 
            default_pulse_setup.jit_mtone_space = 100E3;
            default_pulse_setup.jit_mtone_ampl  = 0.01;
            default_pulse_setup.trg_src         = obj.TASK_EVENT_NONE;
            default_pulse_setup.trg_delay       = 0.0; 

            default_pulse_setup.polyphase_chips = complex(double.empty);
            default_pulse_setup.polyphase_code  = 1;
            default_pulse_setup.nl_fm_polynom   = double.empty;
            default_pulse_setup.adc_trg         = false;

            default_pulse_setup.mkr_1_pol       = obj.AWG_MKR_POL_NONE;
		    default_pulse_setup.mkr_2_pol       = obj.AWG_MKR_POL_NONE;
		    default_pulse_setup.mkr_1_pos       = 0.0;
		    default_pulse_setup.mkr_2_pos       = 0.0;
		    default_pulse_setup.mkr_1_width     = 0.0;
		    default_pulse_setup.mkr_2_width     = 0.0;
            
            default_pulse_setup.file_fmt        = obj.FILE_FMT_CSV;
            default_pulse_setup.file_name       = "";
            default_pulse_setup.in_sample_rate  = 5E3;
            default_pulse_setup.in_wfm_fraction = 100.0; % in %
            default_pulse_setup.in_wfm_offset   = 0.0; % in %
            default_pulse_setup.time_fmt        = obj.FILE_TIME_IMPLICIT;
            default_pulse_setup.complex_fmt     = obj.FILE_COMPLEX_IMPLICIT;

            default_pulse_setup.task_run_mode   = obj.TASK_RUN_MODE_TASK;

            default_pulse_setup.corr_apply      = false;
            default_pulse_setup.corr_freq       = double.empty;
            default_pulse_setup.corr_ampl       = double.empty;
            default_pulse_setup.corr_phase      = double.empty;

            default_pulse_setup.min_seg_t       = 0.0;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Pulse Sequence Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_pulse_sequence created struct with default values
% =========================================================================
        function [default_pulse_sequence, default_pulse_element, error] = CreateDefaultPulseSequence(obj)
            error = 0;
            default_pulse_sequence.center_freq      = 1E9;
            default_pulse_sequence.offset_freq      = 0.0;
            default_pulse_sequence.delay            = 0.0;
            default_pulse_sequence.spec_reversed    = false;
            default_pulse_sequence.gen_iq           = true;
            default_pulse_sequence.coherent         = true;
            default_pulse_sequence.noise_gen        = false;
            default_pulse_sequence.noise_rms        = 0.0;
            default_pulse_sequence.noise_bw         = 1.0E9;
            default_pulse_sequence.num_of_pulses    = 1;
            default_pulse_sequence.start_time       = 0.0;
            default_pulse_sequence.dead_time        = 1E-6;            
            default_pulse_element                   = obj.CreateDefaultPulseSetup();
            default_pulse_sequence.pulse(1)         = default_pulse_element;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Equivalent Time Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_eq_time_setup created struct with default values
% =========================================================================
        function [default_eq_time_setup, error] = CreateDefaultEqTimeSetup(obj)
            error = 0;
        
            default_eq_time_setup.mode          = obj.DIG_ET_MODE_NORMAL;
            default_eq_time_setup.clk_int       = false;
            default_eq_time_setup.all_edges     = false;
            default_eq_time_setup.clk_div       = 2;
            default_eq_time_setup.size          = 1e-9;
            default_eq_time_setup.delay         = 0.0;
            default_eq_time_setup.sampling_rate = 2.7e9;
            default_eq_time_setup.unit_interval = 1E-9;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Scope Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_scope_setup created struct with default values
% =========================================================================
        function [default_scope_setup, error] = CreateDefaultScopeSetup(obj)
            error = 0;

            default_scope_setup.handle      = int8.empty;
            default_scope_setup.scope_model = obj.SCOPE_MODEL_KEYSIGHT;
            default_scope_setup.chan_scope  = 1;
            default_scope_setup.volt_pp     = 1.0;
            default_scope_setup.offset      = 0;
            default_scope_setup.time_window = 1E-6;
            default_scope_setup.sample_rate = 10E9;
            default_scope_setup.trg_channel = 3; % 0 = EXTERNAL
            default_scope_setup.trg_lvl     = 0.0;
            default_scope_setup.trg_slope   = obj.SCOPE_TRG_SLOPE_POS;
            default_scope_setup.trig_pos    = 50.0;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Calibration Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_cal_setup created struct with default values
% =========================================================================
        function [default_cal_setup, error] = CreateDefaultCalSetup(obj)
            error = 0;

            default_cal_setup.cal_type          = obj.CAL_TYPE_AMPL_PHASE;

            default_cal_setup.scope_type        = obj.SCOPE_MODEL_KEYSIGHT;
            default_cal_setup.scope_sample_rate = 10E9;
                        default_cal_setup.scope_test        = 1;
            default_cal_setup.scope_sync        = 3; % 0 = ext trigger
            default_cal_setup.scope_trg_lvl     = 0.5;
            default_cal_setup.scope_range       = [1.0, 1.0];
            default_cal_setup.scope_offset      = [0.0, 0.0];
            default_cal_setup.scope_time_window = 1E-6;
            default_cal_setup.sel_module        = obj.PROTEUS_MODULE_01;
            default_cal_setup.awg_test_channel  = obj.AWG_CHAN_CH01;
            default_cal_setup.awg_sync_channel  = obj.AWG_CHAN_CH03;
            
            default_cal_setup.sync_pulse_width  = 1E-6;
            default_cal_setup.sync_pulse_low    = -1.0;
            default_cal_setup.sync_pulse_high   = +1.0;
        
            default_cal_setup.avg_freq_range    = [0.0 , 1E9, 2E9, 3E9];
            default_cal_setup.num_of_avg        = [1, 2, 4, 8];
            default_cal_setup.awg_sample_rate   = 9E9;
            default_cal_setup.awg_interpol      = 1;
            default_cal_setup.start_freq        = 10E6;
            default_cal_setup.stop_freq         = 4E9;
            default_cal_setup.step_freq         = 10E6;
        
            default_cal_setup.num_of_cycles     = 100;
            default_cal_setup.freq_res          = 1E6;
            default_cal_setup.min_wfm_size      = 2048;
        
            default_cal_setup.wfmVolt           = [0.5 , 0.5];
            default_cal_setup.WfmOffset         = [0.0 , 0.0];
            default_cal_setup.mkrVolt           = 1.0;
            default_cal_setup.mkrOff            = 0.0;

            default_cal_setup.factors_filename  = "";
            default_cal_setup.factors_filefmt   = obj.CAL_TYPE_FILE_FMT_MAT;

            default_cal_setup.verbose           = true;
            default_cal_setup.disp_handle       = 0;
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of a Correction Setup struct
%>
%> Struct variable is created with default values for all its fields
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @retval default_corr_setup created struct with default values
% =========================================================================
        function [default_corr_setup, error] = CreateDefaultCorrSetup(obj)
            error = 0;

            default_corr_setup.sampling_rate    = 9E9;
            default_corr_setup.wfm_delay        = 0.0;
            default_corr_setup.corr_type        = obj.CAL_TYPE_AMPL_PHASE;
            default_corr_setup.gain             = 0.0; %dB
            default_corr_setup.f_var            = obj.CORR_FREQ_UNIT_HZ; 
            default_corr_setup.x_freq           = double.empty;
            default_corr_setup.amp_var          = obj.CORR_AMPL_UNIT_DB;
            default_corr_setup.ampl_resp        = double.empty;
            default_corr_setup.phase_var        = obj.CORR_PHASE_UNIT_DEGREE;
            default_corr_setup.phase_resp       = double.empty;
           
            default_corr_setup.start_freq       = 0.0;
            default_corr_setup.stop_freq        = 1E9;
            
            default_corr_setup.interpol         = 1;            
            default_corr_setup.corr_mode        = obj.CORR_MODE_FREQ_DOMAIN;
            default_corr_setup.interpol_factor  = obj.CORR_INTERPOL_DEFAULT;

            default_corr_setup.num_of_taps      = 200;
            default_corr_setup.shift_taps       = 0;
            default_corr_setup.oversampling     = 1;

            default_corr_setup.factors_filename = "";
            default_corr_setup.factors_filefmt  = obj.CAL_TYPE_FILE_FMT_MAT;        
        end

%**************************************************************************

% =========================================================================
%> @brief Get the element value after the cyclic index for any array
%>
%> The index is converted to an existing index of the input vector and the
%> corresponding value is returned. This function allows to re-use the
%> values in the vector for multiple target parameters.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param my_array input vector, any type of data in it
%> @param my_idx arbitary index
%> @retval value vector value for index within the array limits
% =========================================================================
        function [value, error] = GetActualElement(obj, my_array, my_idx)
            error       = 0;
            value       = 0;
            array_size  = length(my_array);
            num_of_dims = size(my_array, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif array_size == 0
                error = 2; % Warning empty array
            else
                my_idx      = mod(my_idx - 1, array_size) + 1;
                % value = data corresponding to mod(my_idx, length(my_array))
                value       = my_array(my_idx);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Adapt an input vector to the granularity requirements
%>
%> The function concantenates the minimum number of repetitions until the
%> overall lengtn is a multiple of the granularity.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm input vector, any type of data in it
%> @param granul granularity
%> @retval out_wfm vector built through concatenation of multiple copies of wfm
%> @retval num_of_reps number of repetitions of wfm in out_wfm 
% =========================================================================
        function [out_wfm, num_of_reps, error] = WfmAppendGranularity(obj, wfm, granul)
            % Final Lengtn is calculated as the minimum common multiple of
            % length(wfm) and granularity
            error = 0;
            num_of_reps = 0;
            out_wfm = double.empty;
            vector_length = length(wfm);
            num_of_dims = size(wfm, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array
            elseif granul < 1
                error = -4; % Error wrong granularity
            else           
                final_length    = lcm(vector_length,int32(granul));
                num_of_reps     = final_length / vector_length;
                out_wfm         = obj.WfmRepeat(wfm, num_of_reps); 
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Concatenates multiple copies of a vector
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm input vector, any type of data in it
%> @param num_of_reps number of repetitions of wfm
%> @retval out_wfm vector built through num_of_reps concatenation of wfm
% =========================================================================
        function [out_wfm, error] = WfmRepeat(obj, wfm, num_of_reps)
            error = 0;
            out_wfm = double.empty;
            vector_length = length(wfm);
            num_of_dims = size(wfm, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array
            elseif num_of_reps < 1
                error = -5; % Error wrong parameter
            else
                num_of_reps = int32(num_of_reps);
                out_wfm     = repmat(wfm,1,num_of_reps);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Concatenates multiple copies of a vector to reah a minimum size
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm input vector, any type of data in it
%> @param min_size minimum size for the output vector
%> @retval out_wfm vector built through concatenation of wfm
% =========================================================================
        function [out_wfm, error] = WfmRepeatForMinSize(obj, wfm, min_size)   
            error           = 0;
            out_wfm         = double.empty;
            vector_length   = length(wfm);
            num_of_dims     = size(wfm, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array
            elseif min_size < 1
                error = -5; % Error wrong parameter
            else
                num_of_reps = ceil(min_size / vector_length);
                out_wfm     = repmat(wfm,1,num_of_reps);
            end
        end


%**************************************************************************

% =========================================================================
%> @brief Expand vector by an integer factor 
%>
%> This method is static and public
%> This function repeats each element of the input vector by an integer
%> number of times (EF).
%> (v1, v2,..vN) -> (v11,...V1EF, v21,...v2EF,...,...vN1,...vNEF)
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm input vector, any type of data in it
%> @param expand_factor Expansion factor
%> @retval out_wfm vector built expansion of elements of wfm
% =========================================================================
        function [out_wfm, error] = WfmExpand(obj, wfm, expand_factor) 
            error           = 0;
            out_wfm         = double.empty;
            vector_length   = length(wfm);
            num_of_dims     = size(wfm, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array
            elseif expand_factor < 1
                error = -5; % Error wrong parameter
            else
                expand_factor   = int32(expand_factor);
                out_wfm         = zeros(1, vector_length * expand_factor);            
                for i = 1:expand_factor
                    out_wfm(i:expand_factor:end) = wfm;
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Compress (Decimate) vector by an integer factor 
%>
%> This method is static and public
%> This function keeps one element of the input vector every N elements.
%> It is the opposite operation to the WfmExpand function
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm input vector, any type of data in it
%> @param compress_factor compression (decimation) factor
%> @retval out_wfm vector built compression of elements of wfm
% =========================================================================
        function [out_wfm, error] =WfmCompress(obj, wfm, compress_factor) 
            error           = 0;
            out_wfm         = double.empty;
            vector_length   = length(wfm);
            num_of_dims     = size(wfm, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array
            elseif compress_factor < 1
                error = -5; % Error wrong parameter
            else
                compress_factor = int32(compress_factor);
                out_wfm         = wfm(1:compress_factor:end);  
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Interleave two vectors 
%>
%> This method is static and public
%> This function interleaves values of the first input vector with values
%> of the second input vector. This can be useful to generate an IQ
%> waveform with input vectors with the real(I), imaginary(Q) components.
%> Length of the output vector is twice the length of the shortest input
%> vector. Useful to create waveforms for Proteus IQ Mode ONE. Mode
%> TWO requires downloading real(out_wfm) and imag(out_wfm) to different
%> segments.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm_1 I (real) input vector, any type of data in it
%> @param wfm_2 Q (imag) input vector, any type of data in it
%> @retval out_wfm vector built by interlaving of wfm_1 and wfm_2 data
% =========================================================================
        function [out_wfm, error] = Interleave(obj, wfm_1, wfm_2)
            error           = 0;
            out_wfm         = double.empty;
            wfm_1_length    = length(wfm_1);
            wfm_2_length    = length(wfm_2);
            num_of_dims_1   = size(wfm_1, 1);
            num_of_dims_2   = size(wfm_2, 2);

            if num_of_dims_1 > 1 && num_of_dims_2 > 1
                error = -3; % Wrong dimensions error
            elseif wfm_1_length == 0 || wfm_2_length == 0
                error = -2; % Error Empty Array            
            else  
                if wfm_1_length ~= wfm_2_length
                    error = 3; % Truncated Array Warning
                end
                wfm_length          = wfm_1_length;
                if wfm_2_length < wfm_length
                    wfm_length      = wfm_2_length;
                end           
        
                out_wfm             = uint8(zeros(1, 2 * wfm_length));            
                out_wfm(1:2:end)    = wfm_1(1:wfm_length);
                out_wfm(2:2:end)    = wfm_2(1:wfm_length);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Interleave of real and imaginary parts of a complex input vector 
%>
%> This method is static and public
%> This function interleaves real, imaginary values from the input vector.
%> Length of the output vector is twice the length of that of the input
%> complex vector. Useful to create waveforms for Proteus IQ Mode ONE. Mode
%> TWO requires downloading real(out_wfm) and imag(out_wfm) to different
%> segments.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm_iq Complex input vector, data type complex
%> @retval out_wfm vector built by interlaving of real(wfm_iq), imag(wfm_iq)
% =========================================================================
        function [out_wfm, error] = ComplexToInterleaved(obj, wfm_iq) 
            error           = 0;
            out_wfm         = double.empty;
            vector_length   = length(wfm_iq);
            num_of_dims     = size(wfm_iq, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array           
            else           
                out_wfm             = zeros(1, 2 * vector_length);
                % Odd samples = I samples
                out_wfm(1:2:end)    = real(wfm_iq);
                % Even samples = Q samples
                out_wfm(2:2:end)    = imag(wfm_iq);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief De-Interleaving of interleaved real and imaginary components 
%>
%> This method is static and public
%> This function takes interleaved real, imaginary values from the input
%> vector and creates a complex vector. Output vectro length is half the
%> size of the input vector. It is the opposite function of
%> ComplexToInterleaved. Useful to conver wfm data from Proteus Digitizer
%> working in COMPLEX mode to complex baseband waveforms.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm_iq Interleaved (r1,i1,...rn,in) input vector
%> @retval out_wfm complex vector (r1+j*i1,...rn+j*in)
% =========================================================================
        function [out_wfm, error] = InterleavedToComplex(obj, wfm_iq) 
            error           = 0;
            out_wfm         = double.empty;
            vector_length   = length(wfm_iq);
            num_of_dims     = size(wfm_iq, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array           
            else        
                % Complex sample building
                out_wfm = double(wfm_iq(2:2:end)) +...
                            1.0i * double(wfm_iq(1:2:end));
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Double Interleaving of two iq waveforms for IQ Mode TWO
%>
%> This method is static and public
%> This function takes two input complex waveforms and creates a single
%> output vector to be downloaded to Proteus when working in the IQ Mode
%> TWO. It implemnts quantization. All waveforms must be properly normalized
%> together to the unity circle range. Length of the output waveform is 4
%> times the length of the shortest input waveform.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param wfm_1 Complex IQ pair #1
%> @param wfm_2 Complex IQ pair #2
%> @retval out_wfm double interleaved vector
% =========================================================================
        function [out_wfm, error] = ComplexToInterleavedTwo(obj, wfm_1, wfm_2)        
            % Formatting requires to go through the following steps:
            %   1) quantize samples to 16-bit unsigned integers
            %   2) swap the LSB and MSB as MSBs will be sent first for this mode
            %   3) convert the uint16 array to an uint8 array of twice the size
            % Final wfm is MSB, LSB, MSB, LSB,...
            error           = 0;
            out_wfm         = double.empty;
            wfm_1_length    = length(wfm_1);
            wfm_2_length    = length(wfm_2);
            num_of_dims_1   = size(wfm_1,1);
            num_of_dims_2   = size(wfm_2,1);

            if num_of_dims_1 > 1 && num_of_dims_2 > 1
                error = -3; % Wrong dimensions error
            elseif wfm_1_length == 0 || wfm_2_length == 0
                error = -2; % Error Empty Array 
            else 
                if wfm_1_length ~= wfm_2_length
                    error = 3; % Truncated Array Warning
                end
                min_length  = wfm_1_length;
                if wfm_2_length < min_length
                    min_length = wfm_2_length;
                end
                wfm_1 = wfm_1(1:min_length);
                wfm_2 = wfm_2(1:min_length); 
                wfm_i_1     = typecast(swapbytes(uint16(obj.Quantization(real(wfm_1), 16, 1))),'uint8'); 
                wfm_q_1     = typecast(swapbytes(uint16(obj.Quantization(imag(wfm_1), 16, 1))),'uint8');
                wfm_i_2     = typecast(swapbytes(uint16(obj.Quantization(real(wfm_2), 16, 1))),'uint8');
                wfm_q_2     = typecast(swapbytes(uint16(obj.Quantization(imag(wfm_2), 16, 1))),'uint8');
                % Sequence MSBI1, MSBQ1, MSBQ2, MSBI2, LSBI1, LSBQ1, LSBQ2, LSBI2
                % This is done in three interleaving steps
                out_wfm_i   = obj.Interleave(wfm_i_1, wfm_q_2);
                out_wfm     = obj.Interleave(wfm_q_1, wfm_i_2);
                out_wfm     = obj.Interleave(out_wfm_i, out_wfm);         
                % Format as 16 bit integers as this is how waveforms are transferred
                out_wfm = uint16(out_wfm(1:2:length(out_wfm))) + 256 * uint16(out_wfm(2:2:length(out_wfm)));
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Convert num_of_frames frames in a single vector to a num_of_frames x frame_length array
%>
%> This method is static and public
%> This function takes a single vector made by multiple frames of a known
%> length (frame_length )to a two-dimension array so eah frame can be accessed
%> sepparately as an entity.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param framed_acq vector with multiple frames, any type of data
%> @param frame_length number of elements (samples) per frame
%> @retval framed_acq output num_of_frames x frame_length array
%> @retval num_of_frames num of full frames in the input vector.
% =========================================================================
        function [framed_acq, num_of_frames, error] = SamplesToFrames(obj, framed_acq, frame_length)
            error           = 0;   
            num_of_frames   = 0;
            vector_length   = length(framed_acq);
            num_of_dims     = size(framed_acq, 1);

            if num_of_dims > 1
                error = -3; % Wrong dimensions error
            elseif vector_length == 0
                error = 2; % Warning Empty Array  
            elseif frame_length < 1
                error = -5; % Error wrong parameter
            else
                % Number of frames is always an integer number. Incomplete
                % frames at the end are just discarded.
                num_of_frames   = floor(vector_length / frame_length);
                % Just complete frames are preserved
                framed_acq      = framed_acq(1:num_of_frames * frame_length);
                % An MxN array is created
                framed_acq      = reshape(framed_acq, frame_length, num_of_frames);
                % The final NxM array is created by transposing the array
                framed_acq      = framed_acq';
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Read a Pulse Sequence File and creates a matrix with the same
%> information.
%>
%> This method is static and public
%> This funtion takes an ASCII readable file with a header and a series of
%> pulse parameter definition sections. See example file for keywords and
%> parameters.
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param pulse_seq_file filename for the Pulse Definiton File
%> @retval pulse_seq matrix with the paramters for all the pulses in the sequence.
% =========================================================================
        function [pulse_seq, error] = ReadPulSeq(obj, pulse_seq_file)
    
            error = 0;
            pulse_seq = obj.CreateDefaultPulseSequence();

            try
                fid = fopen(pulse_seq_file,'rt');
            catch
                error = -6; % Failed to open file error
            end

            % Read Header
            while error ~= -6 
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end  %end of file
                if contains(thisline, '!')
                    comment_position = strfind(thisline,'!');
                    comment_position = comment_position(1);
                    thisline = thisline(1:comment_position); 
                    thisline = strrep(thisline, '!', '');
                end
                thisline = upper(thisline);
                thisline                = strrep(thisline, '=', '');
                thisline                = strrep(thisline, ';', ' ');
                thisline                = strrep(thisline, ',', ' ');

                if contains(thisline, 'PULSE') && ~contains(thisline, 'NUMOFPULSES')
                    break;
                end
                
                if contains(thisline, 'CFREQ') 
                    thisline                = strrep(thisline, 'CFREQ', '');
                    try
                        pulse_seq.center_freq   = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'OFREQ') 
                    thisline                = strrep(thisline, 'OFREQ', '');
                    try
                        pulse_seq.offset_freq   = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'DELAY') 
                    thisline                = strrep(thisline, 'DELAY', '');
                    try
                        pulse_seq.delay     = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'SPECTRUMREV') 
                    thisline                = strrep(thisline, 'SPECTRUMREV', '');                    
                    if contains(thisline, 'YES')
                        pulse_seq.spec_reversed = true;
                    elseif contains(thisline, 'NO')
                        pulse_seq.spec_reversed = false;
                    else
                        error = 5;
                    end                    
                end   

                if contains(thisline, 'GENIQ') 
                    thisline                = strrep(thisline, 'GENIQ', '');                    
                    if contains(thisline, 'YES')
                        pulse_seq.gen_iq = true;
                    elseif contains(thisline, 'NO')
                        pulse_seq.gen_iq = false;
                    else
                        error = 5;
                    end                    
                end

                if contains(thisline, 'COHERENT') 
                    thisline                = strrep(thisline, 'COHERENT', '');                    
                    if contains(thisline, 'YES')
                        pulse_seq.coherent = true;
                    elseif contains(thisline, 'NO')
                        pulse_seq.coherent = false;
                    else
                        error = 5;
                    end                    
                end
                
                if contains(thisline, 'NOISEGEN') 
                    thisline                = strrep(thisline, 'NOISEGEN', '');                    
                    if contains(thisline, 'YES')
                        pulse_seq.noise_gen = true;
                    elseif contains(thisline, 'NO')
                        pulse_seq.noise_gen = false;
                    else
                        error = 5;
                    end                    
                end

                if contains(thisline, 'NOISERMS') 
                    thisline                = strrep(thisline, 'NOISERMS', '');
                    try
                        pulse_seq.noise_rms     = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'NOISEBW') 
                    thisline                = strrep(thisline, 'NOISEBW', '');
                    try
                        pulse_seq.noise_bw     = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'NUMOFPULSES') 
                    thisline                = strrep(thisline, 'NUMOFPULSES', '');
                    try
                        pulse_seq.num_of_pulses = sscanf(thisline, '%d');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'STARTT') 
                    thisline                = strrep(thisline, 'STARTT', '');
                    try
                        pulse_seq.start_time    = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'DEADT') 
                    thisline                = strrep(thisline, 'DEADT', '');
                    try
                        pulse_seq.dead_time = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end 
            end

            pulse_index = 0;

            %current_pulse_param = obj.CreateDefaultPulseElement();

            % Read Pulses
            while error ~= -6                 
                if contains(thisline, '!')
                    comment_position = strfind(thisline,'!');
                    comment_position = comment_position(1);
                    thisline = thisline(1:comment_position); 
                    thisline = strrep(thisline, '!', '');
                end
                thisline = upper(thisline);
                % Detect New Pulse
                if contains(thisline, 'PULSE') && ~contains(thisline, 'NUMOFPULSES')
                    if pulse_index > 0
                        pulse_seq.pulse(pulse_index) = current_pulse_param;
                    end
                    current_pulse_param = obj.CreateDefaultPulseSetup();
                    pulse_index = pulse_index + 1;
                else
                    thisline                = strrep(thisline, '=', '');
                    thisline                = strrep(thisline, ';', ' ');
                    thisline                = strrep(thisline, ',', ' ');
                end

                % Check Fields

                if contains(thisline, 'NUMOFPULSES') 
                    thisline                = strrep(thisline, 'NUMOFPULSES', '');
                    try
                        current_pulse_param.num_of_pulses = sscanf(thisline, '%d');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'STAGGERING') 
                    thisline                = strrep(thisline, 'STAGGERING', '');
                    try
                        current_pulse_param.staggering    = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'PWIDTH') 
                    thisline                = strrep(thisline, 'PWIDTH', '');
                    try
                        current_pulse_param.pulse_width = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'PRI') 
                    thisline                = strrep(thisline, 'PRI', '');
                    try
                        current_pulse_param.pulse_rep_freq = sscanf(thisline, '%f');
                        current_pulse_param.pulse_rep_freq = 1 / current_pulse_param.pulse_rep_freq;
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'WIDTHRESHOLD') 
                    thisline                = strrep(thisline, 'WIDTHRESHOLD', '');
                    try
                        current_pulse_param.width_thresh = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'AMPL') 
                    thisline                = strrep(thisline, 'AMPL', '');
                    try
                        current_pulse_param.amplitude = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'PHASE') && ~contains(thisline, 'POLYPHASE')                   
                    thisline                = strrep(thisline, 'PHASE', '');
                    try
                        current_pulse_param.initial_phase = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'OFREQ') && ~contains(thisline, 'APPLYOFREQ') 
                    thisline                = strrep(thisline, 'OFREQ', '');
                    try
                        current_pulse_param.freq_offset = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'APPLYOFREQ') 
                    thisline                = strrep(thisline, 'APPLYOFREQ', '');                    
                    if contains(thisline, 'YES')
                        current_pulse_param.apply_offset = true;
                    elseif contains(thisline, 'NO')
                        current_pulse_param.apply_offset = false;
                    else
                        error = 5;
                    end                    
                end

                if contains(thisline, 'SPECTRUMREV') 
                    thisline                = strrep(thisline, 'SPECTRUMREV', '');                    
                    if contains(thisline, 'YES')
                        current_pulse_param.spec_reversed = true;
                    elseif contains(thisline, 'NO')
                        current_pulse_param.spec_reversed = false;
                    else
                        error = 5;
                    end                    
                end

                if contains(thisline, 'PSHAPE')
                    thisline                = strrep(thisline, 'PSHAPE', '');
                    if contains(thisline, 'RECTANG')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_SQUARE;
                    elseif contains(thisline, 'TRAPEZE')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_TRAPEZOIDAL;
                        current_pulse_param.edge_shape = obj.PULSE_EDGE_LINEAR;
                    elseif contains(thisline, 'RAISEDCOSINE')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_TRAPEZOIDAL;
                        current_pulse_param.edge_shape = obj.PULSE_EDGE_COSINE;
                    elseif contains(thisline, 'GAUSSIAN')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_GAUSSIAN;
                    end
                end

                if contains(thisline, 'RTIME') 
                    thisline                = strrep(thisline, 'RTIME', '');
                    try
                        current_pulse_param.rise_time = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'FTIME') 
                    thisline                = strrep(thisline, 'FTIME', '');
                    try
                        current_pulse_param.fall_time = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'EDGETHRESHOLD')
                    thisline                = strrep(thisline, 'EDGETHRESHOLD', '');
                    if contains(thisline, '0/100') || contains(thisline, '0100')
                        current_pulse_param.edge_thresh   = obj.PULSE_EDGE_THRESH_0100;
                    elseif contains(thisline, '10/90') || contains(thisline, '1090')
                        current_pulse_param.edge_thresh   = obj.PULSE_EDGE_THRESH_1090;
                    elseif contains(thisline, '20/80') || contains(thisline, '2080')
                        current_pulse_param.edge_thresh = obj.PULSE_EDGE_THRESH_2080;                    
                    end
                end

                if contains(thisline, 'MODULATION')
                    thisline                = strrep(thisline, 'MODULATION', '');
                    if contains(thisline, 'NONE')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_SQUARE;
                    elseif contains(thisline, 'LINEARFM')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_CHIRP_UP;
                    elseif contains(thisline, 'NONLINEARFM')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_NL_FM;                    
                    elseif contains(thisline, 'STEPFM')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_STEP_FM;
                    elseif contains(thisline, 'MFSK')
                        current_pulse_param.pulse_type = obj.PULSE_TYPR_MFSK;                    
                    elseif contains(thisline, 'BARKER')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_BARKER_CODE;
                    elseif contains(thisline, 'FRANK')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_FRANK_CODE;                    
                    elseif contains(thisline, 'P1')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_P1_CODE;
                    elseif contains(thisline, 'P2')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_P2_CODE;                    
                    elseif contains(thisline, 'P3')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_P3_CODE;
                    elseif contains(thisline, 'P4')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_P4_CODE;  
                    elseif contains(thisline, 'POLYPHASE') && ~contains(thisline, 'POLYPHASECHIPS')
                        current_pulse_param.pulse_type = obj.PULSE_TYPE_POLYPHASE;
                    end
                end

                if contains(thisline, 'SWEEPF') 
                    thisline                = strrep(thisline, 'SWEEPF', '');
                    try
                        current_pulse_param.bandwidth = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'BARKERCODE') 
                    thisline                = strrep(thisline, 'BARKERCODE', '');                   
                    try
                        poly_code = sscanf(thisline, '%f');
                        if poly_code == obj.PULSE_BARKER_02
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_02;
                        elseif poly_code == obj.PULSE_BARKER_02_BIS
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_02_BIS;
                        elseif poly_code == obj.PULSE_BARKER_03
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_03;
                        elseif poly_code == obj.PULSE_BARKER_04
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_04;
                        elseif poly_code == obj.PULSE_BARKER_04_BIS
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_04_BIS;
                        elseif poly_code == obj.PULSE_BARKER_05
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_05;
                        elseif poly_code == obj.PULSE_BARKER_07
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_07;
                        elseif poly_code == obj.PULSE_BARKER_11
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_11;
                        elseif poly_code == obj.PULSE_BARKER_13
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_13;
                        else
                            current_pulse_param.polyphase_code  = obj.PULSE_BARKER_02;
                        end
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'FRANKCODE') ||...
                        contains(thisline, 'P1CODE') || contains(thisline, 'P2CODE') ||...
                        contains(thisline, 'P3CODE') || contains(thisline, 'P4CODE')                    
                    thisline                = strrep(thisline, 'FRANKCODE', '');
                    thisline                = strrep(thisline, 'P1CODE', '');
                    thisline                = strrep(thisline, 'P2CODE', '');
                    thisline                = strrep(thisline, 'P3CODE', '');
                    thisline                = strrep(thisline, 'P4CODE', '');
                    thisline                = strrep(thisline, '=', '');
                    try
                        current_pulse_param.polyphase_code = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'POLYPHASECHIPS') 
                    thisline                = strrep(thisline, 'POLYPHASECHIPS', '');
                    try
                        current_pulse_param.polyphase_chips = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'FMPOLYNOMIAL') 
                    thisline                = strrep(thisline, 'FMPOLYNOMIAL', '');
                    try
                        current_pulse_param.nl_fm_polynom = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'ADCTRIG') 
                    thisline                = strrep(thisline, 'ADCTRIG', '');                    
                    if contains(thisline, 'YES')
                        current_pulse_param.adc_trg = true;
                    elseif contains(thisline, 'NO')
                        current_pulse_param.adc_trg = false;
                    else
                        error = 5;
                    end                    
                end

                if contains(thisline, 'MKR1POL')
                    thisline                = strrep(thisline, 'MKR1POL', '');
                    if contains(thisline, 'NONE')
                        current_pulse_param.mkr_1_pol   = obj.AWG_MKR_POL_NONE;
                    elseif contains(thisline, 'POS')
                        current_pulse_param.mkr_1_pol   = obj.AWG_MKR_POL_POS;
                    elseif contains(thisline, 'NEG')
                        current_pulse_param.mkr_1_pol   = obj.AWG_MKR_POL_NEG;                    
                    end
                end

                if contains(thisline, 'MKR2POL')
                    thisline                = strrep(thisline, 'MKR2POL', '');
                    if contains(thisline, 'NONE')
                        current_pulse_param.mkr_2_pol   = obj.AWG_MKR_POL_NONE;
                    elseif contains(thisline, 'POS')
                        current_pulse_param.mkr_2_pol   = obj.AWG_MKR_POL_POS;
                    elseif contains(thisline, 'NEG')
                        current_pulse_param.mkr_2_pol   = obj.AWG_MKR_POL_NEG;                    
                    end
                end

                if contains(thisline, 'MKR1DLY') 
                    thisline                = strrep(thisline, 'MKR1DLY', '');
                    try
                        current_pulse_param.mkr_1_pos = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'MKR2DLY') 
                    thisline                = strrep(thisline, 'MKR2DLY', '');
                    try
                        current_pulse_param.mkr_2_pos = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'MKR1WIDTH') 
                    thisline                = strrep(thisline, 'MKR1WIDTH', '');
                    try
                        current_pulse_param.mkr_1_width = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end

                if contains(thisline, 'MKR2WIDTH') 
                    thisline                = strrep(thisline, 'MKR2WIDTH', '');
                    try
                        current_pulse_param.mkr_2_width = sscanf(thisline, '%f');
                    catch
                        error = 5;
                    end
                end
                
                % Read Next Line
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end  %end of file
            end  

            if pulse_index > 0
                pulse_seq.pulse(pulse_index) = current_pulse_param;
                pulse_seq.num_of_pulses = pulse_index;
            else
                pulse_seq.num_of_pulses = 0;
            end

        end

% =========================================================================
%> @brief Import waveform data for XYZ display from .plt files (HPGL format)
%>
%> X and Y data is normalized so it always go from -1.0 to +1.0 to use all
%> the DAC range. It supports just PU and PD commands with single pair of
%> associated coordinates
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param filename .plt file name
%> @param interpol Interpolation factor for output data (integer)
%> @param plot_flag Display imported figure
%> @retval x_coord Output X values
%> @retval y_coord Output y values
%> @retval z_flag Z axis (brightness) control
% =========================================================================
        function [x_coord, y_coord, z_flag, error] = ReadPlt(obj, fileName,interpol, plot_flag)
            error           = 0;     
            numOfElements   = 0;
            x_coord         = double.empty;
            y_coord         = double.empty;
            z_flag          = double.empty;

            try
                fid = fopen(fileName,'rt');
            catch
                error = -6; % Failed to open file error
            end

            while error ~= -6 
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end  %end of file
                
                thisline = upper(thisline);
                
                if contains(thisline, 'PU') 
                    thisline        = strrep(thisline, 'PU', '');
                    thisline        = strrep(thisline, ';', '');
                    currentCoord    = sscanf(thisline, '%f');
                    
                    if numOfElements == 0
                        numOfElements           = numOfElements + 1;
                        x_coord                 = currentCoord(1);
                        y_coord                 = currentCoord(2);
                        z_flag                  = 1;
                        numOfElements           = numOfElements + 1;
                        x_coord(numOfElements)  = currentCoord(1);
                        y_coord(numOfElements)  = currentCoord(2);
                        z_flag(numOfElements)   = -1;
                    else
                        numOfElements           = numOfElements + 1;
                        x_coord(numOfElements)  = x_coord(numOfElements - 1);
                        y_coord(numOfElements)  = y_coord(numOfElements - 1);
                        z_flag(numOfElements)   = 1;
                        numOfElements           = numOfElements + 1;
                        x_coord(numOfElements)  = currentCoord(1);
                        y_coord(numOfElements)  = currentCoord(2);
                        z_flag(numOfElements)   = 1;   
                        numOfElements           = numOfElements + 1;
                        x_coord(numOfElements)  = currentCoord(1);
                        y_coord(numOfElements)  = currentCoord(2);
                        z_flag(numOfElements)   = -1;  
                    end           
                elseif contains(thisline, 'PD') 
                    thisline                = strrep(thisline, 'PD', '');
                    thisline                = strrep(thisline, ';', '');
                    currentCoord            = sscanf(thisline, '%f'); 
                    
                    numOfElements = numOfElements + 1;
                    x_coord(numOfElements)  = currentCoord(1);
                    y_coord(numOfElements)  = currentCoord(2);
                    z_flag(numOfElements)   = -1;
                else
                    error = 5; % Unsupported HPGL Command Warning
                end        
            end

            if error ~= -6  && numOfElements > 0           
                numOfElements           = numOfElements + 1;
                x_coord(numOfElements)  = x_coord(numOfElements - 1);
                y_coord(numOfElements)  = y_coord(numOfElements - 1);
                z_flag(numOfElements)   = 1;
                
                fclose(fid);   
                
                xMin    = min(x_coord);
                xMax    = max(x_coord);
                yMin    = min(y_coord);
                yMax    = max(y_coord);
                
                x_coord = -1.0 + 2.0 * (x_coord - xMin) / (xMax - xMin);
                y_coord = -1.0 + 2.0 * (y_coord - yMin) / (yMax - yMin);
                
                xBase   = 1: length(x_coord);
                xInter  = 1: 1/interpol : (length(x_coord) - 1/interpol);
                
                x_coord = interp1(xBase,x_coord, xInter);
                y_coord = interp1(xBase,y_coord, xInter); 
                z_flag  = -interp1(xBase,z_flag, xInter);
    
                if plot_flag
                    obj.Plot_xyz(x_coord, y_coord, z_flag);
                end
            end   

            if error ~= -6  && numOfElements == 0
                error = -7; % No useful data in file error
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Shows graph to validate .plt imported values
%>
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param filename .plt file name
%> @param x_coord Input X values
%> @param y_coord Input y values
%> @param z_flag Z axis (brightness) control
% =========================================================================
        function error = Plot_xyz(obj, x_coord, y_coord, z_flag)
            error = 0;
            vector_length = min([length(x_coord), length(y_coord), length(z_flag)]);

            if vector_length > 0
                x_coord = x_coord(1: vector_length);
                x_coord = x_coord(1: vector_length);
                x_coord = x_coord(1: vector_length);

                new_figure_flag = false;
                hold_flag       = true;
            
                current_x       = double.empty;
                current_y       = double.empty;
            
                for current_point = 1:vector_length
                    if new_figure_flag
                        current_x       = double.empty;
                        current_y       = double.empty;
                        new_figure_flag = false;
                    end
            
                    if z_flag(current_point) == 1 && current_point < vector_length
                        current_x       = [current_x, x_coord(current_point)];
                        current_y       = [current_y, y_coord(current_point)];            
                    else
                        if current_point == length(x_coord) && z_flag(current_point) == 1
                            current_x   = [current_x, x_coord(current_point)];
                            current_y   = [current_y, y_coord(current_point)];                      
                        end                    
    
                        plot(current_x, current_y, 'color','blue');
                        if hold_flag
                            hold;
                            hold_flag   = false;                
                        end
                        new_figure_flag = true;
                    end
                end
            else
                error = -2; % Empty array error
            end
        end

%***********************************************************************

% =========================================================================
%> @brief Export IQ Data to an 89600 compatible file for further analysis
%>
%> This method is static and public
%> File is compatible with 89600 recording file format
%>
%> @param obj instance of the TEProteusLib class
%> @param file_name Target file name
%> @param wfm_iq IQ vector with complex data
%> @param sample_rate Sample Rate of the waveform in the wfm_iq vector
%> @retval sample_stored Samples exported to output file
% =========================================================================
        function [sample_stored, error] = SaveIqToCsvFile89600(obj, file_name, wfm_iq, sample_rate)
            error           = 0;
            sample_stored   = length(wfm_iq);           

            if sample_rate <= 0.0
                error = -5; % Wrong parameter error
                sample_stored = 0;
            elseif sample_stored == 0
                error = -2; % Empty Array Error
            else        
                try
                    file_id     = fopen(file_name, 'w');
            
                    fprintf(file_id, 'XStart, %6.8f\n', 0.0);
                    fprintf(file_id, 'XDelta, %e\n', 1/sample_rate);
                    fprintf(file_id, 'XDomain, %d\n', 2);
                    fprintf(file_id, 'Y,\n');
                    for i=1:sample_stored
                        fprintf(file_id, '%6.8f, %6.8f\n', real(wfm_iq(i)), imag(wfm_iq(i)));
                    end
                    fclose(file_id);
                catch
                    sample_stored   = 0; 
                    error           = -8; % Failed to Create File
                end
            end
        end

%***********************************************************************

% =========================================================================
%> @brief Export IQ Data to an X-Series VSA compatible file for further
%> analysis
%>
%> This method is static and public
%> File is compatible with X-Series VSA recording file format
%>
%> @param obj instance of the TEProteusLib class
%> @param file_name Target file name
%> @param wfm_iq IQ vector with complex data
%> @param center_frequency Central Frequency for Exported Complex wfm
%> @param sample_rate Sample Rate of the waveform in the wfm_iq vector
%> @retval sample_stored Samples exported to output file
% =========================================================================
        function [sample_stored, error] = SaveIqToCsvFileXseries(obj, file_name, wfm_iq, center_frequency, sample_rate)
            error           = 0;
            sample_stored   = length(wfm_iq);

            if sample_rate <= 0.0
                error = -5; % Wrong parameter error
                sample_stored = 0;
            elseif sample_stored == 0
                error = -2; % Empty Array Error
            else         
                try
                    file_id     = fopen(file_name, 'w');
            
                    % Header
                    fprintf(file_id, 'InputZoom, TRUE\n');
                    fprintf(file_id, 'InputCenter, %12.8f\n', center_frequency);
                    fprintf(file_id, 'InputRefImped, %d\n', 50);
                    fprintf(file_id, 'XStart, %6.8f\n', 0.0);
                    fprintf(file_id, 'XDelta, %e\n', 1/sample_rate);
                    fprintf(file_id, 'XDomain, %d\n', 2);
                    fprintf(file_id, 'XUnit, Sec\n');
                    fprintf(file_id, 'YUnit, V\n');        
                    dt          = string(datetime('now','TimeZone','local',...
                                        'Format','MM/dd/yyyy HH:mm:ss a'));
                    fprintf(file_id, 'TimeString, %s\n', dt);
                    fprintf(file_id, 'Y\n');
                    % Data as I,Q pairs        
                    fprintf(file_id, '%6.8f, %6.8f\n', real(wfm_iq), imag(wfm_iq));
                    
                    fclose(file_id);
                catch
                    sample_stored   = 0;  
                    error           = -8; % Failed to Create File
                end
            end
        end

%***********************************************************************  

% =========================================================================
%> @brief Import IQ Data from an X-Series VSA compatible file
%>
%> This method is static and public
%> File is compatible with X-Series VSA recording file format
%>
%> @param obj instance of the TEProteusLib class
%> @param file_name Target file name
%> @retval wfm_iq Imported IQ vector with complex data
%> @retval center_frequency Central Frequency for Imported Complex wfm
%> @retval sample_rate Sample Rate of the waveform in imported file
% =========================================================================
        function [wfm_iq, center_frequency, sample_rate, error] = LoadCsvFileXseries(obj, file_name)
            error = 0;
            center_frequency            = 0.0;
            sample_rate                 = 0.0;        
            y_flag                      = false;   

            try
                fid     = fopen(file_name, 'rt');
            catch
                error   = -6;
            end
        
            while error ~= -6
                thisline                = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end  %end of file
                
                thisline = upper(thisline);
        
                if contains(thisline, 'INPUTCENTER') 
                    thisline            = strrep(thisline, 'INPUTCENTER', '');
                    thisline            = strrep(thisline, ',', '');
                    center_frequency    = sscanf(thisline, '%f');
                end
        
                if contains(thisline, 'XDELTA') 
                    thisline            = strrep(thisline, 'XDELTA', '');
                    thisline            = strrep(thisline, ',', '');
                    sample_rate = sscanf(thisline, '%f');
                    if sample_rate ~= 0.0
                        sample_rate     = 1.0 / sample_rate;
                    end
        
                end
            
                if strcmp(thisline, 'Y')
                    y_flag              = true;
                    break;            
                end
            end
            if error ~= -6        
                num_of_elem                 = 0;
            
                if y_flag
                    while true
                        thisline            = fgetl(fid);
                        if ~ischar(thisline) 
                            break; 
                        end  %end of file
                    
                        num_of_elem         = num_of_elem + 1;
                        current_sample      = sscanf(thisline, '%f, %f');
                        current_sample      = current_sample(1) +...
                            1i * current_sample(2);
                        wfm_iq(num_of_elem) = current_sample;
                    end
                end        
                fclose(fid); 
            end
        end

%*********************************************************************** 

% =========================================================================
%> @brief CCDF (Complementary Cumulative Distribution Function)
%>
%> This method is static and public
%> It calculates a CCDF the from a complex or real-only waveform.
%> @param obj instance of the TEProteusLib class
%> @param wfm Waveform to analize
%> @param num_of_bins Number of bins for the CCDF results
%> @retval x_values Amplitude Values in dB over 0.0dB (Average Power)
%> @retval y_values Percentage of time spent by wfm over correponding power
%> @retval papr Peak-to-Average Power Ratio (PAPR) or Crest Factor
% =========================================================================
        function [x_values, y_values, papr, error] = CCDF (obj, wfm, num_of_bins)
            error       = 0;
            x_values    = double.empty;
            y_values    = double.empty;
            papr        = 0.0;
            wfm_length  = length(wfm);

            if wfm_length == 0
                error = -2;
            else      
                % Calculate power waveform
                wfm         = wfm .* conj(wfm);    
                % Convert to dB relative to mean power
                wfm         = 10 * (log10(wfm) - log10(mean(wfm)));
                % PAPR (Crest Factor) is the maximum value in the vector
                papr        = max(wfm);   
                
                %CCDF is calculated here
                x_values    = 0 : (papr / (num_of_bins - 1)) : papr;
                y_values    = 100 / wfm_length * sum(x_values' <= wfm, 2); % CCDF as a percentage
            end
        end

%***********************************************************************

% =========================================================================
%> @brief Calculate & Plot CCDF (Complementary Cumulative Distribution Function)
%>
%> This method is static and public
%> Graph will be generated with 100 bins if num_of_bins is not passed
%>
%> @param obj instance of the TEProteusLib class
%> @param ax1 Graph Handle
%> @param wfm Waveform to analize
%> @param num_of_bins Number of bins for the CCDF results
% =========================================================================
        function error = PlotCcdf (obj, ax1, wfm, num_of_bins)
            if ~exist('num_of_bins','var')
                num_of_bins = 100;
            end

            wfm_length = length(wfm);

            if wfm_length == 0
                error = -2;
            else  
                [x_values, y_values, papr, error] = obj.CCDF (wfm, num_of_bins);
            
                semilogy(ax1, x_values, y_values);    
                title(ax1,sprintf('CCDF, PAPR = %f', papr));       
                xlabel('dB') 
                ylabel('%') 
            end
        end

%**************************************************************************
%**************************************************************************
        % PROCESSING METHODS
%**************************************************************************

% =========================================================================
%> @brief DFT Calculation for a single bin
%>
%> This method is static and public
%> Calculates DFT(num_of_bin). FFT may be more efficient. dtf_coef can be
%> passed in order to save time when multiple values are necessary. 
%> 
%> @param obj instance of the TEProteusLib class
%> @param wfm Waveform to analize
%> @param num_of_bin Number of bin to obtain the DFT
%> @param dft_coef coefficients for DFT calculatio. (Optional)
%> @retval dft_bin Complex value for DFT(num_of_bin)
% =========================================================================
        function [dft_bin, error] = SingleFreqDft(obj, wfm, num_of_bin, dft_coef)
            error       = 0;
            dft_bin     = 0.0;
            wfm_length  = length(wfm);

            if wfm_length == 0
                error = -2;
            else
                % DFT is cyclic
                num_of_bin = mod(num_of_bin, wfm_length);
                % If dft_coef does not exists or have a bad length, it is calculated 
                if ~exist('dft_coef','var') || length(dft_coef) ~= wfm_length                                
                    dft_coef = 0:(wfm_length - 1);
                    dft_coef = dft_coef * 2 * pi / wfm_length; % * num_of_bin;
                end
                % DFT(num_of_bin) is calculated
                dft_coef    = dft_coef * num_of_bin;
                dft_bin     = sum(wfm .* (cos(dft_coef) + 1i * sin(dft_coef)));
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Shift Frequency for a complex waveform
%>
%> This method is static and public
%> This function shifts the frequency (positive or negative) of the
%> waveform passed to it.
%> 
%> @param obj instance of the TEProteusLib class
%> @param wfm Waveform to shift
%> @param frequency Frequency to shift (positive or negative)
%> @param initial_phase Initial Phase for the shift
%> @param sample_rate Sample Rate for the input waveform
%> @param adjust_carrier Flag to get continuous phase when looping (boolean)
%> @retval shifted_wfm Shifted waveform
%> @retval final_shift Actual shift after applying carrier adjustment
% =========================================================================
        function [  shifted_wfm,...
                    final_shift,...
                    error] = ShiftFreq( obj,...
                                        wfm, ...
                                        frequency, ...
                                        initial_phase,...
                                        sample_rate,...
                                        adjust_carrier)
            error       = 0;
            shifted_wfm = complex(double.empty);
            final_shift = 0.0;
            wfm_length  = length(wfm);

            if wfm_length == 0
                error = -2;
            else            
                if adjust_carrier
                    freq_res    = sample_rate / length(wfm);
                    frequency   = round(frequency / freq_res) * freq_res;
                end
    
                shifted_wfm     = 1:length(wfm);
                shifted_wfm     = shifted_wfm - 1;
                shifted_wfm     = shifted_wfm / sample_rate;    
                shifted_wfm     = exp(1i * 2.0 * pi * frequency *...
                    shifted_wfm + initial_phase * pi / 180.0);
                shifted_wfm     = shifted_wfm .* wfm;    
                final_shift     = frequency;
            end
        end

%**************************************************************************

% PULSE FUNCTIONS
% ***************

%**************************************************************************

% =========================================================================
%> @brief Creation of isolated pulses
%>
%> This method is static and public
%> This function calculates an isolated pulse with user/defined shape and
%> parameters. Pulses are complex time-domain waveforms. Supported pulse
%> types:
%> - Square
%> - Trapezoidal
%> - Gaussian
%> - FID (NMR)
%> - Chirps
%> - Polyphase (RADAR)
%> 
%> @param obj instance of the TEProteusLib class
%> @param pulse_setup Pulse settings struct
%> @retval iq_pulse Complex Isolated Pulse
% =========================================================================
        function [iq_pulse, error] = GetIqPulse( obj,...
                                        pulse_setup)
            error = 0;
            iq_pulse = complex(double.empty);

            switch pulse_setup.pulse_type

                case obj.PULSE_TYPE_TRAPEZOIDAL
                    [iq_pulse,...
                    error] = obj.GetTrapezoidalPulse(   pulse_setup.pulse_width, ...
                                                        pulse_setup.edge_shape, ...
                                                        pulse_setup.rise_time,...
                                                        pulse_setup.sampling_rate, ...                                                    
                                                        1, ...
                                                        pulse_setup.granul, ...
                                                        pulse_setup.quality);

                case obj.PULSE_TYPE_GAUSSIAN
                    [iq_pulse,...
                    error] = obj.GetGaussPulse(         pulse_setup.pulse_width,...
                                                        pulse_setup.sampling_rate,...
                                                        pulse_setup.quality,...
                                                        1,...
                                                        pulse_setup.granul);

                case obj.PULSE_TYPE_NMR_FID
                    [iq_pulse,...
                    error] = obj.GetFidPulse(           pulse_setup.pulse_width, ...
                                                        pulse_setup.sampling_rate, ...
                                                        pulse_setup.quality, ...
                                                        pulse_setup.granul);

                case obj.PULSE_TYPE_CHIRP_UP            
                    [iq_pulse,...
                    error] = obj.GetIqChirp(            pulse_setup.pulse_width, ...
                                                        pulse_setup.bandwidth, ...
                                                        pulse_setup.sampling_rate, ...
                                                        pulse_setup.granul,...
                                                        pulse_setup.corr_apply, ...
                                                        pulse_setup.corr_freq, ...
                                                        pulse_setup.corr_ampl);

                case obj.PULSE_TYPE_CHIRP_DOWN            
                    [iq_pulse,...
                    error] = obj.GetIqChirp(            pulse_setup.pulse_width, ...
                                                        -pulse_setup.bandwidth, ...
                                                        pulse_setup.sampling_rate, ...
                                                        pulse_setup.granul,...
                                                        pulse_setup.corr_apply, ...
                                                        pulse_setup.corr_freq, ...
                                                        pulse_setup.corr_ampl);

                case {  obj.PULSE_TYPE_BARKER_CODE,...
                        obj.PULSE_TYPE_FRANK_CODE,...
                        obj.PULSE_TYPE_P1_CODE,...
                        obj.PULSE_TYPE_P2_CODE,...
                        obj.PULSE_TYPE_P3_CODE,...
                        obj.PULSE_TYPE_P4_CODE}
                    [iq_pulse,...
                    error] = obj.GetPolyPhasePulse(     pulse_setup.pulse_type,...
                                                        pulse_setup.polyphase_code,...
                                                        pulse_setup.sampling_rate, ...
                                                        pulse_setup.pulse_width, ...
                                                        pulse_setup.granul);
                
            end

            iq_pulse = iq_pulse * exp(1i * pulse_setup.initial_phase * pi / 180.0);

            if error == 0
                [iq_pulse,...
                error] = obj.ShiftFreq(                 iq_pulse, ...
                                                        pulse_setup.freq_offset, ...
                                                        0.0,...
                                                        pulse_setup.sampling_rate,...
                                                        false);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Read Pulse form file
%>
%> This function reads pulse samples from a file and prperly format the
%> data to be used as a regular pulse.
%> 
%> This method is static and public
%> @param obj instance of the TEProteusLib class
%> @param file_name Name with full path info of the file to be read
%> @param file_fmt File format (future use)
%> @param time_layout (future use)
%> @param complex_layout IQ component layout
%> @param pulse_duration Pulse duration
%> @param pulse_offset Pulse offest time
%> @param input_sample_rate Sample rate for input data for resampling (future use)
%> @param output_sample_rate Sample rate for output data for resampling (future use)
%> @param min_samples Minimum length for the ouput pulse waveform
%> @param granularity Length Granularity for the ouput pulse waveform
%> @retval test_signal Complex Isolated Pulse
% =========================================================================
        function [test_signal, error] = GetFilePulse(   obj,...
                                                        file_name,...
                                                        file_fmt,...
                                                        time_layout,...
                                                        complex_layout,...
                                                        pulse_duration,...
                                                        pulse_offset,...
                                                        input_sample_rate,...
                                                        output_sample_rate,...                                                    
                                                        min_samples,...
                                                        granularity)
            error = 0;
            test_signal = double.empty;

            try
                load(file_name, test_signal);
            catch
                error = 6;
            end

            if ~exist('test_signal','var')
                error = 7;
            end

            if error == 0 && isempty(test_signal)
                error = 7;
            end

            if granularity == 0
                error = 4;
            end

            if pulse_duration == 0.0
                error = 5;
            end
            
            if error == 0
                % test_sigal is the varuable name within the .m file where
                % waveform data is stored
                input_wfm_length    = length(test_signal);            
                start_sample        = round(pulse_offset *  input_wfm_length / 100.0) + 1;
                stop_sample         = start_sample + round(pulse_duration *  input_wfm_length / 100.0); 
                stop_sample         = stop_sample - 1;
    
                test_signal          = test_signal(start_sample:stop_sample);
                % pulse_duration      = length(test_signal) / input_sample_rate;
                % output_wfm_length   = floor(pulse_duration * output_sample_rate);
                % test_signal         = obj.ResamplingDirect(     test_signal, ...
                %                                                 output_wfm_length, ...
                %                                                 true);
    
                % Adjust Granularity
                while length(test_signal) < min_samples || mod(length(test_signal), granularity) > 0
                    test_signal = [test_signal, complex(0.0)];
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Calculates Trapezoidal Pulse
%>
%> This method is static and public
%> This function calculates a trapezoidal pulse with user-defined rise-time
%> (= fall time), edge shape, and 50% width.
%> 
%> @param obj instance of the TEProteusLib class
%> @param t_50 50% pulse width in seconds
%> @param edge_shape Edge Shape (linear, exponential, gaussian, cosine)
%> @param rise_time 10%-90% Rise and Fall Times (tau for exponential)
%> @param sample_rate Sample Rate for the calculated pulse waveform
%> @param min_samples Minimum length for the ouput pulse waveform
%> @param granularity Length Granularity for the ouput pulse waveform
%> @param quality Number of taus to be calculated for exponential edge shape
%> @retval iq_pulse Complex Isolated Pulse
% =========================================================================
        function [trapeze_pulse,...
                error] = GetTrapezoidalPulse(   obj,...
                                                t_50, ...
                                                edge_shape, ...
                                                rise_time,...
                                                sample_rate, ...                                                    
                                                min_samples, ...
                                                granularity, ...
                                                quality)
            error = 0;
            trapeze_pulse = complex(double.empty);

            if granularity <= 0
                error = 4;
            end

            if t_50 <= 0.0 || sample_rate <= 0.0 || quality <= 0.5
                error = 5; % Wrong parameter(s)
            end

            quality             = round(quality);

            if error == 0            
                switch edge_shape
                    case obj.PULSE_EDGE_LINEAR
                        edge_total_t    = rise_time / 0.8;
                        half_ampl_t     = edge_total_t * 0.5;
                        pulse_length    = t_50 + 2 * half_ampl_t;                    
                        pulse_length    = ceil(pulse_length * sample_rate);
                        trapez_pulse    = zeros(1, pulse_length);
    
                        for current_sample = 0:(pulse_length - 1)
                            current_time                    = current_sample / sample_rate;
    
                            if current_time < edge_total_t
                                trapez_pulse...
                                    (current_sample + 1)    = current_time / edge_total_t;                            
    
                            elseif current_time < t_50
                                trapez_pulse...
                                    (current_sample + 1)    = 1.0;
    
                            elseif current_time <= (t_50 + edge_total_t)
                                trapez_pulse...
                                    (current_sample + 1)    = 1 - (current_time - t_50) / edge_total_t; 
                            end
                        end
    
                    case obj.PULSE_EDGE_EXPONENTIAL
                        tau                 = - rise_time / log(0.1 / 0.9);
                        half_ampl_t         = -tau * log(0.5);
                        num_of_taus         = quality;
                        pulse_length        = t_50 + num_of_taus * tau;
                        pulse_length        = ceil(pulse_length * sample_rate);
                        trapez_pulse        = zeros(1, pulse_length);
                        
                        for current_sample = 0:(pulse_length - 1)
                            current_time                    = current_sample / sample_rate;
    
                            if current_time < (t_50 + half_ampl_t)
                                trapez_pulse...
                                    (current_sample + 1)    = 1 - exp(-current_time / tau);
    
                            elseif current_time <= (t_50 + num_of_taus * tau)
                                trapez_pulse...
                                    (current_sample + 1)    = ( 1 - exp(-(t_50 + half_ampl_t) / tau)) * exp(-(current_time - t_50 - half_ampl_t) / tau);
                            end
                        end
    
                    case obj.PULSE_EDGE_GAUSSIAN
                        alfa            = pi^2 * (0.35 / rise_time)^2 / log(2);                    
                        imp_resp_width  = (log(4) / alfa) ^0.5;
    
                        impulse_resp    = obj.GetGaussPulse(    imp_resp_width, ...
                                                                quality * sample_rate, ...
                                                                4, ...
                                                                1, ...
                                                                1);
                        impulse_resp    = impulse_resp / sum(impulse_resp);
    
                        pulse_length    = round(t_50 * quality * sample_rate);
                        trapez_pulse    =  double(ones(1, pulse_length));
                        trapez_pulse    = conv(trapez_pulse, impulse_resp);
                        trapez_pulse    = trapez_pulse(1:quality:end);
    
                    case obj.PULSE_EDGE_COSINE
                        omega           = 4.0 * asin(0.8) / rise_time;
                        half_ampl_t     = pi / omega;
                        edge_total_t    = 2 * half_ampl_t;
                        pulse_length    = t_50 + edge_total_t;
                        pulse_length    = ceil(pulse_length * sample_rate);
                        trapez_pulse    = zeros(1, pulse_length);
    
                        for current_sample = 0:(pulse_length - 1)
                            current_time                            = current_sample / sample_rate;
    
                            if current_time < edge_total_t
                                trapez_pulse(current_sample + 1)    = 0.5 - 0.5 * cos(omega / 2 * current_time);
    
                            elseif current_time < t_50
                                trapez_pulse(current_sample + 1)    = 1.0;
    
                            elseif current_time <=(t_50 + edge_total_t)
                                trapez_pulse(current_sample + 1)    = 0.5 + 0.5 * cos(omega / 2 * (current_time - t_50));
                            end
                        end
    
                    otherwise
                        error = 5; % Wrong Parameter
                end 

                if error == 0                      
                    final_length        = ceil(length(trapez_pulse) / granularity) * granularity;
                    
                    while final_length < min_samples
                        final_length    = final_length + granularity;
                    end
                
                    trapeze_pulse                           = zeros(1, final_length);
                    trapeze_pulse(1:length(trapez_pulse))   = trapez_pulse;
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Calculates Gaussian Pulse
%>
%> This method is static and public
%> This function calculates a Gaussian pulse with user-defined 50% width.
%> 
%> @param obj instance of the TEProteusLib class
%> @param t_50 50% pulse width in seconds
%> @param sample_rate Sample Rate for the calculated pulse waveform
%> @param pulse_length Pulse waveform length in pulses (50% width)
%> @param min_samples Minimum length for the ouput pulse waveform
%> @param granularity Length Granularity for the ouput pulse waveform
%> @retval gauss_pulse Calculated Gaussian Pulse
% =========================================================================
        function [gauss_pulse, error] = GetGaussPulse(  obj,...
                                                        t_50, ...
                                                        sample_rate, ...
                                                        pulse_length, ...
                                                        min_samples, ...
                                                        granularity)
            error = 0;
            gauss_pulse = double.empty;

            if granularity <= 0
                error = 4;
            end

            if t_50 <= 0.0 || sample_rate <= 0.0 || pulse_length <= 0.0
                error = 5; % Wrong parameter(s)
            end

            if error == 0        
                pulse_length        = pulse_length * t_50;
                pulse_length        = pulse_length * sample_rate;
                pulse_length        = ceil(pulse_length);
            
                if mod(pulse_length, 2) == 0
                    pulse_length    = pulse_length + 1;
                end
            
                a                   =  t_50 / (2 * ((-log(0.5))  ^ 0.5));
            
                isol_gauss_pulse    = (-(pulse_length - 1) / 2):((pulse_length - 1) / 2);
                
                isol_gauss_pulse    = isol_gauss_pulse / sample_rate;
            
                isol_gauss_pulse    = exp(-isol_gauss_pulse .^2 / a ^ 2);
            
                final_length        = ceil(length(isol_gauss_pulse) / granularity) * granularity;
                
                while final_length < min_samples
                    final_length    = final_length + granularity;
                end
            
                gauss_pulse         = zeros(1, final_length);
                gauss_pulse(1:length(isol_gauss_pulse))...
                                    = isol_gauss_pulse;
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Calculates Complex Chirp Pulse
%>
%> This method is static and public
%> This function calculates a Chirp pulse with user defined parameters.
%> 
%> @param obj instance of the TEProteusLib class
%> @param chirp_duration Duration of the chirp in seconds
%> @param chirp_bw Bandwidth of the chirp (-BW/2 to +BW/2 sweep)
%> @param sample_rate Sample Rate for the Chirp Pulse waveform
%> @param corr_apply Apply corrections (optional, boolean)
%> @param corr_freq Frequency data for correction factors
%> @param corr_ampl Frequency response (amplitude, dB)
%> @param corr_phase Frequency response (phase, degrees)
%> @retval iq_chirp Calculated Chirp Pulse
% =========================================================================
        function [iq_chirp, error] = GetIqChirp(    obj,...
                                                    chirp_duration, ...
                                                    chirp_bw, ...
                                                    sample_rate, ...
                                                    granularity, ...
                                                    corr_apply, ...
                                                    corr_freq, ...
                                                    corr_ampl,...
                                                    corr_phase)
            error = 0;
            iq_chirp = complex(double.empty);

            if granularity <= 0
                error = 4;
            end

            if chirp_duration <= 0.0 || sample_rate <= 0.0 
                error = 5; % Wrong parameter(s)
            end

            if error == 0        
                num_samples = floor(chirp_duration * sample_rate);
                iq_chirp    = 0:(num_samples- 1);
                iq_chirp    = iq_chirp - num_samples/ 2;
                iq_chirp    = iq_chirp / sample_rate;
               
                inst_freq   = iq_chirp * chirp_bw / chirp_duration;
    
                ampl_corr = zeros(1, length(inst_freq));
                ampl_corr = ampl_corr + 1.0;
                if corr_apply
                    for i = 1:length(inst_freq)
                        current_freq = abs(inst_freq(i));
                        freq_idx = find(corr_freq >= current_freq);
                        freq_idx = freq_idx(1);
                        freq_offset = freq_idx - current_freq;
    
                        ampl_corr(i) = 10^(-corr_ampl(freq_idx) / 20);
                        %ampl_corr(i) = ampl_corr(i) + (10^(-corr_ampl(freq_idx + 1) / 20) - ampl_corr(i)) * freq_offset / (corr_freq(freq_idx + 1) - corr_freq(freq_idx));
                    end
                end
                % As phase change with t^2, instantaneous frequency is multiplied by pi and not 2pi
                iq_chirp    = ampl_corr .* exp(1i * pi * inst_freq .* iq_chirp);

                if granularity > 1
                    num_samples = ceil(chirp_duration * sample_rate / granularity) * granularity;
                end
                iq_chirp    = [iq_chirp, zeros(1,num_samples - length(iq_chirp))];
                iq_chirp    = iq_chirp / max(abs(iq_chirp));
            end
        end 

%**************************************************************************

% =========================================================================
%> @brief Calculates FID (Free Induction Decay) Pulse for NMR emulation
%>
%> This method is static and public
%> This function calculates a FID pulse from user-defined parameters.
%> 
%> @param obj instance of the TEProteusLib class
%> @param tau Time constant for exponential decay in seconds
%> @param sample_rate Sample Rate for the calculated pulse waveform
%> @param pulse_length Pulse waveform length in taus
%> @param granularity Length Granularity for the ouput pulse waveform
%> @retval fid_pulse Calculated FID Pulse
% =========================================================================
        function [fid_pulse, error] = GetFidPulse(  obj,...
                                                    tau, ...
                                                    sample_rate, ...
                                                    pulse_length, ...
                                                    granularity)
            error       = 0;
            fid_pulse   = double.empty;

            if granularity <= 0
                error = 4;
            end

            if tau <= 0.0 || sample_rate <= 0.0 || pulse_length <= 0.0
                error = 5; % Wrong parameter(s)
            end
            
            if error == 0
                pulse_length    = pulse_length * tau;
                pulse_length    = pulse_length * sample_rate;
                pulse_length    = ceil(pulse_length);
                final_length    = ceil(pulse_length / granularity) * granularity;         
            
                fid_pulse       = 0:(final_length - 1);
                fid_pulse       = fid_pulse / sample_rate; 
                
                fid_pulse       = exp(-fid_pulse / tau);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Frequency Hopping sequence waveform calculation
%>
%> This method is static and public
%> This function calculates a frequency hopping complex waveform from an
%> user-defined frequency offset list (optional). When not supplied, the
%> sequence of hops is made of random hops
%> 
%> @param obj instance of the TEProteusLib class
%> @param awg_setup AWG settins struct
%> @param freq_hop Frequency Hoping struct with FH parameters
%> @param hop_list List of hops as hopping sequence as hop pointers
%> @retval myWfm Common Waveform with all segments appended
%> @retval map_wfm Map for waveforms in myWfm
%> @retval task_list Task list definition for frequency hopping sequence
% =========================================================================
        function [  myWfm,...
                    map_wfm,...
                    task_list,...
                    error] = GetFreqHopWfms(    obj,...
                                                awg_setup,...
                                                freq_hop,...
                                                hop_list)
            error       = 0;
            myWfm       = complex(double.empty);
            map_wfm     = uint32.empty;
            task_list   = int16.empty;

            if freq_hop.num_of_hops == 0
                error = 5;
            end

            if error == 0
                % Non-Repeating Random Frequency Hoping Sequence
                carrier_hop = zeros(1, freq_hop.num_of_hops); 
    
                if ~exist('hop_list','var')
                    for hop = 1:freq_hop.num_of_hops
                        carrier_hop(hop) = round(rand * freq_hop.num_of_carriers - 0.5); 
                        carrier_hop(carrier_hop < 0) = 0;
                        carrier_hop(carrier_hop > (freq_hop.num_of_carriers - 1)) = freq_hop.num_of_carriers - 1;
        
                        if hop > 1
                            while carrier_hop(hop) == carrier_hop(hop - 1)
                                carrier_hop(hop) = round(rand * (freq_hop.num_of_carriers + 1));
                            end
                        end
                    end
    
                    carrier_hop = carrier_hop + 1;
    
                else
                    for hop = 1:freq_hop.num_of_hops
                        carrier_hop(hop) =  obj.GetActualElement(hop_list, hop);
                    end
                end
    
                actual_sampling_rate = awg_setup.sampling_rate / awg_setup.interpol;
    
                segment_length = actual_sampling_rate * freq_hop.hop_duration;
                segment_length = floor(segment_length / awg_setup.granularity) * awg_setup.granularity;
                
                num_of_cycles = 0: (freq_hop.num_of_carriers - 1); 
                num_of_cycles = num_of_cycles - (freq_hop.num_of_carriers - 1) / 2;
    
                if mod(freq_hop.num_of_carriers, 2) == 0
                    num_of_cycles = 2 * num_of_cycles;
                    basic_num_of_cycles = round(freq_hop.hop_duration * freq_hop.carrier_spacing / 2);                
                else
                    basic_num_of_cycles = round(freq_hop.hop_duration * freq_hop.carrier_spacing);
                end
    
                num_of_cycles = num_of_cycles * basic_num_of_cycles;
                myWfm = zeros(1, segment_length * freq_hop.num_of_carriers);
                x_data = 0: (segment_length - 1);
                shift_num_of_cycles = round((segment_length / actual_sampling_rate) * freq_hop.frequency_shift);
                shift_carrier = exp(1i * 2 * pi * shift_num_of_cycles * x_data / segment_length);
    
                for current_carrier = 1:freq_hop.num_of_carriers
                    initial_sample = (current_carrier - 1) * segment_length + 1;
                    final_sample = initial_sample + segment_length - 1;
                    myWfm(initial_sample:final_sample) = exp(1i * 2 * pi * num_of_cycles(current_carrier) * x_data / segment_length);
                    if abs(freq_hop.frequency_shift) > 0.0                    
                        myWfm(initial_sample:final_sample) = myWfm(initial_sample:final_sample) .* shift_carrier;
                    end
                end            
              
                map_wfm = zeros(1, freq_hop.num_of_carriers);
                map_wfm = map_wfm + segment_length;
    
                 % ********************TASK LIST***************************
                task_list = uint32(zeros(freq_hop.num_of_hops, obj.TASK_MATRIX_WIDTH));
                for current_task = 1:freq_hop.num_of_hops
                    task_list(current_task, obj.TASK_SEGMENT_PTR)  = carrier_hop(current_task);
                    task_list(current_task, obj.TASK_TYPE)         = obj.TASK_TYPE_SINGLE;
                    task_list(current_task, obj.TASK_LOOPS)        = 1;
                    if current_task == freq_hop.num_of_hops
                        task_list(current_task, obj.TASK_NEXT)         = 1;
                    else
                        task_list(current_task, obj.TASK_NEXT)         = current_task + 1;   
                    end
                    task_list(current_task, obj.TASK_ENABLE_EVENT) = obj.TASK_EVENT_NONE;
                    task_list(current_task, obj.TASK_ABORT_EVENT)  = obj.TASK_EVENT_NONE;
                    if current_task == 1
                        task_list(current_task, obj.TASK_DTR_FLAG)      = 1;
                    else
                        task_list(current_task, obj.TASK_DTR_FLAG)      = 0;
                    end
                end
                %**********************************************************
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Polyphase Pulse waveform calculation
%>
%> This method is static and public
%> This function calculates a polyphase sequence for pulse-compression in
%> radar applications. It supports the following polyphase standards:
%>  - Barker Codes
%>  - Frank Codes
%>  - P1, P2, P3, and P4 Codes
%> 
%> @param obj instance of the TEProteusLib class
%> @param intra_modulation Code Type
%> @param code_number Code # for a given type of code
%> @param sample_rate Sample Rate for calculated waveform
%> @param pulse_length Pulse duration in seconds
%> @param granularity Granularity parameter for waveform length calculation
%> @retval polyphase_pulse Pulse waveform with the defined Code Type and #
% =========================================================================
        function [polyphase_pulse, error] = GetPolyPhasePulse(  obj,...
                                                                intra_modulation,...
                                                                code_number,...
                                                                sample_rate, ...
                                                                pulse_length, ...
                                                                granularity)
            error = 0;
            polyphase_pulse = complex(double.empty);

            
            if sample_rate <= 0.0 || pulse_length <= 0.0
                error = 5;
            elseif granularity <= 0
                error = 4;
            end

            if error == 0
                pulse_length    = pulse_length * sample_rate;
                pulse_length    = ceil(pulse_length);
                final_length    = ceil(pulse_length / granularity) * granularity;         
            
                switch intra_modulation
                    case obj.PULSE_TYPE_BARKER_CODE
                        [code_iq, error] = obj.GetBarkerCode(code_number);
    
                    case obj.PULSE_TYPE_FRANK_CODE
                        [code_iq, error] = obj.GetFrankCode(code_number);
    
                    case obj.PULSE_TYPE_P1_CODE
                        [code_iq, error] = obj.GetP1Code(code_number);
    
                    case obj.PULSE_TYPE_P2_CODE
                        [code_iq, error] = obj.GetP2Code(code_number);
    
                    case obj.PULSE_TYPE_P3_CODE
                        [code_iq, error] = obj.GetP3Code(code_number);
    
                    case obj.PULSE_TYPE_P4_CODE
                        [code_iq, error] = obj.GetP4Code(code_number);

                    otherwise
                        error = 9;

                end
    
                polyphase_pulse = zeros(1,final_length);
                num_of_chips    = length(code_iq);
    
                for current_chip = 1:num_of_chips
                    start_chip = (current_chip - 1) * double(pulse_length) / num_of_chips;
                    stop_chip = start_chip + pulse_length / num_of_chips;
                    start_chip = round(start_chip) + 1;
                    stop_chip = round(stop_chip) + 1;
                    polyphase_pulse(start_chip:stop_chip) = code_iq(current_chip);
                end 
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get Barker Code chips sequence
%>
%> This method is static and public
%> This function gets the sequence of chips for a given Barker code.
%> Barker codes supported go from # up to #13, including variants.
%> 
%> @param obj instance of the TEProteusLib class
%> @param barker_code Code #
%> @retval code_iq Chips sequence
% =========================================================================
        function [code_iq, error] = GetBarkerCode(obj, barker_code)

            error = 0;
            code_iq = complex(double.empty);

            switch barker_code
                case obj.PULSE_BARKER_02
                    code_iq = obj.PULSE_BARKER_02_SEQ;

                case obj.PULSE_BARKER_02_BIS
                    code_iq = obj.PULSE_BARKER_02_BIS_SEQ;

                case obj.PULSE_BARKER_03
                    code_iq = obj.PULSE_BARKER_03_SEQ;

                case obj.PULSE_BARKER_04
                    code_iq = obj.PULSE_BARKER_04_SEQ;

                case obj.PULSE_BARKER_04_BIS
                    code_iq = obj.PULSE_BARKER_04_BIS_SEQ;

                case obj.PULSE_BARKER_05
                    code_iq = obj.PULSE_BARKER_05_SEQ;

                case obj.PULSE_BARKER_07
                    code_iq = obj.PULSE_BARKER_07_SEQ;

                case obj.PULSE_BARKER_11
                    code_iq = obj.PULSE_BARKER_11_SEQ;

                case obj.PULSE_BARKER_13
                    code_iq = obj.PULSE_BARKER_13_SEQ;

                otherwise
                    error   = 9;
            end        
        end

%**************************************************************************

% =========================================================================
%> @brief Get Frank Code chips sequence
%>
%> This method is static and public
%> This function gets the sequence of chips for a given Frank code.
%> 
%> @param obj instance of the TEProteusLib class
%> @param frank_code Code #
%> @retval code_iq Chips sequence
% =========================================================================
        function [code_iq, error] = GetFrankCode(obj, frank_code)
            error = 0;
            code_iq = complex(double.empty);

            frank_code = floor(frank_code);

            if frank_code <= 0
                error = 9;
            else
                code_iq = zeros(frank_code, frank_code);
    
                for current_row = 1:frank_code
                    for current_column = 1:frank_code
                        code_iq(current_row, current_column) = (current_row - 1) * (current_column - 1);
                    end
                end
    
                delta_angle = 2 * pi / frank_code;
    
                code_iq = delta_angle * code_iq;
                code_iq = reshape(code_iq', 1, frank_code * frank_code);
                code_iq = exp(1i * code_iq);  
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get P1 Code chips sequence
%>
%> This method is static and public
%> This function gets the sequence of chips for a given P1 code.
%> 
%> @param obj instance of the TEProteusLib class
%> @param p1_code Code #
%> @retval code_iq Chips sequence
% =========================================================================
        function [code_iq, error] = GetP1Code(obj, p1_code)
            error = 0;
            code_iq = complex(double.empty);

            p1_code = floor(p1_code);

            if p1_code <= 0
                error = 9;
            else
                code_iq = zeros(p1_code, p1_code);
    
                for current_row = 1:p1_code
                    for current_column = 1:p1_code
                        code_iq(current_row, current_column) =...
                            (p1_code + 1 - 2 * current_column) * ( p1_code * (current_column - 1) + (current_row - 1));
                    end
                end
    
                delta_angle = -pi / p1_code;
    
                code_iq = delta_angle * code_iq;
                %code_iq = mod(code_iq, 2*pi);
                code_iq = reshape(code_iq', 1, p1_code * p1_code);
                code_iq = exp(1i * code_iq); 
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get P2 Code chips sequence
%>
%> This method is static and public
%> This function gets the sequence of chips for a given P2 code.
%> 
%> @param obj instance of the TEProteusLib class
%> @param p2_code Code #
%> @retval code_iq Chips sequence
% =========================================================================
        function [code_iq, error] = GetP2Code(obj, p2_code)
            error = 0;
            code_iq = complex(double.empty);

            p2_code = floor(p2_code);

            if p2_code <= 0
                error = 9;
            else
                code_iq = zeros(p2_code, p2_code);
    
                for current_row = 1:p2_code
                    for current_column = 1:p2_code
                        code_iq(current_row, current_column) =...
                            (p2_code + 1 - 2 * current_row) * (p2_code + 1 - 2 * current_column);
                    end
                end
    
                delta_angle = pi / (2 * p2_code);
    
                code_iq = delta_angle * code_iq;
                %code_iq = mod(code_iq, 2*pi);
                code_iq = reshape(code_iq', 1, p2_code * p2_code);
                code_iq = exp(1i * code_iq);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get P3 Code chips sequence
%>
%> This method is static and public
%> This function gets the sequence of chips for a given P3 code.
%> 
%> @param obj instance of the TEProteusLib class
%> @param p3_code Code #
%> @retval code_iq Chips sequence
% =========================================================================
        function [code_iq, error] = GetP3Code(obj, p3_code)
            error = 0;
            code_iq = complex(double.empty);

            p3_code = floor(p3_code);

            if p3_code <= 0
                error = 9;
            else
                code_iq = zeros(1, p3_code);
    
                for current_column = 1:p3_code
                    code_iq(current_column) = (current_column - 1)^2;
                end
    
                delta_angle = pi / p3_code;
                code_iq = delta_angle * code_iq;
                code_iq = exp(1i * code_iq);     
            end
        end

%**************************************************************************
% =========================================================================
%> @brief Get P4 Code chips sequence
%>
%> This method is static and public
%> This function gets the sequence of chips for a given P4 code.
%> 
%> @param obj instance of the TEProteusLib class
%> @param p4_code Code #
%> @retval code_iq Chips sequence
% =========================================================================
        function [code_iq, error] = GetP4Code(obj, p4_code)
            error = 0;
            code_iq = complex(double.empty);

            p4_code = floor(p4_code);

            if p4_code <= 0
                error = 9;
            else
                code_iq = zeros(1, p4_code);
    
                for current_column = 1:p4_code
                    code_iq(current_column) = (current_column - 1) * (current_column - 1 - p4_code);
                end
    
                delta_angle = pi / p4_code;
                code_iq = delta_angle * code_iq;
                code_iq = exp(1i * code_iq);   
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Pulse waveform and task list calculation
%>
%> This method is static and public
%> This function calculates a baseband pulse and creates an optimal
%> segmentation of the waveform and the corresponding task list to generate
%> the overall pulsed waveform. These requires one, two or three segments.
%> There may be a ON segment, an OFF segment, and a Transition segment.
%> 
%> @param obj instance of the TEProteusLib class
%> @param awg_setup AWG settins struct
%> @param pulse_setup Pulse parameter definition
%> @retval myWfm Common Waveform with all segments appended
%> @retval map_wfm Map for waveforms in myWfm
%> @retval task_list Task list definition for Pulse waveform
% =========================================================================
        function [  myWfm,...
                    map_wfm,...
                    task_list,...
                    error] = GetPulseWfms(  obj,...
                                            awg_setup,...
                                            pulse_setup)
            error = 0;
            myWfm = complex(double.empty);
            map_wfm = uint64.empty;
            task_list = int16.empty;

            if awg_setup.sampling_rate <= 0.0 || awg_setup.interpol <= 0 ...
                || pulse_setup.pulse_rep_freq <= 0.0
                error = 5;
            elseif awg_setup.granularity <= 0
                error = 4;
            end

            if error == 0        
                % Baseband waveform sample rate
                actual_sampling_rate    = awg_setup.sampling_rate / awg_setup.interpol;
                % Actual Granularity and Minimum Segment Length for complex wfms
                awg_granularity         = awg_setup.granularity / 2;
                min_segment_length      = awg_setup.min_segment / 2;
                % Duration of one complete cycle
                total_duration          = 1.0 / pulse_setup.pulse_rep_freq;
                
                % Wfm length in samples rounde to the actual granularity
                awg_wfm_length          = total_duration * actual_sampling_rate;
                while (awg_wfm_length / min_segment_length) > 1E6
                    min_segment_length  = min_segment_length + awg_granularity;
                end
                awg_wfm_length          = awg_granularity * floor(awg_wfm_length / awg_granularity);
            
                % I/Q complex pulse
                % =================
                % Pulse length is samples
    
                pulse_setup.sampling_rate = actual_sampling_rate;
                pulse_min_length = pulse_setup.min_seg_t * actual_sampling_rate;
    
                switch pulse_setup.pulse_type               
    
                    case obj.PULSE_TYPE_SQUARE
                        pulse_length            = round(pulse_setup.pulse_width * actual_sampling_rate);  
                        % Number of segments with minimum segment length
                        repeat_pulse_section    = floor(pulse_length / min_segment_length);
                        % Pulse segment is "all 1s"
                        pulse_section           = complex(ones(1, min_segment_length));
    
                    case obj.PULSE_TYPE_TRAPEZOIDAL
                        pulse_section = obj.GetTrapezoidalPulse(    pulse_setup.pulse_width, ...
                                                                    pulse_setup.edge_shape, ...
                                                                    pulse_setup.rise_time,...
                                                                    pulse_setup.sampling_rate, ...                                                    
                                                                    min_segment_length, ...
                                                                    1, ... % granularity for calculation
                                                                    pulse_setup.quality);
    
                        if abs(pulse_setup.time_offset) > 0.0
                            pre_pulse_samples = round(abs(pulse_setup.time_offset) * actual_sampling_rate);
                            pulse_section = [zeros(1,pre_pulse_samples), pulse_section];
                        end
                         
                        while mod(length(pulse_section), awg_granularity) > 0 || length(pulse_section) < pulse_min_length
                            pulse_section = [pulse_section, 0.0];
                        end
    
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
                        pulse_section           = complex(pulse_section);
    
                    case obj.PULSE_TYPE_GAUSSIAN
                        pulse_section = obj.GetGaussPulse(          pulse_setup.pulse_width,...
                                                                    actual_sampling_rate,...
                                                                    pulse_setup.quality,...
                                                                    min_segment_length,...
                                                                    awg_granularity);
                        
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
                        pulse_section           = complex(pulse_section);
                        
                    case obj.PULSE_TYPE_NMR_FID
                        pulse_section = obj.GetFidPulse(            pulse_setup.pulse_width, ...
                                                                    actual_sampling_rate, ...
                                                                    pulse_setup.quality, ...
                                                                    awg_granularity);
                        
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
                        pulse_section           = complex(pulse_section);
    
                    case obj.PULSE_TYPE_CHIRP_UP
                        pulse_section = obj.GetIqChirp(             pulse_setup.pulse_width, ...
                                                                    pulse_setup.bandwidth, ...
                                                                    actual_sampling_rate, ...
                                                                    awg_granularity,...
                                                                    false,...
                                                                    double.empty,...
                                                                    double.empty);
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
                      
                    case obj.PULSE_TYPE_CHIRP_DOWN
                        pulse_section = obj.GetIqChirp(             pulse_setup.pulse_width, ...
                                                                    pulse_setup.bandwidth, ...
                                                                    actual_sampling_rate, ...
                                                                    awg_granularity,...
                                                                    false,...
                                                                    double.empty,...
                                                                    double.empty);
                        pulse_section           = complex(pulse_section);
                        pulse_section           = conj(pulse_section);
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
    
                    case {  obj.PULSE_TYPE_BARKER_CODE,...
                            obj.PULSE_TYPE_FRANK_CODE,...
                            obj.PULSE_TYPE_P1_CODE,...
                            obj.PULSE_TYPE_P2_CODE,...
                            obj.PULSE_TYPE_P3_CODE,...
                            obj.PULSE_TYPE_P4_CODE}
                        pulse_section = obj.GetPolyPhasePulse(  pulse_setup.pulse_type,...
                                                                pulse_setup.polyphase_code,...
                                                                pulse_setup.sampling_rate, ...
                                                                pulse_setup.pulse_width, ...
                                                                pulse_setup.granul);
                        pulse_section           = complex(pulse_section);
                        pulse_section           = conj(pulse_section);
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
              
    
                    case obj.PULSE_TYPE_FILE
                        pulse_section = obj.GetFilePulse(           pulse_setup.file_name,...
                                                                    pulse_setup.file_fmt,...
                                                                    pulse_setup.time_fmt,...
                                                                    pulse_setup.complex_fmt,...
                                                                    pulse_setup.in_wfm_fraction,...
                                                                    pulse_setup.in_wfm_offset,...
                                                                    pulse_setup.in_sample_rate,...
                                                                    actual_sampling_rate,...                                                    
                                                                    min_segment_length,...
                                                                    awg_granularity);
                        pulse_length            = length(pulse_section);
                        repeat_pulse_section    = 1;
    
                end    
    
                if pulse_setup.pulse_type ~= obj.PULSE_TYPE_SQUARE
    
                    pulse_section = obj.ShiftFreq(  pulse_section, ...
                                                    pulse_setup.freq_offset, ...
                                                    pulse_setup.initial_phase ,...
                                                    actual_sampling_rate,...
                                                    false);
                end
            
                % I/Q interval between pulses
                % ===========================   
                % Total length for the all zeros section in samples
                off_section_length  = awg_wfm_length - pulse_length;
                % Number of segments with minimum segment length
                repeat_off_section  = floor(off_section_length / min_segment_length);
                % Pulse segment is "all 1s"
                off_section         = complex(zeros(1, min_segment_length));
            
                % I/Q transition segment
                % ======================
                if pulse_setup.pulse_type == obj.PULSE_TYPE_SQUARE
                    % Total length for the transition section in samples
                    trans_section_length    = awg_wfm_length -...
                        min_segment_length * (repeat_pulse_section + repeat_off_section);
                    % Number of ones in the transition section
                    ones_in_trans_section   = pulse_length -...
                            repeat_pulse_section * min_segment_length;
                else
                    % Total length for the transition section in samples
                    trans_section_length    = awg_wfm_length -...
                        min_segment_length * repeat_off_section - pulse_length;
                    % Number of ones in the transition section
                    ones_in_trans_section   = 0;
                end
                
                trans_section   = double.empty;
                % Transition segment calculation
                if trans_section_length ~= 0 
                    trans_section = complex(zeros(1, trans_section_length));
                    if ones_in_trans_section ~= 0
                        trans_section(1:ones_in_trans_section) = complex(1.0);
                    end
                    % Transition length must be corrected in case its length is shorter
                    % than the minimum segment length by adding either a pulse or an
                    % off segment so the number of reps must be edited
                    if trans_section_length < min_segment_length 
                        if repeat_off_section > 0
                            trans_section           = [trans_section, off_section];
                            repeat_off_section      = repeat_off_section - 1;
                            trans_section_length    = trans_section_length + min_segment_length;
                        elseif repeat_pulse_section > 0
                            trans_section           = [pulse_section, trans_section];
                            repeat_pulse_section    = repeat_pulse_section - 1;
                        end
                    end
                end
                % Meaning of fields in task array
                %   1               pointer_to_segment
                %   2               task_type: 0: Single, 1: StartSeq, 2: InSeq, 3: EndSeq
                %   3               num_of_loops_task
                %   4               num_of_loops_seq
                %   5               next_task
                %   6               dtr_trig_flag: 0: dtr trigger off, 1: dtr trigger on
                %   7               enable_event
                %   8               abort event
            
                % The number of waveforms may be one, two, or three
                % The number of tasks may be one, two, three, o four
                num_of_wfms     = 0;
                myWfm           = complex(double.empty);
                map_wfm         = uint32.empty;
                num_of_tasks    = 0;
            
                if repeat_pulse_section > 0
                    num_of_wfms = num_of_wfms + 1;        
                    myWfm       = [myWfm, pulse_section];                
                    map_wfm     = [map_wfm, length(pulse_section)];
                 
                    % If there must be more than one repetition of the pulse segment,
                    % there must be an additional task so the DTR trigger happens only
                    % once in a waveform cycle.
                    if repeat_pulse_section == 1
                        num_of_tasks = num_of_tasks + 1;
                    else
                        num_of_tasks = num_of_tasks + 2;
                    end
                end
                if length(trans_section) >= 1
                    num_of_wfms     = num_of_wfms + 1;
                    myWfm           = [myWfm, trans_section];
                    map_wfm         = [map_wfm, trans_section_length];
                    num_of_tasks    = num_of_tasks + 1;
                end
                if repeat_off_section > 0
                    num_of_wfms     = num_of_wfms + 1;
                    myWfm           = [myWfm, off_section];
                    map_wfm         = [map_wfm, min_segment_length];
                    num_of_tasks    = num_of_tasks + 1;
                end
    
                if pulse_setup.trg_src == obj.TASK_EVENT_TRG1 ||...
                        pulse_setup.trg_src == obj.TASK_EVENT_TRG2
                    num_of_tasks = num_of_tasks + 1;
                end
                % Task list two dimensional array is created
                task_list       = uint32(zeros(num_of_tasks, obj.TASK_MATRIX_WIDTH)); 
                % And then populated for proper sequencing, pulse timing, PRI, and
                % continuous geneation
                task_pointer    = 1;
                segment_pointer = 1;
    
                if pulse_setup.trg_src == obj.TASK_EVENT_TRG1 ||...
                        pulse_setup.trg_src == obj.TASK_EVENT_TRG2
                    % The off segment may be repeated zero or more times
                    task_list(task_pointer, obj.TASK_SEGMENT_PTR)   = length(map_wfm);
                    task_list(task_pointer, obj.TASK_TYPE)          = 0;
                    task_list(task_pointer, obj.TASK_LOOPS)         = 1;
                    task_list(task_pointer, obj.TASK_NEXT)          = task_pointer + 1;
                    task_list(task_pointer, obj.TASK_DTR_FLAG)      = 0; 
                    task_list(task_pointer, obj.TASK_ENABLE_EVENT)  = pulse_setup.trg_src;
                    task_list(task_pointer, obj.TASK_ABORT_EVENT)   = obj.TASK_EVENT_NONE;
    
                    task_pointer    = task_pointer + 1;
                end            
    
                if repeat_pulse_section > 0
                    % Pulse segment is always generated once in the first task
                    task_list(task_pointer, obj.TASK_SEGMENT_PTR)   = segment_pointer;
                    task_list(task_pointer, obj.TASK_TYPE)          = 0;
                    task_list(task_pointer, obj.TASK_LOOPS)         = 1;            
                    task_list(task_pointer, obj.TASK_NEXT)          = task_pointer + 1;
                    task_list(task_pointer, obj.TASK_DTR_FLAG)      = 1; 
                    task_list(task_pointer, obj.TASK_ENABLE_EVENT)  = obj.TASK_EVENT_NONE;
                    task_list(task_pointer, obj.TASK_ABORT_EVENT)   = obj.TASK_EVENT_NONE;
                    task_pointer = task_pointer + 1;
                    % If number of repetitions is larger than one, the second task must
                    % be added with the number of repetitions - 1 as task #1 takes care
                    % of the first repetition
                    if repeat_pulse_section > 1
                        task_list(task_pointer, obj.TASK_SEGMENT_PTR)   = segment_pointer;
                        task_list(task_pointer, obj.TASK_TYPE)          = 0;
                        task_list(task_pointer, obj.TASK_LOOPS)         = repeat_pulse_section - 1;
                        task_list(task_pointer, obj.TASK_NEXT)          = task_pointer + 1;
                        task_list(task_pointer, obj.TASK_DTR_FLAG )     = 0;
                        task_list(task_pointer, obj.TASK_ENABLE_EVENT)  = obj.TASK_EVENT_NONE;
                        task_list(task_pointer, obj.TASK_ABORT_EVENT)   = obj.TASK_EVENT_NONE;
                        task_pointer = task_pointer + 1;
                    end
                    segment_pointer = segment_pointer + 1;
                end           
            
                if length(trans_section) >= 1
                    task_list(task_pointer, obj.TASK_SEGMENT_PTR)   = segment_pointer;
                    task_list(task_pointer, obj.TASK_TYPE)          = 0;
                    task_list(task_pointer, obj.TASK_LOOPS)         = 1;
                    task_list(task_pointer, obj.TASK_NEXT)          = task_pointer + 1;
                    % Transition segments may be repeated zero or one time. When there
                    % is no pulse segment, the transition segment will be generated
                    % first and it has to generate the DTR trigger
                    if repeat_pulse_section == 0
                        task_list(task_pointer, obj.TASK_DTR_FLAG)  = 1;
                    else
                        task_list(task_pointer, obj.TASK_DTR_FLAG)  = 0;
                    end
                    
                    task_list(task_pointer, obj.TASK_ENABLE_EVENT)  = obj.TASK_EVENT_NONE;
                    task_list(task_pointer, obj.TASK_ABORT_EVENT)   = obj.TASK_EVENT_NONE;
            
                    task_pointer    = task_pointer + 1;
                    segment_pointer = segment_pointer + 1;
                end
    
                % TASK_SEGMENT_PTR        = 1;
                % TASK_TYPE               = 2;
                % TASK_LOOPS              = 3;
                % TASK_LOOPS_SEQ          = 4;
                % TASK_NEXT               = 5;
                % TASK_DTR_FLAG           = 6;
                % TASK_ENABLE_EVENT       = 7;
                % TASK_ABORT_EVENT        = 8;
            
                if repeat_off_section > 0
                    % The off segment may be repeated zero or more times
                    task_list(task_pointer, obj.TASK_SEGMENT_PTR)   = segment_pointer;
                    task_list(task_pointer, obj.TASK_TYPE)          = 0;
                    task_list(task_pointer, obj.TASK_LOOPS)         = repeat_off_section;
                    task_list(task_pointer, obj.TASK_NEXT)          = 1;
                    task_list(task_pointer, obj.TASK_DTR_FLAG)      = 0; 
                    task_list(task_pointer, obj.TASK_ENABLE_EVENT)  = obj.TASK_EVENT_NONE;
                    task_list(task_pointer, obj.TASK_ABORT_EVENT)   = obj.TASK_EVENT_NONE;
                end
                % The last task always point yo task # 1
                task_list(task_pointer, obj.TASK_NEXT) = 1;    
            end
        end

%*************************************************************************%
%                            NMR FUNCTIONS                                %
%*************************************************************************%

        function [  time_corrected_signal,...
                    shift_factor] = RmnCoarseDelayCorrection(   obj,...
                                                                test_signal)
            % Delay correction
            stop_sample     = length(test_signal);
            start_sample    = stop_sample - round(length(test_signal) * 10/100);          
            threshold       = max(abs(real(test_signal))) / 4;            
            shift_factor    = 0;
            
            while abs(test_signal(shift_factor + 1)) < threshold && shift_factor <= stop_sample
                shift_factor = shift_factor + 1;
            end
        
            time_corrected_signal = circshift(test_signal,-shift_factor);
        end

%**************************************************************************

        function [  phase_corrected_data,...
                    time_correction,...
                    final_phase_correction] = RmnFineCorrection(    obj,...
                                                                    spectrum_data,...
                                                                    target_phase_resolution)

            xData = 0:(length(spectrum_data) -1);
            xData = xData - length(spectrum_data) / 2;
            xData = xData / length(spectrum_data);
            xData = 2.0 * pi * xData;

            abs_min_ratio           = 0.0;
            time_correction         = 0.0;
            final_phase_correction  = 0.0;
            init_flag               = true;
            phase_corrected_data    = spectrum_data;
            % imag_avg                = double.empty;
            % ratio_vs_offset         = double.empty;

            for sample_offset = -2:0.05:2
                test_spectrum_data = spectrum_data .* exp(-1i * sample_offset * xData);
                [   test_spectrum_data,...
                    phase_correction,...
                    min_ratio]  = obj.RmnPhaseCorrection(   test_spectrum_data,...
                                                            target_phase_resolution);
                % ratio_vs_offset = [ratio_vs_offset, min_ratio];
                % imag_avg = [imag_avg, mean(imag(test_spectrum_data))];
                if init_flag || min_ratio < abs_min_ratio
                    init_flag               = false;
                    abs_min_ratio           = min_ratio;
                    phase_corrected_data    = test_spectrum_data;
                    time_correction         = sample_offset;
                    final_phase_correction  = phase_correction;
                end
                plot(real(test_spectrum_data));
                drawnow;
                pause(1);
            end
            %a = 1;
        end

%**************************************************************************

        function [  phase_corrected_data,...
                    final_phase_correction,...
                    min_ratio]  = RmnPhaseCorrection(   obj,...
                                                        spectrum_data,...
                                                        target_phase_resolution)
        
            if ~exist('target_phase_resolution','var')
             % third parameter does not exist, so default it to something
              target_phase_resolution = 0.1;
            end
        
            % Phase Correction
            final_phase_correction  = 0.0;
            init_flag               = true;    
            min_ratio               = 1.0;        
            phase_resolution        = 1.0;
            start_phase             = -180.0;
            stop_phase              = 180.0;
        
            while phase_resolution >= target_phase_resolution
            
                for phase_correction = start_phase:phase_resolution:stop_phase   
                    
                    pSpec = exp(1i*phase_correction / 180) * spectrum_data;    
                    pSpec = real(pSpec);
                
                    num_sample_pos = sum(pSpec(pSpec > 0.0)); %.^2);
                    num_sample_neg = -sum(pSpec(pSpec < 0.0));%.^2);
                
                    if num_sample_pos > num_sample_neg
                        current_ratio = num_sample_neg / num_sample_pos;
                    else
                        current_ratio = num_sample_pos / num_sample_neg;
                    end
                
                    if init_flag || current_ratio < min_ratio
                        init_flag               = false;
                        min_ratio               = current_ratio;
                        final_phase_correction  = phase_correction;
                    end   
                end
        
                init_flag   = true;
                start_phase = final_phase_correction - phase_resolution; 
                stop_phase  = final_phase_correction + phase_resolution;
        
                phase_resolution = phase_resolution / 10.0;
            end
          
            phase_corrected_data = exp(1i*final_phase_correction / 180) * spectrum_data;
        end

%**************************************************************************        
        
        function [  rmn_spec,...
                    delay_corr,...
                    phase_corr] = RmnGetSpectrum(   obj,...
                                                    test_data,...
                                                    sample_rate,...
                                                    target_phase_resolution)
            
            if ~exist('target_phase_resolution','var')
             % third parameter does not exist, so default it to something
              target_phase_resolution = 0.1;
            end
        
            % Delay correction
            [   test_data,...
                shift_factor]   = obj.RmnCoarseDelayCorrection(test_data);
            delay_corr          = shift_factor / sample_rate; 
        
            spectrum_data       = fft(test_data);
            spectrum_data       = fftshift(spectrum_data);
            spectrum_data       = spectrum_data / max(abs(spectrum_data));

            [   rmn_spec,...
                time_correction,...
                phase_corr] = RmnFineCorrection(    obj,...
                                                    spectrum_data,...
                                                    target_phase_resolution);
           
            delay_corr = delay_corr + time_correction / sample_rate;                  
        end

%*************************************************************************%
%                         INTERPOLATION EMULATOR                          %
%*************************************************************************%

% =========================================================================
%> @brief DAC's interpolation filter calculation for Proteus
%>
%> This method is static and public
%> This function returns all the filter coefficients for all the
%> interpolation filters used in Proteus
%>
%> @retval filters Vector of vectors containing all the FIR coefficients
%> @retval filter_size Vector with number of taps for each filter
% =========================================================================
        function [filters, filter_size] = GetProteusFilters(obj)
        
            filters     = zeros(8, 59);
            filter_size = zeros(1, 8);
        
            filters(obj.AWG_INT_FILTER_0,:) = [6,0,-19,0,47,0,-100,0,192,0,...
                -342,0,572,0,-914,0,1409,0,-2119,0,3152,0,-4729,0,7420,0,...
                -13334,0,41527,65536,41527,0,-13334,0,7420,0,-4729,0,3152,...
                0,-2119,0,1409,0,-914,0,572,0,-342,0,192,0,-100,0,47,0,-19,0,6];
            filter_size(obj.AWG_INT_FILTER_0)           = 59;
            filters(obj.AWG_INT_FILTER_1,1:23) = [-12,0,84,0,-336,0,1006,0,...
                -2691,0,10141,16384,10141,0,-2691,0,1006,0,-336,0,84,0,-12];
            filter_size(obj.AWG_INT_FILTER_1)           = 23;
            filters(obj.AWG_INT_FILTER_0_5X,1:39) =[-6,-22,-51,-89,-117,...
                -106,-18,171,449,745,930,841,338,-618,-1892,-3147,-3872,...
                -3500,-1564,2121,7336,13430,19426,24231,26904,-618,338,841,...
                930,745,449,171,-18,-106,-117,-89,-51,-22,-6];
            filter_size(obj.AWG_INT_FILTER_0_5X)        = 50;
            filters(obj.AWG_INT_FILTER_2,1:11) = [29,0,-214,0,1209,2048,...
                1209,0,-214,0,29];
            filter_size(obj.AWG_INT_FILTER_2)           = 11;
            filters(obj.AWG_INT_FILTER_0_3X,1:30) = [-14,-61,-125,-95,181,...
                681,972,347,-1475,-3519,-3528,707,9337,19445,26299,26299,...
                19445,9337,707,-3528,-3519,-1475,347,972,681,181,-95,-125,-61,-14];
            filter_size(obj.AWG_INT_FILTER_0_3X)        = 30;
            filters(obj.AWG_INT_FILTER_3,1:11) = [3,0,-25,0,150,256,150,0,-25,0,3];
            filter_size(obj.AWG_INT_FILTER_3)           = 11;
            filters(obj.AWG_INT_FILTER_1_3X,1:20) = [25,88,22,-576,-1764,...
                -2263,491,8139,18625,26365,26365,18625,8139,491,-2263,-1764,...
                -576,22,88,25];
            filter_size(obj.AWG_INT_FILTER_1_3X)        = 20;
            filters(obj.AWG_INT_FILTER_INVSINC,1:9) = [1,-4,13,-50,592,-50,...
                13,-4,1];
            filter_size(obj.AWG_INT_FILTER_INVSINC)     = 9;
            filters(obj.AWG_INT_FILTER_NOFILTER,1)      = 1;
            filter_size(obj.AWG_INT_FILTER_NOFILTER)    = 1;
        end

%**************************************************************************

% =========================================================================
%> @brief DAC's combination of filters for each interpolation factor
%>
%> This method is static and public
%> This function returns the sequence of filters being applied for each one
%> of the intrepolation factors supported by the DAC, according to the DAC
%> chip manufacturer.
%>
%> @param obj instance of the TEProteusLib class
%> @param interpol_factor overall interpolation factor
%> @param flag_invsinc Apply sinc inversion
%> @retval filter_sequence Vector with the involved interpolation filters
% =========================================================================        
function filter_sequence = GetIntFilterSeq(obj, interpol_factor, flag_invsinc)
            filter_sequence = int16.empty;
        
            switch interpol_factor
                case obj.AWG_INTERPOL_X1
                    filter_sequence = [ obj.AWG_INT_FILTER_NOFILTER];
                case obj.AWG_INTERPOL_X2
                    filter_sequence = [ obj.AWG_INT_FILTER_0];
                case obj.AWG_INTERPOL_X4
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_1];
                case obj.AWG_INTERPOL_X6
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_0_3X];            
                case obj.AWG_INTERPOL_X8
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_1,...
                                        obj.AWG_INT_FILTER_2];
                case obj.AWG_INTERPOL_X10
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_0_5X];
                case obj.AWG_INTERPOL_X12
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_1,...
                                        obj.AWG_INT_FILTER_0_3X];
                case obj.AWG_INTERPOL_X16
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_1,...
                                        obj.AWG_INT_FILTER_2,...
                                        obj.AWG_INT_FILTER_3];
                case obj.AWG_INTERPOL_X18
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_0_3X,...
                                        obj.AWG_INT_FILTER_1_3X];
                case obj.AWG_INTERPOL_X20
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_1,...
                                        obj.AWG_INT_FILTER_0_5X];
                case obj.AWG_INTERPOL_X24
                    filter_sequence = [ obj.AWG_INT_FILTER_0,...
                                        obj.AWG_INT_FILTER_1,...
                                        obj.AWG_INT_FILTER_2,...
                                        obj.AWG_INT_FILTER_0_3X];
            end

            if flag_invsinc
                filter_sequence = [filter_sequence, obj.AWG_INT_FILTER_INVSINC];
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get interpolation factor associated to each interpolation filter
%>
%> This method is static and public
%> This function returns the interpolation factor associated to each filter
%> so it can be applied to the calculation of the combined FIR.
%>
%> @param obj instance of the TEProteusLib class
%> @param filter_index filter identifier
%> @retval filter_interpolation interpolation factor for current filter 
% ========================================================================= 
        function filter_interpolation = GetIntFilterIntFactor(obj, filter_index)
            
            filter_interpolation = 1;
        
            switch filter_index
                case obj.AWG_INT_FILTER_0
                    filter_interpolation = 2;
        
                case obj.AWG_INT_FILTER_1
                    filter_interpolation = 2;
        
                case obj.AWG_INT_FILTER_2
                    filter_interpolation = 2;
        
                case obj.AWG_INT_FILTER_3
                    filter_interpolation = 2;
        
                case obj.AWG_INT_FILTER_0_5X
                    filter_interpolation = 5;
        
                case obj.AWG_INT_FILTER_0_3X
                    filter_interpolation = 3;
        
                case obj.AWG_INT_FILTER_1_3X
                    filter_interpolation = 3;
        
                case obj.AWG_INT_FILTER_INVSINC
                    filter_interpolation = 1;

                 case obj.AWG_INT_FILTER_NOFILTER
                    filter_interpolation = 1;
            end
        end

%**************************************************************************
        
        function out_vector = ZeroPadding(obj, in_vector, exp_factor)
            out_vector = zeros(1, exp_factor * length(in_vector));
            out_vector(1:exp_factor:end) = in_vector;
        end

%**************************************************************************
 
% =========================================================================
%> @brief Get interpolation filter associated to a given interpolation factor
%>
%> This method is static and public
%> This function returns the equivalent one-step interpolation filter for a
%> given combined interpolation factor. Coefficients arenormalized so the
%> DC reponse for a zero-padded wfm is 0dB.
%>
%> @param obj instance of the TEProteusLib class
%> @param interpol_factor Overall Interpolation factor
%> @param flag_invsinc Apply sinc inversion
%> @retval interpol_filter Taps for the FIR filter to be applied to the zero-padded wfm. 
% =========================================================================
        function interpol_filter = GetInterpolFilter(obj, interpol_factor, flag_invsinc)
        
            [filters, filter_size]  = obj.GetProteusFilters();
            filter_sequence         = obj.GetIntFilterSeq(interpol_factor, flag_invsinc);
        
            num_of_steps            = length(filter_sequence);
        
            interpol_filter         = filters(filter_sequence(1),1:filter_size(filter_sequence(1)));
        
            for step = 2:num_of_steps
                interpol_filter     = obj.ZeroPadding(interpol_filter, GetIntFilterIntFactor(obj, filter_sequence(step)));
                current_filter      = filters(filter_sequence(step), 1:filter_size(filter_sequence(step)));
                interpol_filter     = conv(current_filter,interpol_filter);
            end
        
            interpol_filter         = interpol_filter / sum(interpol_filter);
            interpol_filter         = interpol_filter * interpol_factor;
        end

%**************************************************************************        

% =========================================================================
%> @brief Apply interpolation to a waveform as the Protus DAC chip
%>
%> This method is static and public
%> This function returns the interpolated waveform according to the target
%> interpolation factor. DC response is, by definiton, 0dB.
%>
%> @param obj instance of the TEProteusLib class
%> @param interpol_factor Overall Interpolation factor
%> @param wfm Waveform to be interpolated. Real-only or complex(IQ)
%> @param flag_invsinc Apply sinc inversion
%> @retval interpol_wfm Interpolated Waveform 
% =========================================================================
        function interpol_wfm = ProteusInterpolation(obj, interpol_factor, wfm, flag_invsinc)

            % Get Interpolation Filters and zero-padding
            wfm             = obj.ZeroPadding(wfm, interpol_factor);
            interpol_filter = obj.GetInterpolFilter(interpol_factor, flag_invsinc);            
            interpol_wfm    = cconv(wfm, interpol_filter, length(wfm));
        end

%**************************************************************************

%*************************************************************************%
%                       INSTRUMENT SETTINGS SUPPORT                       %
%*************************************************************************%

% =========================================================================
%> @brief It finds out if the DC Output Option is installed in the unit
%>
%> This method is static and public
%>
%> @param obj instance of the TEProteusLib class
%> @param options string vector with the options for the target
%> @retval direct_output_status True if option DC x is installed. False otherwise 
% =========================================================================
        function dc_output_status = GetDcOutputStatus(obj, options)
            
            % Any of these options will result in LTJ being available            
            target_options  = [ obj.PROTEUS_OPT_DC1,...
                                obj.PROTEUS_OPT_DC2,...
                                obj.PROTEUS_OPT_DC3,...
                                obj.PROTEUS_OPT_DC4];
            % If any of the options above is true, flag will be true
            dc_output_status = obj.GetOptionStatus(target_options, options, true);
        end

%**************************************************************************

% =========================================================================
%> @brief It finds out if the Direct Output Option is installed in the unit
%>
%> This method is static and public
%>
%> @param obj instance of the TEProteusLib class
%> @param options string vector with the options for the target
%> @retval direct_output_status True if option DOx is installed. False otherwise 
% =========================================================================
        function direct_output_status = GetDirectOutputStatus(obj, options)
            
            % Any of these options will result in LTJ being available            
            target_options  = [ obj.PROTEUS_OPT_DO1,...
                                obj.PROTEUS_OPT_DO2,...
                                obj.PROTEUS_OPT_DO3,...
                                obj.PROTEUS_OPT_DO4];
            % If any of the options above is true, flag will be true
            direct_output_status = obj.GetOptionStatus(target_options, options, true);
        end


%**************************************************************************

% =========================================================================
%> @brief It finds out if the Low Trigger Jitter is installed in the unit
%>
%> This method is static and public
%>
%> @param obj instance of the TEProteusLib class
%> @param options string vector with the options for the target
%> @retval ltj_status True if option LTJ is installed. False otherwise 
% =========================================================================
        function ltj_status = GetLtjStatus(obj, options)
            
            % Any of these options will result in LTJ being available            
            target_options  = [ obj.PROTEUS_OPT_LTJ1,...
                                obj.PROTEUS_OPT_LTJ2,...
                                obj.PROTEUS_OPT_LTJ3,...
                                obj.PROTEUS_OPT_LTJ4];
            % If any of the options above is true, flag will be true
            ltj_status      = obj.GetOptionStatus(target_options, options, true);
        end

%**************************************************************************

% =========================================================================
%> @brief It gets the granularity in samples for the target Proteus
%>
%> This method is static and public
%> It gets the granularity in samples for the target Proteus unit depending
%> on the model, options, and DAC operation mode           
%>
%> @param obj instance of the TEProteusLib class
%> @param model string with model name (as returned by the IdentifyModel function).
%> @param options string vector with the options for the target
%> @param dacMode Apply Current operational mode for the DAC in the target Proteus.
%> @retval granularity Granularity for the current instrument and settings 
% =========================================================================
        function granularity = GetGranularity(obj, model, options, dac_mode) 
            
            granularity     = 32;
            % Any of these options will result in low granularity settings
            target_options  = [ obj.PROTEUS_OPT_G1,...
                                obj.PROTEUS_OPT_G2,...
                                obj.PROTEUS_OPT_G3,...
                                obj.PROTEUS_OPT_G4];
            % If any of the options above is true, flag will be true
            flagLowG        = obj.GetOptionStatus(target_options, options, true);
        
            if contains(model, 'P128') || contains(model, 'P258')
                granularity     = 32;    
                if flagLowG
                    granularity = 32; %16;
                end        
            elseif contains(model, 'P948')
                if dac_mode == obj.AWG_DAC_MODE_16
                    granularity = 32;    
                    if flagLowG
                        granularity = 32; %16;
                    end
                else
                    granularity = 64;    
                    if flagLowG
                        granularity = 64; %32;
                    end
                end
            elseif contains(model, 'P908')
                granularity     = 64;    
                if flagLowG
                    granularity = 64; %32;
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Gets the number of addressable channels for a given Proteus
%>
%> This method is static and public
%> Gets the number of addressable channels for a given Proteus           
%>
%> @param obj instance of the TEProteusLib class
%> @param model string with model name (as returned by the IdentifyModel function).
%> @retval num_of_channels Total number of channels
% =========================================================================
        function num_of_channels = GetNumOfChannels(obj, model) 

            num_of_channels     = 4;
            
            if contains(model, 'P9082') ||...
                    contains(model, 'P9482') ||...
                    contains(model, 'P2582')
                num_of_channels = 2;            
            elseif contains(model, 'P9086') ||...
                    contains(model, 'P9486') ||...
                    contains(model, 'P1286') ||...
                    contains(model, 'P2586')
                num_of_channels = 6;            
            elseif contains(model, 'P9488') ||...
                    contains(model, 'P1288') ||...
                    contains(model, 'P2588')
                num_of_channels = 8;             
            elseif  contains(model, 'P94812') ||...
                    contains(model, 'P12812') ||...
                    contains(model, 'P25812')
                num_of_channels = 12;            
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Gets the valid channel numbers and segment offset
%>
%> This method is static and public
%> Gets the valid channel numbers and segment offset depending on the
%> model, options and sample rate (DAC Mode).
%>
%> @param obj instance of the TEProteusLib class.
%> @param model string with model name (as returned by the IdentifyModel function).
%> @param sample_rate Target sample rate for the current setting.
%> @retval channel_list Vector with all the addressable channel numbers
%> @retval segment_list Vector with the corresponding segment offsets
% =========================================================================
        function [channel_list, segment_list] = GetChannels(obj, model, sample_rate)

            if  contains(model, 'P9484') ||...
                contains(model, 'P2584') ||...
                contains(model, 'P1284')
                if sample_rate <= 2.5E9
                    channel_list = [1 2 3 4];
                    segment_list = [1 2 1 2];
                else
                    channel_list = [1 3];
                    segment_list = [1 1];
                end
        
            elseif  contains(model, 'P9482') ||...
                    contains(model, 'P2582') ||...
                    contains(model, 'P1282')
                if sample_rate <= 2.5E9
                    channel_list = [1 2];
                    segment_list = [1 2];
                else
                    channel_list = [1];
                    segment_list = [1];
                end
        
            elseif  contains(model, 'P9488') ||...
                    contains(model, 'P2588') ||...
                    contains(model, 'P1288')
                if sample_rate <= 2.5E9
                    channel_list = [1 2 3 4 5 6 7 8];
                    segment_list = [1 2 1 2 1 2 1 2];
                else
                    channel_list = [1 3 5 7];
                    segment_list = [1 1 1 1];
                end
        
            elseif  contains(model, 'P94812') ||...
                    contains(model, 'P25812') ||...
                    contains(model, 'P12812')
                if sample_rate <= 2.5E9
                    channel_list = [1 2 3 4 5 6 7 8 9 10 11 12];
                    segment_list = [1 2 1 2 1 2 1 2 1 2 1 2];
                else
                    channel_list = [1 3 5 7 9 11];
                    segment_list = [1 1 1 1 1 1];
                end
        
            elseif contains(model, 'P9082')        
                channel_list = [1 2];
                segment_list = [1 1];
        
            elseif contains(model, 'P9084')        
                channel_list = [1 2 3 4];
                segment_list = [1 1 1 1];
        
            elseif contains(model, 'P9086')        
                channel_list = [1 2 3 4 5 6];
                segment_list = [1 1 1 1 1 1];
            end
        end

%**************************************************************************

% =========================================================================
%> @brief N-bit quantization of waveforms
%>
%> This method is static and public
%> Normalized (-1.0/+1.0) waveform quantization for any DAC resolution.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm input waveform to quantize.
%> @param dac_res DAC resolution in bits (integer).
%> @param min_lvl minimum usable DAC level. Select 1 for no DC.
%> @retval quant_wfm Quantized waveform in the valid integer range
% =========================================================================
        function quant_wfm = Quantization (obj, wfm, dac_res, min_lvl)
            
            max_lvl     = 2 ^ dac_res - 1;  
            num_of_lvls = max_lvl - min_lvl + 1;
            
            quant_wfm   = round((num_of_lvls .* (wfm + 1) - 1) ./ 2);
            quant_wfm   = quant_wfm + min_lvl;
            
            quant_wfm(quant_wfm > max_lvl) = max_lvl;
            quant_wfm(quant_wfm < min_lvl) = min_lvl;
            quant_wfm   = uint16(quant_wfm);        
        end

%**************************************************************************

% =========================================================================
%> @brief N-bit quantization of waveforms in a limited range of the DAC
%>
%> This method is static and public
%> Normalized (-1.0/+1.0) waveform quantization for any DAC resolution and
%> for a limited DAC range.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm input waveform to quantize.
%> @param dac_res DAC resolution in bits (integer).
%> @param min_lvl minimum usable DAC level.
%> @param max_lvl maximum usable DAC level.
%> @retval quant_wfm Quantized waveform in the valid integer range
% =========================================================================
        function quant_wfm = Quantization2 (obj, wfm, min_lvl, max_lvl)
            
            num_of_lvls = max_lvl - min_lvl + 1;
            
            quant_wfm   = round((num_of_lvls .* (wfm + 1) - 1) ./ 2);
            quant_wfm   = quant_wfm + min_lvl;
            
            quant_wfm(quant_wfm > max_lvl) = max_lvl;
            quant_wfm(quant_wfm < min_lvl) = min_lvl;
            quant_wfm   = uint16(quant_wfm);        
        end       

%**************************************************************************

% =========================================================================
%> @brief Wavefom normalization around 0.0V
%>
%> This method is static and public
%> Normalization to peak modulus. It works with waveform data. It normalizes
%> waveform data to the -1.0 to +1.0 range while keeping the realitive DC
%> level. When input is complex data, it is appropriated for IQ baseband
%| wavefom calculation when using the DUC.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm input waveform to normalize.
%> @retval out_wfm Normalized waveform
% =========================================================================
        function out_wfm = Normalize(obj, wfm)
            % Normalization to peak modulus. It works with waveform
            % data. It normalizes waveform data to the -1.0 to +1.0
            % range while keeping the realitive DC level.
            % is appropriated for IQ baseband generation.
            % wfm: Raw waveform to normalize
            
            % It returns:
            % out_wfm: Normalized waveform           
            
            max_peak    = max(abs(wfm));   
            out_wfm     = wfm / max_peak;
        end

%**************************************************************************

% =========================================================================
%> @brief Wavefom normalization using the full -1.0/1.0 range
%>
%> This method is static and public
%> Normalization to peak modulus. It works with waveform data. It normalizes
%> waveform data to the -1.0 to +1.0 range without keeping the realitive DC
%> level and using the full value range. SNR is optimized in that way. DC
%> level must be recovered using offset control.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm input waveform to normalize.
%> @retval out_wfm Normalized waveform
% =========================================================================
        function out_wfm = NormalizeFull(obj, wfm)
            % Normalization to peak modulus. It works with waveform
            % data. It normalizes waveform data to the -1.0 to +1.0
            % range without keeping the relative DC level.
            % is appropriated for maximum amplitude
            % wfm: Raw waveform to normalize
            
            % It returns:
            % out_wfm: Normalized waveform           
            
            max_peak = max(wfm); 
            min_peak = min(wfm);
            if max_peak > min_peak
                out_wfm = 2 / (max_peak - min_peak) * wfm;
                out_wfm = out_wfm - (max_peak + min_peak) / (max_peak - min_peak); 
            else
                out_wfm = wfm;
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Joint Wavefom normalization for real I and Q waveforms
%>
%> This method is static and public
%> Normalization to peak modulus. It works with a pair of complex waveform
%> data. It normalizes waveform data to the -1.0 to +1.0 for the highest
%> peak of any of the waveform and scales the other accordingly. It is
%> appropriate for baseband wavefom generation using two channels to be
%> connected to an external IQ modulator.
%>
%> @param obj instance of the TEProteusLib class.
%> @param i_wfm I raw waveform to normalize.
%> @param q_wfm Q raw waveform to normalize
%> @retval out_i_wfm I Normalized waveform.
%> @retval out_q_wfm Q Normalized waveform.
% =========================================================================
        function [out_i_wfm,  out_q_wfm] = NormalIq(obj, i_wfm, q_wfm)
            
            max_peak    = max([max(abs(i_wfm)), max(abs(q_wfm))]);   
            out_i_wfm   = i_wfm / max_peak;
            out_q_wfm   = q_wfm / max_peak;
        end

%**************************************************************************

% =========================================================================
%> @brief Joint Wavefom normalization for complex I/Q waveform
%>
%> This method is static and public
%> Normalization to peak modulus. It works with a complex waveform data. It
%> normalizes waveform data to the -1.0 to +1.0 for the highest
%> peak of the any of the real and imaginary components of the waveform and
%> scales the other accordingly. It is appropriate for baseband wavefom
%> generation using two channels to be connected to an external IQ modulator.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm_in I complex (I/Q) raw waveform to normalize.
%> @retval wfm_out Complex Normalized waveform.
% =========================================================================
        function wfm_out = NormalIqComplex(obj, wfm_in)
          
            max_peak    = max([max(abs(real(wfm_in))), max(abs(imag(wfm_in)))]); 
            if max_peak > 0.0
                wfm_out   = wfm_in / max_peak;
            else
                wfm_out   = wfm_i;
            end            
        end

%**************************************************************************

% =========================================================================
%> @brief Wavefom normalization around 0.0V for HALF MODE
%>
%> This method is static and public
%> Normalization to peak modulus. It works with complex (I/Q)waveform data.
%> It normalizes so peak module of waveform data is +1.0 while keeping
%> the realitive DC level. It is appropriated for IQ baseband wavefom
%> calculation when using the DUC in the HALF MODE as it returns two
%> real-only waveforms.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm Complex (I/Q) input waveform to normalize.
%> @retval out_i_wfm Normalized I waveform.
%> @retval out_q_wfm: Q Normalized waveform.
% =========================================================================
        function [out_i_wfm,  out_q_wfm] = NormalIqHalf(obj, wfm)
           
            max_peak    = max(abs(wfm));   
            out_i_wfm   = real(wfm) / max_peak;
            out_q_wfm   = imag(wfm) / max_peak;
        end

%**************************************************************************

% =========================================================================
%> @brief Wavefom normalization around 0.0V for HALF MODE with interpolation
%>
%> This method is static and public
%> Normalization to peak modulus. It works with complex (I/Q)waveform data.
%> It normalizes so peak module of waveform data is +1.0 while keeping
%> the relative DC level icluding peaks caused by the interpolation process.
%> It is appropriated for IQ baseband wavefom calculation when using the DUC
%> in the HALF MODE as it returns two real-only waveforms.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm Complex (I/Q) input waveform to normalize.
%> @param interpol_factor Intrepolation factor to be applied.
%> @param flag_invsinc Apply Inverted Sinc
%> @retval out_i_wfm Normalized I waveform.
%> @retval out_q_wfm: Q Normalized waveform.
% =========================================================================
        function [out_i_wfm,  out_q_wfm] = NormalIqHalfPlus(obj, wfm, interpol_factor, flag_invsinc)      
            
            interp_wfm = obj.ProteusInterpolation(interpol_factor, wfm, flag_invsinc);

            max_peak    = max(abs(interp_wfm));   
            out_i_wfm   = real(wfm) / max_peak;
            out_q_wfm   = imag(wfm) / max_peak;
        end        

%**************************************************************************

% =========================================================================
%> @brief IQ Wavefom normalization around 0.0V for DUC Mode ONE
%>
%> This method is static and public
%> Normalization to peak modulus. It works with waveform data. It normalizes
%> complex waveform data so amplitude is always within the unity Circle.
%> It is appropriated for IQ baseband calculation when using the DUC in mode
%> ONE.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm input waveform to normalize.
%> @retval out_wfm Normalized waveform
% =========================================================================
        function out_wfm = NormalIqOne(obj, wfm)
        
            max_peak    = max(abs(wfm));
            out_wfm     = wfm / max_peak;  
        end

%**************************************************************************

% =========================================================================
%> @brief IQ Wavefom normalization for DUC Mode ONE with interpolation
%>
%> This method is static and public
%> Normalization to peak modulus. It works with waveform data. It normalizes
%> complex waveform data so amplitude is always within the unity Circle.
%> It is appropriated for IQ baseband calculation when using the DUC in mode
%> ONE. Max peak of the interpolated wavefom is found so clipping is
%> avoided.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm Complex (I/Q) input waveform to normalize.
%> @param interpol_factor Intrepolation factor to be applied.
%> @param flag_invsinc Apply Inverted Sinc
%> @retval out_wfm Normalized Complex(I/Q) waveform.
% =========================================================================
        function out_wfm = NormalIqOnePlus(obj, wfm, interpol_factor, flag_invsinc)
 
            interp_wfm = obj.ProteusInterpolation(interpol_factor, wfm, flag_invsinc);

            max_peak    = max(abs(interp_wfm));
            out_wfm     = wfm / max_peak;  
        end

%**************************************************************************

% =========================================================================
%> @brief IQ Wavefom normalization around 0.0V for DUC Mode TWO
%>
%> This method is static and public
%> Normalization to peak modulus. It works with waveform data. It normalizes
%> the two complex waveforms so amplitude is always within the unity Circle.
%> It is appropriated for IQ baseband calculation when using the DUC in mode
%> TWO.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm_1 Complex Input waveform #1 to normalize.
%> @param wfm_2 Complex Input waveform #2 to normalize.
%> @retval out_wfm_1 Normalized waveform #1
%> @retval out_wfm_2 Normalized waveform #2
% =========================================================================
        function [out_wfm_1,  out_wfm_2] = NormalIqTwo(obj, wfm_1, wfm_2)

            max_peak    = max(abs(wfm_1) + abs(wfm_2));   
            out_wfm_1   = wfm_1 / max_peak;
            out_wfm_2   = wfm_2 / max_peak;
        end

%**************************************************************************

% =========================================================================
%> @brief IQ Wavefom normalization around 0.0V for DUC Mode TWO including
%> interpolation
%>
%> This method is static and public
%> Normalization to peak modulus. It works with waveform data. It normalizes
%> the two complex waveforms so amplitude is always within the unity Circle.
%> It is appropriated for IQ baseband calculation when using the DUC in mode
%> TWO. Max peak of the combined interpolated wavefom is found so clipping is
%> avoided.
%>
%> @param obj instance of the TEProteusLib class.
%> @param wfm_1 Complex Input waveform #1 to normalize.
%> @param wfm_2 Complex Input waveform #2 to normalize.
%> @param interpol_factor Intrepolation factor to be applied.
%> @param flag_invsinc Apply Inverted Sinc
%> @retval out_wfm_1 Normalized waveform #1
%> @retval out_wfm_2 Normalized waveform #2
% =========================================================================
        function [out_wfm_1,  out_wfm_2] = NormalIqTwoPlus(obj, wfm_1, wfm_2, interpol_factor, flag_invsinc)
           
            interp_wfm_1 = obj.ProteusInterpolation(interpol_factor, wfm_1, flag_invsinc);
            interp_wfm_2 = obj.ProteusInterpolation(interpol_factor, wfm_2, flag_invsinc);

            max_peak    = max(abs(interp_wfm_1) + abs(interp_wfm_2));   
            out_wfm_1   = wfm_1 / max_peak;
            out_wfm_2   = wfm_2 / max_peak;
        end        

%**************************************************************************

% =========================================================================
%> @brief This function maps any frequency to its image in the first or
%> second Nyquist Zone.
%>
%> This method is static and public
%> It calculates the right frequency to set up the NCO so an image is
%> aligned in frequency to the target frequency. It can be limited to the
%> first NZ or extended to the second NZ. When using the first and second NZ
%> it is possible to keep the same phase in the target image.
%>
%> @param obj instance of the TEProteusLib class.
%> @param carrier_freq Target carrier frequency
%> @param sampling_rate DAC/ADC Sampling Rate
%> @param remove_second_nyquist Second Nyquist Zone excluded when "true"
%> @retval nco_freq The frequency to be set in the target NCO
% =========================================================================
        function nco_freq = GetNcoFreq( obj,...
                                        carrier_freq, ...
                                        sampling_rate, ...
                                        remove_second_nyquist)           

            nco_freq = abs(carrier_freq);
            nco_freq = mod(nco_freq, sampling_rate);
        
            if remove_second_nyquist
                if nco_freq > sampling_rate / 2
                    nco_freq = sampling_rate - nco_freq;
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief This function formats marker data for modes using two markers
%> per channel.
%>
%> This method is static and public
%> This function formats marker data for modes using two markers per channel.
%> The output array can be downloaded to Proteus. The size of the output is
%> equal to the longest input array. Undefined states are set to "0".
%>
%> @param obj instance of the TEProteusLib class.
%> @param dac_mode If != 16, data is handled as 8-bits.
%> @param mkr_1 Logical states for marker #1
%> @param mkr_2 Logical states for marker #2
%> @retval mkr_data Formated marker data. Size is half for 16-bit mode
% =========================================================================
        function mkr_data = FormatMkr2(obj, dac_mode, mkr_1, mkr_2)
            % It calls the 4 marker version of the function
            mkr_data = obj.FormatMkr4(dac_mode, mkr_1, mkr_2, 0, 0);            
        end     

%**************************************************************************

% =========================================================================
%> @brief This function formats marker data for modes using four markers
%> per channel.
%>
%> This method is static and public
%> This function formats marker data for modes using four markers per channel.
%> The output array can be downloaded to Proteus. The size of the output is
%> equal to the longest input array. Undefined states are set to "0".
%>
%> @param obj instance of the TEProteusLib class.
%> @param dac_mode If != 16, data is handled as 8-bits.
%> @param mkr_1 Logical states for marker #1
%> @param mkr_2 Logical states for marker #2
%> @param mkr_3 Logical states for marker #3
%> @param mkr_4 Logical states for marker #4
%> @retval mkr_data Formated marker data. Size is half for 16-bit mode
% =========================================================================
        function mkr_data = FormatMkr4(obj, dac_mode, mkr_1, mkr_2, mkr_3, mkr_4)
            
            % Size for the final marker data
            mkr_size = max([length(mkr_1),length(mkr_2),length(mkr_3),length(mkr_4)]);
            %Creation of output data
            mkr_data = uint8(zeros(1, mkr_size));
            % Add the contribution of each marker
            % mkr_1 goes to bit 0 and mkr_2 goes to bit 1 in a 4-bit Nibble
            % mkr_3 goes to bit 2 and mkr_4 goes to bit 3 in a 4-bit Nibble
            mkr_data(1:length(mkr_1)) = mkr_1;
            mkr_data(1:length(mkr_2)) = mkr_data(1:length(mkr_2)) + 2 * mkr_2;
            mkr_data(1:length(mkr_3)) = mkr_data(1:length(mkr_3)) + 4 * mkr_3;
            mkr_data(1:length(mkr_4)) = mkr_data(1:length(mkr_4)) + 8 * mkr_4;

            % For DAC Mode 8, just one Nibble per Byte is sent
            % For DAC Mode 16, two consecutive nibbles are multiplexed in one byte
            if dac_mode == obj.AWG_DAC_MODE_16
                mkr_data = mkr_data(1:2:end) + 16 * mkr_data(2:2:end);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief This function applies direct IQ modulation to a complex baseband
%> waveform.
%>
%> This method is static and public
%> It calculates a complex carrier with an integer number of cycles to
%> guarantee phase continuity and it multiplies it by the input complex
%> baseband modulating signal.
%>
%> @param obj instance of the TEProteusLib class.
%> @param bb_wfm Complex Modulating Baseband Waveform.
%> @param carrier_f Carrier frequency in Hz
%> @param sample_rate Sample rate of the input baseband waveform
%> @retval mod_wfm Real modulated waveform
%> @retval actual_cf Actual center frequency after applying IQ Modulation
% =========================================================================
        function [mod_wfm, actual_cf] = IqDirectModulation(obj, bb_wfm, carrier_f, sample_rate)
        
            final_wfm_length = length(bb_wfm);
            carrier_wfm = 1:final_wfm_length;
            carrier_wfm = carrier_wfm - 1;
            num_carrier_cycles = round((final_wfm_length / sample_rate) * carrier_f);
            carrier_wfm = exp(1i * 2 * pi * num_carrier_cycles * carrier_wfm / final_wfm_length);
            mod_wfm = real(bb_wfm .* carrier_wfm);
        
            actual_cf = num_carrier_cycles / (final_wfm_length / sample_rate);
        end

%**************************************************************************

% =========================================================================
%> @brief Creation of sinc lookup table to be used as resampling filter
%>
%> This method is static and public
%> The quality of the  resampling filter in terms of roll-off and attenuation
%> at the stop band can be user-defined. Only positive values are returned
%> as filter is symmetrical in the time-domain.
%>
%> @param obj instance of the TEProteusLib class.
%> @param num_of_convolution_samples It controls the quality of the filter.
%> @param resolution_of_filter It sets the number of values per sample time.
%> @param bw_fraction It reduces de BW to avoid aliasing problems.
%> @retval resampling_filter Filter object with values and metadata.
% =========================================================================
        function resampling_filter = GetResamplingFilter(   obj,...
                                                            num_of_convolution_samples, ...
                                                            resolution_of_filter, ...
                                                            bw_fraction)

            % Number of samples to be used in resampling calculations
            resampling_filter.num_of_samples    = num_of_convolution_samples;
            % Number of lockup values per sample time
            resampling_filter.resolution        = resolution_of_filter;
            % BW fraction. Set 1.0 for full Nyquist Zone
            resampling_filter.bw_fraction       = bw_fraction;
            sinc_length                         = floor(num_of_convolution_samples * resolution_of_filter / bw_fraction);
            resampling_filter.filter            = 0:(sinc_length);  
            resampling_filter.filter            = resampling_filter.filter / resolution_of_filter;
            resampling_filter.filter            = resampling_filter.filter * bw_fraction;
            % Basic filter shape is ideal low pass filter (sinc)
            resampling_filter.filter            = sinc(resampling_filter.filter);
            % Flattop window is applied to improve flatness and stop band rejection
            %windowed_filter = blackmanharris(2 * sinc_length);
            windowed_filter                     = hamming(2 * sinc_length);
            windowed_filter                     = windowed_filter(sinc_length:end);
            % Resampling filter lockup table. Only positive time values.
            resampling_filter.filter            = resampling_filter.filter .* windowed_filter';
        end

 %*************************************************************************  

% =========================================================================
%> @brief Waveform Resampling
%>
%> This method is static and public
%> This funtion resamples the input waveform (inWfm) to generate a new
%> waveform with a new length (outWl). New length can be longer (upsampling)
%> or shorter (downsampling) than the original one. The new waveform can be
%> selfconsistent for loop generation (isCirc == true) or not, for singe shot
%> generation.
%>
%> @param obj instance of the TEProteusLib class.
%> @param input_wfm Waveform to be resampled.
%> @param output_wfm_length Waveform length of the resampled waveform.
%> @param is_circular Se to true for loop generartion of the waveform.
%> @param resampling_filter Filter object with values and metadata.
%> @retval output_wfm Resampled waveform.
% =========================================================================
        function output_wfm = Resampling(   obj,...
                                            input_wfm, ...
                                            output_wfm_length, ...
                                            is_circular, ...                                       
                                            resampling_filter) 
            % This funtion resamples the input waveform (inWfm) to generate a new
            % waveform with a new length (outWl). New length can be longer (upsampling)
            % or shorter (downsampling) than the original one. The new waveform can be
            % selfconsistent for loop generation (isCirc == true) or not for singe shot
            % generation.
        
            input_wfm           = single(input_wfm);
            input_wfm_length    = length(input_wfm);
            % Sampling rate ratio (>1.0, upsampling)
            sampling_ratio      = double(output_wfm_length) / double(input_wfm_length);
            
            % The parameters of the resampling filter are part of the associated
            % object
            convolution_length          = resampling_filter.num_of_samples;
            filter_resolution           = resampling_filter.resolution;
            resampling_filter.filter    = single(resampling_filter.filter);
            resampling_filter_length    = length(resampling_filter.filter);
            bw_fraction                 = resampling_filter.bw_fraction;
            % For undersampling filter, the amplitude of the resampling filter must
            % be corrected by the relative BW
            if sampling_ratio < 1.0
                % The distance for samples in the input (measured in samples of the
                % output) must be corrected for undersampling as well in order to
                % preserve SFDR
                convolution_length          = floor(convolution_length / (sampling_ratio * bw_fraction));
                resampling_filter.filter    = single(resampling_filter.filter * (sampling_ratio * bw_fraction));
            else
                convolution_length          = floor(resampling_filter.num_of_samples / bw_fraction);
            end
            
            % Output waveform is initialized to "all zeros"
            output_wfm = single(zeros(1, output_wfm_length));  
            % Convolution loop for each output sample
            if sampling_ratio >= 1.0
                mult_factor1 = bw_fraction * filter_resolution;
            else
                mult_factor1 = bw_fraction * filter_resolution * sampling_ratio;
            end
        
            for i = 1:output_wfm_length
                % Index for the central sample to process in the input wfm
                central_sample      = (i - 1) / sampling_ratio;
                central_sample_int  = round(central_sample);
                % Contribution for all the participating samples form the input is
                % accumulated on the current output sample
                start_conv_sample   = central_sample_int - convolution_length;
                stop_conv_sample    = central_sample_int + convolution_length;
                        
                for j = start_conv_sample:stop_conv_sample
                    % Actual fractional distance to the input sample
                    % Distance is converted to a relative integer index to the
                    % resampling filter (lookup table) 
                    time_distance   = round(mult_factor1 * abs(central_sample - j));           
                    
                    input_wfm_index = j;
        
                    % If convolution is circular the initial samples are used at
                    % the end and the end samples are used at the beginning.            
                    if is_circular && (input_wfm_index >= input_wfm_length || input_wfm_index < 0)
                        input_wfm_index = mod(input_wfm_index, input_wfm_length);
                    end
        
                    input_wfm_index = input_wfm_index + 1;
        
                    % If the pointer to the resampling filter is within the limits
                    % of the lookup table, the contribution of the input sample is
                    % added to the current output sample
                    if time_distance < resampling_filter_length && ...
                            input_wfm_index >=1 && ...
                            input_wfm_index <= input_wfm_length && ...
                            input_wfm(input_wfm_index) ~= 0.0
        
                        output_wfm(i) = output_wfm(i) +...
                            input_wfm(input_wfm_index) * ...
                            resampling_filter.filter(time_distance + 1);
                    end
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Self-contained Waveform Resampling
%>
%> This method is static and public
%> This funtion resamples the input waveform (inWfm) to generate a new
%> waveform with a new length (outWl). New length can be longer (upsampling)
%> or shorter (downsampling) than the original one. The new waveform can be
%> selfconsistent for loop generation (isCirc == true) or not, for singe shot
%> generation. Resampling filter is calculated internally.
%>
%> @param obj instance of the TEProteusLib class.
%> @param input_wfm Waveform to be resampled.
%> @param output_wfm_length Waveform length of the resampled waveform.
%> @param is_circular Se to true for loop generartion of the waveform.
%> @retval output_wfm Resampled waveform.
% =========================================================================

        function output_wfm = ResamplingDirect( obj,...
                                                input_wfm, ...
                                                output_wfm_length, ...
                                                is_circular)

            resampling_filter   = obj.GetResamplingFilter(  obj.RESAMP_QUALITY, ...
                                                            obj.RESAMP_FILTER_RES, ...
                                                            obj.RESAMP_BW_FRACTION);
            output_wfm          = obj.Resampling(   input_wfm, ...
                                                    output_wfm_length, ...
                                                    is_circular,...
                                                    resampling_filter);
        end

%**************************************************************************

% =========================================================================
%> @brief Get near optimal sample rate and resampling parameters
%>
%> This method is static and public
%> This funtion gets the final DAC sampling rate and wavwfrom length given
%> the length of the input waveform, target sampling rate and DAC modes.It
%> preserves the total duration of the waveform.
%>
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup AWG object with current settings inclusing sample rate.
%> @param sample_rate_bb_in Sample rate for the input waveform.
%> @param wfm_length_in Lenth of the input waveform.
%> @retval dac_resolution DAC Mode (either 8 or 16 bit).
%> @retval sampling_rate Final near optimal sampling rate for the DAC.
%> @retval interpol Interpolation factor to be applied.
%> @retval wfm_length_out Target length of the resampled waveform.
% =========================================================================
        function [  dac_resolution,...
                    sampling_rate,...
                    interpol,...
                    wfm_length_out] = GetOptInterParam( obj,...
                                                        awg_setup,...
                                                        sample_rate_bb_in,...
                                                        wfm_length_in)

            dac_resolution    = obj.AWG_DAC_MODE_16;
            interpol          = obj.AWG_INTERPOL_X1;
            sampling_rate     = awg_setup.sampling_rate;
            
            % DAC Mode setup, sample rate, and interpolation setup
            if awg_setup.mode  == obj.AWG_MODE_DIRECT
                if sampling_rate > 2.5E9
                    dac_resolution= obj.AWG_DAC_MODE_8;
                elseif sampling_rate <= 2.5E9 && sampling_rate > 2.25E9
                    sampling_rate = sampling_rate * 2;
                    interpol      = obj.AWG_INTERPOL_X2; 
                elseif sampling_rate <= 2.25E9 && sampling_rate > 1.125E9
                    sampling_rate = sampling_rate * 4;
                    interpol      = obj.AWG_INTERPOL_X4;
                elseif sampling_rate <= 1.125E9
                    sampling_rate = sampling_rate * 8;
                    interpol      = obj.AWG_INTERPOL_X8;
                end

            elseif awg_setup.mode  == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_ONE
                if sampling_rate > 1.125E9
                    sampling_rate = 1.125E9;                 
                end
                interpol      = obj.AWG_INTERPOL_X8;
                sampling_rate = sampling_rate * interpol;                

            elseif awg_setup.mode  == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_HALF
                if sampling_rate > 2.25E9
                    sampling_rate = 2.25E9;
                end
                interpol      = obj.AWG_INTERPOL_X4;
                sampling_rate = sampling_rate * interpol;
                
            elseif awg_setup.mode  == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_TWO   
                if sampling_rate > (1.125E9 / 2.0)
                    sampling_rate = 1.125E9 / 2.0;
                end
                interpol      = obj.AWG_INTERPOL_X8;
                sampling_rate = sampling_rate * interpol;            
            end

            % Resampling must be carrier out for the DUC baseband sampling rate
            sampling_rate   = sampling_rate / interpol;

            %Calculation of lenght of the interpolated waveform
            wfm_length_out  = floor(wfm_length_in * sampling_rate /...
                (sample_rate_bb_in * awg_setup.granularity)) * awg_setup.granularity;
            % Get the actual sample rates for acurate timing/symbol rate
            sampling_rate   = sample_rate_bb_in * wfm_length_out / wfm_length_in;
            sampling_rate   = sampling_rate * interpol;            
        end

%**************************************************************************

% =========================================================================
%> @brief Apply near optimal resampling to a waveform
%>
%> This method is static and public
%> This funtion gets the resampled waveform along with the final DAC
%> sampling rate and waveform length given the input waveform, target sampling
%> rate and DAC modes.It preserves the total duration of the waveform.
%>
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup AWG object with current settings inclusing sample rate.
%> @param sample_rate_bb_in Sample rate for the input waveform.
%> @param input_wfm Input waveform to be resampled.
%> @retval dac_resolution DAC Mode (either 8 or 16 bit).
%> @retval sampling_rate Final near optimal sampling rate for the DAC.
%> @retval interpol Interpolation factor to be applied.
%> @retval output_wfm Resampled waveform.
% =========================================================================
        function [  dac_resolution,...
                    sampling_rate,...
                    interpol,...
                    output_wfm] = GetResampledWfm(  obj,...
                                                    awg_setup,...
                                                    sample_rate_bb_in,...
                                                    input_wfm)
            [   dac_resolution,...
                sampling_rate,...
                interpol,...
                wfm_length_out] = obj.GetOptInterParam( awg_setup,...
                                                        sample_rate_bb_in,...
                                                        length(input_wfm));

            output_wfm          = obj.ResamplingDirect( input_wfm, ...
                                                        wfm_length_out, ...
                                                        true);
        end

%**************************************************************************

% =========================================================================
%> @brief Apply fast decimation to a waveform
%>
%> This method is static and public
%> This funtion aa
% pplies boxcar averaging as a method to implement fast
%> decimation. The resulting bandwidth of the decimation filter can be
%> reduced by any factor to avoid unwanted aliasing in the frequency
%> domain. Designed for use with data catured by the ADC. This function can
%> be applied to speed up downsampling through the resampling function.
%>
%> @param obj instance of the TEProteusLib class.
%> @param input_wfm Input waveform to be decimated.
%> @retval decimation Decimation factor (must be a positive integer).
%> @retval bw_ratio The effective BW will be limited by this factor.
%> @retval out_wfm Decimated waveform.
% =========================================================================
        function out_wfm = BoxcarDecimation(obj, input_wfm, decimation, bw_ratio)
        
            out_sample = 1;
        
            out_wfm = zeros(1, floor(length(input_wfm) / decimation));
        
            final_sample = length(input_wfm) - decimation * bw_ratio;
            integration_size = decimation * bw_ratio - 1;
        
            for current_sample = 1:decimation:final_sample 
                out_wfm(out_sample) = sum(input_wfm(current_sample:(current_sample + integration_size)));
                out_sample = out_sample + 1;
            end
            out_wfm = out_wfm / integration_size;
        end

%**************************************************************************
        % INSTRUMENT CONTROL METHODS 
%**************************************************************************

% =========================================================================
%> @brief Connect to Proteus unit
%>
%> This method is static and public
%> This function connects to any of the Proteus unit in a given chassis. It
%> also returns vectors with model numbers, serial number, and slot number.
%> Connection parameters are carried by class variables that must be
%> defined befor calling the function, unless the default values are valid.
%>
%> @param obj instance of the TEProteusLib class.
%> @param obj.com_ifc API identifier, LAN or DLL (class variable).
%> @param obj.ip_addr String with a valid ip address for the target Proteus
%> (class variable).
%> @param obj.ip_port Port number to access TCP-IP comm (class variable).
%> @param obj.pxi_slot Target PXI slot for DLL API. For 0, user can
%> manually select the target slot for a list supplied by the function
%> (class variable).
%> @retval inst Handler for the selected instrument.
%> @retval modelName Vector of strings with model name for selected instrument (i.e. "P9484")
%> @retval sId  Vector with slot number for modules. When obj.pxi_slot == 0,
%> all slot numbers for all modules are included.
%> @retval serial_number Vector with serial numbers for the modules.
% =========================================================================
        function [  inst,...            
                    modelName,...
                    sId,...
                    serial_num] = ConnecToProteus(obj)
             
            obj.admin   = 0;
            sId         = 0;            
            if obj.com_ifc == obj.COMM_IFC_LAN
                try            
                    connStr     = strcat('TCPIP::',obj.ip_addr,'::',num2str(obj.ip_port),'::SOCKET');
                    inst        = TEProteusInst(connStr, obj.paranoia_level);
                    obj.inst    = inst;
                    res         = inst.Connect();
                    assert (res == true);
                    [modelName,...
                    sId,... 
                    serial_num] = obj.IdentifyModel();
                catch ME
                    rethrow(ME)
                end   
            else
                asm             = NET.addAssembly(obj.DLL_PATH);
            
                import TaborElec.Proteus.CLI.*
                import TaborElec.Proteus.CLI.Admin.*
                import System.*
                
                obj.admin       = CProteusAdmin(@OnLoggerEvent);
                rc              = obj.admin.Open();
                assert(rc == 0);   
                
                try
                    slotIds     = obj.admin.GetSlotIds();
                    numSlots    = length(size(slotIds));
                    assert(numSlots > 0);

                    connStr     = obj.pxi_slot;
                    
                    % If there are multiple slots, let the user select one ..
                    sId         = slotIds;
                    if numSlots > 1
                        if obj.pxi_slot == 0
                            fprintf('\n%d slots were found\n', numSlots);
                            
                            for n = 1:numSlots
                                sId(n)      = slotIds(n);
                                slotInfo    = obj.admin.GetSlotInfo(sId(n));
                                if ~slotInfo.IsSlotInUse
                                    modelName = slotInfo.ModelName;
                                    if slotInfo.IsDummySlot && connStr == 0
                                        fprintf(' * Slot Number:%d Model %s [Dummy Slot].\n', sId, modelName);
                                    elseif connStr == 0
                                        fprintf(' * Slot Number:%d Model %s.\n', sId(n), modelName);
                                    end
                                end
                            end
                        end
                        pause(0.1);
                        if connStr == 0
                            choice = input('Enter SlotId ');
                            fprintf('\n');
                        else
                            choice = connStr;
                        end                
                        sId         = uint32(choice);
                        slotInfo    = obj.admin.GetSlotInfo(sId);
                        serial_num  = slotInfo.SerialNumber;
                        modelName   = slotInfo.ModelName;
                        modelName   = strtrim(obj.netStrToStr(modelName));
                    end
                    
                    % Connect to the selected instrument ..
                    should_reset    = true;
                    inst            = obj.admin.OpenInstrument(sId, should_reset);
                    obj.inst        = inst;
                    instId          = inst.InstrId;
                    
                catch ME
                    obj.admin.Close();
                    rethrow(ME) 
                end    
            end
        end  

%**************************************************************************

% =========================================================================
%> @brief Disconnect from Proteus unit
%>
%> This method is static and public
%> This function disconnectsconnects from the selected the Proteus unit.
%>
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
% =========================================================================
        function DisconnectFromProteus(obj)
            if obj.com_ifc == obj.COMM_IFC_LAN
                obj.inst.Disconnect();
            else
                obj.admin.CloseInstrument(obj.inst.InstrId);    
                obj.admin.Close();
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Selects one of the Proteus units
%>
%> This method is static and public
%> This function selects any of the Proteus unit installed in a single
%> chassis when using the VISA API (LAN).
%>
%> @param obj instance of the TEProteusLib class.
%> @param module_number Number of Proteus Module in the chassis.
%> @param inst Handler for the selected instrument (class variable).
% =========================================================================
        function SelectModule(obj, module_number)
            if obj.com_ifc == obj.COMM_IFC_LAN
                obj.inst.SendScpi([':INST:ACT ' num2str(module_number)]);
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Identify Proteus unit
%>
%> This method is static and public
%> This function identifies a given Proteus unit returning model type, PXI
%> slot where it is plugged in, its serial number, and comprehensive
%> information about installed options.
%>
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @retval model String with model name for selected instrument (i.e.
%> "P9484M").
%> @retval slot PXI slot# for selected instrument.
%> @retval serial Serial # for selected instrument.
%> @retval option_info Option struct with options installed, description and mask.
% =========================================================================
        function [model, slot, serial, option_info] = IdentifyModel(obj)

            idnStr  = obj.inst.SendScpi('*IDN?');
            idnStr  = strtrim(obj.netStrToStr(idnStr.RespStr));
            idnStr  = split(idnStr, [",", "-", " "]);
        
            model   = string.empty;
            slot    = uint8.empty;
            serial  = uint32.empty;

            module_ptr = 1;
        
            for k = 1:length(idnStr)
                if contains(idnStr(k), "P")
                   model(module_ptr)    = idnStr(k);
                   serial(module_ptr)   = uint32(str2double(idnStr(k + 1)));
                   module_ptr = module_ptr + 1;
                end                
            end    

            module_ptr = 1;
        
            for k = 1:length(idnStr)                
                if contains(idnStr(k), "slot")
                   slot(module_ptr)    = uint8(str2double(idnStr(k + 1)));
                   module_ptr = module_ptr + 1;
                end                
            end 
            [options, description, mask] = obj.GetProteusOptions();
            option_info.options = options;
            option_info.description = description;
            option_info.mask = mask;

        end

%**************************************************************************    

% =========================================================================
%> @brief Get Complete Installed Options Information
%>
%> This method is static and public
%> It returns the list of the installed options as they are named in the
%> Proteus data sheet, the description found for them in the same document,
%> and a mask with the status for all options in the target Proteus unit.
%>
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @retval options String vector with the acronym for all the options.
%> @retval options_description Description for each installed option.
%> @retval options_mask Logical Mask for all the available Proteus options.
% =========================================================================
        function [options, options_description, options_mask] = GetProteusOptions(obj)

            optStr  = obj.inst.SendScpi('*OPT?');  
            optStr  = strtrim(obj.netStrToStr(optStr.RespStr));
            options = split(optStr, ',');             
            options_description = obj.GetProteusOptionsText(options);
            options_mask = obj.GetProteusOptionsState(options);
        end

%**************************************************************************    

% =========================================================================
%> @brief Get Complete Mask for All Options
%>
%> This method is static and public
%> It returns a mask with the status for all options in the target Proteus
%> unit.
%>
%> @param obj instance of the TEProteusLib class.
%> @param options String vector with the acronym for all the options.
%> @retval options_mask Logical Mask for all the available Proteus options.
% =========================================================================
        function options_state = GetProteusOptionsState(obj, options)
            
            options_state   = false(1, length(obj.PROTEUS_OPT_STRINGS));

            for current_option = 1:length(options)
                for opt_num = 1:length(obj.PROTEUS_OPT_STRINGS)
                    if upper(options(current_option)) == upper(obj.PROTEUS_OPT_STRINGS(opt_num))
                        options_state (opt_num) = true;
                    end    
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get Description Text for Installed Options
%>
%> This method is static and public
%> It returns a string vector with the descriptions of all installed
%> options as found in the Proteus Data Sheet.
%>
%> @param obj instance of the TEProteusLib class.
%> @param options String vector with the acronym for all the options.
%> @retval options_txt String vector with description of installed options.
% =========================================================================
        function options_txt = GetProteusOptionsText(obj, options)

            options_txt = string.empty;

            for current_option = 1:length(options)
                for opt_num = 1:length(obj.PROTEUS_OPT_STRINGS)
                    if upper(options(current_option)) == upper(obj.PROTEUS_OPT_STRINGS(opt_num))
                        options_txt = [options_txt, obj.PROTEUS_OPT_TEXT(opt_num)];
                    end    
                end
            end
        end        

%**************************************************************************

% =========================================================================
%> @brief Get Instalation Status of a Set of Options
%>
%> This method is static and public
%> It returns a vector of logical values showing the installation status of
%> a given set of options defined by the user.
%>
%> @param obj instance of the TEProteusLib class.
%> @param target_options Vector of integers with the list of options to
%> analyze (Integer constants with user-friendly names available).
%> @param options String vector with the acronym for the installed options.
%> @param any_option If true, a single logical value is returned is any of
%> the options in the target_options vector is found.
%> @retval option_state Logical vector with option status.
% =========================================================================
        function option_state = GetOptionStatus(obj, target_options, options, any_option)

            options_proteus = obj.GetProteusOptionsState(options);
            option_state = false(1, length(target_options));
            
            for k = 1:length(target_options)
                if options_proteus(target_options(k))
                    option_state(k) = true;
                end
            end
            
            overall_option = false;
            if any_option
                for k = 1:length(target_options)
                    if option_state(k)
                        overall_option = true;
                    end
                end
                option_state = overall_option;
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get current DAC resolution
%>
%> This method is static and public
%> It returns the resolution of the DAC according to the current state of
%> the target Proteus.
%>
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @retval dacRes DAC Resolurion in bits (either 8 or 16 bits).
% =========================================================================
        function dacRes = GetDacResolution(obj)  
            % Get the current DAC resolution for the taget Proteus
            % inst = Instrument handle
            % It returns:
            % dacRes = Current DAC sample resolution. Either 8 or 16.
    
            dacRes = obj.inst.SendScpi(':TRAC:FORM?');
            dacRes = strtrim(obj.netStrToStr(dacRes.RespStr));
        
            if contains(dacRes, 'U8')
                dacRes = 8;
            else
                dacRes = 16;
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Get the maximum and minimum Sample Rate
%>
%> This method is static and public
%> It returns the maximum and minimum valid settings for the DAC's Sample
%> Rate parameter in the target Proteus unit.
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @retval min_sr Minimum Sample Rate for the DAC expressed in Samples/s.
%> @retval max_sr Maximum Sample Rate for the DAC expressed in Samples/s.
% =========================================================================
        function [min_sr, max_sr] = GetAwgSamplingRateRange(obj)
    
            min_sr = obj.inst.SendScpi(':FREQ:RAST MIN?');  
            min_sr = strtrim(obj.netStrToStr(min_sr.RespStr));
            min_sr = str2double(min_sr);
            max_sr = obj.inst.SendScpi(':FREQ:RAST MAX?');  
            max_sr = strtrim(obj.netStrToStr(max_sr.RespStr));
            max_sr = str2double(max_sr);
        end

%**************************************************************************    

% =========================================================================
%> @brief Get the maximum and minimum Output Voltage Level
%>
%> This method is static and public
%> It returns the maximum and minimum valid settings for the DAC's Output
%> voltage level in the target Proteus unit.
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @retval min_volt Minimum Output Voltage for the DAC expressed in Vpp.
%> @retval max_volt Maximum Output Voltage for the DAC expressed in Vpp.
% =========================================================================
function [min_volt, max_volt] = GetAwgVoltageRange(obj)
   
            min_volt = obj.inst.SendScpi(':SOUR:VOLT MIN?');  
            min_volt = strtrim(obj.netStrToStr(min_volt.RespStr));
            min_volt = str2double(min_volt);
            max_volt = obj.inst.SendScpi(':SOUR:VOLT MAX?');  
            max_volt = strtrim(obj.netStrToStr(max_volt.RespStr));
            max_volt = str2double(max_volt);
        end

%**************************************************************************

% =========================================================================
%> @brief Task List Setup and Task Activation
%>
%> This method is static and public
%> This function defines a complete Task List based in the definitions
%> defined by the taskList integer uint32 matrix. The matrix is NxM, where
%> N is the number of entries in the task list being defined and M is the
%> number of fields specifying the parameters of each tasks. This is the
%> definition of the fields:
%>
%>      Number  Description         
%>      ________________________________________
%>
%>      1       pointer_to_segment
%>      2       task_type: 0: Single, 1: StartSeq, 2: InSeq, 3: EndSeq
%>      3       num of loops (task)
%>      4       num of loops (sequence)
%>      5       next task #1
%>      6       dtr trigger flag: 0: dtr trigger off, 1: dtr trigger on
%>      7       use enable task event
%>      8       use abort task event
%>      9       idle mode
%>      10      idle level 
%>      11      jump mode
%>      12      delay
%>      13      next task #2
%>      14      keep
%>      15      destination
%>
%> A set of constants for each fiels is available in order to make code
%> more readable and easier to maintain.
%>
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @param awg_setup Proteus settings structure.
%> @param task_list task list definition matrix(see description).
% =========================================================================
        function TaskListSetup( obj,...
                                awg_setup,...
                                task_list)

              

            segm_multiplier = 1;

            if awg_setup.mode == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_HALF
                segm_multiplier = 2;
            end

            channel = awg_setup.channel;
            segment = awg_setup.segment;
            
            num_of_tasks = size(task_list, 1);
            obj.SelectModule(awg_setup.sel_module);
            for chan = 0:(segm_multiplier - 1)
                % Select Channel
                obj.inst.SendScpi(sprintf(':INST:CHAN %d', channel + chan));  
                % The Task Composer is configured to handle a certain number of task
                % entries
                obj.inst.SendScpi(sprintf(':TASK:COMP:LENG %d', num_of_tasks)); 
            
                % Then, each task is defined
                for task_number = 1:num_of_tasks 
                    % Task to be defined is selected
                    obj.inst.SendScpi(sprintf(':TASK:COMP:SEL %d', task_number));
                    % The type of task is defined.
                    switch task_list(task_number, obj.TASK_TYPE)
                        case obj.TASK_TYPE_SINGLE
                            obj.inst.SendScpi(':TASK:COMP:TYPE SING');
                        case obj.TASK_TYPE_START
                            obj.inst.SendScpi(':TASK:COMP:TYPE STAR');
                        case obj.TASK_TYPE_SEQ
                            obj.inst.SendScpi(':TASK:COMP:TYPE SEQ');
                        case obj.TASK_TYPE_END
                            obj.inst.SendScpi(':TASK:COMP:TYPE END');
                    end
                           
                    % The action to take after completing the task is defined. NEXT is the
                    % default so sending this command is not mandatory
                    obj.inst.SendScpi(':TASK:COMP:DEST NEXT');
                    % Assigns segment for task in the sequence        
                    obj.inst.SendScpi(sprintf(':TASK:COMP:SEGM %d',...
                        segment + (task_list(task_number, 1) - 1) * segm_multiplier + chan));
                    % Assigns task to generate next in the sequence
                    obj.inst.SendScpi(sprintf(':TASK:COMP:NEXT1 %d', task_list(task_number, 5)));  
            
                    % Set the Trigger for Digitizer  
                    switch task_list(task_number, obj.TASK_DTR_FLAG)
                        case 0
                            %inst.SendScpi(':TASK:COMP:DTR NONE');
                            % remove previous and activate below for older FPGA
                            obj.inst.SendScpi(':TASK:COMP:DTR OFF');
                        otherwise
                            %inst.SendScpi(':TASK:COMP:DTR AWG');
                            % remove previous and activate below for older FPGA
                            obj.inst.SendScpi(':TASK:COMP:DTR ON');            
                    end  
    
                    switch task_list(task_number, obj.TASK_ENABLE_EVENT)
                        case obj.TASK_EVENT_TRG1
                            obj.inst.SendScpi(':TASK:COMP:ENAB TRG1');
                        case obj.TASK_EVENT_TRG2
                            obj.inst.SendScpi(':TASK:COMP:ENAB TRG2');
                        case obj.TASK_EVENT_CPU
                            obj.inst.SendScpi(':TASK:COMP:ENAB CPU');
                        case obj.TASK_EVENT_INT
                            obj.inst.SendScpi(':TASK:COMP:ENAB INT');
                    end
    
                    switch task_list(task_number, obj.TASK_ABORT_EVENT)
                        case obj.TASK_EVENT_TRG1
                            obj.inst.SendScpi(':TASK:COMP:ABOR TRG1');
                        case obj.TASK_EVENT_TRG2
                            obj.inst.SendScpi(':TASK:COMP:ABOR TRG2');
                        case obj.TASK_EVENT_CPU
                            obj.inst.SendScpi(':TASK:COMP:ABOR CPU');
                        case obj.TASK_EVENT_INT
                            obj.inst.SendScpi(':TASK:COMP:ABOR INT');
                    end

                    switch task_list(task_number, obj.TASK_IDLE_MODE)
                        case obj.TASK_IDLE_MODE_DC
                            obj.inst.SendScpi(':TASK:COMP:IDLE DC');
                        case obj.TASK_IDLE_MODE_FIRST
                            obj.inst.SendScpi(':TASK:COMP:IDLE FIRS');
                        case obj.TASK_IDLE_MODE_CURRENT
                            obj.inst.SendScpi(':TASK:COMP:IDLE CURR');                        
                    end

                    obj.inst.SendScpi(sprintf(':TASK:COMP:IDLE:LEV %d', task_list(task_number, obj.TASK_IDLE_LVL)));
            
                    % Num of loops for the current sequence
                    if task_list(task_number, obj.TASK_TYPE) == obj.TASK_TYPE_START
                        obj.inst.SendScpi(sprintf(':TASK:COMP:SEQ %d', task_list(task_number, obj.TASK_LOOPS_SEQ)));
                    end
            
                    %  Num of loops for the current task
                    obj.inst.SendScpi(sprintf(':TASK:COMP:LOOP %d', task_list(task_number, obj.TASK_LOOPS)));
                    
                    % Delay in Sclk for current task
                    if task_list(task_number, obj.TASK_DELAY) >= 1
                        obj.inst.SendScpi(sprintf(':TASK:COMP:DEL %d', abs(floor(task_list(task_number, obj.TASK_DELAY)))));
                        % delStr  = obj.inst.SendScpi(':TASK:COMP:DEL?');
                        % delStr  = strtrim(obj.netStrToStr(delStr.RespStr));
                    end
                end   
            
                % The task table created with the Composer is written to the actual task
                % table of teh selected channel
                obj.inst.SendScpi(':TASK:COMP:WRIT');
                if obj.lib_verbose
                    fprintf(1, 'SEQUENCE CREATED!\n');
                end
                % Select Task Mode for generation    
                % Start in task #1 (#1 is the default)    trg_src
                obj.inst.SendScpi(':FUNC:MODE TASK');
                % obj.inst.SendScpi(sprintf(':TASK:COMP:SEL %d', 4));
                % delStr  = obj.inst.SendScpi(':TASK:COMP:DEL?');
                % delStr  = strtrim(obj.netStrToStr(delStr.RespStr));
                % a = 1;
            end
            
            obj.inst.SendScpi(sprintf(':INST:CHAN %d', channel));             
        end
  
%**************************************************************************

% =========================================================================
%> @brief External AWG Trigger Set Up and Activation
%>
%> This method is static and public
%> External Trigger #1 or #2 can be selected for set up
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @param awg_setup Proteus settings structure.
% =========================================================================
        function SetExtTriggerAwg(obj, awg_setup)
            trg_src     = awg_setup.trg_src;                                            
            trg_lvl     = awg_setup.trg_lvl;
            trg_slope   = awg_setup.trg_slope;
            idl_lvl     = awg_setup.trg_idle_lvl;
        
            switch trg_src
                case obj.TASK_EVENT_TRG1 
                    obj.inst.SendScpi(':TRIG:SOUR:ENAB TRG1');
                    obj.inst.SendScpi(':TRIG:SELECT TRG1');      
                    
                case obj.TASK_EVENT_TRG2
                    obj.inst.SendScpi(':TRIG:SOUR:ENAB TRG2');
                    obj.inst.SendScpi(':TRIG:SELECT TRG2');           
            end
        
            obj.inst.SendScpi([':TRIG:LEV ' num2str(trg_lvl)]);
            if trg_slope == obj.AWG_TRG_SLOPE_NEG
                obj.inst.SendScpi(':TRIG:SLOP NEG');
            else
                obj.inst.SendScpi(':TRIG:SLOP POS');
            end

            obj.inst.SendScpi([':TRIG:IDLE:LEV ' num2str(idl_lvl)]);
        
            obj.inst.SendScpi(':TRIG:STAT ON');
        
        end

%**************************************************************************

% =========================================================================
%> @brief Set Up Proteus' AWG Mode
%>
%> This method is static and public
%> This functions handles the following functonal parameters:
%>      - Interpolation Factor
%>      - Sample Repetition Factor
%>      - Direct, DUC, or NCO mode selection
%>      - Trigger Source and Mode
%>      - DUC Mode and NCO parameters
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @param awg_setup Proteus settings structure.
% =========================================================================
        function SetupProteusAwgMode(   obj,...
                                        awg_setup)            

            obj.SelectModule(awg_setup.sel_module);        
            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
            % Sample rate 

            if awg_setup.sampling_rate / awg_setup.interpol <= 2.5E9
                obj.inst.SendScpi([':FREQ:RAST ' num2str(2.5E9)]);

                switch awg_setup.interpol
                    case obj.AWG_INTERPOL_X2
                        obj.inst.SendScpi(':SOUR:INT X2');

                    case obj.AWG_INTERPOL_X4
                        obj.inst.SendScpi(':SOUR:INT X 4');

                    case obj.AWG_INTERPOL_X8
                        obj.inst.SendScpi(':SOUR:INT X8');

                    otherwise
                        obj.inst.SendScpi(':SOUR:INT NONE');
                end
            end

            % Repeat sample factor
            switch awg_setup.repeat_sample
                case obj.AWG_REPEAT_X1
                    obj.inst.SendScpi(':SOUR:PTR X1');

                case obj.AWG_REPEAT_X2
                    obj.inst.SendScpi(':SOUR:PTR X2');

                case obj.AWG_REPEAT_X4
                    obj.inst.SendScpi(':SOUR:PTR X4');

                case obj.AWG_REPEAT_X8
                    obj.inst.SendScpi(':SOUR:PTR X8');
            end

            % AWG DUC and IQ MODES
            switch awg_setup.mode
                case obj.AWG_MODE_DIRECT
                    obj.inst.SendScpi(':SOUR:MODE DIR');
                case obj.AWG_MODE_DUC
                    obj.inst.SendScpi(':SOUR:MODE DUC');
                    switch awg_setup.iq_mode
                        case obj.AWG_IQ_MODE_HALF
                            obj.inst.SendScpi(':IQM HALF');
                            
                        case obj.AWG_IQ_MODE_ONE
                            obj.inst.SendScpi(':IQM ONE');                            

                        case obj.AWG_IQ_MODE_TWO
                            obj.inst.SendScpi(':IQM TWO');                             
                    end

                case obj.AWG_MODE_NCO
                    obj.inst.SendScpi(':SOUR:MODE NCO');                   
            end
            %obj.inst.SendScpi(':TRAC:DEL:ALL');              

            obj.inst.SendScpi([':FREQ:RAST ' num2str(awg_setup.sampling_rate)]);        

            switch awg_setup.trg_src 
                case obj.TASK_EVENT_NONE
                    obj.inst.SendScpi(':TRIG:SOUR:ENAB NONE');

                case obj.TASK_EVENT_CPU
                    obj.inst.SendScpi(':TRIG:SOUR:ENAB CPU');

                case obj.TASK_EVENT_TRG1
                    obj.SetExtTriggerAwg(awg_setup);

                case obj.TASK_EVENT_TRG2 
                    obj.SetExtTriggerAwg(awg_setup);                   

                case obj.TASK_EVENT_INT
                    obj.inst.SendScpi(':TRIG:SOUR:ENAB INT');               
            end

            obj.inst.SendScpi(sprintf(':TRIG:COUN %d ', awg_setup.trg_count));

            if awg_setup.trg_mode == obj.AWG_TRG_MODE_CONT
                obj.inst.SendScpi(':INIT:CONT:STAT 1');

            elseif awg_setup.trg_mode == obj.AWG_TRG_MODE_TRIG
                obj.inst.SendScpi(':INIT:CONT:STAT 0');
            end

            if awg_setup.cpu_trg_mode == obj.AWG_CPU_TRG_GLOBAL
                obj.inst.SendScpi(':TRIG:CPU:MODE GLOBAL');
            elseif awg_setup.cpu_trg_mode == obj.AWG_CPU_TRG_LOCAL
                obj.inst.SendScpi(':TRIG:CPU:MODE LOCAL');
            end

            switch awg_setup.mode            

                case obj.AWG_MODE_DUC
                    switch awg_setup.iq_mode
                        case obj.AWG_IQ_MODE_HALF
                            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel + 1));
                            obj.inst.SendScpi(sprintf(':NCO:CFR1 %f', obj.GetActualElement(awg_setup.cfr1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:PHAS1 %f', obj.GetActualElement(awg_setup.phase1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:SIXD1 %d', obj.GetActualElement(awg_setup.six_db1, 1)));
                            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
                            obj.inst.SendScpi(sprintf(':NCO:CFR1 %f', obj.GetActualElement(awg_setup.cfr1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:PHAS1 %f', obj.GetActualElement(awg_setup.phase1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:SIXD1 %d', obj.GetActualElement(awg_setup.six_db1, 1)));

                        case obj.AWG_IQ_MODE_ONE
                            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
                            obj.inst.SendScpi(sprintf(':NCO:CFR1 %f', obj.GetActualElement(awg_setup.cfr1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:PHAS1 %f', obj.GetActualElement(awg_setup.phase1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:SIXD1 %d', obj.GetActualElement(awg_setup.six_db1, 1)));

                        case obj.AWG_IQ_MODE_TWO
                            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
                            obj.inst.SendScpi(sprintf(':NCO:CFR1 %f', obj.GetActualElement(awg_setup.cfr1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:PHAS1 %f', obj.GetActualElement(awg_setup.phase1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:SIXD1 %d', obj.GetActualElement(awg_setup.six_db1, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:CFR2 %f', obj.GetActualElement(awg_setup.cfr2, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:PHAS2 %f', obj.GetActualElement(awg_setup.phase2, 1)));
                            obj.inst.SendScpi(sprintf(':NCO:SIXD2 %d', obj.GetActualElement(awg_setup.six_db2, 1)));
                    end

                case obj.AWG_MODE_NCO
                    obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
                    obj.inst.SendScpi(sprintf(':NCO:CFR1 %f', obj.GetActualElement(awg_setup.cfr1, 1)));
                    obj.inst.SendScpi(sprintf(':NCO:PHAS1 %f', obj.GetActualElement(awg_setup.phase1, 1)));
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Sets up AWG channel and segment and set up output
%>
%> This method is static and public
%> This functions handles the following functonal parameters:
%>      - Module and Channel selection
%>      - Segment # (two cosecutive segments for DUC HALF mode)
%>      - Output voltage and offset
%>      - Output state (ON/OFF)
%>      - Skew
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @param awg_setup Proteus settings structure.
% =========================================================================
        function SetupProteusAwgChannel(obj, awg_setup)       

            % Select Module and Channel
            obj.SelectModule(awg_setup.sel_module);
            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
            % Select segment
            obj.inst.SendScpi(sprintf(':SOUR:FUNC:MODE:SEGM %d', awg_setup.segment));
            % Output voltage set to voltage. If voltage <0, set to Max
            if awg_setup.volt >= 0
                obj.inst.SendScpi([':SOUR:VOLT ' num2str(awg_setup.volt)]); 
            else
                obj.inst.SendScpi(':SOUR:VOLT MAX');   
            end
            % Set Offset
            obj.inst.SendScpi([':SOUR:VOLT:OFFS ' num2str(awg_setup.offset)]);
            % if awg_setup.mode == obj.AWG_MODE_DUC
            %     obj.inst.SendScpi(sprintf(':NCO:SIXD1 %d', obj.GetActualElement(awg_setup.six_db1, 1)))
            % end
            % Activate output and start generation
            if awg_setup.output_state
                obj.inst.SendScpi(':OUTP ON'); 
            else
                obj.inst.SendScpi(':OUTP OFF');
            end
            % Even numbered channel must be set up for IQ Mode HALF
            if awg_setup.mode == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_HALF
                obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel + 1));
                obj.inst.SendScpi(sprintf(':SOUR:FUNC:MODE:SEGM %d', awg_setup.segment + 1));
                % Output voltage set to voltage
                if awg_setup.volt >= 0
                    obj.inst.SendScpi([':SOUR:VOLT ' num2str(awg_setup.volt)]); 
                else
                    obj.inst.SendScpi(':SOUR:VOLT MAX');   
                end

                % obj.inst.SendScpi(sprintf(':NCO:SIXD1 %d', obj.GetActualElement(awg_setup.six_db1, 1)))
                % Activate outpurt and start generation
                if awg_setup.output_state
                    obj.inst.SendScpi(':OUTP ON'); 
                else
                    obj.inst.SendScpi(':OUTP OFF');
                end
                obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
            end
            % Skew setup
            if abs(awg_setup.delay) <= 1.2E-9
                obj.inst.SendScpi(sprintf(':INST:COUP:SKEW %e', awg_setup.delay));
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Download and set up a task list and associated waveforms
%>
%> This method is static and public
%> It downloads a set of waveforms to multiple consecutive segments and a
%> task list pointing to these segments.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param inst Handler for the selected instrument (class variable).
%> @param myWfm One or multiple waveforms. Mapping in awg_setup.
%> @param task_list task list definition matrix.
%> @param initialize If true, AWG will be set up for generation.
%> @retval result Error code. 0 = No errors.
% =========================================================================
        function result = SendListToProteus(obj,...                
                                            awg_setup,...
                                            myWfm,...
                                            task_list,...
                                            initialize)

            result = obj.SendWfmToProteus(  awg_setup,...
                                            myWfm,...
                                            initialize);

            obj.TaskListSetup(  awg_setup,...
                                task_list);  
        end

%**************************************************************************

% =========================================================================
%> @brief Arrange complex IQ waveform for download in the HALF Mode
%>
%> This method is static and public
%> It creates a vector made by all the concatenated real parts and then all
%> the concatenated imaginary parts so they can be download sepparately to
%> the odd and even numbered channels associated to each active channel in
%> the HALF IQ Mode.
%> @param obj instance of the TEProteusLib class.
%> @param wfm_map Waveform map with the lengths for each waveform.
%> @param myWfm One or multiple waveforms. Mapping in wfm_map.
%> @retval final_wfm All waveforms properly concatenated as real and then imaginary.
% =========================================================================
        function final_wfm = GetHalfModeInterleavedWfm(obj, wfm_map, myWfm)

            num_of_wfm = length(wfm_map);
            if num_of_wfm == 1
                if wfm_map == 0
                    wfm_map = length(myWfm);
                end               
            end
            final_wfm_end = sum(wfm_map);
            final_wfm_end = 2 * final_wfm_end;

            final_wfm = zeros(1, final_wfm_end);

            init_sample = 1;
            init_pointer = 1;

            for current_wfm = 1:num_of_wfm
                end_sample = init_sample + wfm_map(current_wfm) - 1;
                final_wfm(init_pointer:(init_pointer + wfm_map(current_wfm) - 1)) = real(myWfm(init_sample:end_sample));
                init_pointer = init_pointer + wfm_map(current_wfm);
                final_wfm(init_pointer:(init_pointer + wfm_map(current_wfm) - 1)) = imag(myWfm(init_sample:end_sample));
                init_pointer = init_pointer + wfm_map(current_wfm);
                init_sample = init_sample + wfm_map(current_wfm);
            end                   
        end

%**************************************************************************

% =========================================================================
%> @brief Download waveform to target channel and segment
%>
%> This method is static and public
%> Download waveform to target channel and segment and, optionally, set up
%> AWG mode, generation paramters and output as defined by parameters in
%> the awg_setup struct
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @param initialize If True, AWG is configured and generation is
%> initiated.
%> @retval result length of downloaded waveform in samples
% =========================================================================
        function result = SendWfmToProteus( obj,...                
                                            awg_setup,...
                                            myWfm,...
                                            initialize)
                 
            % Set up AWG Mode if initialize is true
            if initialize                
                obj.SetupProteusAwgMode(awg_setup);     
            end
            %Select Module
            obj.SelectModule(awg_setup.sel_module);
            %Select Channel
            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
            % Select optimal data format according to DAC Mode
            if awg_setup.dac_resolution == obj.AWG_DAC_MODE_16  
                    obj.inst.SendScpi(':TRAC:FORM U16');
            else
                    obj.inst.SendScpi(':TRAC:FORM U8');
            end 
            % Analyze Wfm map. If map == 0 then there is only a waveform so
            % the field is modified to store just the length of the
            % waveform
            num_of_wfm = length(awg_setup.wfm_map);
            if num_of_wfm == 1
                if awg_setup.wfm_map == 0
                    awg_setup.wfm_map = length(myWfm);
                end
            end  
            % Check if the AWG is set to the DUC mode and IQ mode is HALF.
            % If so, waveform is interleaved accordingly.
            if awg_setup.mode == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_HALF 
                myWfm = obj.GetHalfModeInterleavedWfm(awg_setup.wfm_map, myWfm);
            end
            % Just one segment per waveform
            segm_multiplier = 1;

            % Download all wfms
            current_length = length(myWfm);
            % Segment is defined
            obj.inst.SendScpi(sprintf(':TRAC:DEF %d, %d', awg_setup.segment, current_length));        
            % select segment as the the target segment
            obj.inst.SendScpi(sprintf(':TRAC:SEL %d', awg_setup.segment));

            switch awg_setup.mode
                case obj.AWG_MODE_DIRECT
                    current_wfm = obj.Quantization(myWfm, awg_setup.dac_resolution, 0);

                case obj.AWG_MODE_DUC
                    if awg_setup.iq_mode ~= obj.AWG_IQ_MODE_TWO
                        current_wfm = obj.Quantization(myWfm, awg_setup.dac_resolution, 1);
                    else
                        current_wfm = myWfm;
                    end
                    if awg_setup.iq_mode == obj.AWG_IQ_MODE_HALF 
                        % For IQ Mode HALF there are two segments per
                        % complex waveform (I and Q) so multiplier is 2
                        segm_multiplier = 2;                          
                    end                
            end

            % Download the binary data to segment   
            prefix = ':TRAC:DATA 0,';
        
            if awg_setup.dac_resolution == obj.AWG_DAC_MODE_16
                current_wfm = uint16(current_wfm);
                current_wfm = typecast(current_wfm, 'uint8');                    
            else
                current_wfm = uint8(current_wfm);                    
            end
            dataLength = length(current_wfm);
            if awg_setup.dac_resolution == obj.AWG_DAC_MODE_16 
                dataLength = dataLength / 2;
            end
            if awg_setup.report_time && obj.lib_verbose
                fprintf('AWG Download Time for All Wfms, # of samples: %d \n', dataLength);
                tic;
            end
            % All waveforms are download in a single transfer to speed up
            % the process
            obj.inst.WriteBinaryData(prefix, current_wfm); 

            if awg_setup.report_time && obj.lib_verbose
                toc;
            end
            % Once all the waveforms have been downloaded, the memory is
            % segmented according to the map in awg_setup
            for wfm_number = 0:(num_of_wfm - 1)
                current_length  = awg_setup.wfm_map(wfm_number + 1);
                current_segment = awg_setup.segment + wfm_number * segm_multiplier;
                obj.inst.SendScpi(sprintf(':TRAC:DEF %d, %d', current_segment, current_length));        
                % select segmenT as the the programmable segment
 
                if awg_setup.mode == obj.AWG_MODE_DUC && awg_setup.iq_mode == obj.AWG_IQ_MODE_HALF 
                    obj.inst.SendScpi(sprintf(':TRAC:DEF %d, %d', current_segment + 1, current_length));        
                end                
            end
            % Output is configured and generation is started when
            % initialize is true
            if initialize                
                obj.SetupProteusAwgChannel(awg_setup);
            end
            % The # of transferred samples are returned
            result = length(myWfm);
        end

%**************************************************************************

% =========================================================================
%> @brief Download marker states to target channel and segment
%>
%> This method is static and public
%> Download marker stated to a given channel and segment and configure the
%> marker outputs according to marker settings in awg_setup.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myMkr Marker states in the marker format according to the DAC
%> mode and markers per Analog channel output.
%> @retval result Number of marker states downloaded
% =========================================================================
        function result = SendMkrToProteus(obj, awg_setup, myMkr)
            obj.SelectModule(awg_setup.sel_module);
            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel));
            obj.inst.SendScpi(sprintf(':TRAC:SEL %d', awg_setup.segment));
            % Download the binary data to segment   
            prefix = ':MARK:DATA 0,';
            obj.inst.WriteBinaryData(prefix, myMkr); 
            result = length(myMkr);
            
            if      awg_setup.mkr_mode == obj.AWG_MKR_MODE_TWO ||...
                    awg_setup.mkr_mode == obj.AWG_MKR_MODE_FOUR||...
                    awg_setup.mkr_mode == obj.AWG_MKR_MODE_EIGHT

                obj.inst.SendScpi(':MARK:SEL 1');         %Marker 1
                obj.inst.SendScpi([':MARK:VOLT:PTOP ' num2str(awg_setup.mkr1_volt)]);      %Vpp
                obj.inst.SendScpi([':MARK:VOLT:OFFS ' num2str(awg_setup.mkr1_offset)]);      %DC Offset
                if awg_setup.mkr1_state == 1
                    obj.inst.SendScpi(':MARK ON');
                else
                    obj.inst.SendScpi(':MARK OFF');
                end
                obj.inst.SendScpi(':MARK:SEL 2');         %Marker 2
                obj.inst.SendScpi([':MARK:VOLT:PTOP ' num2str(awg_setup.mkr2_volt)]);      %Vpp
                obj.inst.SendScpi([':MARK:VOLT:OFFS ' num2str(awg_setup.mkr2_offset)]);      %DC Offset
                if awg_setup.mkr2_state == 1
                    obj.inst.SendScpi(':MARK ON');
                else
                    obj.inst.SendScpi(':MARK OFF');
                end
            end

            if      awg_setup.mkr_mode == obj.AWG_MKR_MODE_FOUR||...
                    awg_setup.mkr_mode == obj.AWG_MKR_MODE_EIGHT

                obj.inst.SendScpi(':MARK:SEL 3');         %Marke 3  
                obj.inst.SendScpi([':MARK:VOLT:PTOP ' num2str(awg_setup.mkr3_volt)]);      %Vpp
                obj.inst.SendScpi([':MARK:VOLT:OFFS ' num2str(awg_setup.mkr3_offset)]);      %DC Offset
                if awg_setup.mkr3_state == 1
                    obj.inst.SendScpi(':MARK ON');
                else
                    obj.inst.SendScpi(':MARK OFF');
                end
                obj.inst.SendScpi(':MARK:SEL 4');         %Marker 4
                obj.inst.SendScpi([':MARK:VOLT:PTOP ' num2str(awg_setup.mkr4_volt)]);      %Vpp
                obj.inst.SendScpi([':MARK:VOLT:OFFS ' num2str(awg_setup.mkr4_offset)]);      %DC Offset
                if awg_setup.mkr4_state == 1
                    obj.inst.SendScpi(':MARK ON');
                else
                    obj.inst.SendScpi(':MARK OFF');
                end
            end
        end

%**************************************************************************

% =========================================================================
%> @brief Download a task list and associated waveforms for IQ Mode ONE
%>
%> This method is static and public
%> Download task list and associated waveforms to target segments for IQ
%> Mode ONE.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @param task_list 2-dimension matrix with all the parameters for all the
%> entries in the task list.
%> @retval result Number of samples downloaded
% =========================================================================
        function result = SendIqmOneListToProteus(  obj,...                
                                                    awg_setup,...
                                                    myWfm,...
                                                    task_list)

            result = obj.SendIqmOneWfm( awg_setup,...
                                        myWfm);

            obj.TaskListSetup(awg_setup, task_list);
        end

%**************************************************************************

% =========================================================================
%> @brief Download waveforms for IQ Mode ONE
%>
%> This method is static and public
%> Download waveforms to target segments for IQ Mode ONE. It includes
%> normalization.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @retval result Number of samples downloaded
% =========================================================================
        function result = SendIqmOneWfm(    obj,...                
                                            awg_setup,...                                            
                                            myWfm)        
            % format Wfm
            myWfm = obj.NormalIqOne(myWfm);
            myWfm = obj.ComplexToInterleaved(myWfm); 
            if length(awg_setup.wfm_map) > 1
                awg_setup.wfm_map = 2 * awg_setup.wfm_map;
            end
            % Transfer to AWG, including quantization
            if obj.lib_verbose
                fprintf(1, sprintf('DOWNLOADING WAVEFORM: %d samples\n', length(myWfm))); 
            end
            result = obj.SendWfmToProteus( awg_setup,...
                                            myWfm,...
                                            true);            
            if obj.lib_verbose
                fprintf(1, 'WAVEFORM DOWNLOADED!\n');
            end
            clear myWfm;           
        end

%**************************************************************************

% =========================================================================
%> @brief Download a task list and associated waveforms for IQ Mode HALF
%>
%> This method is static and public
%> Download task list and associated waveforms to target segments and
%> channels for IQ Mode HALF.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @param task_list 2-dimension matrix with all the parameters for all the
%> entries in the task list.
%> @retval result Number of samples downloaded
% =========================================================================
        function result = SendIqmHalfListToProteus( obj,...                
                                                    awg_setup,...
                                                    myWfm,...
                                                    task_list)

            result = obj.SendIqmHalfWfm(    awg_setup,...
                                            myWfm);
            
            obj.TaskListSetup(awg_setup, task_list);
        end

%**************************************************************************

% =========================================================================
%> @brief Download waveforms for IQ Mode HALF
%>
%> This method is static and public
%> Download waveforms to target segments and channels for IQ Mode HALF. It
%> includes normalization.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @retval result Number of samples downloaded
% =========================================================================
        function result = SendIqmHalfWfm(   obj,...                
                                            awg_setup,...                                            
                                            myWfm)

            myWfm = obj.NormalIqOne(myWfm);           
                   
            % Channel I is 2N - 1 and Channel Q is 2N
            % If channel is even, then base channle number is corrected
            if mod(awg_setup.channel, 2) == 0
                 awg_setup.channel = awg_setup.channel - 1;
            end

            % Waveform Downloading
            % ********************             
            if obj.lib_verbose
                fprintf(1, 'DOWNLOADING WAVEFORMS I/Q\n');
            end
            % awg_setup.channel = awg_setup.channel - 1;
            % awg_setup.segment = awg_setup.segment - 2;
            result = obj.SendWfmToProteus(  awg_setup,...
                                            myWfm,...
                                            true);                      
            if obj.lib_verbose
                fprintf(1, 'WAVEFORMS DOWNLOADED!\n');
            end
            clear myWfm;          
        end

%**************************************************************************

% =========================================================================
%> @brief Download a task list and associated waveforms for IQ Mode TWO
%>
%> This method is static and public
%> Download task list and associated waveforms to target segments for IQ
%> Mode TWO.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @param task_list 2-dimension matrix with all the parameters for all the
%> entries in the task list.
%> @retval result Number of samples downloaded
% =========================================================================
        function result = SendIqmTwoListToProteus(  obj,...                
                                                    awg_setup,...
                                                    myWfm1,...
                                                    myWfm2,...
                                                    task_list)

            if length(awg_setup.wfm_map) > 1
                awg_setup.wfm_map = 4 * awg_setup.wfm_map;
            end

            result = obj.SendIqmTwoWfm( awg_setup,...
                                        myWfm1,...
                                        myWfm2);

            obj.TaskListSetup(awg_setup, task_list);
        end

%**************************************************************************

% =========================================================================
%> @brief Download waveforms for IQ Mode TWO
%>
%> This method is static and public
%> Download waveforms to target segments for IQ Mode TWO. It includes
%> normalization.
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
%> @param myWfm One or multiple normalized waveforms. Mapping in wfm_map.
%> @retval result Number of samples downloaded
% =========================================================================
        function result = SendIqmTwoWfm(    obj,...                
                                            awg_setup,...
                                            myWfm1,...
                                            myWfm2)
    
            [myWfm1,  myWfm2]   = obj.NormalIqTwo(myWfm1, myWfm2);    
            myWfm               = obj.ComplexToInterleavedTwo(myWfm1, myWfm2); 

            result              = obj.SendWfmToProteus( awg_setup,...
                                                        myWfm,...
                                                        true);           
            
            if obj.lib_verbose
                fprintf(1, 'WAVEFORM DOWNLOADED!\n');
            end
            clear myWfm;           
        end

%**************************************************************************

% =========================================================================
%> @brief Set NCO Mode
%>
%> This method is static and public
%> This function sets up the NCO mode and the associated frequency and
%> phase parameters according to the corresponding fields in awg_setup
%> @param obj instance of the TEProteusLib class.
%> @param awg_setup Proteus settings structure.
% =========================================================================
        function SetNco(    obj,...
                            awg_setup)

            obj.SelectModule(awg_setup.sel_module);
            % Select Channel
            obj.inst.SendScpi(sprintf(':INST:CHAN %d', awg_setup.channel)); 
            if obj.lib_verbose
                fprintf(1, 'SETTING SAMPLING CLOCK\n');
            end
            % The two below commands will keep Proteus in th 16-bit mode
            % Otherwise, for sample rates > 2.5GS/s, even-numbered channels
            % will not be active
            obj.inst.SendScpi([':FREQ:RAST ' num2str(2.5E9)]); 
            obj.inst.SendScpi(':SOUR:INT X8');
            % DAC Mode set to 'NCO'       
            obj.inst.SendScpi(':MODE NCO'); 
            
            if awg_setup.nco_mode == obj.AWG_NCO_MODE_DUAL
                obj.inst.SendScpi(':NCO:MODE DUAL');
            else
                obj.inst.SendScpi(':NCO:MODE SINGLE');
            end
            
            obj.inst.SendScpi([':FREQ:RAST ' num2str(awg_setup.sampling_rate)]);
            % 'NCO' Settings
            obj.inst.SendScpi(sprintf(':NCO:CFR1 %f', awg_setup.cfr1));
            obj.inst.SendScpi(sprintf(':NCO:PHAS1 %f', awg_setup.phase1));
            % if apply6db
            if awg_setup.six_db1
                obj.inst.SendScpi(':NCO:SIXD1 ON');   
            else
                obj.inst.SendScpi(':NCO:SIXD1 OFF');    
            end

            if awg_setup.nco_mode == obj.AWG_NCO_MODE_DUAL
                % 'NCO' Settings
                obj.inst.SendScpi(sprintf(':NCO:CFR2 %f', awg_setup.cfr2));
                obj.inst.SendScpi(sprintf(':NCO:PHAS2 %f', awg_setup.phase2));
                % if apply6db
                if awg_setup.six_db2
                    obj.inst.SendScpi(':NCO:SIXD2 ON');   
                else
                    obj.inst.SendScpi(':NCO:SIXD2 OFF');    
                end
            end

            % Output voltage 
            if awg_setup.volt > 0.0
                obj.inst.SendScpi(sprintf(':SOUR:VOLT %f', awg_setup.volt));
            else
                obj.inst.SendScpi(':SOUR:VOLT MAX');
            end
            % Activate outpurt and start generation
            if awg_setup.output_state
                obj.inst.SendScpi(':OUTP ON');
            else
                obj.inst.SendScpi(':OUTP OFF');
            end
        end

%**************************************************************************
        % DIGITIZER METHODS
%**************************************************************************

% =========================================================================
%> @brief Set Proteus Digitizer Mode and Acquisition
%>
%> This method is static and public
%> It sets up the mode and settings for both channels in Proteus digitizer.
%> It includes selection of the dual/single mode, direct/DDC Mode, trigger
%> modes and settings, input full scale, frame length and number of frames,
% %> pre-trigger and acquisition state fo both channels.
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @param dig_setup Digitizer settings structure.
% =========================================================================
        function SetupProteusDigMode(   obj,...
                                        dig_setup)
            % ----------
            % ADC Config
            % It supports up to two channels with different setups
            % ----------
            obj.SelectModule(dig_setup.sel_module);
            % Set the ADC mode and set the channel mapping
            if dig_setup.mode == obj.DIG_ACQ_MODE_DUAL
                obj.inst.SendScpi(':DIG:MODE DUAL');  
                num_of_channels = 2;
            elseif dig_setup.mode == obj.DIG_ACQ_MODE_SINGLE
                obj.inst.SendScpi(':DIG:MODE SINGLE');
                num_of_channels = 1;
                dig_setup.ch_state(obj.DIG_CHAN_ONE) = obj.DIG_CHAN_ENABLE;
                dig_setup.ch_state(obj.DIG_CHAN_TWO) = obj.DIG_CHAN_DISABLE;
                % Only Channel 1 in Single mode
            end 
            % Setting acquisition type            
            % if dig_setup.acq_type == obj.DIG_ACQ_TYPE_HEADERS
            %     obj.inst.SendScpi(':DIG:ACQ:TYPE HEAD');
            % else
            %     obj.inst.SendScpi(':DIG:ACQ:TYPE ALL');
            % end

            % Free Acquistion Memory and Set sampling rate
            obj.inst.SendScpi(':DIG:ACQ:FREE');    
            obj.inst.SendScpi(sprintf(':DIG:FREQ %g', dig_setup.sampling_rate));

            % DDC activation
            % Calculate actual frame length depending on the DDC mode
            actual_frame_len = dig_setup.frame_length;
            actual_pretrig = round(dig_setup.pre_trigger * actual_frame_len / 100);
            actual_pretrig = round(actual_pretrig / dig_setup.granul) * dig_setup.granul;
            if dig_setup.ddc == obj.DIG_MODE_COMPLEX      
                obj.inst.SendScpi(':DIG:DDC:MODE COMP');
                actual_pretrig = 2 * actual_pretrig;
                actual_frame_len = 2 * actual_frame_len;
                for channel = 1:num_of_channels
                    % NCO frequency mapped to the first and second NZ
                    ddc_freq = obj.GetNcoFreq(  dig_setup.cfr(channel), ...
                                                dig_setup.sampling_rate, ...
                                                false);                    
                    obj.inst.SendScpi(sprintf(':DIG:DDC:CFR%d %f', channel, abs(ddc_freq)));                    
                end
            else
                obj.inst.SendScpi(':DIG:DDC:MODE REAL');
            end

            % Setup frames layout. Common to both ADC channels.    
            obj.inst.SendScpi(sprintf(':DIG:ACQ:DEF %d, %d',...
                dig_setup.num_of_frames, actual_frame_len));
    
            % Pretrigger for DDC must be set to double as acquisions are made
            % by IQ pair of samples   
            obj.inst.SendScpi(sprintf(':DIG:PRET %d', actual_pretrig));

            for channel = 1:2
                if  (dig_setup.ch_state(obj.DIG_CHAN_ONE) == obj.DIG_CHAN_ENABLE && channel == 1) ||...
                    (dig_setup.ch_state(obj.DIG_CHAN_TWO) == obj.DIG_CHAN_ENABLE && channel == 2)
                    % Select digitizer channel:
                    obj.inst.SendScpi(sprintf(':DIG:CHAN %d', channel));
                    % Set the voltage-range of the selected channel
                    switch dig_setup.rng(channel)
                        case obj.DIG_RNG_250MV
                            obj.inst.SendScpi(':DIG:CHAN:RANG LOW');
                        case obj.DIG_RNG_400MV
                            obj.inst.SendScpi(':DIG:CHAN:RANG MED');
                        case obj.DIG_RNG_500MV
                            obj.inst.SendScpi(':DIG:CHAN:RANG HIGH');
                    end
                    %Enable acquisition in the selected channel
                    if dig_setup.ch_state(channel) == obj.DIG_CHAN_ENABLE
                        obj.inst.SendScpi(':DIG:CHAN:STATE ENAB');
                    elseif dig_setup.ch_state(channel) == obj.DIG_CHAN_DISABLE
                        obj.inst.SendScpi(':DIG:CHAN:STATE DIS');
                    end                
                    
                    % Set channel 1 of the digitizer as its trigger source
                    % If DTR trigger, it is directed to the designated AWG channel
                    
                    switch dig_setup.trg_src(channel)
                        case obj.DIG_TRG_CPU
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE CPU');
    
                        case obj.DIG_TRG_EXT
                            obj.inst.SendScpi(':DIG:TRIG:SOUR EXT');
                            obj.inst.SendScpi(':DIG:TRIG:SOUR EDGE');
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:LEV1 %f',...
                                dig_setup.trg_lvl(channel)));
    
                            switch dig_setup.trg_slope(1)
                                case obj.DIG_TRG_EDGE_NEG
                                    obj.inst.SendScpi(':DIG:TRIG:SLOP NEG');
    
                                case obj.DIG_TRG_EDGE_POS
                                    obj.inst.SendScpi(':DIG:TRIG:SLOP POS');
                            end
    
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:DEL %f',...
                                dig_setup.trg_delay(channel)));
    
                        case obj.DIG_TRG_CH1
                            obj.inst.SendScpi(':DIG:TRIG:SOUR CH1');
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:SELF %f',...
                                dig_setup.trg_lvl(channel)));
                            switch dig_setup.trg_slope(channel)
                                case obj.DIG_TRG_EDGE_NEG
                                    obj.inst.SendScpi(':DIG:TRIG:SLOP NEG');
    
                                case obj.DIG_TRG_EDGE_POS
                                    obj.inst.SendScpi(':DIG:TRIG:SLOP POS');
                            end                           
    
                        case obj.DIG_TRG_CH2
                            obj.inst.SendScpi(':DIG:TRIG:SOUR CH2');
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:SELF %f',...
                                dig_setup.trg_lvl(channel)));
                            switch dig_setup.trg_slope(channel)
                                case obj.DIG_TRG_EDGE_NEG
                                    obj.inst.SendScpi(':DIG:TRIG:SLOP NEG');
    
                                case obj.DIG_TRG_EDGE_POS
                                    obj.inst.SendScpi(':DIG:TRIG:SLOP POS');
                            end
    
                        case obj.DIG_TRG_DTR_CH1
                            obj.SelectModule(dig_setup.sel_module);
                            obj.inst.SendScpi(':INST:CHAN 1');
                            trg_delay = obj.GetActualElement(dig_setup.trg_delay, channel);
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:AWG %e',...
                                trg_delay));
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE TASK1');
                            
                        case obj.DIG_TRG_DTR_CH2
                            obj.SelectModule(dig_setup.sel_module);
                            obj.inst.SendScpi(':INST:CHAN 2');
                            trg_delay = obj.GetActualElement(dig_setup.trg_delay, channel);
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:AWG %e',...
                                trg_delay));
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE TASK2');
    
                        case obj.DIG_TRG_DTR_CH3
                            obj.SelectModule(dig_setup.sel_module);
                            obj.inst.SendScpi(':INST:CHAN 3');
                            trg_delay = obj.GetActualElement(dig_setup.trg_delay, channel);
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:AWG %e',...
                                trg_delay));
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE TASK3');
    
                        case obj.DIG_TRG_DTR_CH4
                            obj.SelectModule(dig_setup.sel_module);
                            obj.inst.SendScpi(':INST:CHAN 4');
                            trg_delay = obj.GetActualElement(dig_setup.trg_delay, channel);
                            obj.inst.SendScpi(sprintf(':DIG:TRIG:AWG %e',...
                                trg_delay));
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE TASK4');
    
                        case obj.DIG_TRG_MR1
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE MR1');
    
                        case obj.DIG_TRG_MF1
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE MF1');
    
                        case obj.DIG_TRG_MR2
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE MR2');
    
                        case obj.DIG_TRG_MF2  
                            obj.inst.SendScpi(':DIG:TRIG:SOURCE MF2');
                    end        
                    % ***** SEE IF THIS MAY BE DONE FOR EACH CHANNEL
                    % Select which frames are filled with captured data 
                    %(all frames in this example)
                    obj.inst.SendScpi(':DIG:ACQ:FRAM:CAPT:ALL');            
                    % Delete all wfm memory
                    obj.inst.SendScpi(':DIG:ACQ:ZERO:ALL'); 
                end
            end
            % Get ADC wfm format. For informative purposes
            % resp = inst.SendScpi(':DIG:DATA:FORM?');
            % resp = strtrim(netStrToStr(resp.RespStr));
            % Stop the digitizer
            obj.inst.SendScpi(':DIG:INIT OFF');
        end

%***********************************************************

% =========================================================================
%> @brief Acquire Waveform from Proteus Digitizer
%>
%> This method is static and public
%> Acquire multiple frames with waveforms from one or two channels in
%> Proteus digitizer.
%> @param obj instance of the TEProteusLib class.
%> @param inst Handler for the selected instrument (class variable).
%> @param dig_setup Digitizer settings structure.
%> @retval num_of_acq_frames Number of frames actually acquired
% =========================================================================
        function num_of_acq_frames = AcquireWfm(    obj,...
                                                    dig_setup)
            obj.inst.SendScpi(':DIG:INIT ON');
            
            num_of_acq_frames   = 0;

            % Identify Digitizer channels to acquire
            active_channels     = [false, false];
            completion_flag     = [true, true];
            % Channels and acquisition flag are activated if necessary
            if dig_setup.ch_state(1) == obj.DIG_CHAN_ENABLE
                active_channels(1)  = true;
                completion_flag(1)  = false;
            end
            % Channel #2 is considered if ADC mode is DUAL
            if dig_setup.mode == obj.DIG_ACQ_MODE_DUAL
                if dig_setup.ch_state(2) == obj.DIG_CHAN_ENABLE
                    active_channels(2)  = true;  
                    completion_flag(2)  = false;
                end
            end

            if active_channels(1)
                current_channel = 1;
            elseif active_channels(2)
                current_channel = 2;
            end

            if (active_channels(1) && dig_setup.trg_src(1) == obj.DIG_TRG_CPU) ||...
                (active_channels(2) && dig_setup.trg_src(2) == obj.DIG_TRG_CPU)
                obj.inst.SendScpi(':DIG:TRIG:IMM');
            end

            loop_counter = 0;
            num_of_loops = ceil(dig_setup.acq_timeout / 0.1);

            obj.inst.SendScpi(':TRIG:IMM');

            % Get acquisition status CSV string from Proteus for selected
            % channel
            while (~completion_flag(1) || ~completion_flag(2)) && loop_counter < num_of_loops
                % Select channel                
                obj.inst.SendScpi(sprintf(':DIG:CHAN %d', current_channel));
                % Check acquisition status for current channel
                resp = obj.inst.SendScpi(':DIG:ACQ:FRAM:STAT?');
                resp = strtrim(obj.netStrToStr(resp.RespStr));
                resp = strtrim(resp);
                items = split(resp, ',');
                items = str2double(items);
                % If item 2 in the CSV string is '1', then all frames have been
                % captured
                if length(items) >= 3 && items(2) == 1
                    completion_flag(current_channel) = true;
                end
                % This is just to give some information when trigger times out
                if mod(loop_counter, 10) == 0 && obj.lib_verbose               
                    fprintf('%d. %s Time:\n', fix(loop_counter / 10), resp);                                
                end
                pause(0.1);
                loop_counter = loop_counter + 1;
                if active_channels(1) && active_channels(2)
                    if current_channel == 1
                        current_channel = 2;
                    else
                        current_channel = 1;
                    end
                end
            end
            % Digitizer is stopped
            obj.inst.SendScpi(':DIG:INIT OFF');
            % Number of frames acquired is returned
            if completion_flag(1) && completion_flag(2)
                num_of_acq_frames = dig_setup.num_of_frames;
            end            
        end

%**************************************************************************

% =========================================================================
%> @brief Upload Frames from Proteus Digitizer
%>
%> This method is static and public
%> Transfer multiple frames from one or two channels in Proteus Digitizer
%> @param obj instance of the TEProteusLib class. Returned Waveform data is
%> formatted so all frames for one channel are appedend firsta and then all
%> the frames for the other channel are appedende to the previous channel so
%> only one vector is returned.
%> @param inst Handler for the selected instrument (class variable).
%> @param dig_setup Digitizer settings structure.
%> @retval acq_wfm Vector with waveform data for all uploaded frames.
% =========================================================================
        function acq_wfm = GetDigWfm(   obj,...
                                        dig_setup)

            acq_wfm             = int16.empty;
            length_multiplier   = 1;
            if dig_setup.ddc == obj.DIG_MODE_COMPLEX
                length_multiplier = 2;
            end

            if  dig_setup.ch_state(1) == obj.DIG_CHAN_ENABLE && ...
                dig_setup.ch_state(2) == obj.DIG_CHAN_ENABLE
                acq_wfm = int16(zeros(2, dig_setup.num_of_frames * dig_setup.frame_length * length_multiplier));
                if  dig_setup.ch_state(1) == obj.DIG_CHAN_ENABLE || ...
                    dig_setup.ch_state(2) == obj.DIG_CHAN_ENABLE
                    acq_wfm = int16(zeros(1, dig_setup.num_of_frames * dig_setup.frame_length * length_multiplier));
                end
            end

            index_ptr = 0;
            for current_channel = 1:2
                if (current_channel == 1 && dig_setup.ch_state(1) == obj.DIG_CHAN_ENABLE) ||...
                        (current_channel == 2 && dig_setup.ch_state(2) == obj.DIG_CHAN_ENABLE)
                    index_ptr = index_ptr + 1;
                    % Select channel
                    obj.inst.SendScpi(sprintf(':DIG:CHAN %d', current_channel));
                    % Define what we want to read 
                    % (frames data, frame-header, or both).
                    % In this example we read the frames-data
                    obj.inst.SendScpi(':DIG:DATA:TYPE FRAM');
                    obj.inst.SendScpi(':DIG:DATA:SEL ALL');
            
                    % Read binary block
                    % Get the size in bytes of the acquisition
                    resp = obj.inst.SendScpi(':DIG:DATA:SIZE?');
                    resp = strtrim(obj.netStrToStr(resp.RespStr));
                    num_bytes = uint64(str2double(resp));
                    % upload time will be shown so transfer rate can be compared
                    if obj.lib_verbose
                        fprintf('ADC Upload Time for %d bytes:\n', num_bytes);                    
                        tic;
                    end
                    if obj.com_ifc == obj.COMM_IFC_LAN
                        if dig_setup.ddc == obj.DIG_MODE_COMPLEX 
                            % DDC data is formatted as 15-bit in a 32-bit unsigned
                            % integer
                            samples = obj.inst.ReadBinaryData(':DIG:DATA:READ?', 'uint32');              
                            %toc;
                            samples = int16(samples) - 16384; % Set zero level
                            % Convert to complex I + jQ samples
                            %samples = obj.InterleavedToComplex(samples);
                            % Invert spectrum if ddcFreq < 0.0
                            if dig_setup.cfr(current_channel) < 0.0
                                samples(2:2:end) = -samples(2:2:end);
                            end
                        else
                            %tic;
                            % Direct ADC data is formated as 12-bit samples in 16-bit
                            % unsigned integers
                            samples = obj.inst.ReadBinaryData(':DIG:DATA:READ?', 'uint16');     
                            %toc;
                            samples = int16(samples) - 2048; % Set zero level
                        end
                    else
                        % For the PXI library, downloads can only handlw 8 or 16-bit
                        % unsigned.
                        if dig_setup.ddc == obj.DIG_MODE_COMPLEX
                            % For DDC, because read format is UINT16 we divide byte
                            % number by 2
                            wavlen = floor(num_bytes / 2);        
                            % allocate NET array
                            netArray = NET.createArray('System.UInt16', wavlen);
                            % read the captured frame
                            %tic;
                            res = obj.inst.ReadMultipleAdcFrames(   current_channel - 1,...
                                                                    1, ...
                                                                    dig_setup.num_of_frames, ...
                                                                    netArray);
                            %toc;
                         
                            assert(res == 0);
                            % Each 32 sample is now 2 contiguous 16-bit samples
                            samples = uint16(netArray);
                            % As the first 16-bit samples in the pair is "all zeros"
                            % they can be discarded by taking one very two bytes
                            samples = samples(1:2:length(samples));
                            
                            % cast to matlab vector
                            samples = int16(samples) - 16384; % Set zero level
                            % Convert to complex I + jQ samples
                            %samples = obj.InterleavedToComplex(samples);
                            % Invert spectrum if ddcFreq < 0.0
                            if dig_setup.cfr(current_channel) < 0.0
                                samples(2:2:end) = -samples(2:2:end);
                            end                
                            % deallocate the NET array
                            delete(netArray);
                        else
                            wavlen = floor(num_bytes / 2);
                    
                            % allocate NET array
                            netArray = NET.createArray('System.UInt16', wavlen);
                            % read the captured frame
                            %tic
                            res = obj.inst.ReadMultipleAdcFrames(   current_channel - 1,...
                                                                    1, ...
                                                                    dig_setup.num_of_frames, ...
                                                                    netArray);
                            %res = obj.inst.ReadMultipleAdcFrames(0, 1, numberOfFrames, netArray);
                            %toc
                            assert(res == 0);
                            
                            samples = uint16(netArray);
                            % cast to matlab vector
                            samples = int16(samples) - 2048;
                                            
                            % deallocate the NET array
                            delete(netArray);
                        end            
                    end
                    if obj.lib_verbose
                        toc;
                    end
                    acq_wfm(index_ptr, :) = samples;
                end                   
            end
            % Ouput data is formatted as a two dimensions array with A x F
            % rows (A = number of acquisitions, F = number of Frames) and
            % FrameLem columns
            %fprintf('Formatting time for %d frames:\n', numberOfFrames);            
        end

%**************************************************************************

        function [  trg_loc,...
                    gate_addr,...
                    min_adc,...
                    max_adc,...
                    time_stamp] = GetHeaderData(obj, channel, num_of_frames)
        
            obj.inst.SendScpi(sprintf(':DIG:CHAN %d', channel));
        
            obj.inst.SendScpi(':DIG:DATA:TYPE HEAD');
            if obj.com_ifc == obj.COMM_IFC_LAN
                header_raw = obj.inst.ReadBinaryData(':DIG:DATA:READ?', 'uint8');
            else
                % % allocate NET array
                % netArray = NET.createArray('System.UInt16', 44 * num_of_frames);
                % res = obj.inst.ReadBinaryData(':DIG:DATA:READ?', netArray, 44 * num_of_frames);
                % header_raw = uint16(netArray);
                % % deallocate the NET array
                % delete(netArray);
            end
        
            %num_of_frames = round(length(header_raw) / 88);
        
            trg_loc =       uint32(zeros(1, num_of_frames));
            gate_addr =     uint32(zeros(1, num_of_frames));
            min_adc =       uint32(zeros(1, num_of_frames));
            max_adc =       uint32(zeros(1, num_of_frames));
            time_stamp =    uint64(zeros(1, num_of_frames));
        
            base_pointer = 0;
        
            for frame = 1:num_of_frames
                for k = 1:4
                    trg_loc(frame) = trg_loc(frame) + uint32(header_raw(base_pointer + k)) * uint32(256)^(k-1);
                end
        
                raw_level = uint32(0);
        
                for k = 9:12
                    raw_level = raw_level + uint32(header_raw(base_pointer + k)) * uint32(256)^(k-9);
                end
        
                min_adc(frame) = raw_level;
        
                raw_level = uint32(0);
        
                for k = 13:16
                    raw_level = raw_level + uint32(header_raw(base_pointer + k)) * uint32(256)^(k-13);
                end
        
                max_adc(frame) = raw_level;  
        
                time_stamp(frame) = 0;
        
                for k = 17:24
                    time_stamp(frame) = time_stamp(frame) + uint64(header_raw(base_pointer + k)) * uint64(256)^(k-17);
                end
                
                base_pointer = base_pointer + 88;
            end
        end

%**************************************************************************

        function [  read_hdr] = GetHeaderData2(obj, channel, num_of_frames)
        
            obj.inst.SendScpi(sprintf(':DIG:CHAN %d', channel));
        
            obj.inst.SendScpi(':DIG:DATA:TYPE HEAD');
            if obj.com_ifc == obj.COMM_IFC_LAN
                header_raw = obj.inst.ReadBinaryData(':DIG:DATA:READ?', 'uint8');
            else
                % % allocate NET array
                % netArray = NET.createArray('System.UInt16', 44 * num_of_frames);
                % res = obj.inst.ReadBinaryData(':DIG:DATA:READ?', netArray, 44 * num_of_frames);
                % header_raw = uint16(netArray);
                % % deallocate the NET array
                % delete(netArray);
            end

            actual_num_of_frames = floor(length(header_raw) / obj.DIG_FRAME_HDR_TOT_SIZE);
            if num_of_frames > actual_num_of_frames
                num_of_frames = actual_num_of_frames;
            end
        
            base_pointer = 0;

            read_hdr = uint64(zeros(num_of_frames, length(obj.DIG_FRAME_HDR_FLD_SIZE)));
        
            for frame = 1:num_of_frames
                field_pointer = 0;
                for field = 1:length(obj.DIG_FRAME_HDR_FLD_SIZE)
                    raw_value = uint64(0);
                    for k = 1:obj.DIG_FRAME_HDR_FLD_SIZE(field)
                        raw_value = raw_value + uint64(header_raw(base_pointer + field_pointer + k)) * uint64(256)^(k-1);
                    end

                    read_hdr(frame, field) = raw_value;

                    field_pointer = field_pointer + obj.DIG_FRAME_HDR_FLD_SIZE(field);                   
                end
                base_pointer = base_pointer + obj.DIG_FRAME_HDR_TOT_SIZE;
            end
        end

%**************************************************************************

        function [  out_wfm,...
                    out_hdr,... 
                    out_mkr] = GetWfmFromProteusDig(    obj,...
                                                        dig_setup)            
            % Creation of output arrays
            obj.SetupProteusDigMode(dig_setup);
            out_wfm             = uint16.empty;
            out_hdr             = uint64.empty;
            out_mkr             = uint8.empty;            
            num_of_acq_frames   = obj.AcquireWfm(dig_setup);

            if dig_setup.acq_type == obj.DIG_ACQ_TYPE_ALL &&...
                    (dig_setup.data_type == obj.DIG_DATA_TYPE_FRAMES || dig_setup.data_type == obj.DIG_DATA_TYPE_BOTH)
                out_wfm         = obj.GetDigWfm(dig_setup);
            end

            if dig_setup.acq_type == obj.DIG_DATA_TYPE_HEADERS ||...
                    (dig_setup.acq_type == obj.DIG_ACQ_TYPE_ALL &&...
                    (dig_setup.data_type == obj.DIG_DATA_TYPE_BOTH || dig_setup.data_type == obj.DIG_DATA_TYPE_HEADERS))

                if dig_setup.ch_state(obj.DIG_CHAN_ONE) == obj.DIG_CHAN_ENABLE
                    out_hdr = [out_hdr; obj.GetHeaderData2(obj.DIG_CHAN_ONE, num_of_acq_frames)];
                end
                if dig_setup.ch_state(obj.DIG_CHAN_TWO) == obj.DIG_CHAN_ENABLE
                    out_hdr = [out_hdr; obj.GetHeaderData2(obj.DIG_CHAN_TWO, num_of_acq_frames)];
                end
            end            
        end

%**************************************************************************

        function [scaled_wfm, max_y, min_y] = ScaleAdcWfm(  obj,...
                                                            dig_setup,...
                                                            raw_wfm, ...
                                                            use_dac_lvl)
        
            num_of_wfms     = size(raw_wfm, 1);
            num_of_samples  = size(raw_wfm, 2);
            scaled_wfm      = zeros(num_of_wfms, num_of_samples);
        
            for wfm = 1:num_of_wfms
                switch dig_setup.rng(wfm)
                    case obj.DIG_RNG_250MV
                        actual_v_range = 0.25 / 2;
            
                    case obj.DIG_RNG_400MV
                        actual_v_range = 0.4 / 2;
            
                    case obj.DIG_RNG_500MV
                        actual_v_range = 0.5 / 2;
                end
        
                actual_v_offset = dig_setup.offset(wfm);
        
                if dig_setup.avg == obj.DIG_AVG_ON
                    word_length_norm = 1;
                    if (12 + floor(log2(dig_setup.num_avgs))) > 28
                        word_length_norm = 12 + floor(log2(dig_setup.num_avgs)) - 28;
                        word_length_norm = 2^word_length_norm;
                    end
                    scaled_wfm(wfm, :) = double(int32(raw_wfm) - 134217728);
                    scaled_wfm(wfm, :) = scaled_wfm(wfm, :) / dig_setup.num_avgs;
                    scaled_wfm(wfm, :) = scaled_wfm(wfm, :) * word_length_norm;
                    max_y = 2048; % * avg_settings.num_of_avg;            
                else
                    if dig_setup.ddc == obj.DIG_MODE_COMPLEX
                        max_y = 16384;                
                    else
                        max_y = 2048;               
                    end
        
                    scaled_wfm(wfm, :) = double(raw_wfm(wfm, :) - max_y);            
                end
        
                if use_dac_lvl
                    min_y = -max_y;
                else
                    scaled_wfm(wfm, :)  = scaled_wfm(wfm, :) + max_y;
                    scaled_wfm(wfm, :)  = scaled_wfm(wfm, :) * actual_v_range / max_y;
                    scaled_wfm(wfm, :)  = scaled_wfm(wfm, :) + actual_v_offset;
                    max_y               = actual_v_offset + actual_v_range;
                    min_y               = actual_v_offset - actual_v_range;
                end
            end
        end

%**************************************************************************
%                       OTHER INSTRUMENTATION METHODS                     *
%**************************************************************************

        function [scope_session, idn_str] = ConnectToScope( obj,...
                                                            connStr)
            %fprintf('\nConnecting to Scope\n');
            % VISA session opened to the spectrum analyer.Use the right device
            % descritor for the interface and address being used.
            %connStr = 'TCPIP0::192.168.1.57::hislip0::INSTR';
            scope_session                   = visa('NI', connStr);
            scope_session.OutputBufferSize  = 10000000;
            scope_session.InputBufferSize   = 10000000;
            scope_session.Timeout           = 100.0;
            scope_session.ByteOrder         = 'littleEndian';
            fopen(scope_session);
            %pause(1);
            fprintf(scope_session, '%s', '*IDN?');
            idn_str                          = fscanf(scope_session);            
        end

%**************************************************************************

        function  DisconnectFromScope(  obj,...
                                        scope_session)
            fclose(scope_session);
        end

%**************************************************************************

        function SetScope(  obj,...
                            scope_session,...
                            scope_settings)
        
            switch scope_settings.scope_model
                case obj.SCOPE_MODEL_KEYSIGHT
                    obj.SetInfiniiumScope(  scope_session,...
                                            scope_settings);
            end
        end

%**************************************************************************

        function SetInfiniiumScope( obj,...
                                    scope_session,...
                                    scope_settings)
        
            %----------------------------------------------------------------------
            % Set up Scope
            %----------------------------------------------------------------------
            if obj.lib_verbose
                fprintf('Scope Set-Up for Measurements\n');
            end
            fprintf(scope_session, '%s', '*RST');
        
            fprintf(scope_session, '%s', '*OPC?');
            res = fscanf(scope_session);
        
            % Activate selected channels
            for current_channel = 1:4
                fprintf(scope_session, '%s', [':CHAN' num2str(current_channel) ':DISP OFF']);        
            end
            for current_channel = 1:length(scope_settings.chan_scope)
                fprintf(scope_session, '%s', [':CHAN' num2str(scope_settings.chan_scope(current_channel)) ':DISP ON']);
                fprintf(scope_session, '%s', '*OPC?');
                res = fscanf(scope_session);       
        
                % Set vertical scale     
                init_volt_div = obj.GetActualElement(scope_settings.volt_pp, current_channel);
                init_volt_div = init_volt_div / 8.0;
                init_offset = obj.GetActualElement(scope_settings.offset, current_channel);
        
                fprintf(scope_session, '%s', [':CHAN' num2str(scope_settings.chan_scope(current_channel)) ':SCAL ' num2str(init_volt_div)]);
                fprintf(scope_session, '%s', '*OPC?');
                fprintf(scope_session, '%s', [':CHAN' num2str(scope_settings.chan_scope(current_channel)) ':OFFS ' num2str(init_offset)]);
                fprintf(scope_session, '%s', '*OPC?');                
                fprintf(scope_session, '%s', [':CHAN' num2str(scope_settings.chan_scope(current_channel)) ':PROB:SKEW ' num2str(0.0)]);
                fprintf(scope_session, '%s', '*OPC?');
                res = fscanf(scope_session);
            end
        
            % Set Time Base        
            timeBase = scope_settings.time_window / 10.0;
        
            fprintf(scope_session, '%s', [':TIM:SCAL ' num2str(timeBase)]);
            fprintf(scope_session, ':TIM:REF CENT');    
            fprintf(scope_session, '%s', '*OPC?');
            res = fscanf(scope_session);
        
            xPos = (scope_settings.trig_pos - 50.0) * timeBase / 10.0;
        
            fprintf(scope_session, '%s', [':TIM:POS ' num2str(xPos)]);    
            fprintf(scope_session, '%s', '*OPC?');
            res = fscanf(scope_session);     
        
            % Set trigger source, level    

            if scope_settings.trg_channel == 0
                fprintf(scope_session, ':TRIG:EDGE:SOUR AUX');
            else
                fprintf(scope_session, '%s', [':TRIG:EDGE:SOUR CHAN' num2str(scope_settings.trg_channel)]);
            end
            if scope_settings.trg_slope == obj.SCOPE_TRG_SLOPE_POS
                fprintf(scope_session, ':TRIG:EDGE:SLOP POS'); 
            else
                fprintf(scope_session, ':TRIG:EDGE:SLOP NEG');
            end
            fprintf(scope_session, '%s', [':TRIG:LEV CHAN' num2str(scope_settings.trg_channel) ',' num2str(scope_settings.trg_lvl)]); 
            holdTime = 1E-6;
            fprintf(scope_session, '%s', [':TRIG:HOLD ' num2str(holdTime)]);    
            fprintf(scope_session, '%s', '*OPC?');
            res = fscanf(scope_session);        
        end

%**************************************************************************

        function waveform = GetScopeWfm(    obj,...
                                            scope_session,...
                                            scope_settings,...
                                            init)

            switch scope_settings.scope_model
                case obj.SCOPE_MODEL_KEYSIGHT
                    waveform = obj.GetInfiniiumWfm( scope_session,...
                                                    scope_settings,...
                                                    init);
            end
        end
        
%**************************************************************************

        function waveform = GetInfiniiumWfm(    obj,...
                                                scope_session,...
                                                scope_settings,...
                                                init)
                                
            displayed_points = scope_settings.time_window * scope_settings.sample_rate;            
    
            % Set acquisition parameters
            fprintf(scope_session,':STOP');
            if init
                % Specify data from Channel
                fprintf(scope_session,[':WAVEFORM:SOURCE CHAN' num2str(scope_settings.chan_scope(1))]); 
                % Set timebase to main
                fprintf(scope_session,':TIMEBASE:MODE MAIN');
                % Set up acquisition type and count. 
                fprintf(scope_session,':ACQUIRE:TYPE NORMAL');
                fprintf(scope_session,':ACQUIRE:COUNT 1');
                % Specify 5000 points at a time by :WAV:DATA?
                fprintf(scope_session,':WAV:POINTS:MODE RAW');
                fprintf(scope_session,[':WAV:POINTS ' num2str(displayed_points)]);
            end
            % Now tell the instrument to digitize channel1
            fprintf(scope_session,[':DIGITIZE CHAN' num2str(scope_settings.chan_scope(1))]);
            % Wait till complete
            operationComplete = str2double(query(scope_session,'*OPC?'));
            while ~operationComplete
                operationComplete = str2double(query(scope_session,'*OPC?'));
            end
    
            if init
                % Get the data back as a WORD (i.e., INT16), other options are ASCII and BYTE
                fprintf(scope_session,':WAVEFORM:FORMAT WORD');
                % Set the byte order on the instrument as well
                fprintf(scope_session,':WAVEFORM:BYTEORDER LSBFirst');
                end
            % Get the preamble block
            preambleBlock = query(scope_session,':WAVEFORM:PREAMBLE?');
    
            % Now send commmand to read data
            fprintf(scope_session,':WAV:DATA?');
            % read back the BINBLOCK with the data in specified format and store it in
            % the waveform structure. FREAD removes the extra terminator in the buffer
            waveform.RawData = binblockread(scope_session,'int16'); fread(scope_session,1);
            % Read back the error queue on the instrument
        %     instrumentError = query(ViSessn,':SYSTEM:ERR?');
        %     while ~isequal(instrumentError,['+0,"No error"' char(10)])
        %         disp(['Instrument Error: ' instrumentError]);
        %         instrumentError = query(ViSessn,':SYSTEM:ERR?');
        %     end      
    
            % Maximum value storable in a INT16
            maxVal = 2^16; 
            %  split the preambleBlock into individual pieces of info
            preambleBlock = regexp(preambleBlock,',','split');
            % store all this information into a waveform structure for later use
            waveform.Format         = str2double(preambleBlock{1});     % This should be 1, since we're specifying INT16 output
            waveform.Type           = str2double(preambleBlock{2});
            waveform.Points         = str2double(preambleBlock{3});
            waveform.Count          = str2double(preambleBlock{4});      % This is always 1
            waveform.XIncrement     = str2double(preambleBlock{5});     % in seconds
            waveform.XOrigin        = str2double(preambleBlock{6});    % in seconds
            waveform.XReference     = str2double(preambleBlock{7});
            waveform.YIncrement     = str2double(preambleBlock{8}); % V
            waveform.YOrigin        = str2double(preambleBlock{9});
            waveform.YReference     = str2double(preambleBlock{10});
            waveform.VoltsPerDiv    = (maxVal * waveform.YIncrement / 8);      % V
            waveform.Offset         = ((maxVal/2 - waveform.YReference) * waveform.YIncrement + waveform.YOrigin);         % V
            waveform.SecPerDiv      = waveform.Points * waveform.XIncrement/10 ; % seconds
            waveform.Delay          = ((waveform.Points/2 - waveform.XReference) * waveform.XIncrement + waveform.XOrigin); % seconds
            
            % Generate X & Y Data            
            waveform.YData          = (waveform.YIncrement.*(waveform.RawData - waveform.YReference)) + waveform.YOrigin;            
            %wfm                     = waveform.YData;
            %x_delta                 = waveform.XIncrement;
            %sec_div                 = waveform.SecPerDiv;
        end

%**************************************************************************

        function SaveCorrectionFilter( obj, file_name, corr_setup, taps)
            fid = fopen(file_name,'wt');
        
            current_txt = sprintf("GAIN %e", corr_setup.gain);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
            
            current_txt = sprintf("SRATE %e", corr_setup.sampling_rate);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            current_txt = sprintf("DELAY %e", corr_setup.wfm_delay);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            num_of_taps = length(taps);
            current_txt = sprintf("TAPS %d", num_of_taps);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            for current_tap = 1:num_of_taps        
                current_txt = sprintf("%e", taps(current_tap));        
                current_txt = strcat(current_txt, "\n");  
                fprintf(fid, current_txt);
            end
        
            fclose(fid);
        end

%**************************************************************************

        function [  gain,...
                    wfm_delay,...
                    sampling_rate,...
                    taps] = LoadCorrectionFilter( obj, file_name)
        
            gain            = 1.0;
            wfm_delay       = 0.0;
            sampling_rate   = 9E9;
            taps            = double.empty;
        
            end_of_header = false;
            num_of_taps = 0;

            fid = fopen(file_name,'rt');
        
            while ~end_of_header
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end  %end of file
        
                thisline = upper(thisline);
        
                if contains(thisline, 'GAIN')
                    thisline        = strrep(thisline, 'GAIN', '');            
                    gain            = sscanf(thisline, '%e');               
                end 
    
                if contains(thisline, 'SRATE')
                    thisline        = strrep(thisline, 'SRATE', '');            
                    sampling_rate   = sscanf(thisline, '%e');               
                end
    
                if contains(thisline, 'DELAY')
                    thisline        = strrep(thisline, 'DELAY', '');            
                    wfm_delay       = sscanf(thisline, '%e');            
                end
    
                if contains(thisline, 'TAPS')
                    thisline        = strrep(thisline, 'TAPS', '');            
                    num_of_taps  = sscanf(thisline, '%d');       
                    end_of_header = true;
                end
            end
        
            for current_tap = 1:num_of_taps
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end
        
                values = sscanf(thisline, '%e');
                taps(current_tap) = values(1);        
            end
            fclose(fid);
        end

%**************************************************************************

        function SaveCalibrationFile(   obj,...
                                        file_name,...
                                        sampling_rate,...
                                        wfm_delay,...
                                        type_file,...
                                        f_var,...
                                        amp_var,...
                                        phase_var,...
                                        freq_list,...
                                        amplitude_list,...
                                        phase_list)
        
            fid = fopen(file_name,'wt');
        
            switch type_file
                case obj.CAL_TYPE_AMPL_PHASE
                    current_txt = "TYPE AMP_PHASE";
        
                case obj. CAL_TYPE_AMPL
                    current_txt = "TYPE AMP_ONLY";
            end
            current_txt = strcat(current_txt, "\n");                    
            fprintf(fid, current_txt);

            current_txt = sprintf("SRATE %e", sampling_rate);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);

            current_txt = sprintf("DELAY %e", wfm_delay);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            current_txt = "FREQ EXP";
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            switch f_var
                case obj.CORR_FREQ_UNIT_HZ
                    current_txt = "X_UNIT HZ";
        
                case obj.CORR_FREQ_UNIT_KHZ
                    current_txt = "X_UNIT KHZ";
        
                case obj.CORR_FREQ_UNIT_MHZ
                    current_txt = "X_UNIT MHZ";
        
                case obj.CORR_FREQ_UNIT_GHZ
                    current_txt = "X_UNIT GHZ";
            end

            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            switch amp_var
                case obj.CORR_AMPL_UNIT_DB
                    current_txt = "AMP_UNIT DB";
        
                case obj.CORR_AMPL_UNIT_LINEAR
                    current_txt = "AMP_UNIT LIN";        
            end

            current_txt = strcat(current_txt, "\n");  
            fprintf(fid, current_txt);
        
            switch phase_var
                case obj.CORR_PHASE_UNIT_DEGREE
                    current_txt = "PHASE_UNIT DEG";
        
                case obj.CORR_PHASE_UNIT_RADIAN
                    current_txt = "PHASE_UNIT RAD";        
            end

            current_txt = strcat(current_txt, "\n");          
            fprintf(fid, current_txt);          
        
            num_of_factors = length(freq_list);
            current_txt = sprintf("FACTORS %d", num_of_factors);
            current_txt = strcat(current_txt, "\n");   
            fprintf(fid, current_txt);
        
            for current_factor = 1:num_of_factors
                switch type_file
                    case obj.CAL_TYPE_AMPL_PHASE
                        current_txt = sprintf("%e, %e, %e", freq_list(current_factor), amplitude_list(current_factor), phase_list(current_factor));
                    case obj.CAL_TYPE_AMPL
                        current_txt = sprintf("%e, %e", freq_list(current_factor), amplitude_list(current_factor));
                end
                current_txt = strcat(current_txt, "\n");  
                fprintf(fid, current_txt);
            end
        
            fclose(fid);                   
        end

%**************************************************************************

        function corr_setup = LoadCalibrationFile(obj, file_name)

            corr_setup = obj.CreateDefaultCorrSetup();
        
            corr_setup.corr_type        = obj.CAL_TYPE_AMPL_PHASE;
            corr_setup.sampling_rate    = 9E9;
            corr_setup.wfm_delay        = 0.0;
            corr_setup.f_var            = obj.CORR_FREQ_UNIT_HZ;
            corr_setup.amp_var          = obj.CORR_AMPL_UNIT_DB;
            corr_setup.phase_var        = obj.CORR_PHASE_UNIT_DEGREE;
        
            num_of_factors = 0;
        
            fid             = fopen(file_name,'rt');
            end_of_header   = false;
        
            while ~end_of_header
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end  %end of file
        
                thisline = upper(thisline);
        
                if contains(thisline, 'TYPE')
                    thisline        = strrep(thisline, 'TYPE', '');            
                    type            = sscanf(thisline, '%s');
                    if contains(type, 'AMP_ONLY')
                        corr_setup.corr_type = obj.CAL_TYPE_AMPL;
                    end
                end 
        
                if contains(thisline, 'SRATE')
                    thisline                    = strrep(thisline, 'SRATE', '');            
                    corr_setup.sampling_rate    = sscanf(thisline, '%e');            
                end
        
                if contains(thisline, 'DELAY')
                    thisline                    = strrep(thisline, 'DELAY', '');            
                    corr_setup.wfm_delay        = sscanf(thisline, '%e');            
                end
        
                if contains(thisline, 'X_UNIT')
                    thisline                    = strrep(thisline, 'X_UNIT', '');            
                    unit                        = sscanf(thisline, '%s');
                    if contains(unit, 'KHZ')
                        corr_setup.f_var        = obj.CORR_FREQ_UNIT_KHZ;
                    elseif contains(unit, 'MHZ')
                        corr_setup.f_var        = obj.CORR_FREQ_UNIT_MHZ;
                    elseif contains(unit, 'GHZ')
                        corr_setup.f_var        = obj.CORR_FREQ_UNIT_GHZ;
                    end
                end
        
                if contains(thisline, 'AMP_UNIT')
                    thisline                    = strrep(thisline, 'AMP_UNIT', '');            
                    unit                        = sscanf(thisline, '%s');
                    if contains(unit, 'LIN')
                        corr_setup.amp_var      = obj.CORR_AMPL_UNIT_LINEAR;            
                    end
                end
        
                if contains(thisline, 'PHASE_UNIT')
                    thisline                    = strrep(thisline, 'PHASE_UNIT', '');            
                    unit                        = sscanf(thisline, '%s');
                    if contains(unit, 'RAD')
                        corr_setup.phase_var    = obj.CORR_PHASE_UNIT_RADIAN;            
                    end
                end
        
                if contains(thisline, 'FACTORS')
                    thisline                    = strrep(thisline, 'FACTORS', '');            
                    num_of_factors              = sscanf(thisline, '%d');       
                    end_of_header               = true;
                end
            end
        
            corr_setup.x_freq       = zeros(1, num_of_factors);
            corr_setup.ampl_resp    = zeros(1, num_of_factors);
            corr_setup.phase_resp   = double.empty;
        
            if corr_setup.corr_type == obj.CAL_TYPE_AMPL_PHASE        
                corr_setup.phase_resp = zeros(1, num_of_factors);
            end
        
            for current_factor = 1:num_of_factors
                thisline = fgetl(fid);
                if ~ischar(thisline) 
                    break; 
                end
        
                if corr_setup.corr_type == obj.CAL_TYPE_AMPL_PHASE
                    values = sscanf(thisline, '%e, %e, %e');
                    corr_setup.x_freq(current_factor)       = values(1);
                    corr_setup.ampl_resp(current_factor)    = values(2);
                    corr_setup.phase_resp(current_factor)   = values(3);
                else
                    values = sscanf(thisline, '%e, %e');
                    corr_setup.x_freq(current_factor)       = values(1);
                    corr_setup.ampl_resp(current_factor)    = values(2);
                end
            end
            fclose(fid);
        end

%**************************************************************************

        function [  c_ampl,...
                    c_phase,...
                    wfm_delay] = ProcessFreqResp(   obj,...
                                                    x_freq,...
                                                    ampl_resp,...
                                                    phase_resp)
        
            c_ampl = 20.0 * log10(ampl_resp);
            c_ampl = c_ampl - c_ampl(1);
        
            c_phase = unwrap(phase_resp);
            linear_range = round(length(x_freq) / 4);
            linear_model = polyfit(x_freq(1:linear_range), c_phase(1:linear_range), 1);
            wfm_delay = -linear_model(1) / (2 * pi);    
            
            c_phase = c_phase + (wfm_delay * 2 * pi * x_freq)  - linear_model(2);
            
            c_phase = c_phase * 180.0 / pi;
        end

%**************************************************************************

        function [x_freq, ampl_resp, phas_resp] = CalAwgChannel(    obj,...
                                                                    awg_setup,...
                                                                    scope_setup,...
                                                                    cal_setup)        
            % SETTING AWG
            fprintf(1, 'SETTING AWG\n');
            
            % Reset AWG
            obj.inst.SendScpi('*CLS;*RST');
            
            awg_setup.channel       = cal_setup.awg_test_channel;
            awg_setup.volt          = cal_setup.wfmVolt(1);
            awg_setup.offset        = cal_setup.WfmOffset;
            awg_setup.mode          = obj.AWG_MODE_DIRECT;
            awg_setup.mkr_mode      = obj.AWG_MKR_MODE_TWO;
            awg_setup.mkr1_state    = 1;
            awg_setup.mkr1_volt     = cal_setup.mkrVolt;
            awg_setup.mkr1_offset   = cal_setup.mkrOff;
            awg_setup.mkr2_state    = 1;
            awg_setup.mkr2_volt     = cal_setup.mkrVolt;
            awg_setup.mkr2_offset   = cal_setup.mkrOff;
        
            mkrDiv = 2;
            if awg_setup.dac_resolution == 8
                mkrDiv = 8;
                awg_setup.mkr_mode = obj.AWG_MKR_MODE_FOUR;
            end
            
            %  TEST LOOP
            current_freq            = cal_setup.start_freq(1);
            time_window             = 1.0 / cal_setup.freq_res;
            basic_num_of_samples    = time_window * awg_setup.sampling_rate / awg_setup.interpol;
            basic_num_of_samples    = round(basic_num_of_samples);
            
            awg_num_of_samples      = basic_num_of_samples;
            while mod(awg_num_of_samples, awg_setup.granularity) ~= 0
                awg_num_of_samples  = awg_num_of_samples + basic_num_of_samples;
            end
            
            time_window             = awg_num_of_samples / awg_setup.sampling_rate * awg_setup.interpol;
            
            % Marker set up
            myMkr1          = uint8(zeros(1, awg_num_of_samples / mkrDiv));
            myMkr1(1:100)   = uint8(1); % Sync marker duration depends on the channel
            myMkr2          = rand(1, length(myMkr1)); % Random data is different for each channel
            myMkr2          = uint8(myMkr2 > 0.5);
            myMkr           = obj.FormatMkr2(awg_setup.dac_resolution, myMkr1, myMkr2);

            % Set up sync channel

            myWfm                   = zeros (1, awg_num_of_samples);
            %myWfm                   = myWfm + cal_setup.sync_pulse_low;
            sync_samples            = round(cal_setup.sync_pulse_width * awg_setup.sampling_rate / awg_setup.interpol);
            myWfm(1:sync_samples)   = cal_setup.sync_pulse_high;
            myWfm((awg_num_of_samples - sync_samples):end)   = cal_setup.sync_pulse_low;
            
            % DOWNLOAD
            awg_setup.channel       = cal_setup.awg_sync_channel;
            awg_setup.volt          = cal_setup.wfmVolt(2);
            awg_setup.segment       = 1;
            
            obj.SendWfmToProteus(   awg_setup,...
                                    myWfm,...
                                    true);
            
            awg_setup.channel       = cal_setup.awg_test_channel;
            
            % Set scope settings
            scope_setup.scope_model = cal_setup.scope_type;
            scope_setup.chan_scope  = [cal_setup.scope_test, cal_setup.scope_sync];
            scope_setup.trg_channel = cal_setup.scope_sync;
            scope_setup.volt_pp     = cal_setup.scope_range ;
            scope_setup.offset      = cal_setup.scope_offset;
            scope_setup.time_window = 1.0 / cal_setup.freq_res;
            scope_setup.trg_lvl     = cal_setup.scope_trg_lvl;
            scope_setup.trig_pos    = 50.0;
            obj.SetScope(   scope_setup.handle,...
                            scope_setup);
            
            init_flag               = true;            
            x_freq                  = double.empty;
            ampl_resp               = double.empty;
            phas_resp               = double.empty;
            
            init_scope = true;
            awg_setup.volt          = cal_setup.wfmVolt(1);

            while current_freq <= cal_setup.stop_freq   
                for idx = 1:length(cal_setup.start_freq)
                    if current_freq >= cal_setup.start_freq(idx)
                        step_freq = cal_setup.step_freq(idx);
                    end
                end
                
                if cal_setup.verbose
                    txt = sprintf("\nCurrent Freq = %fMHz\n", current_freq / 1E6);
                    %cal_setup.disp_handle.Text = txt;
                    fprintf(txt);
                    pause(0.01);
                end


                num_of_cycles       = round(current_freq * time_window);
                myWfm               = 0:(awg_num_of_samples - 1);                
                myWfm               = cos(2 * pi * myWfm * num_of_cycles / awg_num_of_samples);
                actual_freq         = num_of_cycles / time_window;
                %myWfm               = proteus_lib.WfmRepeatForMinSize(myWfm, min_wfm_size);   
            
                % DOWNLOAD
                awg_setup.segment   = 1;
            
                obj.SendWfmToProteus(   awg_setup,...
                                        myWfm,...
                                        init_flag);   %init_flag
                if init_flag
                    obj.SendMkrToProteus(awg_setup, myMkr);
                end   
            
                avg_ampl = 0.0;
                avg_real = 0.0;
                avg_imag = 0.0;
            
                pause(0.01);

                
                for idx = 1:length(cal_setup.num_of_avg)
                    if current_freq >= cal_setup.avg_freq_range(idx)
                        num_avg = cal_setup.num_of_avg(idx);
                    end
                end
                % show_graph = false;  
                % keep_graph_flag = false;
                % 
                % if abs(current_freq - 1E9) < 1E6
                %     num_avg = 256;
                %     keep_graph_flag = false;
                %     show_graph = false;
                % end
            
                for scope_acq = 1:num_avg        
                
                    scope_setup.chan_scope = cal_setup.scope_test;
                    scope_wfm = obj.GetScopeWfm(    scope_setup.handle,...
                                                    scope_setup,...
                                                    init_scope);
                    if init_scope
                        init_scope = false;
                    end               
                
                    valid_scope_samples = 1.0 / scope_wfm.XIncrement * 1.0 / cal_setup.freq_res;
                    valid_scope_samples = round(valid_scope_samples);
                    fft_wfm             = scope_wfm.YData - mean(scope_wfm.YData);
                    fft_wfm             = fft_wfm(1:valid_scope_samples);
                    ft_window           = flattopwin(valid_scope_samples);
                    
                    %ft_window = ft_window';
                    
                    fft_wfm             = fft_wfm .* ft_window;
                    mySpec              = fft(fft_wfm);                    
                    
    
                    %scope_time_window = scope_wfm.XIncrement * length(fft_wfm);
                    fft_freq_resolution = (1.0 / scope_wfm.XIncrement) / valid_scope_samples;
                    current_bin         = actual_freq / fft_freq_resolution;
                    current_bin         = round(current_bin) + 1;
                    bin                 = mySpec(current_bin);
                    %bin = bin * exp(-1i * 2 * pi * scope_wfm.Delay * actual_freq);
                    bin = bin * exp(-1i * 2 * pi * scope_wfm.XOrigin * actual_freq);
                    avg_ampl            = avg_ampl + abs(bin);
                    avg_real            = avg_real + abs(bin) * cos(angle(bin));
                    avg_imag            = avg_imag + abs(bin) * sin(angle(bin));

                    % if show_graph
                    %     xdata = 0:(length(scope_wfm.YData) - 1);
                    %     xdata = xdata * scope_wfm.XIncrement;
                    %     plot(xdata, scope_wfm.YData);
                    % 
                    %     if keep_graph_flag 
                    %         hold on;
                    %         keep_graph_flag = false;
                    %     end            
                    % end

                end

                % if show_graph
                %     a = 1;
                % end
            
                %plot(abs(mySpec((current_bin - 5):(current_bin + 5))));
                avg_ampl    = avg_ampl / num_avg;    
                avg_phase   = angle(avg_real + 1i * avg_imag);
            
                x_freq      = [x_freq, current_freq];            
                ampl_resp   = [ampl_resp, avg_ampl];
                phas_resp   = [phas_resp, avg_phase];
            
            
                init_flag = false;
                current_freq = current_freq + step_freq;                
            end        
        end

%**************************************************************************

        function impulse_response = GetImpulseResponse( obj,...
                                                        x_freq,...
                                                        ampl_resp,...
                                                        phase_resp,...
                                                        sampling_rate)

            ampl_resp               = 10.0.^(ampl_resp / 20.0);
            phase_resp              = phase_resp * pi / 180.0;           
            actual_sampling_rate    = sampling_rate;
            step_freq               = x_freq(2) - x_freq(1); 

            num_of_bins                         = length(ampl_resp);
            size_ext_freq_resp                  = round(actual_sampling_rate / step_freq);
            corr_freq_resp                      = zeros(1, size_ext_freq_resp);
            corr_freq_resp(2:(num_of_bins + 1)) = ampl_resp .* exp(1i * phase_resp);
            corr_freq_resp((num_of_bins + 1):...
                (size_ext_freq_resp/2 - 1))     = corr_freq_resp(num_of_bins); 
            corr_freq_resp...
                (size_ext_freq_resp/2)          = abs(corr_freq_resp(num_of_bins));
            
            for num_bin = 0:(size_ext_freq_resp/2 - 1)
                corr_freq_resp(size_ext_freq_resp - num_bin) = conj(corr_freq_resp(num_bin + 2));
            end
            
            corr_freq_resp(1) = abs(corr_freq_resp(2));
            
            impulse_response    = ifft(corr_freq_resp);
            impulse_response    = fftshift(impulse_response);
            impulse_response    = impulse_response / sum(impulse_response);           
        end

%**************************************************************************

        function [  fir_taps,...
                    x_freq,...
                    corr_ampl,...
                    corr_phase] = GetCorrectionFilter(obj, corr_setup)

            x_freq      = corr_setup.x_freq;
            ampl_resp   = corr_setup.ampl_resp;
            phase_resp  = corr_setup.phase_resp;

            ampl_resp   = 10.0.^(ampl_resp / 20.0);
            phase_resp  = phase_resp * pi / 180.0;            
            
            % ampl_resp(x_freq > corr_setup.stop_freq) = 0.0;
            % phase_resp(x_freq > corr_setup.stop_freq) = 0.0;

            actual_sampling_rate    = corr_setup.sampling_rate / corr_setup.interpol;
            step_freq               = x_freq(2) - x_freq(1);

            % CORRECTION FILTER

            corr_ampl = zeros(1, length(ampl_resp));

            corr_ampl = 1 ./ampl_resp;
            corr_phase = - phase_resp;

            num_of_bins                         = length(ampl_resp);
            size_ext_freq_resp                  = round(corr_setup.oversampling * (actual_sampling_rate) / step_freq);
            corr_freq_resp                      = ones(1, size_ext_freq_resp);
            corr_freq_resp(2:(num_of_bins + 1)) = corr_ampl .* exp(1i * corr_phase);
            corr_freq_resp((num_of_bins + 1):(size_ext_freq_resp/2 - 1)) = corr_freq_resp(num_of_bins); 
            corr_freq_resp(size_ext_freq_resp/2) = abs(corr_freq_resp(num_of_bins));
            
            for num_bin = 0:(size_ext_freq_resp/2 - 1)
                corr_freq_resp(size_ext_freq_resp - num_bin) = conj(corr_freq_resp(num_bin + 2));
            end
            
            corr_freq_resp(1) = abs(corr_freq_resp(2));
            
            fir_taps = ifft(corr_freq_resp);
            fir_taps = fftshift(fir_taps);
            fir_taps = fir_taps / sum(fir_taps);
            
            start_bin   = (length(fir_taps) - corr_setup.num_of_taps) / 2 + 1;
            stop_bin    = (length(fir_taps) + corr_setup.num_of_taps) / 2;
            start_bin   = start_bin + corr_setup.shift_taps;
            stop_bin    = stop_bin + corr_setup.shift_taps;
            fir_taps    = fir_taps(start_bin:stop_bin);
            corr_ampl   = abs(corr_freq_resp(1:size_ext_freq_resp/2));
            corr_phase  = angle(corr_freq_resp(1:size_ext_freq_resp/2));
            x_freq      = 0:(size_ext_freq_resp/2 - 1);
            x_freq      = x_freq * step_freq;
        end

%**************************************************************************

        function [x_freq, freq_resp] = CalcFreqResponse(obj, impulse_response, start_freq, stop_freq, step_freq, sampling_rate)

            x_freq = start_freq:step_freq:stop_freq;
            freq_resp = zeros(1, length(x_freq));

            for freq_index = 1:length(x_freq)
                for current_sample = 1:length(impulse_response)
                    freq_resp(freq_index) = freq_resp(freq_index) +...
                        impulse_response(current_sample) * exp(-1i * 2 * pi * x_freq(freq_index) * (current_sample - 1) / sampling_rate);
                end
            end        
        end

%**************************************************************************

        function taps = GetTargetImpulseResponse(obj, start_freq, stop_freq, sample_rate, num_of_taps)
        
            idx = 0:(num_of_taps - 1);
            idx = idx - floor(num_of_taps / 2);
        
            t_wind = hamming(num_of_taps);
            t_wind = t_wind';
        
            zero_pos = stop_freq / sample_rate;
            taps = sinc( 2 * idx * zero_pos); 
            taps = taps .* t_wind; 
            taps = taps / sum(taps);
        
            if start_freq > 0.0
                zero_pos = start_freq / sample_rate;    
                taps_low = sinc( 2 * idx * zero_pos);
                taps_low = taps_low .* t_wind;
                taps_low = taps_low / sum(taps_low);
            else
                taps_low = zeros(1, num_of_taps);
            end
        
            taps = taps - taps_low;
        end

%**************************************************************************
%                 EQUIVALENT TIME ACQUISITION METHODS
%**************************************************************************

        function filtered_clock = ClockFilter(  obj,...
                                                clk_wfm, ...
                                                cutoff_freq, ...
                                                sampling_rate)
        
            filter_length   = 20 * (sampling_rate/cutoff_freq);
            filter_length   = round(filter_length);
            if mod(filter_length, 2) == 0
                filter_length = filter_length + 1;
            end
            lp_filter       = -floor(filter_length / 2):floor(filter_length / 2);
            lp_filter       = sinc(2 * cutoff_freq / sampling_rate * lp_filter);
            
            lp_filter       = lp_filter / sum(lp_filter);
            
            filtered_clock  = cconv(clk_wfm,lp_filter,length(clk_wfm));
        end

%**************************************************************************

        function interp_clock = ClockInterp(    obj,...
                                                input_clock, ...
                                                interp_factor)
        
            interp_clock = zeros(1, interp_factor * (length(input_clock) - 1) + 1);
            
            for i = 0: (length(input_clock) - 2)
                for j = 0:(interp_factor - 1)
                    interp_clock(interp_factor * i + j + 1) = input_clock(i + 1) + j *...
                        (input_clock(i + 2) - input_clock(i + 1))/interp_factor;            
                end        
            end
            
            interp_clock(length(interp_clock)) = input_clock(length(input_clock));
        end

%**************************************************************************

        function x_cross = GetCrossing(obj, y_1, y_2, y_3, y_cross)
        
            y_1     = double(y_1);
            y_2     = double(y_2);
            y_3     = double(y_3);
        
            a       = (y_1 + y_3 - 2*y_2) / 2;
            b       = (y_3 - y_1) / 2;
            c       = y_2;
            
            c       = c - y_cross;    
            e       = sqrt(b * b - 4 * a * c);    
            x_cross = (- b + e) / (2 * a) ;
            
            if abs(x_cross) > 1.0
                x_cross = (- b - e) / (2 * a);        
            end   
        end

%**************************************************************************

        function [eye_x, eye_y] = GetEquivalentTimeAcq( obj,...
                                                        data_wfm, ...
                                                        clk_wfm, ...
                                                        eq_time_setup)
        
            % Zero cross detection for clock waveform
            x_values = double.empty;
            
            for i = 2:(length(clk_wfm) - 1)
                if (clk_wfm(i) <= 0.0 && clk_wfm(i + 1) >= 0.0)
                    x_cross = obj.GetCrossing(clk_wfm(i - 1), clk_wfm(i), clk_wfm(i + 1), 0.0); 
                    x_values = [x_values, (i + x_cross)]; 
                elseif (clk_wfm(i) >= 0.0 && clk_wfm(i + 1) <= 0.0) && eq_time_setup.all_edges
                    x_cross = obj.GetCrossing(clk_wfm(i - 1), clk_wfm(i), clk_wfm(i + 1), 0.0); 
                    x_values = [x_values, (i + x_cross)];  
                end
            end
            
            % Interpolation of clock edges
            if eq_time_setup.clk_int
                x_values = obj.ClockInterp(x_values, eq_time_setup.clk_div);
            end

            eye_x = zeros(1, length(x_values));
            eye_y = zeros(1, length(x_values));
            
            if eq_time_setup.mode == obj.DIG_ET_MODE_NORMAL
                % Times specified in seconds
                sample_range = eq_time_setup.sampling_rate * eq_time_setup.size;
                sample_range = sample_range / 2;
                sample_delay = eq_time_setup.sampling_rate * eq_time_setup.delay;
            else
                % Times specified in UI for Eye Diagrams
                sample_range = eq_time_setup.sampling_rate * eq_time_setup.size * eq_time_setup.unit_interval;
                sample_range = sample_range / 2;
                sample_delay = eq_time_setup.sampling_rate * eq_time_setup.delay * eq_time_setup.unit_interval;
            end

            eye_ptr = 0;

            search_range_left = floor(sample_range + sample_delay);
            search_range_right = ceil(sample_range - sample_delay);
            
            for i = 1:length(x_values)    
                j = round(x_values(i));
                for k = (j - search_range_left):(j + search_range_right)
                    if k > 0 && k <= length(data_wfm)
                        delta_t = x_values(i) - k; 
                        if delta_t >= (-sample_range + sample_delay) &&...
                                delta_t <= (sample_range + sample_delay)
                            eye_ptr = eye_ptr + 1;
                            eye_x(eye_ptr) = delta_t - sample_delay;
                            eye_y(eye_ptr)= data_wfm(k);
                        end
                    end
                end    
            end

            eye_x = (eye_x) / eq_time_setup.sampling_rate;
            
            %eye_x = (eye_x - sample_delay) / eq_time_setup.sampling_rate;       
        end

%**************************************************************************

        function [  xyz_map,...
                    max_x, min_x,...
                    max_y, min_y] = GetXyzMap(  obj,...
                                                x_wfm, ...
                                                y_wfm, ...
                                                num_of_bins, ...
                                                num_of_lvls)
        
            max_x = max(x_wfm);
            min_x = min(x_wfm);
            max_y = max(y_wfm);
            min_y = min(y_wfm);

            x_wfm = obj.NormalizeFull(x_wfm);
            y_wfm = obj.NormalizeFull(y_wfm);
        
            x_wfm = obj.Quantization2 (x_wfm, 1, num_of_bins);
            y_wfm = obj.Quantization2 (y_wfm, 1, num_of_lvls);
        
            xyz_map = zeros(num_of_lvls, num_of_bins);
        
            for sample = 1:length(x_wfm)
                xyz_map(y_wfm(sample), x_wfm(sample)) = xyz_map(y_wfm(sample), x_wfm(sample)) + 1;
            end

            for x = 1:num_of_bins
                for y = 1:num_of_lvls
                    if xyz_map(y,x) == 0

                    else
                        %xyz_map(y,x) =  2 * max(xyz_map(y,x)) + xyz_map(y,x);
                        xyz_map(y,x) = 1 + log2(xyz_map(y,x));
                    end
                end
            end
        end

%**************************************************************************

        function [  optimum_jitter_rms,...
                    optimum_jitter_pp,...
                    box_1,...
                    box_2,...
                    samples_in_box_optimum] = GetJitter(    obj,...
                                                            x_wfm, ...
                                                            y_wfm, ...
                                                            box,...
                                                            optimize)   
            if optimize
                % The box moves vertically to find the minimum
                start_y     = box(2) - box(1);
                % Step Size = half of the box so there is 50% overlaping
                delta_y     = start_y / 2;
                % Starting position for the box
                start_y     = box(1) - obj.DIG_ET_JIT_SEARCH_ITER * delta_y; 
                steps_y     = obj.DIG_ET_JIT_SEARCH_ITER * 2 + 1;
            else
                % Just direct measurement in the original box
                start_y     = box(1);
                delta_y     = (box(2) - box(1)) / 2;
                steps_y     = 1;
            end
            
            % Variables to store optimum values
            optimum_step            = 0;
            optimum_jitter_rms      = 0.0;
            optimum_jitter_pp       = 0;
            samples_in_box_optimum  = 0;
            % The first non-zero reading will be taken as reference
            first_data_flag         = true;

            jitter_wfm = zeros(1, steps_y);
            
            % Steps according to optimization mode
            for step = 1:steps_y
                % box_1 and box_2 (vertical interval) is calculated for each
                % iteration
                box_1 = start_y + (step - 1) * delta_y;
                box_2 = box_1 + 2 * delta_y;
                % Time data is nitialized to empty
                time_data       = double.empty;
                samples_in_box  = 0;
        
                for i = 1:length(x_wfm)
                    % For all the waveform pairs, check if inside the current box
                    % First vertical
                    if y_wfm(i) >= box_1 && y_wfm(i) <= box_2
                        % And then horizontal
                        if x_wfm(i) >= box(3) && x_wfm(i) <= box(4)
                            % if inside the box, the number of saamples is
                            % invreased by one and the time value added to the
                            % vector for jitter calculation
                            samples_in_box              = samples_in_box + 1;
                            time_data(samples_in_box)   = x_wfm(i);
                        end
                    end
                end    
                % Only boxes with at least one sample inside will be processed for
                % jitter values
                if samples_in_box > 0
                    % Peak-to-Peak jitter = mextrema values difference
                    jitter_pp   = max(time_data) - min(time_data);
                    % RMS Jitter = stabdard deviation of the time vector
                    jitter_rms  = std(time_data);
                    % The optimum values are updates for the first non-zero
                    % iteration and when the rms jitter is lower than the previous
                    % minimum
                    if first_data_flag || jitter_rms < optimum_jitter_rms
                        % # of step if preserved for optimum box value return
                        optimum_step            = step;
                        optimum_jitter_pp       = jitter_pp;
                        optimum_jitter_rms      = jitter_rms;
                        % If this return value is zero, no valid box definition
                        samples_in_box_optimum  = samples_in_box;
                        % First time jitter data is calculated this flag goes to
                        % false so only minimum values will upfate the optimum
                        % values.
                        first_data_flag         = false;            
                    end        
                end

                %jitter_wfm(step) = jitter_rms;
            end
            % Location of the optimal box is reported so it can be used for further
            % processing or graphs
            box_1 = start_y + (optimum_step - 1) * delta_y;
            box_2 = box_1 + 2 * delta_y;            
        end

%**************************************************************************
%                       MODULATION METHODS
%**************************************************************************

        function [waveform, Fs] = GetModWfm( obj, mod_settings)

            switch mod_settings.mod_type
                case {  obj.MOD_ANALOG_AM,...
                        obj.MOD_ANALOG_FM,...
                        obj.MOD_ANALOG_PM,...
                        obj.MOD_ANALOG_SSB}

                    [waveform, Fs] = obj.GetAnalogModWfm(mod_settings);

                case {  obj.MOD_SCHEME_BPSK,...
                        obj.MOD_SCHEME_QPSK,...
                        obj.MOD_SCHEME_QAM16,...
                        obj.MOD_SCHEME_QAM32,...
                        obj.MOD_SCHEME_QAM64,...
                        obj.MOD_SCHEME_QAM128,...
                        obj.MOD_SCHEME_QAM256,...
                        obj.MOD_SCHEME_QAM512,...
                        obj.MOD_SCHEME_QAM1024,...
                        obj.MOD_SCHEME_8PSK...
                        obj.MOD_SCHEME_APSK16,...
                        obj.MOD_SCHEME_APSK32}

                    [waveform, Fs] = obj.GetQamWfm(mod_settings);

                case {  obj.MOD_SCHEME_FSK,...
                        obj.MOD_SCHEME_MSK}

                    [waveform, Fs] = obj.GetFskWfm(mod_settings);
            end            
        end

%**************************************************************************

function [waveform, Fs] = GetAnalogModWfm( obj, mod_settings)
    
            % Worst case delta(phase) <= 90 degrees for FM/PM
            if mod_settings.mod_type == obj.MOD_ANALOG_FM
                min_oversampling = mod_settings.modul_freq / mod_settings.modul_index;
                min_oversampling = (pi / 4) * min_oversampling;
                min_oversampling = asin(min_oversampling);
                min_oversampling = pi / min_oversampling;
                if min_oversampling > mod_settings.oversampling
                    mod_settings.oversampling = min_oversampling;
                end
            elseif mod_settings.mod_type == obj.MOD_ANALOG_PM
                min_oversampling = mod_settings.modul_index * pi / 180.0;
                min_oversampling = 1 / min_oversampling;
                min_oversampling = (pi / 4) * min_oversampling;
                min_oversampling = asin(min_oversampling);
                min_oversampling = pi / min_oversampling;
                if min_oversampling > mod_settings.oversampling
                    mod_settings.oversampling = min_oversampling;
                end
            end

            waveform_length = round(mod_settings.num_of_mod_cycles * mod_settings.oversampling);
            Fs              = mod_settings.modul_freq * mod_settings.oversampling;
            Fs              = abs(Fs);

            % Modulating sinewave calculation
            modulating_wfm  = 0:(waveform_length - 1);
            modulating_wfm  = cos(2 * pi * mod_settings.num_of_mod_cycles * modulating_wfm / waveform_length);

            % Modulated Waveform Calculation
            switch mod_settings.mod_type 
                case obj.MOD_ANALOG_AM
                    % Envelope Calculation
                    waveform = 0.5 + 0.5 *  mod_settings.modul_index / 100.0 * modulating_wfm;
                    % Normalization in the -1.0 / +1.0 Range
                    waveform = waveform / (0.5 + 0.5 * mod_settings.modul_index / 100.0 );
                    waveform = complex(waveform);

                case obj.MOD_ANALOG_SSB
                    waveform = modulating_wfm;
                    modulating_wfm  = 0:(waveform_length - 1);
                    modulating_wfm  = sin(2 * pi * mod_settings.num_of_mod_cycles * modulating_wfm / waveform_length);
                    if mod_settings.modul_freq < 0.0
                        modulating_wfm = - modulating_wfm;
                    end
                    waveform = waveform + 1i * modulating_wfm;

                case obj.MOD_ANALOG_FM
                    % Instantaneous phase
                    fm_mod_index = mod_settings.modul_index / mod_settings.modul_freq;
                    waveform = fm_mod_index * modulating_wfm;
                    % Complex Modulation waveform         
                    waveform = exp(1i * waveform);

                case obj.MOD_ANALOG_PM
                    % Instantaneous phase
                    waveform = pi * mod_settings.modul_index * modulating_wfm / 180.0;
                    % Complex Modulation waveform
                    waveform = exp(1i * waveform);
            end        
        end

%**************************************************************************

        function [waveform, Fs] = GetFskWfm(    obj,...
                                                mod_settings)

            bits_per_symbol = obj.GetModParam(mod_settings.mod_type);
            oversampling = round(mod_settings.oversampling);

            % Create IQ for FSK/MSK  
        
            % Get symbols in the range 1..2^bps and Map to IQ as Complex Symbol
             % Get symbols in the range 1..2^bps and Map to IQ as Complex Symbol
            switch mod_settings.data_src
                case obj.DATA_SRC_PRBS
                    if mod_settings.prbs_seq == obj.PRBS_USER
                        data = obj.GetUsrPrbsData(  mod_settings.usr_polinom,...
                                                    mod_settings.usr_seed,...
                                                    mod_settings.num_of_symbols,...
                                                    bits_per_symbol);

                    else
                        data = obj.GetStdPrbsData(  mod_settings.prbs_seq,...
                                                    mod_settings.usr_seed,...
                                                    mod_settings.num_of_symbols,...
                                                    bits_per_symbol);
                    end

                case obj.DATA_SRC_USER
                    data = obj.GetUsrData(  mod_settings.usr_data,...                                                    
                                            mod_settings.num_of_symbols,...
                                            bits_per_symbol);
            end

            data = double(data);
            data(data < 0.5) = -1.0;
            % 4 time repetition to ensure phase contitnuity
            %data = obj.WfmRepeat(data, 4);

            if mod_settings.mod_type == obj.MOD_SCHEME_FSK
                %peak_dev = mod_settings.modul_index;
                delta_phase = (pi / 2) * mod_settings.modul_index;
                %delta_phase = delta_phase * mod_settings.modul_index / baud_rate;
                phase_symbol = (pi / 2) * mod_settings.modul_index / mod_settings.symbol_rate;
            elseif mod_settings.mod_type == obj.MOD_SCHEME_MSK
                %peak_dev = mod_settings.symbol_rate / 4;
                delta_phase = (pi / 2) * mod_settings.symbol_rate;
                phase_symbol = pi/ 2;
            end

            Fs              = mod_settings.symbol_rate * oversampling;
            num_of_bits     = length(data);
            waveform        = zeros(1, num_of_bits * oversampling);

            previous_phase  = 0.0;
            previous_bit    = 0;           

            for current_sample = 1:length(waveform)
                current_time = (current_sample - 1) / Fs;
                current_bit = floor(current_time * mod_settings.symbol_rate);
                if current_bit > previous_bit
                    if data(previous_bit + 1) > 0.0
                        previous_phase = previous_phase + phase_symbol;
                    else
                        previous_phase = previous_phase - phase_symbol;
                    end
                    previous_bit = current_bit;
                end
                delta_time = current_time - current_bit / mod_settings.symbol_rate;
                if data(current_bit + 1) > 0.0
                    waveform(current_sample) = previous_phase + delta_time * delta_phase;
                else
                    waveform(current_sample) = previous_phase - delta_time * delta_phase;
                end
            end

            waveform = cos(waveform) - 1i * sin(waveform);

            if mod_settings.apply_fsk_corr
                if data(previous_bit + 1) > 0.0
                    correction = previous_phase + phase_symbol;
                else
                    correction = previous_phase - phase_symbol;
                end
    
                correction = mod(correction, 2 * pi);
                if correction > pi
                    correction = correction - 2 * pi;
                end
                correction = -correction;
    
                phase_correction = 0:(length(waveform) - 1);
                phase_correction = exp(1i * correction * phase_correction / length(waveform));    
                
                waveform = waveform .* phase_correction;
            end
        end

%**************************************************************************

        function [waveform, Fs] = GetQamWfm(    obj,...
                                                mod_settings)           
        
            bits_per_symbol = obj.GetModParam(mod_settings.mod_type);    
            oversampling = round(mod_settings.oversampling);
        
            % Create IQ for QPSK/QAM  
        
            % Get symbols in the range 1..2^bps and Map to IQ as Complex Symbol
            switch mod_settings.data_src
                case obj.DATA_SRC_PRBS
                    if mod_settings.prbs_seq == obj.PRBS_USER
                        data = obj.GetUsrPrbsData(  mod_settings.usr_polinom,...
                                                    mod_settings.usr_seed,...
                                                    mod_settings.num_of_symbols,...
                                                    bits_per_symbol);

                    else
                        data = obj.GetStdPrbsData(  mod_settings.prbs_seq,...
                                                    mod_settings.usr_seed,...
                                                    mod_settings.num_of_symbols,...
                                                    bits_per_symbol);
                    end

                case obj.DATA_SRC_USER
                    data = obj.GetUsrData(  mod_settings.usr_data,...                                                    
                                            mod_settings.num_of_symbols,...
                                            bits_per_symbol);
            end

            if mod_settings.mod_type >= obj.MOD_SCHEME_BPSK && mod_settings.mod_type <= obj.MOD_SCHEME_QAM1024
                waveform = obj.GetIqMap(data, mod_settings.mod_type);
            elseif mod_settings.mod_type >= obj.MOD_SCHEME_8PSK && mod_settings.mod_type <= obj.MOD_SCHEME_APSK32
                waveform = obj.GetDvbs2Map( data, ...
                                            mod_settings.mod_type,...
                                            mod_settings.dvbs2_hp_code,...
                                            mod_settings.dvbs2_lp_code,...
                                            mod_settings.dvbs2_8psk_teta);

            end
            
            % Adapt I/Q sample rate to the Oversampling parameter
            waveform =  obj.ZeroPadding(waveform, oversampling);
           
            % Calculate baseband shaping filter
            % accuracy is the length of-1 the shaping filter
            accuracy = 512;

            %filter_type = 'sqrt'; % 'normal' or 'sqrt'
            if mod_settings.filter_type == obj.MOD_BB_FILTER_SQRT
                baseband_filter = rcosdesign(   mod_settings.roll_off, ...
                                                accuracy, ...
                                                mod_settings.oversampling, ...
                                                'sqrt');
            elseif mod_settings.filter_type == obj.MOD_BB_FILTER_NORMAL
                baseband_filter = rcosdesign(   mod_settings.roll_off, ...
                                                accuracy, ...
                                                mod_settings.oversampling, ...
                                                'normal');
            end
        
            % Apply filter through circular convolution and calculate Fs
            waveform = cconv(waveform, baseband_filter, length(waveform));   
            Fs = mod_settings.symbol_rate * mod_settings.oversampling;
        end

%**************************************************************************        

        function [  bits_per_symbol,...
                    max_val,... 
                    mod_name] = GetModParam(        obj,...
                                                    mod_scheme)
            switch mod_scheme
                case obj.MOD_SCHEME_BPSK
                    max_val = 1;
                    mod_name = 'BPSK';
                case obj.MOD_SCHEME_QPSK
                    max_val = 3;
                    mod_name = 'QPSK';
                case obj.MOD_SCHEME_QAM16
                    max_val = 6;
                    mod_name = 'QAM16';
                case obj.MOD_SCHEME_QAM32
                    max_val = 9;
                    mod_name = 'QAM32';
                case obj.MOD_SCHEME_QAM64
                    max_val = 12;
                    mod_name = 'QAM64';
                case obj.MOD_SCHEME_QAM128
                    max_val = 20;
                    mod_name = 'QAM128';
                case obj.MOD_SCHEME_QAM256
                    max_val = 25;
                    mod_name = 'QAM256';
                case obj.MOD_SCHEME_QAM512
                    max_val = 35;
                    mod_name = 'QAM512';
                case obj.MOD_SCHEME_QAM1024
                    max_val = 45;
                    mod_name = 'QAM1024';
                case obj.MOD_SCHEME_FSK
                    max_val = 1;
                    mod_name = 'FSK';  
                case obj.MOD_SCHEME_MSK
                    max_val = 1;
                    mod_name = 'MSK';   
                case obj.MOD_SCHEME_8PSK
                    max_val = 1;
                    mod_name = '8PSK';
                case obj.MOD_SCHEME_APSK16
                    max_val = 1;
                    mod_name = '16-APSK';
                case obj.MOD_SCHEME_APSK32
                    max_val = 1;
                    mod_name = '32-APSK';
            end

            bits_per_symbol = obj.GetBitsPerSymbol(mod_scheme);
        end

%**************************************************************************        

        function bits_per_symbol = GetBitsPerSymbol(    obj,...
                                                        mod_scheme)
            switch mod_scheme
                case obj.MOD_SCHEME_FSK
                    bits_per_symbol = 1;
                case obj.MOD_SCHEME_MSK
                    bits_per_symbol = 1;
                case obj.MOD_SCHEME_BPSK
                    bits_per_symbol = 1;
                case obj.MOD_SCHEME_QPSK
                    bits_per_symbol = 2;
                case obj.MOD_SCHEME_QAM16
                    bits_per_symbol = 4;
                case obj.MOD_SCHEME_QAM32
                    bits_per_symbol = 5;
                case obj.MOD_SCHEME_QAM64
                    bits_per_symbol = 6;
                case obj.MOD_SCHEME_QAM128
                    bits_per_symbol = 7;
                case obj.MOD_SCHEME_QAM256
                    bits_per_symbol = 8;
                case obj.MOD_SCHEME_QAM512
                    bits_per_symbol = 9;
                case obj.MOD_SCHEME_QAM1024
                    bits_per_symbol = 10;
                case obj.MOD_SCHEME_8PSK
                    bits_per_symbol = 3;
                case obj.MOD_SCHEME_APSK16
                    bits_per_symbol = 4;
                case obj.MOD_SCHEME_APSK32
                    bits_per_symbol = 5;
            end
        end

%**************************************************************************

        function bits_per_symbol = GetSerialBitsPerSymbol(obj, serial_type)
        
            switch serial_type
                case obj.DATA_TYPE_BILVL_NRZ
                    bits_per_symbol = 1;
        
                case obj.DATA_TYPE_BILVL_RZ
                    bits_per_symbol = 1;
        
                case obj.DATA_TYPE_PAM4
                    bits_per_symbol = 2;
        
                case obj.DATA_TYPE_PAM8
                    bits_per_symbol = 3;
        
                case obj.DATA_TYPE_PAM3
                    bits_per_symbol = 3;
        
                % case obj.DATA_TYPE_PAM5
                %     bits_per_symbol = 8;
            end
        end

%**************************************************************************

        function symbols_per_symbol = GetOutSymbolsPerSymbol(obj, serial_type)
        
            switch serial_type
                case obj.DATA_TYPE_BILVL_NRZ
                    symbols_per_symbol = 1;
        
                case obj.DATA_TYPE_BILVL_RZ
                    symbols_per_symbol = 2;
        
                case obj.DATA_TYPE_PAM4
                    symbols_per_symbol = 1;
        
                case obj.DATA_TYPE_PAM8
                    symbols_per_symbol = 1;
        
                case obj.DATA_TYPE_PAM3
                    symbols_per_symbol = 2;
        
                % case obj.DATA_TYPE_PAM5
                %     symbols_per_symbol = 8;
            end
        end

%**************************************************************************

        function out_lvls = GetLevelPerSymbol(obj, serial_type, symbols)        
            
            symbols_per_symbol  = obj.GetOutSymbolsPerSymbol(serial_type);
            out_lvls = zeros(1, symbols_per_symbol * length(symbols));

            switch serial_type
                case obj.DATA_TYPE_BILVL_NRZ
                    out_lvls = symbols;
                    out_lvls = 2.0 * (out_lvls - 0.5);
        
                case obj.DATA_TYPE_BILVL_RZ
                    out_lvls(1:2:end) = symbols;
                    out_lvls(2:2:end) = 0.0;
                    out_lvls = 2.0 * (out_lvls - 0.5);
        
                case obj.DATA_TYPE_PAM4
                    out_lvls = symbols;
                    out_lvls = (out_lvls - 1.5) / 1.5;
        
                case obj.DATA_TYPE_PAM8
                    out_lvls = symbols;
                    out_lvls = (out_lvls - 3.5) / 3.5;
        
                case obj.DATA_TYPE_PAM3
                    out_lvls = obj.GetPam3Lvls(symbols);
                    a = 1;
        
                % case obj.DATA_TYPE_PAM5
                %     symbols_per_symbol = 8;
            end
        end

%**************************************************************************

        function out_lvls = GetPam3Lvls(obj, symbols)
            num_of_input_symbols = length(symbols);
            out_lvls = zeros(1,2 * num_of_input_symbols);

            for current_symbol = 1:num_of_input_symbols
                symbol_pointer = (current_symbol - 1) * 2 + 1;
                switch symbols(current_symbol)
    
                    case 0
                        out_lvls(symbol_pointer) = -1;
                        out_lvls(symbol_pointer + 1) = -1;
    
                    case 1
                        out_lvls(symbol_pointer) = -1;
                        out_lvls(symbol_pointer + 1) = 0;                  
    
                    case 2
                        out_lvls(symbol_pointer) = -1;
                        out_lvls(symbol_pointer + 1) = 1;               
    
                    case 3
                        out_lvls(symbol_pointer) = 0;
                        out_lvls(symbol_pointer + 1) = -1;               
    
                    case 4
                        out_lvls(symbol_pointer) = 0;
                        out_lvls(symbol_pointer + 1) = 1;
                   
                    case 5
                        out_lvls(symbol_pointer) = 1;
                        out_lvls(symbol_pointer + 1) = -1;
    
                    case 6
                        out_lvls(symbol_pointer) = 1;
                        out_lvls(symbol_pointer + 1) = 0; 
    
                    case 7  
                        out_lvls(symbol_pointer) = 1;
                        out_lvls(symbol_pointer + 1) = 1;
                end
            end
            a = 1;
        end
     
 %*************************************************************************

         function [out_symbols, rate_multiplier] = GetEncodedData(  obj,...
                                                                    data_encdg,...
                                                                    input_bits)
             rate_multiplier = 1;
        
             if      data_encdg == obj.DATA_ENCDG_MANCHESTER ||...
                     data_encdg == obj.DATA_ENCDG_DME ||...
                     data_encdg == obj.DATA_ENCDG_DME_T1S
                 rate_multiplier = 2;
             end
             
             out_symbols = int8(zeros(1, rate_multiplier * length(input_bits)));
        
             input_bits = int8(input_bits);
             input_bits(input_bits == 1) = +1;
             input_bits(input_bits ~= 1) = -1;
        
             switch data_encdg
                 case obj.DATA_ENCDG_NONE
                    out_symbols(input_bits == 1) = +1;
                    out_symbols(input_bits ~= 1) = -1;
        
                 case obj.DATA_ENCDG_NRZL
                    out_symbols(input_bits == 1) = +1;
                    out_symbols(input_bits ~= 1) = -1;
        
                 case obj.DATA_ENCDG_NRZI
                     previous_lvl = int8(-1);
                     current_lvl = previous_lvl;
                     for current_bit = 1:length(input_bits)
                         if input_bits(current_bit) == 1
                             current_lvl = -previous_lvl;
                             previous_lvl = current_lvl;                     
                         else
                             current_lvl = previous_lvl;
                         end
        
                         out_symbols(current_bit) = current_lvl;                    
                     end
        
                 case obj.DATA_ENCDG_MANCHESTER
                     for current_bit = 1:length(input_bits)
                         if input_bits(current_bit) == 1
                             out_symbols(2 * current_bit -1) =  +1;
                             out_symbols(2 * current_bit) =  -1;
                         else
                             out_symbols(2 * current_bit -1) =  -1;
                             out_symbols(2 * current_bit) =  +1;
                         end
                     end
        
                 case obj.DATA_ENCDG_DME
                     previous_lvl = int8(-1);
                     current_lvl = previous_lvl;
                     for current_bit = 1:length(input_bits)
                         if input_bits(current_bit) == 1
                             current_lvl = -previous_lvl;
                             previous_lvl = current_lvl;
                             out_symbols(2 * current_bit -1) =  +current_lvl;
                             out_symbols(2 * current_bit) =  -current_lvl;
                         else
                             out_symbols(2 * current_bit -1) =  +current_lvl;
                             out_symbols(2 * current_bit) =  -current_lvl;
                         end
                     end
        
                 case obj.DATA_ENCDG_DME_T1S
                     % out_symbols(1:2:end) = +1;
                     % out_symbols(2:2:end) = -1;
                     % out_symbols = out_symbols .* repelem(input_bits, 2);
                     % out_symbols = -1 * out_symbols;
                     previous_lvl = +1;
                     for current_bit = 1:length(input_bits)
                         if input_bits(current_bit) == 1
                             current_lvl = -previous_lvl;
                             out_symbols(2 * current_bit -1) = current_lvl;
                             out_symbols(2 * current_bit) = -current_lvl;
                         else
                             current_lvl = -previous_lvl;
                             out_symbols(2 * current_bit -1) = current_lvl;
                             out_symbols(2 * current_bit) = current_lvl;
                             previous_lvl = current_lvl;                        
                         end
                     end
             end
         end

 %*************************************************************************

        function [  data_wfm_out,...
                    sample_rate_out] = GetSerialDataWfm(    obj,...
                                                            data_bits,...
                                                            pulse_setup)

            res_mult        = 1.0 / (pulse_setup.sampling_rate * pulse_setup.timing_res);
            res_mult        = round(res_mult);
            
            bits_per_symbol = obj.GetSerialBitsPerSymbol(pulse_setup.data_wfm_type);             
            lvls_per_symbol = obj.GetOutSymbolsPerSymbol(pulse_setup.data_wfm_type);

            if pulse_setup.data_wfm_type == obj.DATA_TYPE_BILVL_NRZ
                [data_bits, rate_multiplier] = obj.GetEncodedData(  pulse_setup.data_encdg,...
                                                                    data_bits);
                pulse_setup.pulse_width = pulse_setup.pulse_width / rate_multiplier;
            end

            num_of_bits     = length(data_bits);
            num_of_symbols  = num_of_bits / bits_per_symbol;
            out_symbols     = num_of_symbols * lvls_per_symbol;
            % Waveform length in time
            wfm_length      = pulse_setup.pulse_width * out_symbols;
            % Waveform length in samples
            wfm_length      = wfm_length * pulse_setup.sampling_rate;
            % Adjust sample rate to keep baud rate
            sample_rate_out = pulse_setup.sampling_rate * floor(wfm_length) / wfm_length;
            wfm_length      = floor(wfm_length);

            data_wfm_out = zeros(1, wfm_length);

            % Get Isolated Pulse
            isolated_pulse = obj.GetTrapezoidalPulse(   pulse_setup.pulse_width, ...
                                                        pulse_setup.edge_shape, ...
                                                        pulse_setup.rise_time,...
                                                        res_mult * sample_rate_out, ...                                                    
                                                        1, ...
                                                        1, ...
                                                        pulse_setup.quality);

            isolated_pulse  = [zeros(1,res_mult), isolated_pulse, zeros(1,res_mult)];

            symbols         = zeros(1, num_of_symbols);
            
            for current_symbol = 1:num_of_symbols
                current_value = 0;
                % for bit = 1:bits_per_symbol
                %     current_value = current_value +...
                %         data_bits((current_symbol - 1) * bits_per_symbol + bit) * 2^(bit - 1); 
                % end
                % 
                % symbols(current_symbol) = double(current_value) / (2^bits_per_symbol - 1);
                symbols(current_symbol) = data_bits((current_symbol)); % / (2^bits_per_symbol - 1);
            end

            symbols = obj.GetLevelPerSymbol(pulse_setup.data_wfm_type, symbols); 

            final_length_pulse = ceil(length(isolated_pulse) / res_mult);

            for current_symbol = 1:out_symbols                
                bit_sample      = (current_symbol - 1) * pulse_setup.pulse_width;
                bit_sample      = bit_sample * sample_rate_out;
                start_sample    = round(bit_sample);
                bit_sample      = bit_sample - start_sample;
                bit_sample      = round(bit_sample * res_mult);
                start_sample    = start_sample + 1;
                current_pulse   = isolated_pulse((res_mult - bit_sample):res_mult:end);
                final_pulse     = zeros(1, final_length_pulse);
                final_pulse(1:length(current_pulse)) = current_pulse;
                final_pulse     = final_pulse * symbols(current_symbol); 
                data_wfm_out    = obj.AddVectorCirc(data_wfm_out, final_pulse, start_sample);       
            end
        end

%**************************************************************************

        function [  data_wfm_out,...
                    sample_rate_out] = GetSerialClkWfm(     obj,...
                                                            num_of_symbols,...
                                                            clk_div,...
                                                            pulse_setup)
            
            clk_tics                = zeros(1, num_of_symbols);
            clk_tics(1:clk_div:end) = 1.0;

            res_mult        = 1.0 / (pulse_setup.sampling_rate * pulse_setup.timing_res);
            res_mult        = round(res_mult);
            % Waveform length in time
            wfm_length      = pulse_setup.pulse_width * num_of_symbols;
            % Waveform length in samples
            wfm_length      = wfm_length * pulse_setup.sampling_rate;
            % Adjust sample rate to keep baud rate
            sample_rate_out = pulse_setup.sampling_rate * floor(wfm_length) / wfm_length;
            wfm_length      = floor(wfm_length);
            data_wfm_out    = zeros(1, wfm_length);

            % Get Isolated Pulse
            isolated_pulse = obj.GetTrapezoidalPulse(   pulse_setup.pulse_width * (clk_div / 2), ...
                                                        pulse_setup.edge_shape, ...
                                                        pulse_setup.rise_time,...
                                                        res_mult * sample_rate_out, ...                                                    
                                                        1, ...
                                                        1, ...
                                                        pulse_setup.quality);

            isolated_pulse = [zeros(1,res_mult), isolated_pulse, zeros(1,res_mult)];
            final_length_pulse = ceil(length(isolated_pulse) / res_mult);

            for current_tick = 1:num_of_symbols
                if clk_tics(current_tick) == 1
                    bit_sample      = (current_tick - 1) * pulse_setup.pulse_width;
                    bit_sample      = bit_sample * sample_rate_out;
                    start_sample    = round(bit_sample);
                    bit_sample      = bit_sample - start_sample;
                    bit_sample      = round(bit_sample * res_mult);
                    start_sample    = start_sample + 1;    
                    current_pulse   = isolated_pulse((res_mult - bit_sample):res_mult:end);
                    final_pulse     = zeros(1, final_length_pulse);
                    final_pulse(1:length(current_pulse)) = current_pulse;
                    data_wfm_out    = obj.AddVectorCirc(data_wfm_out, final_pulse, start_sample);
                end
            end
        end

%**************************************************************************

        function [  jitter_profile,...
                    actual_freq,...
                    actual_ssc_freq] = GetJitterProfile(    obj,...
                                                            num_of_samples,...
                                                            pulse_setup)
            actual_freq = double.empty;
            actual_ssc_freq = 0.0;
            jitter_profile = zeros(1, num_of_samples);
            x_values = 1:num_of_samples;
            x_values = x_values - 1;
            time_window = num_of_samples / pulse_setup.sampling_rate;

            if pulse_setup.jit_unit == obj.PULSE_JITTER_UNIT_UI
                pulse_setup.jit_sine_ampl = pulse_setup.jit_sine_ampl * pulse_setup.pulse_width;
                pulse_setup.jit_rnd_ampl = pulse_setup.jit_rnd_ampl * pulse_setup.pulse_width;
                pulse_setup.jit_mtone_ampl = pulse_setup.jit_mtone_ampl * pulse_setup.pulse_width;
            end
            % SSC Injection
            % *************
            if pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_SSC)
                num_of_cycles = round(time_window * pulse_setup.jit_ssc_freq);
                actual_ssc_freq = num_of_cycles / time_window;
                jitter_profile = 0:(num_of_samples - 1);

                t_period = num_of_samples / num_of_cycles;
                jitter_profile = mod(jitter_profile,t_period);
                % Trangular frequency profile
                for sample = 1:num_of_samples
                    if jitter_profile(sample) > (t_period / 4) && jitter_profile(sample) <= (t_period * 3 / 4)
                        jitter_profile(sample) = t_period / 2 - jitter_profile(sample); 
                    elseif jitter_profile(sample) > (t_period * 3 / 4)
                        jitter_profile(sample) = - t_period + jitter_profile(sample);
                    end
                end
                % Accurate Period Profile
                jitter_profile = 0.5 * jitter_profile / max(jitter_profile);
                jitter_profile = (1.0 / pulse_setup.pulse_width) * (1 + (pulse_setup.jit_ssc_dev / 1E6) * jitter_profile);                
                jitter_profile = 1.0 ./ jitter_profile;                
                jitter_profile = jitter_profile - pulse_setup.pulse_width;                
                
                % Integration to obtain TIE profile
                jitter_profile = cumsum(jitter_profile - mean(jitter_profile));
                % Normalization
                jitter_profile = jitter_profile * (1.0 / pulse_setup.pulse_width) / pulse_setup.sampling_rate;               
            end
            % Sinusoidal jitter injection
            % ***************************
            if  pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_SINE) ||...
                pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_MTONE)        

                if  pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_MTONE)          
                    num_of_components           = pulse_setup.jit_mtone_tones;
                    mtone.num_of_tones          = num_of_components;
                    pulse_setup.jit_sine_freq   = zeros(1, num_of_components);
                    % Phase distribution for minimum peak jitter
                    mtone.phase_distr           = obj.MTONE_PHASE_NEWMAN;
                    pulse_setup.jit_sine_phase  = obj.MtonePhaseDistr(mtone);
                    pulse_setup.jit_sine_phase  = 180.0 * pulse_setup.jit_sine_phase / pi;  % Phase in sexagesimal degrees    
                    pulse_setup.jit_sine_ampl   = pulse_setup.jit_mtone_ampl;

                    for current_tone = 1:num_of_components
                        pulse_setup.jit_sine_freq(current_tone) = current_tone * pulse_setup.jit_mtone_space;                        
                    end
                end

                num_of_components = length(pulse_setup.jit_sine_freq);
                actual_freq = zeros(1, num_of_components);
                % Get minimum frequency settings
                min_freq = min(pulse_setup.jit_sine_freq);
                min_num_of_cycles = round(time_window * min_freq);
                for component = 1:num_of_components
                    num_of_cycles = round(min_num_of_cycles * pulse_setup.jit_sine_freq(component) / min_freq);
                    actual_freq(component) = num_of_cycles / time_window;
                    jitter_profile = jitter_profile +...
                        obj.GetActualElement(pulse_setup.jit_sine_ampl, component) *...
                        sin(pi * (2 * x_values * num_of_cycles / num_of_samples +...
                        obj.GetActualElement(pulse_setup.jit_sine_phase,component)/180.0));
                end    
            end
            % Random (Gaussian) Jitter Injection
            % **********************************
            if pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_RAND)
                jitter_profile = jitter_profile + ...
                    pulse_setup.jit_rnd_ampl *...
                    obj.GetAwgnWfm( pulse_setup.jit_rnd_freq,...
                                    num_of_samples,...
                                    pulse_setup.sampling_rate);
            end           

            jitter_profile = jitter_profile * pulse_setup.sampling_rate;
        end

%**************************************************************************

        function jitter_wfm = ApplyJitterProfile(   obj,...
                                                    input_wfm,...
                                                    jitter_profile)
            jitter_wfm = zeros(1, length(input_wfm));

            for current_sample = 0:(length(input_wfm) - 1)
                jittered_sample = jitter_profile(current_sample + 1);
                t_offset = jittered_sample - floor(jittered_sample);
                jittered_sample = floor(jittered_sample);
                jittered_sample = current_sample + jittered_sample;
                start_sample = mod(jittered_sample, length(input_wfm));
                stop_sample = start_sample + 1;
                stop_sample = mod(stop_sample, length(input_wfm));
                start_sample = start_sample + 1;
                stop_sample = stop_sample + 1;
                jitter_wfm(int32(current_sample + 1)) = input_wfm(int32(start_sample)) *(1 - t_offset) + input_wfm(int32(stop_sample)) * t_offset; 
            end
        end

%**************************************************************************

        function [  jitter_wfm,...
                    actual_freq,...
                    actual_ssc_freq] = GetAndApplyJitter(   obj,...
                                                            input_wfm,...
                                                            pulse_setup)
            if  pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_RAND) ||...
                pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_SINE) ||...
                pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_SSC) ||...
                pulse_setup.jit_enable(obj.PULSE_JITTER_CAT_MTONE)
                
                [   jitter_profile,...
                    actual_freq,...
                    actual_ssc_freq]    = obj.GetJitterProfile(     length(input_wfm),...
                                                                    pulse_setup);
                jitter_wfm              = obj.ApplyJitterProfile(   input_wfm,...
                                                                    jitter_profile); 
            else
                jitter_wfm  = input_wfm;
                actual_freq     = double.empty;
                actual_ssc_freq = double.empty;
            end
        end

%**************************************************************************

        function data_out = GetAwgnWfm( obj,...
                                        awgn_bw,...
                                        wfm_length,...
                                        sample_rate)

            time_window         =  wfm_length / sample_rate;
            noise_wfm_length    = round(2 * awgn_bw * time_window);
            data_out            = zeros(1, noise_wfm_length);
            data_out            = awgn(data_out, 0.0);
            data_out            = obj.ResamplingDirect(data_out, wfm_length, true);
        end

%**************************************************************************

        function data_out = GetRandomData(  obj,...
                                            num_of_symbols, ...
                                            bits_per_symbol)
            rng("default");
            max_val                         = 2 ^ bits_per_symbol;
            data_out                        = max_val * rand(1, num_of_symbols);
            data_out                        = floor(data_out);
            data_out(data_out >= max_val)   = max_val - 1;    
        end

%**************************************************************************

        function data_out = GetHadamardCode(obj, k, n, samples_per_symbol)

            if ~exist('samples_per_symbol','var')
              samples_per_symbol = 1;
            end

            h(1,1) = 1;
            
            while length(h) < k
                h = [h, h; h, -h];           
            end  
            
            n(n>k) = k;
            n(n<1) = 1;
            data_out = repelem(h(n, :), 1, samples_per_symbol);         
        end

%**************************************************************************

        function [data_out, lfsr] = GetPrbsData(    obj,...
                                                    polynomial,...
                                                    seed,...
                                                    num_of_bits)
            polynomial  = uint8(polynomial);
            seed        = uint8(seed);
            order       = length(polynomial) - 1;
            lfsr        = uint8(zeros(1,order));     

            if length(seed) >= order
                lfsr = seed(1:order);
            else
                lfsr(1:length(seed)) = seed;
            end

            data_out = uint8(zeros(1,num_of_bits));

            
            for current_bit = 1:num_of_bits
                data_out(current_bit) = lfsr(1);
                next_bit = lfsr(1);
                for current_lfsr_bit = 2:order
                    if polynomial(current_lfsr_bit) == 1
                        next_bit = xor(next_bit, lfsr(current_lfsr_bit));
                    end
                end
                lfsr        = circshift(lfsr, - 1);
                lfsr(order) = next_bit;
            end  
        end

%**************************************************************************

        function [data_out, lfsr] = GetStdPrbsData( obj,...
                                                    prbs_seq,...
                                                    seed,...
                                                    num_of_symbols,...
                                                    bits_per_symbol)
            if prbs_seq == obj.PRBS_RND
                data = obj.GetRandomData((num_of_symbols * bits_per_symbol), ...
                                                1);
            else            
                polynomial          = obj.GetPrbsPolynomial(prbs_seq);    
                [data, lfsr]        = obj.GetPrbsData(  polynomial,...
                                                        seed,...
                                                        num_of_symbols * bits_per_symbol); 
            end

            if bits_per_symbol > 1
                data_out = zeros(1, num_of_symbols);
                for current_symbol = 1:num_of_symbols
                    for current_bit = 1:bits_per_symbol
                        data_out(current_symbol) = data_out(current_symbol) +...
                            data((current_symbol - 1) * bits_per_symbol + current_bit) * 2^(current_bit - 1);
                    end
                end
            else
                data_out = data;
            end
        end

%**************************************************************************

        function [data_out, lfsr] = GetUsrPrbsData( obj,...
                                                    polynomial,...
                                                    seed,...
                                                    num_of_symbols,...
                                                    bits_per_symbol)
                      
            [data, lfsr]        = obj.GetPrbsData(  polynomial,...
                                                    seed,...
                                                    num_of_symbols * bits_per_symbol);          

            if bits_per_symbol > 1
                data_out = zeros(1, num_of_symbols);
                for current_symbol = 1:num_of_symbols
                    for current_bit = 1:bits_per_symbol
                        data_out(current_symbol) = data_out(current_symbol) +...
                            data((current_symbol - 1) * bits_per_symbol + current_bit) * 2^(current_bit - 1);
                    end
                end
            else
                data_out = data;
            end
        end

%**************************************************************************

        function data_out = GetUsrData(     obj,...
                                            data,...                                                    
                                            num_of_symbols,...
                                            bits_per_symbol)
                      
            num_of_input_bits = length(data);

            if bits_per_symbol > 1
                data_out = zeros(1, num_of_symbols);
                for current_symbol = 1:num_of_symbols
                    for current_bit = 1:bits_per_symbol
                        index_data = (current_symbol - 1) * bits_per_symbol + current_bit;
                        index_data = mod(index_data - 1, num_of_input_bits) + 1;
                        data_out(current_symbol) = data_out(current_symbol) +...
                            data(index_data) * 2^(current_bit - 1);
                    end
                end
            else
                data_out = data;
            end
        end
       
%**************************************************************************

        function walsh_codes = GetWalshCodes(obj, code_length, inverted)
            if ~exist('inverted','var')
                inverted = false;
            end

            matrix_dim = ceil(log2(code_length));
            matrix_dim = 2 ^ matrix_dim;
            
            walsh_codes = -1; %int8([-1, -1; -1, 1]);
            if inverted
                walsh_codes = - walsh_codes;
            end            
        
            while length(walsh_codes) < matrix_dim
                walsh_codes = [walsh_codes, walsh_codes; walsh_codes, -walsh_codes];
            end
            walsh_codes(walsh_codes == -1) = 0;
            walsh_codes = uint8(walsh_codes);
        end

%**************************************************************************

        function walsh_code = GetWalshCode(obj, code_length, code, inverted)
            if ~exist('inverted','var')
                inverted = false;
            end
            
            walsh_codes = obj.GetWalshCodes(code_length, inverted);
            if length(walsh_codes) <= code
                code = length(walsh_codes) - 1;
            end
            walsh_code = walsh_codes(code + 1, :);            
            walsh_code = walsh_code(1:code_length);            
        end


%**************************************************************************

        function polynomial = GetPrbsPolynomial(obj, prbs_seq)

            % X^0, X^1,....X^N
        
            polynomial = [1,0,0,0,0,0,1,1];
        
            switch prbs_seq
                case obj.PRBS_2
                    polynomial = [1,1,1];
        
                case obj.PRBS_3 
                    polynomial = [1,0,1,1];
        
                case obj.PRBS_4 
                    polynomial = [1,0,0,1,1];
        
                case obj.PRBS_5   
                    polynomial = [1,0,0,1,0,1];
        
                case obj.PRBS_6 
                    polynomial = [1,0,0,0,0,1,1];
        
                case obj.PRBS_7
                    polynomial = [1,0,0,0,0,0,1,1];
        
                case obj.PRBS_8 
                    polynomial = [1,0,0,0,1,1,1,0,1];
        
                case obj.PRBS_9
                    polynomial = [1,0,0,0,0,1,0,0,0,1];
        
                case obj.PRBS_10
                    polynomial = [1,0,0,0,0,0,0,1,0,0,1];
                    
                case obj.PRBS_11
                    polynomial = [1,0,0,0,0,0,0,0,0,1,0,1];
                    
                case obj.PRBS_12
                    polynomial = [1,0,0,0,0,0,1,0,1,0,0,1,1];
                    
                case obj.PRBS_13
                    polynomial = [1,0,0,0,0,0,0,0,0,1,1,0,1,1];
                    
                case obj.PRBS_14
                    polynomial = [1,0,0,0,0,0,0,0,0,1,0,1,0,1,1];
                    
                case obj.PRBS_15
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1];
                    
                case obj.PRBS_16
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,1,0,1,1,0,1];
                    
                case obj.PRBS_17
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1];
                    
                case obj.PRBS_18
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1];
                    
                case obj.PRBS_19 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1,1];
                    
                case obj.PRBS_20 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1];
                    
                case obj.PRBS_21   
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1];
                    
                case obj.PRBS_22
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1];
                    
                case obj.PRBS_23
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,1];
                    
                case obj.PRBS_24
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,1,1];
                    
                case obj.PRBS_25
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1];
                    
                case obj.PRBS_26 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,1,1];
                    
                case obj.PRBS_27 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1,1];
                    
                case obj.PRBS_28
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1];
                    
                case obj.PRBS_29  
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1];
                    
                case obj.PRBS_30 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,1,1];
                    
                case obj.PRBS_31 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1];
                    
                case obj.PRBS_32
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,0,1];
                    
                case obj.PRBS_33
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1];
                    
                case obj.PRBS_34
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1,1,0,0,1];
                    
                case obj.PRBS_35
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1];
                    
                case obj.PRBS_36 
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1];
                    
                case obj.PRBS_37
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,1,1];
                    
                case obj.PRBS_38
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1];
                    
                case obj.PRBS_39
                    polynomial = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1];
                    
            end
        
            polynomial = uint8(polynomial);
            % X^N, X^(N-1),....X^0
            polynomial = flip(polynomial);
        end

%**************************************************************************

        function symbol = GetIqMap( obj,...
                                    data, ...
                                    mod_scheme)

            bits_per_symbol = obj.GetModParam(mod_scheme);

            switch mod_scheme

                case obj.MOD_SCHEME_QAM32
                    lev                 = 6;
                    data                = data + 1;
                    data(data > 4)      = data(data > 4) + 1;
                    data(data > 29)     = data(data > 29) + 1;

                case obj.MOD_SCHEME_QAM128
                    lev                 = 12;
                    data                = data + 2;
                    data(data > 9)      = data(data > 9) + 4;
                    data(data > 21)     = data(data > 21) + 2;
                    data(data > 119)    = data(data > 119) + 2;
                    data(data > 129)    = data(data > 129) + 4;

                case obj.MOD_SCHEME_QAM512
                    lev                 = 24;
                    data                = data + 4;
                    data(data > 19)     = data(data > 19) + 8;
                    data(data > 43)     = data(data > 43) + 8;
                    data(data > 67)     = data(data > 67) + 8;
                    data(data > 91)     = data(data > 91) + 4;
                    data(data > 479)    = data(data > 479) + 4;
                    data(data > 499)    = data(data > 499) + 8;
                    data(data > 523)    = data(data > 523) + 8;
                    data(data > 547)    = data(data > 547) + 8;

                otherwise
                    % QPSK, QAM16, QAM64, QAM256, QAM1024
                    lev                 = 2 ^ (bits_per_symbol / 2); 
            end

            if mod_scheme == obj.MOD_SCHEME_BPSK
                symb_i = data;
                symb_i(symb_i > 0.5) = 1.0;
                symb_i(symb_i <= 0.5) = -1.0;
                symbol = complex(symb_i);
            else
                symb_i  = floor(data / lev);
                symb_q  = mod(data, lev);
                lev     = lev / 2 - 0.5;   
                symb_i  = (symb_i - lev) / lev;
                symb_q  = (symb_q - lev) / lev;
                symbol  = symb_i + 1i * symb_q;
            end
        end

%**************************************************************************

        function [  amplitude,...
                    phase] = GetApskSymbols(    obj,...
                                                radius,...
                                                symbols_per_radius, ...
                                                initial_phase)
            num_of_amp_lvls = length(radius);
            num_of_symbols = sum(symbols_per_radius);
        
            amplitude = zeros(1, num_of_symbols);
            phase = amplitude;
        
            current_symbol = 1;
        
            for lvl = 1:num_of_amp_lvls
                delta_phase = 360.0/symbols_per_radius(lvl);
                for symbol = 1:symbols_per_radius(lvl)
                    amplitude(current_symbol) = radius(lvl);
                    phase(current_symbol) = initial_phase(lvl) + delta_phase * (symbol - 1);
                    current_symbol = current_symbol + 1;
                end
            end
        
            % Normalization for avg power = 1.0
        
            rms_ampl = sqrt(sum(amplitude .* amplitude) / num_of_symbols);
            amplitude = amplitude / rms_ampl;
        end

%**************************************************************************

        function symbols = SymbolsToComplex(obj, amplitude, phase)
            symbols = amplitude .* exp(1i * phase * pi/180.0);
        end

%**************************************************************************

        function symbol = GetDvbs2Map(  obj,...
                                        data, ...
                                        mod_scheme,...
                                        hp_code,...
                                        lp_code,...
                                        teta)

            bits_per_symbol = obj.GetModParam(mod_scheme);

            % MOD_SCHEME_8PSK
            radius = 1.0;
            symbols_per_radius = 8;
            initial_phase = 0;
            
            [   amplitude,...
                phase] = obj.GetApskSymbols(    radius,...
                                                symbols_per_radius, ...
                                                initial_phase);            
            symbol_map          = [2, 1, 5, 6, 3, 8, 4, 7];

            switch mod_scheme                
                case obj.MOD_SCHEME_APSK16

                    gamma = 3.15;
                    switch hp_code
                        case obj.MOD_DVBS2_CODE_2_3
                            gamma = 3.15;

                        case obj.MOD_DVBS2_CODE_3_4
                            gamma = 2.85;

                        case obj.MOD_DVBS2_CODE_4_5
                            gamma = 2.75;

                        case obj.MOD_DVBS2_CODE_5_6
                            gamma = 2.70;

                        case obj.MOD_DVBS2_CODE_8_9
                            gamma = 2.60;

                        case obj.MOD_DVBS2_CODE_9_10
                            gamma = 2.57;                            
                    end

                    radius = [1.0, gamma];
                    symbols_per_radius = [4, 12];
                    initial_phase = [45.0, 15.0];
                    
                    [   amplitude,...
                        phase] = obj.GetApskSymbols(    radius,...
                                                        symbols_per_radius, ...
                                                        initial_phase);

                    symbol_map      = [6, 15, 9, 12, 5, 16, 10, 11,...
                                       7, 14, 8, 13, 1, 4, 2, 3];                    

                case obj.MOD_SCHEME_APSK32
                    
                    gamma_1 = 2.84;
                    gamma_2 = 5.27;
                    switch hp_code
                        case obj.MOD_DVBS2_CODE_3_4
                            gamma_1 = 2.84;
                            gamma_2 = 5.27;

                        case obj.MOD_DVBS2_CODE_4_5
                            gamma_1 = 2.72;
                            gamma_2 = 4.87;

                        case obj.MOD_DVBS2_CODE_5_6
                            gamma_1 = 2.64;
                            gamma_2 = 4.64;

                        case obj.MOD_DVBS2_CODE_8_9
                            gamma_1 = 2.54;
                            gamma_2 = 4.33;

                        case obj.MOD_DVBS2_CODE_9_10
                            gamma_1 = 2.53;
                            gamma_2 = 4.30;
                    end

                    radius              = [1.0, gamma_1, gamma_2];
                    symbols_per_radius  = [4, 12, 16];
                    initial_phase       = [45.0, 15.0, 0.0];

                    [   amplitude,...
                        phase] = obj.GetApskSymbols(    radius,...
                                                        symbols_per_radius, ...
                                                        initial_phase);                   

                    symbol_map          = [ 6, 7, 15, 14, 9, 8, 12, 13,...
                                            18, 20, 31, 29, 23, 21, 26, 27,...
                                            5, 1, 16, 4, 10, 2, 11, 3,...
                                            17, 19, 32, 30, 24, 22, 25, 27];
                 
            end

            data = mod(data, 2^bits_per_symbol);
            data = data + 1;
            symbol = symbol_map(data);
            symbol  = amplitude(symbol) .* exp(1i * phase(symbol) * pi / 180.0);       
        end

%**************************************************************************

        function waveform = GetQamClock(    obj,...
                                            mod_settings, ...
                                            div_factor)    
    
            oversampling    = round(mod_settings.oversampling);
            div_factor      = round(div_factor);

            % out_wfm = WfmExpand(obj, wfm, expand_factor)
  
            % Get basic clock signal
            waveform            = zeros(1, mod_settings.num_of_symbols);
            waveform(1:2:end)   = +1.0;
            waveform(2:2:end)   = -1.0;
            waveform            = obj.WfmExpand(waveform, div_factor);            
            
            % Adapt I/Q sample rate to the Oversampling parameter
            waveform = obj.ZeroPadding(waveform, oversampling);
           
            % Calculate baseband shaping filter
            % accuracy is the length of-1 the shaping filter
            accuracy        = 512;
            baseband_filter = rcosdesign(   1.0, ...
                                            accuracy, ...
                                            mod_settings.oversampling, ...
                                            'normal');
        
            % Apply filter through circular convolution and calculate Fs
            waveform = cconv(waveform, baseband_filter, length(waveform));    
        end

%**************************************************************************
    
    function tone_wfm = GetTones(obj, freq, ampl, phase, sample_rate, wfm_length)
        % This function calculates any number of complex tones (positive and/or
        % negative frequencies) with arbitrary frequencies, amplitude, and
        % phase settings.
        tone_wfm        = complex(zeros(1, wfm_length));
        % Length of amp and phase vectors must eb equal or longer than freq
        num_of_tones    = length(freq);
        % X values required for efficient calculation of tones
        x_values        = 1:wfm_length;
        x_values        = x_values - 1;
        x_values        = 2 * pi * x_values / wfm_length;
        % All the tones are calculated one by one and accumulated to the final
        % group waveform
        for current_tone = 1:num_of_tones
            num_of_cycles   = (wfm_length / sample_rate) * freq(current_tone);
            num_of_cycles   = round(num_of_cycles);
            tone            = exp(1i * (num_of_cycles * x_values + phase(current_tone)));
            tone_wfm        = tone_wfm + ampl(current_tone) * tone;
        end
    end

%**************************************************************************

        function [waveform, Fs] = GetMultiTone( obj,...
                                                mtone_settings)

            % Compute maximum frequency component in the signal
            max_freq    = (mtone_settings.num_of_tones - 1) * mtone_settings.spacing / 2.0;
            max_freq    = max_freq + mtone_settings.spacing * mtone_settings.offset_tone;
            % Sample rate for calcualtion will be twice the maximum freq x
            % oversampling factor
            Fs          = mtone_settings.oversampling * 2.0 * max_freq;
            % Tone frequency calculation
            tone_freq   = 0:(mtone_settings.num_of_tones - 1);
            tone_freq   = tone_freq - (mtone_settings.num_of_tones - 1.0) / 2.0;
            tone_freq   = mtone_settings.spacing * tone_freq; 
            tone_freq   = tone_freq + mtone_settings.spacing * mtone_settings.offset_tone;
        
            % Time window will be the minimum one: 1 / spacing
            % It must be double when the number of tones is even for symmetrical
            % spectrum around carrier frequency.
            if mod(mtone_settings.num_of_tones,2) == 1
                time_window = 1.0 / mtone_settings.spacing;
            else
                time_window = 2.0 / mtone_settings.spacing;
            end

            time_window = time_window * mtone_settings.num_of_repeats;
        
            % Waveform length must be an integer
            wfm_length  = round(Fs * time_window);
            % Fs must be recalculated after rounding wavweform length
            Fs          = wfm_length / time_window;
            % Time values for samples
            x_data      = 0 :(wfm_length -1);
            x_data      = x_data / Fs;
            % Phase distribution for PAPR reduction is selected. Newman = 2.
            tones_phase = obj.MtonePhaseDistr(mtone_settings);
            % Waveform data is initialized to zero 
            waveform    = zeros(1, wfm_length);
            % The contribution of each tone is added to the waveform
            for k = 1 : mtone_settings.num_of_tones
                if k < mtone_settings.notch_start ||...
                        k > (mtone_settings.notch_start + mtone_settings.notch_size - 1)
                    waveform = waveform + ...
                        exp(1i * (x_data * 2 * pi * tone_freq(k) + tones_phase(k)));
                end
            end  
        end

%**************************************************************************

        function phase_table = MtonePhaseDistr(obj, mtone_settings)

            switch mtone_settings.phase_distr
                case obj.MTONE_PHASE_CONSTANT
                    phase_table = zeros(1, mtone_settings.num_of_tones);
                
                case obj.MTONE_PHASE_RANDOM
                    phase_table = 2.0 * pi .* (rand(1, mtone_settings.num_of_tones) - 0.5);
        
                case obj.MTONE_PHASE_NEWMAN
                    phase_table = 1:mtone_settings.num_of_tones;
                    phase_table = wrapToPi(-(pi / mtone_settings.num_of_tones) .* ...
                        ( 1.0 - phase_table .* phase_table));
        
                case obj.MTONE_PHASE_RUDIN
                    % Rudin (near optimal for equal amplitude tones when number of
                    % tones = 2^N)
                    num_of_steps = int16(round(log(mtone_settings.num_of_tones) / log(2)));
            
                    if 2^num_of_steps < mtone_settings.num_of_tones
                        num_of_steps = num_of_steps + 1;
                    end 
        
                    num_of_steps = num_of_steps - 1; 
                    phase_table(1:2) = 1; 
                    % Rudin sequence construction
                    for n=1:num_of_steps       
                        m           = int16(length(phase_table) / 2);
                        phase_table = [phase_table, phase_table(1 : m),...
                            -phase_table(m + 1 : 2 * m)];        
                    end 
                    % Conversion to radians
                    phase_table = -0.5 * pi .* (phase_table(1 : mtone_settings.num_of_tones) - 1);
            end
        end

%**************************************************************************

function [wfm_length, Fs] = GetStdWfmSettings(  obj,...
                                                freq,...
                                                num_of_cycles,...
                                                oversampling,...
                                                granularity)
            if granularity <= 0
                granularity = 1;
            end

            wfm_length_max = num_of_cycles * oversampling;
            % Maximum multiple of granularity equal or lower than the ideal
            % waveform length (wfm_length_max). Equal or lower is chosen so
            % sample rate is equal or lower than the ideal sample rate.
            wfm_length = floor(wfm_length_max / granularity) * granularity;

            Fs = oversampling * freq;
            Fs = Fs * wfm_length / wfm_length_max;
end

%**************************************************************************

        function [waveform, Fs] = GetStdWfm(    obj,...
                                                signal_type,...
                                                freq,...
                                                phase,...
                                                duty_cycle,...
                                                num_of_cycles,...
                                                oversampling,...
                                                granularity)
            
            [wfm_length, Fs] = obj.GetStdWfmSettings(   freq,...
                                                        num_of_cycles,...
                                                        oversampling,...
                                                        granularity);      

            waveform = 1:wfm_length;
            waveform = waveform - 1;

            switch signal_type
                case obj.STD_FUNC_SINE
                    waveform = sin(waveform * num_of_cycles * 2 * pi / wfm_length + phase * pi / 180.0);

                case obj.STD_FUNC_TRIANGLE
                    
                    freq = num_of_cycles / wfm_length;                                        
                    waveform = sawtooth(2*pi*freq*waveform + phase * pi / 180.0, duty_cycle/100.0);

                case obj.STD_FUNC_SQUARE
                    freq = num_of_cycles / wfm_length;                                        
                    waveform = sawtooth(2*pi*freq*waveform + phase * pi / 180.0);
                    thres_lvl = 1.0 - 2 * duty_cycle / 100;

                    waveform(waveform > thres_lvl) = 1.0;
                    waveform(waveform <= thres_lvl) = -1.0;                    

                case obj.STD_FUNC_RAMP
                    freq = num_of_cycles / wfm_length;                                        
                    waveform = sawtooth(2*pi*freq*waveform + phase * pi / 180.0);
            end
        end
        

%**************************************************************************
% DEMODULATION FUNCTIONS
%**************************************************************************

        function ddc_wfm = GetSwDdcWfm(obj, rf_wfm, sample_rate, carrier_freq, decim_factor)

            num_of_frames   = size(rf_wfm, 1);
            num_of_samples  = size(rf_wfm, 2);
            out_length      = round(num_of_samples / decim_factor);
            ddc_wfm         = complex(zeros(num_of_frames, out_length));
            % Calculate Complex Carrier
            carrier_wfm     = 1:num_of_samples;
            carrier_wfm     = carrier_wfm - 1;
            carrier_wfm     = carrier_wfm / sample_rate;
            % IQ carrier generation
            carrier_wfm     = exp(1i * 2 * pi * carrier_freq * carrier_wfm);

            for current_frame = 1:num_of_frames                
                % Mixing
                iq_wfm  = complex(double(rf_wfm(current_frame, :)));
                iq_wfm  = iq_wfm .* carrier_wfm;  
                % Decimation
                ddc_wfm(current_frame, :)   = obj.ResamplingDirect( iq_wfm, ...
                                                                    out_length, ...
                                                                    false); 
            end
        end

        function ddc_wfm = GetSwDdcWfmMod(obj, rf_wfm, mod_setup)
            ddc_wfm = obj.GetSwDdcWfm(  rf_wfm,...
                                        mod_setup.sample_rate,...
                                        mod_setup.carrier_freq,--- ...
                                        mod_setup.decimation);            
        end

%**************************************************************************

        function [rxSig, sps] = QpskDemod(obj, fs, sRate, alfa, rxSig, symbolsToShow)    
            
            sps = 128;
            
            %rxSig = MyOldResampleWfm(rxSig, 5, fs, sps * sRate);
            rxSig = resample(rxSig,sps * sRate,fs);
          
            [rxFilter,...
                filterSpan]     = MyRxFilter(alfa);
            
            rxSig               = rxFilter(rxSig');
            
            rxSig               = rxSig((sps*filterSpan + 1):(length(rxSig) - sps*filterSpan));
            
            [delay, ampl]       = GetQpskSymbolDelay(rxSig, sps);
        
            rxSig               = sqrt(2.0) * rxSig / ampl;
            rxSig               = 2.0 * rxSig((delay + 1):end);
           
            [constPhase, evMin] = GetQpskPhase(sps, rxSig);   
          
            rxSig               = rxSig * exp(1i * constPhase * pi / 180.0);
            numOfSymbols        = floor(length(rxSig) / sps);
            numOfSymbols        = numOfSymbols - filterSpan;
            starS               = floor (numOfSymbols / 2 - symbolsToShow / 2);
            finalS              = starS + symbolsToShow;
            if starS < 0
                starS   = 0;
            end
            if finalS   >= numOfSymbols
                finalS  = numOfSymbols - 1;
            end
            
            starS   = starS*sps + 1; 
            finalS  = finalS*sps;   
            rxSig   = rxSig(starS:finalS);
        end

        function out_vector = AddVectorCirc(obj, vector_1, vector_2, start_sample)
            out_vector      = vector_1;
            start_sample    = start_sample - round(length(vector_2) / 2);
            out_idxs        = start_sample:(start_sample + length(vector_2) - 1);
            out_idxs        = mod(out_idxs - 1, length(vector_1)) + 1;

            out_vector...
                (out_idxs)  = vector_1(out_idxs) + vector_2;
        end

%**************************************************************************

        function [  dac_control_freq_reg,... 
                    adc_control_freq_reg,...
                    freq_dac,...
                    freq_adc] =     GetFreqRegisters(   obj,...
                                                        carrier_freq, ...
                                                        dac_sampling_rate, ...
                                                        dac_adc_ratio, ...
                                                        size_nco_dac, ...
                                                        size_nco_adc)
            % Calculation of Frequency Control Registers
                
            % Calculate Raw Value for DAC
            dac_control_freq_reg_raw =...
                uint64(round(2^size_nco_dac * carrier_freq / dac_sampling_rate));
            
            % Keep in the two first Nyquist Zones (not necessary as same operation
            % is performed by the mask below. It is here for clarity
            dac_control_freq_reg_raw = ...
                mod(dac_control_freq_reg_raw, 2^size_nco_dac);
            
            % Calculate the number of bits to keep to make sure coherent operation
            % is possible. The number of zeros at the end depends on the size of
            % the adc frequency control register. It can be extended by some
            % additional bits depending on the ratio between DAC and ADC sample
            % rates as the important number of zeros is the one after multiplying
            % the frequency control word by this ratio
            num_of_valid_bits = size_nco_adc + int16(log2(dac_adc_ratio));
            
            % mask calculation
            mask_for_adc_compatibility = 2^(uint64(num_of_valid_bits)) - 1;
            mask_for_adc_compatibility =...
                mask_for_adc_compatibility * ...
                2^(uint64(size_nco_dac - num_of_valid_bits));
            
            % application of the mask
            dac_control_freq_reg =...
                bitand(dac_control_freq_reg_raw, mask_for_adc_compatibility);
            
            % Proper rounding for better frequency accuracy. Not applied in the
            % associated document.
            if ((dac_control_freq_reg_raw - dac_control_freq_reg >=...
                    2^(size_nco_dac - num_of_valid_bits - 1)))
                dac_control_freq_reg =...
                    dac_control_freq_reg +...
                    uint64(2^(size_nco_dac - num_of_valid_bits));
            end
            
            % Calculation of the frequency control register for the ADC
            adc_control_freq_reg = dac_adc_ratio * dac_control_freq_reg;
            
            % Size adjustment to the ADC Frequency Control Register
            adc_control_freq_reg = adc_control_freq_reg /...
                2^(uint64(size_nco_dac - size_nco_adc));
            
            % Keep in the two first Nyquist Zones
            adc_control_freq_reg = mod(adc_control_freq_reg, 2^size_nco_adc);
            
            % Calculation of the frequencies in the first or second Nyquist Zone of
            % the ADC
            % Frequency will be calculated in MHz
            dac_sampling_rate_mhz = uint64(dac_sampling_rate / 1000000);
            
            freq_dac =...
                double(dac_control_freq_reg) *...
                double(dac_sampling_rate_mhz) / 2^size_nco_dac;
            while freq_dac >= double(dac_sampling_rate_mhz / dac_adc_ratio)
                freq_dac = freq_dac - double(dac_sampling_rate_mhz / dac_adc_ratio);
            end
            
            freq_adc = double(adc_control_freq_reg) *...
                double(dac_sampling_rate_mhz / dac_adc_ratio) / 2^size_nco_adc;
        end

%**************************************************************************

    end % public methods

   
%**************************************************************************
%**************************************************************************

    methods (Access = private) % private methods

       
    end % private methods
end