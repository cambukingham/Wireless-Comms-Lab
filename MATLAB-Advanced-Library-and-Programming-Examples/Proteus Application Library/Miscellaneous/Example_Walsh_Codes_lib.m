clear;
close all;
clear variables;
clear global;
clc;

proteus_lib = TEProteusLib();

walsh_codes = proteus_lib.GetWalshCode(8,7)

walsh_codes_inverted = proteus_lib.GetWalshCode(128,7,false)