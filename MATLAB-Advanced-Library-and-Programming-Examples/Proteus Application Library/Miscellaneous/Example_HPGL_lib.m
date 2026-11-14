% XY_Plot_Example


myLib = TEProteusLib();

%fileName = "pxilogo.plt";
fileName = "taborlogo.plt";

[x_coord, y_coord, z_flag] = myLib.ReadPlt(fileName,10,true);
